#Requires -Version 5.1
<#
.SYNOPSIS
    Part F - Active Directory inventory export (read-only).

.DESCRIPTION
    Exports CSV files and a JSON summary to C:\Nexora\reports\<date>\inventory\:
      ous.csv, users.csv, groups.csv, group-memberships.csv, computers.csv,
      gpos.csv, gpo-links.csv, dns-records.csv, summary.json
    Prints the summary so it is visible in the SSM command output.
    No password hashes or secrets are read or exported.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 25-Export-NxADInventory.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force
Start-NxLog -ScriptName '25-Export-NxADInventory'
$cfg = Import-NxConfig -Path $ConfigPath
$domain = Wait-NxActiveDirectory
Import-Module GroupPolicy, DnsServer
$out = Join-Path (Get-NxReportDir) 'inventory'
New-Item -ItemType Directory -Path $out -Force | Out-Null
function Save-Csv($Rows, [string]$File) {
    $path = Join-Path $out $File
    @($Rows) | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    Write-NxLog -Level OK -Message ("{0,-24} {1,5} row(s)" -f $File, @($Rows).Count)
}
$cn = { param($dn) (($dn -split ',')[0] -replace '^(CN|OU)=') }

Write-NxLog -Level STEP -Message "Exporting inventory to $out"

$ous = Get-ADOrganizationalUnit -Filter * -Properties Description, ProtectedFromAccidentalDeletion, whenCreated |
    Select-Object Name, DistinguishedName, Description, ProtectedFromAccidentalDeletion, whenCreated
Save-Csv $ous 'ous.csv'

$users = Get-ADUser -Filter * -Properties Enabled, Title, Department, LastLogonDate, PasswordLastSet, PasswordNeverExpires, AccountNotDelegated, whenCreated, MemberOf |
    Select-Object SamAccountName, Name, UserPrincipalName, Enabled, Title, Department, LastLogonDate, PasswordLastSet,
    PasswordNeverExpires, AccountNotDelegated, whenCreated, DistinguishedName,
    @{ n = 'DirectGroups'; e = { ($_.MemberOf | ForEach-Object { & $cn $_ }) -join ';' } }
Save-Csv $users 'users.csv'

$groups = Get-ADGroup -Filter * -Properties Description, Members, whenCreated |
    Select-Object Name, GroupScope, GroupCategory, Description, @{ n = 'MemberCount'; e = { @($_.Members).Count } }, whenCreated, DistinguishedName
Save-Csv $groups 'groups.csv'

$base = Get-NxOuPath -Config $cfg
$memberships = foreach ($g in Get-ADGroup -SearchBase $base -Filter *) {
    foreach ($m in Get-ADGroupMember -Identity $g) {
        [pscustomobject]@{ Group = $g.Name; Member = $m.SamAccountName; MemberType = $m.objectClass }
    }
}
foreach ($g in 'Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators') {
    foreach ($m in Get-ADGroupMember -Identity $g) {
        $memberships = @($memberships) + [pscustomobject]@{ Group = $g; Member = $m.SamAccountName; MemberType = $m.objectClass }
    }
}
Save-Csv $memberships 'group-memberships.csv'

$computers = Get-ADComputer -Filter * -Properties OperatingSystem, OperatingSystemVersion, IPv4Address, LastLogonDate |
    Select-Object Name, DNSHostName, OperatingSystem, OperatingSystemVersion, IPv4Address, LastLogonDate, DistinguishedName
Save-Csv $computers 'computers.csv'

$gpos = Get-GPO -All | Select-Object DisplayName, Id, GpoStatus, CreationTime, ModificationTime,
    @{ n = 'ComputerVersion'; e = { $_.Computer.DSVersion } }, @{ n = 'UserVersion'; e = { $_.User.DSVersion } }
Save-Csv $gpos 'gpos.csv'

$links = foreach ($t in @($domain.DistinguishedName) + @(Get-ADOrganizationalUnit -Filter * | ForEach-Object DistinguishedName)) {
    foreach ($l in (Get-GPInheritance -Target $t).GpoLinks) {
        [pscustomobject]@{ Target = $t; GPO = $l.DisplayName; Enabled = $l.Enabled; Enforced = $l.Enforced; Order = $l.Order }
    }
}
Save-Csv $links 'gpo-links.csv'

$records = foreach ($z in Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated -and $_.ZoneName -ne 'TrustAnchors' }) {
    foreach ($r in Get-DnsServerResourceRecord -ZoneName $z.ZoneName | Where-Object { $_.RecordType -in 'A', 'CNAME', 'PTR', 'SRV', 'NS' }) {
        $data = switch ($r.RecordType) {
            'A' { $r.RecordData.IPv4Address.IPAddressToString }
            'CNAME' { $r.RecordData.HostNameAlias }
            'PTR' { $r.RecordData.PtrDomainName }
            'SRV' { '{0}:{1}' -f $r.RecordData.DomainName, $r.RecordData.Port }
            'NS' { $r.RecordData.NameServer }
        }
        [pscustomobject]@{ Zone = $z.ZoneName; Name = $r.HostName; Type = $r.RecordType; Data = $data; Static = ($null -eq $r.Timestamp) }
    }
}
Save-Csv $records 'dns-records.csv'

$pp = Get-ADDefaultDomainPasswordPolicy
$summary = [ordered]@{
    GeneratedUtc        = (Get-Date).ToUniversalTime().ToString('o')
    Domain              = $domain.DNSRoot
    NetBIOS             = $domain.NetBIOSName
    DomainMode          = [string]$domain.DomainMode
    DomainControllers   = @(Get-ADDomainController -Filter * | ForEach-Object HostName)
    OrganizationalUnits = @($ous).Count
    Users               = @($users).Count
    UsersEnabled        = @($users | Where-Object Enabled).Count
    StandardUsers       = @($users | Where-Object { $_.DistinguishedName -like "*$base" -and $_.SamAccountName -notmatch '^(adm|svc)-' }).Count
    AdminAccounts       = @($users | Where-Object SamAccountName -Like 'adm-*').Count
    ServiceAccounts     = @($users | Where-Object SamAccountName -Like 'svc-*').Count
    Groups              = @($groups).Count
    NexoraGroups        = @(Get-ADGroup -SearchBase $base -Filter *).Count
    Computers           = @($computers).Count
    Gpos                = @($gpos).Count
    GpoLinks            = @($links).Count
    DnsRecords          = @($records).Count
    DomainAdmins        = @(Get-ADGroupMember -Identity 'Domain Admins' | ForEach-Object SamAccountName)
    PasswordPolicy      = [ordered]@{ MinLength = $pp.MinPasswordLength; Complexity = $pp.ComplexityEnabled; History = $pp.PasswordHistoryCount; LockoutThreshold = $pp.LockoutThreshold }
}
$json = $summary | ConvertTo-Json -Depth 4
Set-Content -Path (Join-Path $out 'summary.json') -Value $json -Encoding UTF8
Write-NxLog -Level STEP -Message 'Summary'
Write-Host $json
exit 0
