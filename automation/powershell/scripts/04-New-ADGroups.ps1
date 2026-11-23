#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / AD-006 - Create security groups in OU=Groups and apply AGDLP nesting.

.DESCRIPTION
    Idempotent. Pass 1 creates every group (Global or DomainLocal, always
    Security). Pass 2 applies the MemberOf nesting from the config, e.g.
    GG-Finance-Users -> GG-Nexora-AllStaff and -> DL-FS-Finance-RW.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 04-New-ADGroups.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '04-New-ADGroups'
$cfg = Import-NxConfig -Path $ConfigPath
Wait-NxActiveDirectory | Out-Null
$groupsOu = Get-NxOuPath -Config $cfg -Name 'Groups'

Write-NxLog -Level STEP -Message 'AD-006 Pass 1 - create groups'
foreach ($g in $cfg.Groups) {
    $existing = Get-ADGroup -Filter "Name -eq '$($g.Name)'" -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.GroupScope -ne $g.Scope) {
            Write-NxLog -Level WARN -Message "$($g.Name) exists with scope $($existing.GroupScope), expected $($g.Scope) - not changed"
        }
        else { Write-NxLog -Level OK -Message "Exists  : $($g.Name)" }
        continue
    }
    New-ADGroup -Name $g.Name -SamAccountName $g.Name -GroupCategory Security -GroupScope $g.Scope `
        -Path $groupsOu -Description $g.Description
    Write-NxLog -Level OK -Message "Created : $($g.Name) ($($g.Scope))"
}

Write-NxLog -Level STEP -Message 'AD-006 Pass 2 - nesting (AGDLP)'
foreach ($g in $cfg.Groups) {
    foreach ($parent in $g.MemberOf) {
        $members = @(Get-ADGroupMember -Identity $parent | Select-Object -ExpandProperty SamAccountName)
        if ($members -contains $g.Name) {
            Write-NxLog -Level OK -Message "Nested  : $($g.Name) -> $parent"
            continue
        }
        Add-ADGroupMember -Identity $parent -Members $g.Name
        Write-NxLog -Level OK -Message "Added   : $($g.Name) -> $parent"
    }
}

exit 0
