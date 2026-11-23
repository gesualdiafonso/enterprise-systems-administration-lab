#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / AD-007 - Create service accounts in OU=Service Accounts.

.DESCRIPTION
    Rules from docs/networking/users-groups.md section 7:
      * svc-<service> naming, documented owner and purpose (Description)
      * long random password generated on the DC and never displayed or stored
        (reset it when the real service is configured, or replace with a gMSA)
      * password never expires, user cannot change it
      * account is sensitive and cannot be delegated (Kerberos delegation off)
      * never a member of privileged groups
    Interactive / RDP logon denial is applied by GPO (Part E).

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 06-New-ADServiceAccounts.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '06-New-ADServiceAccounts'
$cfg = Import-NxConfig -Path $ConfigPath
Wait-NxActiveDirectory | Out-Null
$path = Get-NxOuPath -Config $cfg -Name 'Service Accounts'
$privileged = 'Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators', 'Account Operators', 'Server Operators', 'Backup Operators'

Write-NxLog -Level STEP -Message 'AD-007 Service accounts'
foreach ($s in $cfg.ServiceAccounts) {
    $sam = $s.Sam
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $sam -SamAccountName $sam -UserPrincipalName "$sam@$($cfg.Domain.UpnSuffix)" `
            -Path $path -Description $s.Description -AccountPassword (New-NxRandomPassword -Length 48) `
            -PasswordNeverExpires $true -CannotChangePassword $true -AccountNotDelegated $true -Enabled $true
        Write-NxLog -Level OK -Message "Created : $sam (random 48-char password, not displayed)"
    }
    else {
        Write-NxLog -Level OK -Message "Exists  : $sam"
    }

    $memberOf = @(Get-ADPrincipalGroupMembership -Identity $sam | Select-Object -ExpandProperty Name)
    $bad = @($memberOf | Where-Object { $privileged -contains $_ })
    if ($bad.Count -gt 0) { Write-NxLog -Level ERROR -Message "$sam is in privileged group(s): $($bad -join ', ')" }
    else { Write-NxLog -Level OK -Message "$sam has no privileged group membership" }
}

exit 0
