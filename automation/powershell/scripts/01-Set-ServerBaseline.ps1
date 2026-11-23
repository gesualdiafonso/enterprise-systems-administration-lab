#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / Part B - Windows Server baseline for NX-DC01 (before AD DS).

.DESCRIPTION
    Idempotent. Safe to run several times.
      1. Verifies the private IP is the reserved address (10.20.1.10).
      2. Sets the time zone.
      3. Sets the built-in Administrator password from SSM Parameter Store
         (break-glass account; required before promotion - it becomes the
         domain Administrator password).
      4. Ensures Windows Defender Firewall is ON for all profiles and logs drops.
      5. Validates Server Manager / the ServerManager module.
      6. Renames the computer to NX-DC01. If a rename is needed the script exits
         with code 3010: SSM Run Command then REBOOTS the instance and RUNS THIS
         SCRIPT AGAIN, which finds everything already done and exits 0.

    Windows Update is applied separately with the AWS-managed SSM document
    AWS-InstallWindowsUpdates (see automation/powershell/README.md).

.EXAMPLE
    # From the workstation (macOS):
    ./automation/aws-cli/run-dc-script.sh 01-Set-ServerBaseline.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '01-Set-ServerBaseline'
$cfg = Import-NxConfig -Path $ConfigPath
$isDc = Test-NxDomainController

# --- 1. Reserved private IP ---------------------------------------------------
Write-NxLog -Level STEP -Message 'Checking private IPv4 address'
$ips = @(Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp, Manual -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '169.254.*' } | Select-Object -ExpandProperty IPAddress)
if ($ips -contains $cfg.Server.PrivateIp) {
    Write-NxLog -Level OK -Message "Private IP is $($cfg.Server.PrivateIp) (reserved by the ENI, delivered by AWS DHCP)"
}
else {
    throw "Expected private IP $($cfg.Server.PrivateIp) but found: $($ips -join ', '). Check private_ip in Terraform."
}

# --- 2. Time zone -------------------------------------------------------------
Write-NxLog -Level STEP -Message 'Time zone'
if ((Get-TimeZone).Id -ne $cfg.Server.TimeZone) {
    Set-TimeZone -Id $cfg.Server.TimeZone
    Write-NxLog -Level OK -Message "Time zone set to $($cfg.Server.TimeZone)"
}
else {
    Write-NxLog -Level OK -Message "Time zone already $($cfg.Server.TimeZone)"
}

# --- 3. Built-in Administrator password (break-glass) -------------------------
Write-NxLog -Level STEP -Message 'Built-in Administrator password'
if ($isDc) {
    Write-NxLog -Level WARN -Message 'Server is already a domain controller: local accounts no longer exist, skipping.'
}
else {
    $adminName = (Get-LocalUser | Where-Object { $_.SID.Value -like 'S-1-5-*-500' }).Name
    $secret = Get-NxSecret -Name $cfg.Secrets.AdministratorPassword
    Set-LocalUser -Name $adminName -Password $secret -PasswordNeverExpires $true
    Enable-LocalUser -Name $adminName
    $secret = $null
    Write-NxLog -Level OK -Message "Password of '$adminName' set from $($cfg.Secrets.AdministratorPassword) (value not logged)"
}

# --- 4. Windows Defender Firewall --------------------------------------------
Write-NxLog -Level STEP -Message 'Windows Defender Firewall'
$fwLog = '%systemroot%\system32\LogFiles\Firewall\pfirewall.log'
foreach ($p in Get-NetFirewallProfile) {
    if ($p.Enabled -ne 'True' -or $p.DefaultInboundAction -ne 'Block' -or $p.LogBlocked -ne 'True') {
        Set-NetFirewallProfile -Name $p.Name -Enabled True -DefaultInboundAction Block `
            -DefaultOutboundAction Allow -LogBlocked True -LogFileName $fwLog -LogMaxSizeKilobytes 16384
        Write-NxLog -Level OK -Message "Firewall profile $($p.Name): enabled, inbound Block, dropped packets logged"
    }
    else {
        Write-NxLog -Level OK -Message "Firewall profile $($p.Name) already compliant"
    }
}

# --- 5. Server Manager --------------------------------------------------------
Write-NxLog -Level STEP -Message 'Server Manager'
Import-Module ServerManager
$installed = Get-WindowsFeature | Where-Object { $_.Installed -and $_.FeatureType -eq 'Role' }
Write-NxLog -Level OK -Message ("ServerManager module OK. Installed roles: {0}" -f (($installed.Name) -join ', '))

# --- 6. Hostname (last: may reboot) -------------------------------------------
Write-NxLog -Level STEP -Message 'Computer name'
if ($env:COMPUTERNAME -ne $cfg.Server.ComputerName) {
    if ($isDc) { throw 'Refusing to rename a domain controller.' }
    Write-NxLog -Message "Renaming $env:COMPUTERNAME -> $($cfg.Server.ComputerName)"
    Rename-Computer -NewName $cfg.Server.ComputerName -Force
    Write-NxLog -Level WARN -Message 'Exit 3010: SSM will reboot the instance and run this script again.'
    exit 3010
}
Write-NxLog -Level OK -Message "Computer name is $($cfg.Server.ComputerName)"

Write-NxLog -Level OK -Message 'Baseline complete.'
exit 0
