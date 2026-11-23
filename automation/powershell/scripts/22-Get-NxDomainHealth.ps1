#Requires -Version 5.1
<#
.SYNOPSIS
    AD-009 / Part F - Active Directory health report for nexora.local (read-only).

.DESCRIPTION
    Checks and summarises:
      * domain / forest, functional levels, FSMO role holders
      * critical services (NTDS, DNS, Netlogon, ADWS, KDC, DFSR, W32Time)
      * SYSVOL and NETLOGON shares, DFSR SYSVOL state
      * dcdiag core tests (pass/fail per test)
      * DC SRV records, time source and offset
      * errors in Directory Service / DNS Server / DFS Replication / System logs (24 h)
    Writes the full dcdiag output to C:\Nexora\reports\<date>\dcdiag.txt.
    Exit code 0 = healthy, 1 = at least one check failed.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 22-Get-NxDomainHealth.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1',
    [int]$EventHours = 24
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force
Start-NxLog -ScriptName '22-Get-NxDomainHealth'
$cfg = Import-NxConfig -Path $ConfigPath
$domain = Wait-NxActiveDirectory
$forest = Get-ADForest
$reportDir = Get-NxReportDir
$failures = 0
function Add-Result([bool]$Ok, [string]$Message) {
    if ($Ok) { Write-NxLog -Level OK -Message $Message } else { Write-NxLog -Level ERROR -Message $Message; $script:failures++ }
}

Write-NxLog -Level STEP -Message 'Domain and forest'
Write-NxLog -Message ("Domain {0} ({1}) - DomainMode {2}" -f $domain.DNSRoot, $domain.NetBIOSName, $domain.DomainMode)
Write-NxLog -Message ("Forest {0} - ForestMode {1}" -f $forest.Name, $forest.ForestMode)
Write-NxLog -Message ("FSMO: PDC={0} RID={1} Infra={2} Schema={3} Naming={4}" -f $domain.PDCEmulator, $domain.RIDMaster,
    $domain.InfrastructureMaster, $forest.SchemaMaster, $forest.DomainNamingMaster)

Write-NxLog -Level STEP -Message 'Services'
foreach ($s in 'NTDS', 'DNS', 'Netlogon', 'ADWS', 'Kdc', 'DFSR', 'W32Time') {
    $svc = Get-Service -Name $s
    Add-Result ($svc.Status -eq 'Running') "Service $s : $($svc.Status)"
}

Write-NxLog -Level STEP -Message 'SYSVOL / NETLOGON'
foreach ($share in 'SYSVOL', 'NETLOGON') {
    Add-Result ([bool](Get-SmbShare -Name $share -ErrorAction SilentlyContinue)) "Share $share"
}
try {
    $dfsr = Get-CimInstance -Namespace 'root\microsoftdfs' -ClassName DfsrReplicatedFolderInfo -Filter "ReplicatedFolderName='SYSVOL Share'"
    # State 4 = Normal
    Add-Result ($dfsr.State -eq 4) "DFSR SYSVOL state: $($dfsr.State) (4 = Normal)"
}
catch { Write-NxLog -Level WARN -Message "DFSR state not available: $($_.Exception.Message)" }

Write-NxLog -Level STEP -Message 'dcdiag'
$dcdiag = & dcdiag.exe /s:$env:COMPUTERNAME /c /skip:SystemLog /skip:DNS /skip:OutboundSecureChannels /skip:VerifyEnterpriseReferences /skip:CheckSDRefDom /skip:Topology /skip:CutoffServers /skip:Intersite
$dcdiag | Set-Content -Path (Join-Path $reportDir 'dcdiag.txt') -Encoding UTF8
$tests = foreach ($line in $dcdiag) {
    if ($line -match '\.+\s+(\S+)\s+(passed|failed) test\s+(\S+)') {
        [pscustomobject]@{ Test = $Matches[3]; Target = $Matches[1]; Result = $Matches[2] }
    }
}
$tests | Write-NxTable
$failed = @($tests | Where-Object Result -EQ 'failed')
Add-Result ($failed.Count -eq 0) ("dcdiag: {0} passed, {1} failed{2}" -f @($tests | Where-Object Result -EQ 'passed').Count, $failed.Count,
    $(if ($failed) { ' -> ' + (($failed.Test | Sort-Object -Unique) -join ', ') } else { '' }))

Write-NxLog -Level STEP -Message 'DC locator SRV records'
foreach ($srv in "_ldap._tcp.dc._msdcs.$($domain.DNSRoot)", "_kerberos._tcp.$($domain.DNSRoot)", "_gc._tcp.$($forest.Name)") {
    try {
        $r = @(Resolve-DnsName -Name $srv -Type SRV -Server 127.0.0.1 -DnsOnly -ErrorAction Stop | Where-Object Type -EQ 'SRV')
        Add-Result ($r.Count -gt 0) "$srv -> $(($r.NameTarget | Sort-Object -Unique) -join ', ')"
    }
    catch { Add-Result $false "$srv -> $($_.Exception.Message)" }
}

Write-NxLog -Level STEP -Message 'Time'
$source = ((& w32tm.exe /query /source) -join ' ').Trim()
Write-NxLog -Message "Time source: $source"
$offsetLine = (& w32tm.exe /stripchart /computer:169.254.169.123 /samples:1 /dataonly) | Select-Object -Last 1
Write-NxLog -Message "Offset vs Amazon Time Sync: $offsetLine"

Write-NxLog -Level STEP -Message "Errors in the last $EventHours h"
$since = (Get-Date).AddHours(-$EventHours)
foreach ($log in 'Directory Service', 'DNS Server', 'DFS Replication', 'System') {
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = $log; Level = 1, 2; StartTime = $since } -ErrorAction SilentlyContinue)
    $lvl = if ($events.Count -eq 0) { 'OK' } else { 'WARN' }
    Write-NxLog -Level $lvl -Message ("{0,-18}: {1} error(s)" -f $log, $events.Count)
    $events | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 5 |
        ForEach-Object { [pscustomobject]@{ Log = $log; EventId = $_.Name; Count = $_.Count; Sample = ($_.Group[0].Message -split "`n")[0] } } |
        Write-NxTable
}

Write-NxLog -Level STEP -Message 'Summary'
if ($failures -eq 0) { Write-NxLog -Level OK -Message 'AD health: HEALTHY'; exit 0 }
Write-NxLog -Level ERROR -Message "AD health: $failures check(s) FAILED - see above and $reportDir\dcdiag.txt"
exit 1
