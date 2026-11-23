#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / AD-008 - RBAC: delegate help-desk rights on department OUs.

.DESCRIPTION
    GG-IT-HelpDesk receives, on each department OU and only for user objects
    below it (inheritance /I:S):
      * Reset Password            (extended right)
      * Read/Write lockoutTime    (unlock accounts)
      * Read/Write pwdLastSet     (force "change password at next logon")
    The group is NOT given Account Operators or Domain Admins.

    Other RBAC pieces:
      * Domain Admins = adm-alopes (+ built-in Administrator, ssm-user) - script 05
      * GG-IT-ServerAdmins -> local admins on OU=Servers - GPO in Part E

    Uses dsacls.exe (installed with the AD DS tools). Idempotent: an existing
    ACE is not duplicated by dsacls.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 07-Set-ADDelegation.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1',
    [string]$HelpDeskGroup = 'GG-IT-HelpDesk'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '07-Set-ADDelegation'
$cfg = Import-NxConfig -Path $ConfigPath
Wait-NxActiveDirectory | Out-Null
$principal = "$($cfg.Domain.NetBiosName)\$HelpDeskGroup"
Get-ADGroup -Identity $HelpDeskGroup | Out-Null   # fail early if group is missing

$grants = @(
    'CA;Reset Password;user'
    'RPWP;lockoutTime;user'
    'RPWP;pwdLastSet;user'
)

Write-NxLog -Level STEP -Message "AD-008 Delegating help-desk rights to $principal"
foreach ($ouName in $cfg.DepartmentOus) {
    $ou = Get-NxOuPath -Config $cfg -Name $ouName
    foreach ($g in $grants) {
        $out = & dsacls.exe $ou /I:S /G "${principal}:$g"
        if ($LASTEXITCODE -ne 0) { throw "dsacls failed on $ou ($g): $($out -join ' ')" }
    }
    Write-NxLog -Level OK -Message "Delegated on $ou"
}

Write-NxLog -Level STEP -Message 'Verification (ACEs for the help-desk group)'
foreach ($ouName in $cfg.DepartmentOus) {
    $ou = Get-NxOuPath -Config $cfg -Name $ouName
    $acl = Get-Acl -Path "AD:$ou"
    $count = @($acl.Access | Where-Object { $_.IdentityReference.Value -eq $principal }).Count
    $level = if ($count -ge 3) { 'OK' } else { 'WARN' }
    Write-NxLog -Level $level -Message "$ouName : $count ACE(s) for $principal"
}

exit 0
