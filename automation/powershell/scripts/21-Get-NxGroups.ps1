#Requires -Version 5.1
<#
.SYNOPSIS
    Part F - Query security groups and their (recursive) members (read-only).

.DESCRIPTION
    Without parameters: every group in OU=Groups with scope, direct members,
    nested parents and effective (recursive) user count, plus the membership
    of the privileged built-in groups.
    With -Name: direct and recursive members of one group (AGDLP chain).

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 21-Get-NxGroups.ps1
    ./automation/aws-cli/run-dc-script.sh 21-Get-NxGroups.ps1 -Name DL-FS-Finance-RW
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1',
    [string]$Name
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force
Start-NxLog -ScriptName '21-Get-NxGroups'
$cfg = Import-NxConfig -Path $ConfigPath
Wait-NxActiveDirectory | Out-Null

if ($Name) {
    Write-NxLog -Level STEP -Message "Direct members of $Name"
    Get-ADGroupMember -Identity $Name | Select-Object SamAccountName, objectClass | Write-NxTable
    Write-NxLog -Level STEP -Message "Effective (recursive) user members of $Name"
    Get-ADGroupMember -Identity $Name -Recursive | Select-Object SamAccountName, Name | Write-NxTable
    exit 0
}

$ou = Get-NxOuPath -Config $cfg -Name 'Groups'
Write-NxLog -Level STEP -Message "Groups in $ou"
Get-ADGroup -SearchBase $ou -Filter * -Properties Members, MemberOf, Description | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
        Group     = $_.Name
        Scope     = $_.GroupScope
        Direct    = @($_.Members).Count
        Effective = @(Get-ADGroupMember -Identity $_ -Recursive).Count
        NestedIn  = ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join ';'
    }
} | Write-NxTable

Write-NxLog -Level STEP -Message 'Privileged built-in groups'
foreach ($g in 'Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators', 'Account Operators', 'Backup Operators', 'Server Operators') {
    $m = @(Get-ADGroupMember -Identity $g | ForEach-Object SamAccountName)
    Write-NxLog -Message ("{0,-18}: {1}" -f $g, $(if ($m) { $m -join ', ' } else { '(empty)' }))
}
exit 0
