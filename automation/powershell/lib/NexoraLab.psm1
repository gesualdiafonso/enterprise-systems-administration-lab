#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helpers for the Nexora lab PowerShell scripts (runs ON NX-DC01).

.DESCRIPTION
    - Write-NxLog          : timestamped console + file logging (C:\Nexora\logs)
    - Import-NxConfig      : loads config\nexora-ad.psd1
    - Get-NxSecret         : reads an SSM Parameter Store SecureString as [SecureString]
    - Get-NxRegion         : current AWS region from IMDSv2
    - Assert-NxAdministrator / Test-NxDomainController / Wait-NxActiveDirectory

    Secrets are never written to the console, the log, or the transcript.
#>

Set-StrictMode -Version Latest

$script:NxRoot = 'C:\Nexora'
$script:NxLogFile = $null

function Write-NxLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP')][string]$Level = 'INFO'
    )
    $line = '{0} [{1,-5}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    # Write-Host (not Write-Output) so logging never pollutes function return values.
    # SSM Run Command captures host output in StandardOutputContent.
    Write-Host $line
    if ($script:NxLogFile) { Add-Content -Path $script:NxLogFile -Value $line -Encoding UTF8 }
}

function Start-NxLog {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ScriptName)
    $logDir = Join-Path $script:NxRoot 'logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $script:NxLogFile = Join-Path $logDir ('{0}-{1}.log' -f $ScriptName, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Write-NxLog -Level STEP -Message "=== $ScriptName on $env:COMPUTERNAME ==="
}

function Import-NxConfig {
    [CmdletBinding()]
    param([string]$Path = (Join-Path $script:NxRoot 'config\nexora-ad.psd1'))
    if (-not (Test-Path -Path $Path)) { throw "Config file not found: $Path" }
    Import-PowerShellDataFile -Path $Path
}

function Get-NxImdsToken {
    Invoke-RestMethod -Method Put -Uri 'http://169.254.169.254/latest/api/token' `
        -Headers @{ 'X-aws-ec2-metadata-token-ttl-seconds' = '300' } -TimeoutSec 5
}

function Get-NxRegion {
    [CmdletBinding()]
    param()
    $token = Get-NxImdsToken
    Invoke-RestMethod -Uri 'http://169.254.169.254/latest/meta-data/placement/region' `
        -Headers @{ 'X-aws-ec2-metadata-token' = $token } -TimeoutSec 5
}

function Get-NxSecret {
    <#
    .SYNOPSIS
        Returns an SSM Parameter Store SecureString parameter as a [SecureString].
        Uses AWS Tools for PowerShell (pre-installed on AWS Windows AMIs) and
        falls back to the AWS CLI. The plaintext never reaches the output stream.
    #>
    [CmdletBinding()]
    [OutputType([securestring])]
    param([Parameter(Mandatory)][string]$Name)

    $region = Get-NxRegion
    $plain = $null
    try {
        if (Get-Module -ListAvailable -Name AWS.Tools.SimpleSystemsManagement) {
            Import-Module AWS.Tools.SimpleSystemsManagement -ErrorAction Stop
        }
        elseif (Get-Module -ListAvailable -Name AWSPowerShell) {
            Import-Module AWSPowerShell -ErrorAction Stop
        }
        if (Get-Command -Name Get-SSMParameter -ErrorAction SilentlyContinue) {
            $plain = (Get-SSMParameter -Name $Name -WithDecryption $true -Region $region -ErrorAction Stop).Value
        }
        elseif (Get-Command -Name aws.exe -ErrorAction SilentlyContinue) {
            $plain = & aws.exe ssm get-parameter --name $Name --with-decryption --region $region `
                --query 'Parameter.Value' --output text
            if ($LASTEXITCODE -ne 0) { throw "aws ssm get-parameter failed for $Name" }
        }
        else {
            throw 'Neither AWS Tools for PowerShell nor the AWS CLI is available.'
        }
        if ([string]::IsNullOrEmpty($plain)) { throw "Parameter $Name is empty." }
        ConvertTo-SecureString -String $plain -AsPlainText -Force
    }
    catch {
        throw "Cannot read SSM parameter '$Name' (does it exist as SecureString? does the instance role allow it?): $($_.Exception.Message)"
    }
    finally {
        $plain = $null
    }
}

function New-NxRandomPassword {
    <# Random password for accounts whose password nobody needs to know. #>
    [CmdletBinding()]
    [OutputType([securestring])]
    param([ValidateRange(20, 128)][int]$Length = 40)
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!#%+-=?@_')
    $all = -join $sets
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] $Length
    $rng.GetBytes($bytes)
    $chars = for ($i = 0; $i -lt $Length; $i++) { $all[$bytes[$i] % $all.Length] }
    # Guarantee one character of each class.
    for ($i = 0; $i -lt $sets.Count; $i++) { $chars[$i] = $sets[$i][$bytes[$i] % $sets[$i].Length] }
    $secure = New-Object System.Security.SecureString
    foreach ($c in $chars) { $secure.AppendChar($c) }
    $secure.MakeReadOnly()
    $rng.Dispose()
    $secure
}

function Assert-NxAdministrator {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This script must run elevated (SSM Run Command runs as LocalSystem).'
    }
}

function Test-NxDomainController {
    # DomainRole 4 = backup DC, 5 = primary DC
    (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole -ge 4
}

function Wait-NxActiveDirectory {
    <# Waits until AD Web Services answer (needed by the ActiveDirectory module after boot). #>
    [CmdletBinding()]
    param([int]$TimeoutSeconds = 900)
    Import-Module ActiveDirectory -ErrorAction Stop
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $domain = Get-ADDomain -ErrorAction Stop
            Write-NxLog -Level OK -Message "Active Directory is answering: $($domain.DNSRoot)"
            return $domain
        }
        catch {
            Write-NxLog -Message 'Waiting for Active Directory Web Services...'
            Start-Sleep -Seconds 20
        }
    }
    throw "Active Directory did not become available within $TimeoutSeconds seconds."
}

function Get-NxOuPath {
    <# OU=<Name>,OU=Nexora,DC=nexora,DC=local #>
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [string]$Name
    )
    $root = "OU=$($Config.Domain.RootOu),$($Config.Domain.DistinguishedName)"
    if ([string]::IsNullOrEmpty($Name)) { return $root }
    "OU=$Name,$root"
}

Export-ModuleMember -Function Write-NxLog, Start-NxLog, Import-NxConfig, Get-NxRegion, Get-NxSecret,
New-NxRandomPassword, Assert-NxAdministrator, Test-NxDomainController, Wait-NxActiveDirectory, Get-NxOuPath
