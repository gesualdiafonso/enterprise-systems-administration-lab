#Requires -Version 5.1
<#
.SYNOPSIS
    Day 02 / GPO-001..GPO-005 - Group Policy for nexora.local.

.DESCRIPTION
    Idempotent. Implements docs/networking/gpo-policies.md section 11:

    GPO                              Linked to                               Settings
    -------------------------------  --------------------------------------  ---------------------------------------------
    Default Domain Policy (edited)   nexora.local                            GPO-001 password, GPO-002 lockout
    FGPP NX-PSO-Admins               GG-Admin-Accounts (not a GPO)           stronger policy for adm- accounts
    NX-DC-Audit-Policy               OU=Domain Controllers                   GPO-004 advanced audit, Security log 512 MB
    NX-Baseline-Security (Enforced)  OU=Nexora + OU=Domain Controllers       GPO-003 firewall, SMBv1 off, logon banner
    NX-Servers-Admins                OU=Servers                              GPO-005 GG-IT-ServerAdmins -> local Administrators
    NX-ServiceAccounts-Restrictions  OU=Domain Controllers + OU=Servers      GPO-005 deny local/RDP logon to GG-Service-Accounts
    NX-Users-Desktop                 department OUs                          GPO-005 secure screen saver after 15 min

    Deviations from the draft design (documented):
      * NX-Baseline-Security is ALSO linked to OU=Domain Controllers: the lab has
        no member computers yet, so the DC is the only machine that can show
        evidence (gpresult) of the baseline.
      * NX-ServiceAccounts-Restrictions is linked to COMPUTER OUs. User Rights
        Assignment is a computer setting; linked to OU=Service Accounts (users
        only) it would never apply.

    Settings without a PowerShell cmdlet (security template, advanced audit,
    restricted groups, user rights) are written to the GPO files in SYSVOL
    (GptTmpl.inf, audit.csv), the client-side extension list is registered on
    the GPO object, and the GPO version is increased - the same thing the GPMC
    editor does.

.EXAMPLE
    ./automation/aws-cli/run-dc-script.sh 09-Set-GroupPolicies.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = 'C:\Nexora\config\nexora-ad.psd1'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\NexoraLab.psm1') -Force

Assert-NxAdministrator
Start-NxLog -ScriptName '09-Set-GroupPolicies'
$cfg = Import-NxConfig -Path $ConfigPath
if (-not (Test-NxDomainController)) { throw 'Not a domain controller.' }
Wait-NxActiveDirectory | Out-Null
Import-Module GroupPolicy

$gp = $cfg.GroupPolicy
$domainDns = $cfg.Domain.DnsName
$domainDn = $cfg.Domain.DistinguishedName
$dcOu = "OU=Domain Controllers,$domainDn"
$sysvolPolicies = Join-Path (Get-SmbShare -Name SYSVOL).Path "$domainDns\Policies"

# Client-side extension pairs: [{CSE GUID}{Editor tool GUID}]
$cseSecurity = '[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]'
$cseAudit = '[{F3CCC681-B74C-4060-9F26-CD84525DCA2A}{0F3F3735-573D-9804-99E4-AB2A69BA5FD4}]'

# =============================================================================
# Helpers
# =============================================================================
function Get-NxGpoAdDn([Microsoft.GroupPolicy.Gpo]$Gpo) {
    "CN={$($Gpo.Id.ToString().ToUpper())},CN=Policies,CN=System,$domainDn"
}

function Get-NxGpoSysvolPath([Microsoft.GroupPolicy.Gpo]$Gpo) {
    Join-Path $sysvolPolicies "{$($Gpo.Id.ToString().ToUpper())}"
}

function Get-NxGpo {
    param([string]$Name, [string]$Comment)
    $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $Name -Comment $Comment
        Write-NxLog -Level OK -Message "GPO created: $Name"
    }
    else { Write-NxLog -Level OK -Message "GPO exists : $Name" }
    $gpo
}

function Set-NxGpoLink {
    param([string]$Name, [string]$Target, [switch]$Enforced)
    $wanted = if ($Enforced) { 'Yes' } else { 'No' }
    $link = (Get-GPInheritance -Target $Target).GpoLinks | Where-Object DisplayName -EQ $Name
    if (-not $link) {
        New-GPLink -Name $Name -Target $Target -LinkEnabled Yes -Enforced $wanted | Out-Null
        Write-NxLog -Level OK -Message "  linked  -> $Target (enforced: $wanted)"
    }
    elseif ([bool]$link.Enforced -ne [bool]$Enforced) {
        Set-GPLink -Name $Name -Target $Target -Enforced $wanted | Out-Null
        Write-NxLog -Level OK -Message "  link updated -> $Target (enforced: $wanted)"
    }
    else { Write-NxLog -Level OK -Message "  link ok -> $Target" }
}

function Read-NxInf([string]$Path) {
    $sections = [ordered]@{}
    if (Test-Path $Path) {
        $current = $null
        foreach ($line in Get-Content -Path $Path -Encoding Unicode) {
            if ($line -match '^\s*\[(.+)\]\s*$') {
                $current = $Matches[1]
                if (-not $sections.Contains($current)) { $sections[$current] = [ordered]@{} }
            }
            elseif ($current -and $line -match '^\s*([^=]+?)\s*=\s*(.*)$') {
                $sections[$current][$Matches[1]] = $Matches[2]
            }
        }
    }
    if (-not $sections.Contains('Unicode')) { $sections.Insert(0, 'Unicode', [ordered]@{ Unicode = 'yes' }) }
    if (-not $sections.Contains('Version')) { $sections['Version'] = [ordered]@{ signature = '"$CHICAGO$"'; Revision = '1' } }
    $sections
}

function Write-NxInf([string]$Path, $Sections) {
    $lines = foreach ($s in $Sections.Keys) {
        "[$s]"
        foreach ($k in $Sections[$s].Keys) {
            if ($s -eq 'Registry Values') { "$k=$($Sections[$s][$k])" } else { "$k = $($Sections[$s][$k])" }
        }
    }
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Path $Path -Value $lines -Encoding Unicode
}

function Set-NxSecurityTemplate {
    <# Merges values into Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf. Returns $true if changed. #>
    param([Microsoft.GroupPolicy.Gpo]$Gpo, [hashtable]$Values)
    $path = Join-Path (Get-NxGpoSysvolPath $Gpo) 'Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf'
    $inf = Read-NxInf $path
    $changed = $false
    foreach ($section in $Values.Keys) {
        if (-not $inf.Contains($section)) { $inf[$section] = [ordered]@{} }
        foreach ($key in $Values[$section].Keys) {
            $value = [string]$Values[$section][$key]
            if ($inf[$section][$key] -ne $value) { $inf[$section][$key] = $value; $changed = $true }
        }
    }
    if ($changed) { Write-NxInf -Path $path -Sections $inf }
    $changed
}

function Add-NxGpoCse {
    param([Microsoft.GroupPolicy.Gpo]$Gpo, [string[]]$Pairs)
    $dn = Get-NxGpoAdDn $Gpo
    $obj = Get-ADObject -Identity $dn -Properties gPCMachineExtensionNames
    $current = @([regex]::Matches([string]$obj.gPCMachineExtensionNames, '\[[^\]]+\]') | ForEach-Object Value)
    $merged = @($current + $Pairs | ForEach-Object { $_.ToUpper() } | Sort-Object -Unique)
    if (($merged -join '') -ne (($current | ForEach-Object { $_.ToUpper() } | Sort-Object -Unique) -join '')) {
        Set-ADObject -Identity $dn -Replace @{ gPCMachineExtensionNames = ($merged -join '') }
    }
}

function Step-NxGpoMachineVersion([Microsoft.GroupPolicy.Gpo]$Gpo) {
    <# Computer version = low 16 bits of versionNumber. AD and GPT.ini must match. #>
    $dn = Get-NxGpoAdDn $Gpo
    $version = [int](Get-ADObject -Identity $dn -Properties versionNumber).versionNumber + 1
    Set-ADObject -Identity $dn -Replace @{ versionNumber = $version }
    $gptIni = Join-Path (Get-NxGpoSysvolPath $Gpo) 'GPT.INI'
    $content = if (Test-Path $gptIni) { Get-Content $gptIni } else { @('[General]') }
    if ($content -match '^Version=') { $content = $content -replace '^Version=\d+', "Version=$version" }
    else { $content += "Version=$version" }
    Set-Content -Path $gptIni -Value $content -Encoding ASCII
}

function Get-NxSidString([string]$Name) {
    (Get-ADGroup -Identity $Name).SID.Value
}

# =============================================================================
# GPO-001 / GPO-002 - Default Domain Policy: password + lockout
# =============================================================================
Write-NxLog -Level STEP -Message 'GPO-001/002 Default Domain Policy (password and lockout)'
$ddp = Get-GPO -Guid '31B2F340-016D-11D2-945F-00C04FB984F9'
$systemAccess = [ordered]@{}
foreach ($k in $gp.Password.Keys) { $systemAccess[$k] = $gp.Password[$k] }
foreach ($k in $gp.Lockout.Keys) { $systemAccess[$k] = $gp.Lockout[$k] }
if (Set-NxSecurityTemplate -Gpo $ddp -Values @{ 'System Access' = $systemAccess }) {
    Add-NxGpoCse -Gpo $ddp -Pairs $cseSecurity
    Step-NxGpoMachineVersion $ddp
    Write-NxLog -Level OK -Message ('Default Domain Policy updated: ' + (($systemAccess.Keys | ForEach-Object { "$_=$($systemAccess[$_])" }) -join ' '))
}
else { Write-NxLog -Level OK -Message 'Default Domain Policy already compliant' }

# =============================================================================
# FGPP for adm- accounts
# =============================================================================
Write-NxLog -Level STEP -Message 'Fine-grained password policy for adm- accounts'
$pso = $gp.AdminPso
if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq '$($pso.Name)'" -ErrorAction SilentlyContinue)) {
    New-ADFineGrainedPasswordPolicy -Name $pso.Name -Precedence $pso.Precedence `
        -MinPasswordLength $pso.MinPasswordLength -PasswordHistoryCount $pso.PasswordHistoryCount `
        -ComplexityEnabled $true -ReversibleEncryptionEnabled $false `
        -MinPasswordAge '1.00:00:00' -MaxPasswordAge '365.00:00:00' `
        -LockoutThreshold $pso.LockoutThreshold `
        -LockoutDuration ([TimeSpan]::FromMinutes($pso.LockoutDurationMin)) `
        -LockoutObservationWindow ([TimeSpan]::FromMinutes($pso.LockoutDurationMin)) `
        -Description 'Stronger password policy for privileged adm- accounts' -ProtectedFromAccidentalDeletion $true
    Write-NxLog -Level OK -Message "Created $($pso.Name) (min length $($pso.MinPasswordLength))"
}
$subjects = @(Get-ADFineGrainedPasswordPolicySubject -Identity $pso.Name | ForEach-Object Name)
if ($subjects -notcontains $pso.AppliesTo) {
    Add-ADFineGrainedPasswordPolicySubject -Identity $pso.Name -Subjects $pso.AppliesTo
    Write-NxLog -Level OK -Message "$($pso.Name) applied to $($pso.AppliesTo)"
}
else { Write-NxLog -Level OK -Message "$($pso.Name) already applies to $($pso.AppliesTo)" }

# =============================================================================
# GPO-004 - NX-DC-Audit-Policy
# =============================================================================
Write-NxLog -Level STEP -Message 'GPO-004 NX-DC-Audit-Policy (advanced audit)'
$audit = Get-NxGpo -Name 'NX-DC-Audit-Policy' -Comment 'Advanced audit policy and Security log size for domain controllers'
Set-NxGpoLink -Name $audit.DisplayName -Target $dcOu

# Subcategory GUIDs are read from auditpol on this server (no hard-coded GUIDs).
$guidByName = @{}
foreach ($line in (& auditpol.exe /list /subcategory:* /v)) {
    if ($line -match '^\s+(.+?)\s+(\{[0-9A-Fa-f-]{36}\})\s*$') { $guidByName[$Matches[1].Trim()] = $Matches[2] }
}
$auditWanted = [ordered]@{
    'Credential Validation'           = 3
    'Kerberos Authentication Service' = 3
    'User Account Management'         = 3
    'Security Group Management'       = 3
    'Logon'                           = 3
    'Account Lockout'                 = 2
    'Directory Service Changes'       = 1
    'Audit Policy Change'             = 1
}
$settingText = @{ 1 = 'Success'; 2 = 'Failure'; 3 = 'Success and Failure' }
$csv = @('Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting,Setting Value')
foreach ($name in $auditWanted.Keys) {
    if (-not $guidByName.ContainsKey($name)) { throw "auditpol did not list subcategory '$name'" }
    $v = $auditWanted[$name]
    $csv += ",System,Audit $name,$($guidByName[$name].ToLower()),$($settingText[$v]),,$v"
}
$auditCsv = Join-Path (Get-NxGpoSysvolPath $audit) 'Machine\Microsoft\Windows NT\Audit\audit.csv'
$csvChanged = -not (Test-Path $auditCsv) -or ((Get-Content $auditCsv) -join "`n") -ne ($csv -join "`n")
if ($csvChanged) {
    New-Item -ItemType Directory -Path (Split-Path $auditCsv) -Force | Out-Null
    Set-Content -Path $auditCsv -Value $csv -Encoding ASCII
}
# "Force audit policy subcategory settings to override audit policy category settings"
$secChanged = Set-NxSecurityTemplate -Gpo $audit -Values @{
    'Registry Values' = @{ 'MACHINE\System\CurrentControlSet\Control\Lsa\SCENoApplyLegacyAuditPolicy' = '4,1' }
}
if ($csvChanged -or $secChanged) {
    Add-NxGpoCse -Gpo $audit -Pairs $cseSecurity, $cseAudit
    Step-NxGpoMachineVersion $audit
    Write-NxLog -Level OK -Message "Audit subcategories written: $($auditWanted.Keys -join ', ')"
}
else { Write-NxLog -Level OK -Message 'Audit policy already compliant' }
Set-GPRegistryValue -Name $audit.DisplayName -Key 'HKLM\Software\Policies\Microsoft\Windows\EventLog\Security' `
    -ValueName 'MaxSize' -Type DWord -Value $gp.SecurityEventLogMaxKB | Out-Null
Write-NxLog -Level OK -Message "Security event log max size: $($gp.SecurityEventLogMaxKB) KB"

# =============================================================================
# GPO-003 - NX-Baseline-Security (firewall, SMBv1, banner)
# =============================================================================
Write-NxLog -Level STEP -Message 'GPO-003 NX-Baseline-Security'
$base = Get-NxGpo -Name 'NX-Baseline-Security' -Comment 'Company security baseline: firewall on, SMBv1 off, logon banner'
Set-NxGpoLink -Name $base.DisplayName -Target (Get-NxOuPath -Config $cfg) -Enforced
Set-NxGpoLink -Name $base.DisplayName -Target $dcOu

$store = "$domainDns\$($base.DisplayName)"
Set-NetFirewallProfile -PolicyStore $store -Profile Domain, Private, Public -Enabled True `
    -DefaultInboundAction Block -DefaultOutboundAction Allow -LogBlocked True -LogAllowed False `
    -LogFileName '%systemroot%\system32\LogFiles\Firewall\pfirewall.log' -LogMaxSizeKilobytes 16384
Write-NxLog -Level OK -Message 'Firewall: all profiles ON, inbound Block, outbound Allow, dropped packets logged'

Set-GPRegistryValue -Name $base.DisplayName -Key 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' `
    -ValueName 'SMB1' -Type DWord -Value 0 | Out-Null
Write-NxLog -Level OK -Message 'SMBv1 server disabled'

$bannerChanged = Set-NxSecurityTemplate -Gpo $base -Values @{
    'Registry Values' = [ordered]@{
        'MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\LegalNoticeCaption' = ('1,"{0}"' -f $gp.LogonBannerTitle)
        'MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\LegalNoticeText'    = ('7,{0}' -f $gp.LogonBannerText)
    }
}
if ($bannerChanged) {
    Add-NxGpoCse -Gpo $base -Pairs $cseSecurity
    Step-NxGpoMachineVersion $base
}
Write-NxLog -Level OK -Message 'Interactive logon banner configured'

# =============================================================================
# GPO-005 - Administrative restrictions
# =============================================================================
Write-NxLog -Level STEP -Message 'GPO-005 NX-Servers-Admins (Restricted Groups, MemberOf form)'
$srv = Get-NxGpo -Name 'NX-Servers-Admins' -Comment 'GG-IT-ServerAdmins becomes member of local Administrators on member servers'
Set-NxGpoLink -Name $srv.DisplayName -Target (Get-NxOuPath -Config $cfg -Name 'Servers')
# "MemberOf" form ADDS the group to local Administrators without removing other members.
$srvChanged = Set-NxSecurityTemplate -Gpo $srv -Values @{
    'Group Membership' = @{ ("*{0}__Memberof" -f (Get-NxSidString 'GG-IT-ServerAdmins')) = '*S-1-5-32-544' }
}
if ($srvChanged) { Add-NxGpoCse -Gpo $srv -Pairs $cseSecurity; Step-NxGpoMachineVersion $srv }
Write-NxLog -Level OK -Message 'GG-IT-ServerAdmins -> BUILTIN\Administrators on OU=Servers'

Write-NxLog -Level STEP -Message 'GPO-005 NX-ServiceAccounts-Restrictions (User Rights Assignment)'
$svc = Get-NxGpo -Name 'NX-ServiceAccounts-Restrictions' -Comment 'Service accounts cannot log on locally or through Remote Desktop'
Set-NxGpoLink -Name $svc.DisplayName -Target $dcOu
Set-NxGpoLink -Name $svc.DisplayName -Target (Get-NxOuPath -Config $cfg -Name 'Servers')
$svcSid = '*' + (Get-NxSidString 'GG-Service-Accounts')
$svcChanged = Set-NxSecurityTemplate -Gpo $svc -Values @{
    'Privilege Rights' = [ordered]@{
        SeDenyInteractiveLogonRight       = $svcSid
        SeDenyRemoteInteractiveLogonRight = $svcSid
    }
}
if ($svcChanged) { Add-NxGpoCse -Gpo $svc -Pairs $cseSecurity; Step-NxGpoMachineVersion $svc }
Write-NxLog -Level OK -Message 'GG-Service-Accounts denied local and RDP logon on DCs and member servers'

Write-NxLog -Level STEP -Message 'GPO-005 NX-Users-Desktop (secure screen saver)'
$desk = Get-NxGpo -Name 'NX-Users-Desktop' -Comment 'User desktop restrictions for department OUs'
foreach ($ou in $cfg.DepartmentOus) { Set-NxGpoLink -Name $desk.DisplayName -Target (Get-NxOuPath -Config $cfg -Name $ou) }
$deskKey = 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop'
Set-GPRegistryValue -Name $desk.DisplayName -Key $deskKey -ValueName 'ScreenSaveActive' -Type String -Value '1' | Out-Null
Set-GPRegistryValue -Name $desk.DisplayName -Key $deskKey -ValueName 'ScreenSaverIsSecure' -Type String -Value '1' | Out-Null
Set-GPRegistryValue -Name $desk.DisplayName -Key $deskKey -ValueName 'ScreenSaveTimeOut' -Type String -Value ([string]$gp.ScreenSaverTimeoutSec) | Out-Null
Write-NxLog -Level OK -Message "Screen saver: on, password protected, $($gp.ScreenSaverTimeoutSec) s"

# =============================================================================
# Apply and quick check (full evidence: 23-Get-NxGpoReport.ps1)
# =============================================================================
Write-NxLog -Level STEP -Message 'gpupdate /force on NX-DC01'
& gpupdate.exe /target:computer /force | Out-Null
$pp = Get-ADDefaultDomainPasswordPolicy
Write-NxLog -Level OK -Message ("Domain policy in force: MinLength={0} Complexity={1} History={2} MaxAge={3} LockoutThreshold={4}" -f `
        $pp.MinPasswordLength, $pp.ComplexityEnabled, $pp.PasswordHistoryCount, $pp.MaxPasswordAge, $pp.LockoutThreshold)
Write-NxLog -Level OK -Message 'Done. Evidence: run 23-Get-NxGpoReport.ps1'
exit 0
