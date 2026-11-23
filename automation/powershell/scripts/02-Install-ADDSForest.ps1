#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / AD-001..AD-003 - Install AD DS + DNS and create the nexora.local forest.

.DESCRIPTION
    Two-phase, idempotent script driven by SSM Run Command:

    PHASE A (server is not yet a DC)
      1. Requires the computer name NX-DC01 (run 01-Set-ServerBaseline.ps1 first).
      2. Installs AD-Domain-Services, DNS and GPMC with management tools.
      3. Reads the DSRM password from SSM Parameter Store.
      4. Runs Test-ADDSForestInstallation, then Install-ADDSForest
         (nexora.local / NEXORA, Windows Server 2016 functional level).
      5. Adds the VPC resolver (10.20.0.2) as DNS forwarder BEFORE the reboot, so
         the SSM Agent can still resolve AWS endpoints once the DC uses its own DNS.
      6. Exits 3010 -> SSM reboots the instance and runs the script again.

    PHASE B (server is a DC - also the re-run after the reboot)
      7. Waits for Active Directory Web Services.
      8. Ensures the DNS forwarder and points the DNS client to itself.
      9. Configures the PDC emulator to sync time from Amazon Time Sync.
     10. Creates the domain account ssm-user (Domain Admins) required by
         Session Manager on domain controllers (AWS SSM Agent >= 2.3.612.0).
     11. Prints a health summary (services, SYSVOL/NETLOGON, name resolution).

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 02-Install-ADDSForest.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '02-Install-ADDSForest'
$cfg = Import-NxConfig -Path $ConfigPath
$resolver = $cfg.Server.VpcResolver

function Set-NxDnsForwarder {
    param([string]$Address)
    Import-Module DnsServer -ErrorAction Stop
    $current = @((Get-DnsServerForwarder).IPAddress | ForEach-Object { $_.IPAddressToString })
    if ($current -notcontains $Address) {
        Set-DnsServerForwarder -IPAddress $Address -UseRootHint $true
        Write-NxLog -Level OK -Message "DNS forwarder set to $Address (root hints kept as fallback)"
    }
    else {
        Write-NxLog -Level OK -Message "DNS forwarder already $Address"
    }
}

# =============================================================================
# PHASE A - promote
# =============================================================================
if (-not (Test-NxDomainController)) {
    Write-NxLog -Level STEP -Message 'PHASE A - install AD DS and create the forest'

    if ($env:COMPUTERNAME -ne $cfg.Server.ComputerName) {
        throw "Computer name is $env:COMPUTERNAME. Run 01-Set-ServerBaseline.ps1 first (expected $($cfg.Server.ComputerName))."
    }

    Write-NxLog -Level STEP -Message 'AD-001 Installing AD-Domain-Services, DNS, GPMC'
    $result = Install-WindowsFeature -Name AD-Domain-Services, DNS, GPMC -IncludeManagementTools
    Write-NxLog -Level OK -Message ("Features installed. Success={0} RestartNeeded={1}" -f $result.Success, $result.RestartNeeded)

    $forestParams = @{
        DomainName                    = $cfg.Domain.DnsName
        DomainNetbiosName             = $cfg.Domain.NetBiosName
        ForestMode                    = $cfg.Domain.ForestMode
        DomainMode                    = $cfg.Domain.DomainMode
        InstallDns                    = $true
        CreateDnsDelegation           = $false
        DatabasePath                  = 'C:\Windows\NTDS'
        LogPath                       = 'C:\Windows\NTDS'
        SysvolPath                    = 'C:\Windows\SYSVOL'
        SafeModeAdministratorPassword = (Get-NxSecret -Name $cfg.Secrets.DsrmPassword)
        NoRebootOnCompletion          = $true
        Force                         = $true
    }

    Write-NxLog -Level STEP -Message 'AD-002 Test-ADDSForestInstallation (prerequisite check)'
    $test = Test-ADDSForestInstallation @forestParams -WarningAction SilentlyContinue
    if ($test.Status -ne 'Success') {
        throw "Prerequisite check failed: $($test.Message)"
    }
    Write-NxLog -Level OK -Message 'Prerequisites OK'

    Write-NxLog -Level STEP -Message "AD-003 Install-ADDSForest $($cfg.Domain.DnsName) ($($cfg.Domain.NetBiosName))"
    $promo = Install-ADDSForest @forestParams -WarningAction SilentlyContinue
    $forestParams.SafeModeAdministratorPassword = $null
    if ($promo.Status -ne 'Success') {
        throw "Install-ADDSForest failed: $($promo.Message)"
    }
    Write-NxLog -Level OK -Message 'Forest created. Reboot required.'

    # Safety net for SSM: make sure the new DNS server can resolve AWS endpoints.
    try { Set-NxDnsForwarder -Address $resolver }
    catch { Write-NxLog -Level WARN -Message "Could not set forwarder before reboot (will retry in phase B): $($_.Exception.Message)" }

    Write-NxLog -Level WARN -Message 'Exit 3010: SSM will reboot NX-DC01 and run this script again (phase B).'
    exit 3010
}

# =============================================================================
# PHASE B - post-promotion configuration
# =============================================================================
Write-NxLog -Level STEP -Message 'PHASE B - post-promotion configuration'
$domain = Wait-NxActiveDirectory

Write-NxLog -Level STEP -Message 'DNS forwarder and DNS client'
Set-NxDnsForwarder -Address $resolver
$nic = Get-NetAdapter -Physical | Where-Object Status -EQ 'Up' | Select-Object -First 1
$wantedDns = @($cfg.Server.PrivateIp, '127.0.0.1')
$currentDns = @((Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4).ServerAddresses)
if (($currentDns -join ',') -ne ($wantedDns -join ',')) {
    Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $wantedDns
    Write-NxLog -Level OK -Message "DNS client on '$($nic.Name)' set to $($wantedDns -join ', ')"
}
else {
    Write-NxLog -Level OK -Message "DNS client already $($wantedDns -join ', ')"
}

Write-NxLog -Level STEP -Message 'Time source (PDC emulator -> Amazon Time Sync 169.254.169.123)'
& w32tm.exe /config /manualpeerlist:'169.254.169.123,0x8' /syncfromflags:manual /reliable:yes /update | Out-Null
Restart-Service -Name W32Time
& w32tm.exe /resync /nowait | Out-Null
Write-NxLog -Level OK -Message ("Time source: {0}" -f ((& w32tm.exe /query /source) -join ' ').Trim())

Write-NxLog -Level STEP -Message 'ssm-user for Session Manager on a domain controller'
$ssmUser = Get-ADUser -Filter "SamAccountName -eq 'ssm-user'" -ErrorAction SilentlyContinue
if (-not $ssmUser) {
    New-ADUser -Name 'ssm-user' -SamAccountName 'ssm-user' `
        -UserPrincipalName "ssm-user@$($cfg.Domain.UpnSuffix)" `
        -Description 'AWS Session Manager run-as account on NX-DC01 (password rotated by SSM Agent). Monitored.' `
        -AccountPassword (New-NxRandomPassword) -Enabled $true -PasswordNeverExpires $true
    Write-NxLog -Level OK -Message 'ssm-user created (CN=Users)'
}
if (-not (Get-ADGroupMember -Identity 'Domain Admins' | Where-Object SamAccountName -EQ 'ssm-user')) {
    Add-ADGroupMember -Identity 'Domain Admins' -Members 'ssm-user'
    Write-NxLog -Level OK -Message 'ssm-user added to Domain Admins (documented exception)'
}

Write-NxLog -Level STEP -Message 'Health summary'
$forest = Get-ADForest
Write-NxLog -Level OK -Message ("Domain {0} / NetBIOS {1} / DomainMode {2} / ForestMode {3}" -f $domain.DNSRoot, $domain.NetBIOSName, $domain.DomainMode, $forest.ForestMode)
foreach ($svc in 'NTDS', 'DNS', 'Netlogon', 'ADWS', 'Kdc', 'W32Time') {
    $s = Get-Service -Name $svc
    $level = if ($s.Status -eq 'Running') { 'OK' } else { 'WARN' }
    Write-NxLog -Level $level -Message "Service $svc : $($s.Status)"
}
foreach ($share in 'SYSVOL', 'NETLOGON') {
    if (Get-SmbShare -Name $share -ErrorAction SilentlyContinue) { Write-NxLog -Level OK -Message "Share $share present" }
    else { Write-NxLog -Level WARN -Message "Share $share not yet present (SYSVOL initialisation can take a few minutes)" }
}
$region = Get-NxRegion
foreach ($name in "$($cfg.Server.ComputerName).$($cfg.Domain.DnsName)", "ssm.$region.amazonaws.com", "ssmmessages.$region.amazonaws.com") {
    try {
        $r = Resolve-DnsName -Name $name -Server 127.0.0.1 -Type A -DnsOnly -ErrorAction Stop | Where-Object Type -EQ 'A' | Select-Object -First 1
        Write-NxLog -Level OK -Message "Resolve $name -> $($r.IPAddress)"
    }
    catch { Write-NxLog -Level ERROR -Message "Cannot resolve $name : $($_.Exception.Message)" }
}

Write-NxLog -Level OK -Message 'Domain controller ready. Next: 03-New-ADOrganizationalUnits.ps1'
exit 0
