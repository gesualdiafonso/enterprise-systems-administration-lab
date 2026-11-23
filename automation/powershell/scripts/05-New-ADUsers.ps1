#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / AD-005 + AD-008 - Create standard users and privileged adm- accounts.

.DESCRIPTION
    Follows the joiner process in docs/networking/users-groups.md:
      create DISABLED in the department OU -> add to role groups ->
      set initial password -> must change at next logon -> enable.

    Standard users : initial password from SSM /nexora/ad/initial-user-password
                     (shared lab value, forced change at first logon).
    adm- accounts  : password from SSM /nexora/ad/admin-account-password, NOT
                     forced to change (used for Fleet Manager / RDP logon).

    Idempotent: an existing account is never reset or re-enabled; only missing
    group memberships are added.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 05-New-ADUsers.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '05-New-ADUsers'
$cfg = Import-NxConfig -Path $ConfigPath
Wait-NxActiveDirectory | Out-Null
$upn = $cfg.Domain.UpnSuffix

function Add-NxMembership {
    param([string]$Sam, [string[]]$Groups)
    foreach ($group in $Groups) {
        $isMember = Get-ADGroupMember -Identity $group | Where-Object SamAccountName -EQ $Sam
        if (-not $isMember) {
            Add-ADGroupMember -Identity $group -Members $Sam
            Write-NxLog -Level OK -Message "  + $Sam -> $group"
        }
    }
}

function New-NxUser {
    param(
        [hashtable]$Spec,
        [securestring]$Password,
        [bool]$MustChange
    )
    $sam = $Spec.Sam
    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-NxLog -Level OK -Message "Exists  : $sam (not modified)"
        Add-NxMembership -Sam $sam -Groups $Spec.Groups
        return
    }
    $params = @{
        Name              = $Spec.DisplayName
        DisplayName       = $Spec.DisplayName
        SamAccountName    = $sam
        UserPrincipalName = "$sam@$upn"
        Path              = Get-NxOuPath -Config $cfg -Name $Spec.Ou
        Enabled           = $false
    }
    foreach ($k in 'GivenName', 'Surname', 'Title', 'Description', 'Department') {
        if ($Spec.ContainsKey($k) -and $Spec[$k]) { $params[$k] = $Spec[$k] }
    }
    New-ADUser @params
    Write-NxLog -Level OK -Message "Created : $sam (disabled) in OU=$($Spec.Ou)"
    Add-NxMembership -Sam $sam -Groups $Spec.Groups
    Set-ADAccountPassword -Identity $sam -Reset -NewPassword $Password
    Set-ADUser -Identity $sam -ChangePasswordAtLogon $MustChange
    Enable-ADAccount -Identity $sam
    Write-NxLog -Level OK -Message "Enabled : $sam (change at logon: $MustChange)"
}

Write-NxLog -Level STEP -Message 'AD-005 Standard users'
$userPassword = Get-NxSecret -Name $cfg.Secrets.InitialUserPassword
foreach ($u in $cfg.Users) {
    $spec = @{
        Sam         = $u.Sam
        GivenName   = $u.GivenName
        Surname     = $u.Surname
        DisplayName = "$($u.GivenName) $($u.Surname)"
        Title       = $u.Title
        Department  = $u.Ou
        Ou          = $u.Ou
        Groups      = $u.Groups
    }
    New-NxUser -Spec $spec -Password $userPassword -MustChange $true
}
$userPassword = $null

Write-NxLog -Level STEP -Message 'AD-008 Privileged adm- accounts'
$adminPassword = Get-NxSecret -Name $cfg.Secrets.AdminAccountPassword
foreach ($a in $cfg.AdminAccounts) {
    $owner = Get-ADUser -Identity $a.Owner -Properties DisplayName
    $spec = @{
        Sam         = $a.Sam
        DisplayName = "$($owner.DisplayName) (admin)"
        GivenName   = $owner.GivenName
        Surname     = $owner.Surname
        Description = "Privileged account of $($a.Owner). Not for daily use."
        Ou          = $a.Ou
        Groups      = $a.Groups
    }
    New-NxUser -Spec $spec -Password $adminPassword -MustChange $false
}
$adminPassword = $null

Write-NxLog -Level STEP -Message 'Summary'
$base = Get-NxOuPath -Config $cfg
$all = @(Get-ADUser -SearchBase $base -Filter * -Properties Enabled)
Write-NxLog -Message ("Accounts under {0}: {1} (enabled: {2})" -f $base, $all.Count, @($all | Where-Object Enabled).Count)
Write-NxLog -Message ('Domain Admins: {0}' -f ((Get-ADGroupMember -Identity 'Domain Admins').SamAccountName -join ', '))

exit 0
