#Requires -Version 5.1
<#
.SYNOPSIS
    GPO-006 / Part F - Group Policy evidence for nexora.local (read-only).

.DESCRIPTION
      * every GPO with status, versions and links
      * password policy actually in force (domain + FGPP)
      * advanced audit policy actually in force on NX-DC01 (auditpol)
      * firewall profiles actually in force (ActiveStore)
      * applied GPOs on the DC (gpresult, computer scope)
    HTML reports (one per GPO + RSoP of the DC) are saved under
    C:\Nexora\reports\<date>\ and can be opened through Fleet Manager.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 23-Get-NxGpoReport.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force
Start-NxLog -ScriptName '23-Get-NxGpoReport'
$cfg = Import-NxConfig -Path $ConfigPath
Wait-NxActiveDirectory | Out-Null
Import-Module GroupPolicy
$reportDir = Get-NxReportDir

Write-NxLog -Level STEP -Message 'GPO inventory and links'
$allGpos = @(Get-GPO -All | Sort-Object DisplayName)
$allGpos | ForEach-Object {
    [xml]$xml = Get-GPOReport -Guid $_.Id -ReportType Xml
    $links = @($xml.GPO.LinksTo | ForEach-Object { '{0}{1}' -f $_.SOMPath, $(if ($_.NoOverride -eq 'true') { ' [Enforced]' } else { '' }) })
    Get-GPOReport -Guid $_.Id -ReportType Html -Path (Join-Path $reportDir ("gpo-{0}.html" -f ($_.DisplayName -replace '[^\w-]', '_')))
    [pscustomobject]@{
        GPO      = $_.DisplayName
        Status   = $_.GpoStatus
        CompVer  = '{0}/{1}' -f $_.Computer.DSVersion, $_.Computer.SysvolVersion
        UserVer  = '{0}/{1}' -f $_.User.DSVersion, $_.User.SysvolVersion
        Modified = $_.ModificationTime.ToString('yyyy-MM-dd HH:mm')
        LinkedTo = if ($links) { $links -join '; ' } else { '(not linked)' }
    }
} | Write-NxTable
$mismatch = @($allGpos | Where-Object { $_.Computer.DSVersion -ne $_.Computer.SysvolVersion -or $_.User.DSVersion -ne $_.User.SysvolVersion })
$lvl = if ($mismatch.Count -eq 0) { 'OK' } else { 'WARN' }
Write-NxLog -Level $lvl -Message ("AD/SYSVOL version mismatch: {0}" -f $(if ($mismatch) { $mismatch.DisplayName -join ', ' } else { 'none' }))

Write-NxLog -Level STEP -Message 'GPO-001/002 Password and lockout policy in force'
$pp = Get-ADDefaultDomainPasswordPolicy
$want = $cfg.GroupPolicy
$checks = @(
    @{ Name = 'MinPasswordLength'; Actual = $pp.MinPasswordLength; Expected = $want.Password.MinimumPasswordLength }
    @{ Name = 'ComplexityEnabled'; Actual = $pp.ComplexityEnabled; Expected = [bool]$want.Password.PasswordComplexity }
    @{ Name = 'PasswordHistoryCount'; Actual = $pp.PasswordHistoryCount; Expected = $want.Password.PasswordHistorySize }
    @{ Name = 'MinPasswordAge(days)'; Actual = $pp.MinPasswordAge.Days; Expected = $want.Password.MinimumPasswordAge }
    @{ Name = 'MaxPasswordAge(days)'; Actual = $pp.MaxPasswordAge.Days; Expected = $want.Password.MaximumPasswordAge }
    @{ Name = 'ReversibleEncryption'; Actual = $pp.ReversibleEncryptionEnabled; Expected = [bool]$want.Password.ClearTextPassword }
    @{ Name = 'LockoutThreshold'; Actual = $pp.LockoutThreshold; Expected = $want.Lockout.LockoutBadCount }
    @{ Name = 'LockoutDuration(min)'; Actual = $pp.LockoutDuration.TotalMinutes; Expected = $want.Lockout.LockoutDuration }
    @{ Name = 'ObservationWindow(min)'; Actual = $pp.LockoutObservationWindow.TotalMinutes; Expected = $want.Lockout.ResetLockoutCount }
)
$checks | ForEach-Object {
    [pscustomobject]@{ Setting = $_.Name; InForce = $_.Actual; Expected = $_.Expected; Match = ($_.Actual -eq $_.Expected) }
} | Write-NxTable
Get-ADFineGrainedPasswordPolicy -Filter * | ForEach-Object {
    $subjects = (Get-ADFineGrainedPasswordPolicySubject -Identity $_ | ForEach-Object Name) -join ', '
    Write-NxLog -Message ("FGPP {0}: precedence {1}, min length {2}, lockout {3}, applies to {4}" -f $_.Name, $_.Precedence, $_.MinPasswordLength, $_.LockoutThreshold, $subjects)
}

Write-NxLog -Level STEP -Message 'GPO-004 Advanced audit policy in force (auditpol)'
$audit = & auditpol.exe /get /category:* /r | ConvertFrom-Csv
$audit | Where-Object { $_.'Inclusion Setting' -ne 'No Auditing' } |
    Select-Object @{ n = 'Subcategory'; e = { $_.Subcategory } }, @{ n = 'Setting'; e = { $_.'Inclusion Setting' } } | Write-NxTable

Write-NxLog -Level STEP -Message 'GPO-003 Firewall profiles in force'
Get-NetFirewallProfile -PolicyStore ActiveStore |
    Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, LogBlocked | Write-NxTable

Write-NxLog -Level STEP -Message 'GPOs applied to NX-DC01 (gpresult, computer scope)'
$rsop = Join-Path $reportDir 'rsop-nx-dc01.html'
& gpresult.exe /scope computer /h $rsop /f | Out-Null
$applied = & gpresult.exe /scope computer /r
$inApplied = $false
$seen = $false
foreach ($line in $applied) {
    if ($line -match 'Applied Group Policy Objects') { $inApplied = $true; continue }
    if ($inApplied -and $line -match '^\s*$') { if ($seen) { break } else { continue } }
    if ($inApplied -and $line -match '^\s+-+\s*$') { continue }
    if ($inApplied) { $seen = $true; Write-NxLog -Message ("Applied: {0}" -f $line.Trim()) }
}

Write-NxLog -Level OK -Message "HTML reports saved in $reportDir"
exit 0
