#Requires -Version 5.1
<#
.SYNOPSIS
    Part F - Verify DNS on NX-DC01 (read-only).

.DESCRIPTION
      * zones: type, AD integration, replication scope, dynamic updates
      * forwarders and root-hint fallback
      * DNS client settings of the DC's network adapter
      * resolution tests against 127.0.0.1: DC A/PTR, SRV records, configured
        A/CNAME records, external name, AWS SSM endpoints
    Exit code 0 = all resolution tests passed, 1 = at least one failed.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 24-Test-NxDns.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force
Start-NxLog -ScriptName '24-Test-NxDns'
$cfg = Import-NxConfig -Path $ConfigPath
Import-Module DnsServer
$zone = $cfg.Domain.DnsName
$dcFqdn = "$($cfg.Server.ComputerName.ToLower()).$zone"

Write-NxLog -Level STEP -Message 'Zones'
Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated } |
    Select-Object ZoneName, ZoneType, IsDsIntegrated, ReplicationScope, DynamicUpdate, IsReverseLookupZone | Write-NxTable

Write-NxLog -Level STEP -Message 'Forwarders'
$f = Get-DnsServerForwarder
Write-NxLog -Message ("Forwarders: {0} | UseRootHint: {1} | Timeout: {2}s" -f (($f.IPAddress | ForEach-Object IPAddressToString) -join ', '), $f.UseRootHint, $f.Timeout)

Write-NxLog -Level STEP -Message 'DNS client of NX-DC01'
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } |
    Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } } | Write-NxTable

Write-NxLog -Level STEP -Message 'Resolution tests (server 127.0.0.1)'
$region = Get-NxRegion
$tests = @(
    @{ Name = $dcFqdn; Type = 'A'; Expect = $cfg.Server.PrivateIp }
    @{ Name = $cfg.Server.PrivateIp; Type = 'PTR'; Expect = $dcFqdn }
    @{ Name = "_ldap._tcp.dc._msdcs.$zone"; Type = 'SRV'; Expect = $dcFqdn }
    @{ Name = "_kerberos._tcp.$zone"; Type = 'SRV'; Expect = $dcFqdn }
    @{ Name = $zone; Type = 'A'; Expect = $cfg.Server.PrivateIp }
)
foreach ($a in $cfg.Dns.ARecords) { $tests += @{ Name = "$($a.Name).$zone"; Type = 'A'; Expect = $a.IPv4 } }
foreach ($c in $cfg.Dns.CnameRecords) { $tests += @{ Name = "$($c.Name).$zone"; Type = 'CNAME'; Expect = $c.Target } }
$tests += @{ Name = 'www.amazon.com'; Type = 'A'; Expect = $null }
foreach ($ep in 'ssm', 'ssmmessages', 'ec2messages') { $tests += @{ Name = "$ep.$region.amazonaws.com"; Type = 'A'; Expect = $null } }

$failed = 0
$rows = foreach ($t in $tests) {
    $answer = $null
    try {
        $r = @(Resolve-DnsName -Name $t.Name -Type $t.Type -Server 127.0.0.1 -DnsOnly -QuickTimeout -ErrorAction Stop)
        $answer = switch ($t.Type) {
            'A' { @($r | Where-Object Type -EQ 'A' | ForEach-Object IPAddress) }
            'PTR' { @($r | Where-Object Type -EQ 'PTR' | ForEach-Object { $_.NameHost.TrimEnd('.') }) }
            'SRV' { @($r | Where-Object Type -EQ 'SRV' | ForEach-Object { $_.NameTarget.TrimEnd('.') }) }
            'CNAME' { @($r | Where-Object Type -EQ 'CNAME' | ForEach-Object { $_.NameHost.TrimEnd('.') }) }
        }
    }
    catch { $answer = @() }
    $ok = if ($t.Expect) { $answer -contains $t.Expect } else { $answer.Count -gt 0 }
    if (-not $ok) { $failed++ }
    [pscustomobject]@{
        Type   = $t.Type
        Query  = $t.Name
        Answer = if ($answer) { ($answer | Select-Object -First 3) -join ', ' } else { '(no answer)' }
        Result = if ($ok) { 'PASS' } else { 'FAIL' }
    }
}
$rows | Write-NxTable

if ($failed -eq 0) { Write-NxLog -Level OK -Message 'DNS: all tests passed'; exit 0 }
Write-NxLog -Level ERROR -Message "DNS: $failed test(s) failed"
exit 1
