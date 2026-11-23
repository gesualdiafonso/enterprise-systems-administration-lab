#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / AD-004 - Create the OU hierarchy under OU=Nexora.

.DESCRIPTION
    Idempotent: existing OUs are left untouched. Every OU is protected from
    accidental deletion. Structure comes from config\nexora-ad.psd1
    (docs/networking/domain-structure.md section 6).

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 03-New-ADOrganizationalUnits.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '03-New-ADOrganizationalUnits'
$cfg = Import-NxConfig -Path $ConfigPath
if (-not (Test-NxDomainController)) { throw 'Not a domain controller. Run 02-Install-ADDSForest.ps1 first.' }
Wait-NxActiveDirectory | Out-Null

function New-NxOu {
    param([string]$Name, [string]$Path, [string]$Description)
    $dn = "OU=$Name,$Path"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-NxLog -Level OK -Message "Exists  : $dn"
        return
    }
    New-ADOrganizationalUnit -Name $Name -Path $Path -Description $Description -ProtectedFromAccidentalDeletion $true
    Write-NxLog -Level OK -Message "Created : $dn"
}

Write-NxLog -Level STEP -Message 'AD-004 OU structure'
New-NxOu -Name $cfg.Domain.RootOu -Path $cfg.Domain.DistinguishedName -Description 'Nexora Technologies - company root OU'
$root = Get-NxOuPath -Config $cfg
foreach ($ou in $cfg.OrganizationalUnits) {
    New-NxOu -Name $ou.Name -Path $root -Description $ou.Description
}

Write-NxLog -Level STEP -Message 'Result'
Get-ADOrganizationalUnit -SearchBase $root -Filter * |
    Sort-Object DistinguishedName |
    ForEach-Object { Write-NxLog -Message $_.DistinguishedName }

exit 0
