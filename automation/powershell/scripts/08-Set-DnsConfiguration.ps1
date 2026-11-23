#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / DNS-001..DNS-004 - Windows DNS on NX-DC01.

.DESCRIPTION
    Idempotent.
      DNS-001  Verifies the DNS Server role and service.
      DNS-002  Verifies the AD-integrated zone nexora.local (created by the
               promotion) and enforces secure-only dynamic updates.
               Creates the AD-integrated reverse zone 1.20.10.in-addr.arpa and
               the PTR record of NX-DC01.
      DNS-003  Creates static A records (+PTR) and CNAME records from the config
               (e.g. nx-lnx01 A 10.20.1.20, intranet CNAME nx-lnx01).
      DNS-004  Enforces the forwarder to the VPC resolver (10.20.0.2) with
               root hints as fallback.
    Ends with resolution tests against 127.0.0.1.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 08-Set-DnsConfiguration.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '08-Set-DnsConfiguration'
$cfg = Import-NxConfig -Path $ConfigPath
if (-not (Test-NxDomainController)) { throw 'Not a domain controller. Run 02-Install-ADDSForest.ps1 first.' }
Import-Module DnsServer
$zone = $cfg.Domain.DnsName
$dns = $cfg.Dns

# --- DNS-001 ------------------------------------------------------------------
Write-NxLog -Level STEP -Message 'DNS-001 DNS Server role'
if (-not (Get-WindowsFeature -Name DNS).Installed) { throw 'DNS Server role is not installed.' }
$svc = Get-Service -Name DNS
if ($svc.Status -ne 'Running') { Start-Service -Name DNS }
Write-NxLog -Level OK -Message 'DNS Server role installed and service running'

# --- DNS-002 ------------------------------------------------------------------
Write-NxLog -Level STEP -Message "DNS-002 Forward zone $zone"
$fwd = Get-DnsServerZone -Name $zone -ErrorAction SilentlyContinue
if (-not $fwd) { throw "Zone $zone not found - the promotion should have created it." }
if (-not $fwd.IsDsIntegrated) { throw "Zone $zone is not AD-integrated." }
if ($fwd.DynamicUpdate -ne 'Secure') {
    Set-DnsServerPrimaryZone -Name $zone -DynamicUpdate Secure
    Write-NxLog -Level OK -Message "$zone dynamic updates set to Secure"
}
Write-NxLog -Level OK -Message ("{0}: AD-integrated, replication {1}, updates {2}" -f $zone, $fwd.ReplicationScope, 'Secure')

# Reverse zone name from the network id, e.g. 10.20.1.0/24 -> 1.20.10.in-addr.arpa
$octets = ($dns.ReverseZoneNetworkId -split '/')[0] -split '\.'
$reverseZone = '{0}.{1}.{2}.in-addr.arpa' -f $octets[2], $octets[1], $octets[0]
Write-NxLog -Level STEP -Message "DNS-002 Reverse zone $reverseZone"
if (-not (Get-DnsServerZone -Name $reverseZone -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId $dns.ReverseZoneNetworkId -ReplicationScope $dns.ReplicationScope -DynamicUpdate Secure
    Write-NxLog -Level OK -Message "Created $reverseZone (AD-integrated, $($dns.ReplicationScope), secure updates)"
}
else {
    Write-NxLog -Level OK -Message "Exists  : $reverseZone"
}

function Set-NxPtr {
    param([string]$IPv4, [string]$Fqdn)
    $last = ($IPv4 -split '\.')[3]
    $existing = Get-DnsServerResourceRecord -ZoneName $reverseZone -Name $last -RRType Ptr -ErrorAction SilentlyContinue
    if ($existing) {
        Write-NxLog -Level OK -Message "PTR exists: $IPv4 -> $($existing.RecordData.PtrDomainName)"
        return
    }
    Add-DnsServerResourceRecordPtr -ZoneName $reverseZone -Name $last -PtrDomainName "$Fqdn."
    Write-NxLog -Level OK -Message "PTR created: $IPv4 -> $Fqdn"
}
Set-NxPtr -IPv4 $cfg.Server.PrivateIp -Fqdn "$($cfg.Server.ComputerName.ToLower()).$zone"

# --- DNS-003 ------------------------------------------------------------------
Write-NxLog -Level STEP -Message 'DNS-003 A and CNAME records'
foreach ($a in $dns.ARecords) {
    $existing = Get-DnsServerResourceRecord -ZoneName $zone -Name $a.Name -RRType A -ErrorAction SilentlyContinue
    if ($existing) {
        $ip = $existing.RecordData.IPv4Address.IPAddressToString
        if ($ip -ne $a.IPv4) { Write-NxLog -Level WARN -Message "A $($a.Name) is $ip, config says $($a.IPv4) - not changed" }
        else { Write-NxLog -Level OK -Message "A exists : $($a.Name) -> $ip" }
    }
    else {
        Add-DnsServerResourceRecordA -ZoneName $zone -Name $a.Name -IPv4Address $a.IPv4
        Write-NxLog -Level OK -Message "A created: $($a.Name).$zone -> $($a.IPv4)"
    }
    if ($a.CreatePtr) { Set-NxPtr -IPv4 $a.IPv4 -Fqdn "$($a.Name).$zone" }
}
foreach ($c in $dns.CnameRecords) {
    $existing = Get-DnsServerResourceRecord -ZoneName $zone -Name $c.Name -RRType CName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-NxLog -Level OK -Message "CNAME exists: $($c.Name) -> $($existing.RecordData.HostNameAlias)"
    }
    else {
        Add-DnsServerResourceRecordCName -ZoneName $zone -Name $c.Name -HostNameAlias "$($c.Target)."
        Write-NxLog -Level OK -Message "CNAME created: $($c.Name).$zone -> $($c.Target)"
    }
}

# --- DNS-004 ------------------------------------------------------------------
Write-NxLog -Level STEP -Message 'DNS-004 Forwarders'
$current = @((Get-DnsServerForwarder).IPAddress | ForEach-Object { $_.IPAddressToString })
if (($current -join ',') -ne ($dns.Forwarders -join ',')) {
    Set-DnsServerForwarder -IPAddress $dns.Forwarders -UseRootHint $true
    Write-NxLog -Level OK -Message "Forwarders set to $($dns.Forwarders -join ', ') (root hints fallback)"
}
else {
    Write-NxLog -Level OK -Message "Forwarders already $($dns.Forwarders -join ', ')"
}

# --- Tests --------------------------------------------------------------------
Write-NxLog -Level STEP -Message 'Resolution tests (server 127.0.0.1)'
$region = Get-NxRegion
$tests = @(
    @{ Name = "$($cfg.Server.ComputerName.ToLower()).$zone"; Type = 'A' }
    @{ Name = "_ldap._tcp.dc._msdcs.$zone"; Type = 'SRV' }
    @{ Name = $cfg.Server.PrivateIp; Type = 'PTR' }
    @{ Name = "ssm.$region.amazonaws.com"; Type = 'A' }
)
$tests += @($dns.CnameRecords | ForEach-Object { @{ Name = "$($_.Name).$zone"; Type = 'CNAME' } })
foreach ($t in $tests) {
    try {
        $r = @(Resolve-DnsName -Name $t.Name -Type $t.Type -Server 127.0.0.1 -DnsOnly -ErrorAction Stop)
        $answer = switch ($t.Type) {
            'A' { ($r | Where-Object Type -EQ 'A').IPAddress -join ', ' }
            'SRV' { ($r | Where-Object Type -EQ 'SRV').NameTarget -join ', ' }
            'PTR' { ($r | Where-Object Type -EQ 'PTR').NameHost -join ', ' }
            'CNAME' { ($r | Where-Object Type -EQ 'CNAME').NameHost -join ', ' }
        }
        Write-NxLog -Level OK -Message ("{0,-5} {1} -> {2}" -f $t.Type, $t.Name, $answer)
    }
    catch {
        Write-NxLog -Level ERROR -Message ("{0,-5} {1} -> FAILED: {2}" -f $t.Type, $t.Name, $_.Exception.Message)
    }
}

exit 0
