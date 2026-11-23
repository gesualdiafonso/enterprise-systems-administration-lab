#Requires -Version 5.1
<#
.SYNOPSIS
    Part F - Query user accounts in nexora.local (read-only).

.DESCRIPTION
    Lists users under OU=Nexora with OU, state, last logon, password age and
    group membership. Also checks the acceptance rules of users-groups.md:
    15 standard users, Domain Admins membership, no objects created in CN=Users.

.PARAMETER Department
    Optional department OU name (e.g. Finance, 'Human Resources').

.PARAMETER Identity
    Optional sAMAccountName: show full details of a single account.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 20-Get-NxUsers.ps1
    ./automation/aws-cli/run-dc-script.sh 20-Get-NxUsers.ps1 -Department Finance
    ./automation/aws-cli/run-dc-script.sh 20-Get-NxUsers.ps1 -Identity mgomes
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1',
    [string]$Department,
    [string]$Identity
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force
Start-NxLog -ScriptName '20-Get-NxUsers'
$cfg = Import-NxConfig -Path $ConfigPath
Wait-NxActiveDirectory | Out-Null
$props = 'Enabled', 'LastLogonDate', 'PasswordLastSet', 'PasswordNeverExpires', 'LockedOut', 'Title', 'Department', 'MemberOf', 'whenCreated'

if ($Identity) {
    $u = Get-ADUser -Identity $Identity -Properties ($props + 'DisplayName', 'UserPrincipalName', 'pwdLastSet')
    Write-NxLog -Level STEP -Message "User $Identity"
    $u | Select-Object SamAccountName, DisplayName, UserPrincipalName, Enabled, LockedOut, Title, Department,
    PasswordLastSet, PasswordNeverExpires, LastLogonDate, whenCreated, DistinguishedName | Format-List | Out-String | Write-Host
    Write-NxLog -Message ('Mustchange at next logon: {0}' -f ($u.pwdLastSet -eq 0))
    Write-NxLog -Message ('Groups (direct): {0}' -f (($u.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join ', '))
    exit 0
}

$base = if ($Department) { Get-NxOuPath -Config $cfg -Name $Department } else { Get-NxOuPath -Config $cfg }
Write-NxLog -Level STEP -Message "Users under $base"
$users = @(Get-ADUser -SearchBase $base -Filter * -Properties $props | Sort-Object DistinguishedName)
$users | ForEach-Object {
    [pscustomobject]@{
        Sam        = $_.SamAccountName
        Name       = $_.Name
        OU         = (($_.DistinguishedName -split ',')[1] -replace '^OU=')
        Enabled    = $_.Enabled
        Locked     = $_.LockedOut
        PwdSet     = if ($_.PasswordLastSet) { $_.PasswordLastSet.ToString('yyyy-MM-dd') } else { 'must change' }
        LastLogon  = if ($_.LastLogonDate) { $_.LastLogonDate.ToString('yyyy-MM-dd HH:mm') } else { 'never' }
        Groups     = ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join ';'
    }
} | Write-NxTable

if (-not $Department) {
    Write-NxLog -Level STEP -Message 'Acceptance checks (docs/networking/users-groups.md)'
    $standard = @($users | Where-Object { $_.SamAccountName -notlike 'adm-*' -and $_.SamAccountName -notlike 'svc-*' })
    $expected = $cfg.Users.Count
    $lvl = if ($standard.Count -eq $expected) { 'OK' } else { 'WARN' }
    Write-NxLog -Level $lvl -Message "Standard users: $($standard.Count) (expected $expected)"

    $da = @(Get-ADGroupMember -Identity 'Domain Admins' | ForEach-Object SamAccountName)
    $allowed = @('Administrator', 'ssm-user') + @($cfg.AdminAccounts | Where-Object { $_.Groups -contains 'Domain Admins' } | ForEach-Object Sam)
    $extra = @($da | Where-Object { $allowed -notcontains $_ })
    $lvl = if ($extra.Count -eq 0) { 'OK' } else { 'WARN' }
    Write-NxLog -Level $lvl -Message ("Domain Admins: {0}{1}" -f ($da -join ', '), $(if ($extra) { "  UNEXPECTED: $($extra -join ', ')" } else { '' }))

    $builtinUsers = "CN=Users,$($cfg.Domain.DistinguishedName)"
    $known = 'Administrator', 'Guest', 'krbtgt', 'DefaultAccount', 'ssm-user'
    $stray = @(Get-ADUser -SearchBase $builtinUsers -SearchScope OneLevel -Filter * | Where-Object { $known -notcontains $_.SamAccountName })
    $lvl = if ($stray.Count -eq 0) { 'OK' } else { 'WARN' }
    Write-NxLog -Level $lvl -Message ("Unexpected users in CN=Users: {0}" -f $(if ($stray) { ($stray.SamAccountName -join ', ') } else { 'none' }))
}
exit 0
