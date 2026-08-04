[CmdletBinding()]
param(
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$ExpectedRegion = "ap-northeast-2",
    [string]$AwsProfile = "idea2strategy-terraform",
    [switch]$RequireInputs,
    [switch]$RequireAlpacaSecrets,
    [string]$AlpacaApiKeySecretName = "idea2strategy-dev/backtest/alpaca",
    [string]$AlpacaSecretKeySecretName = "idea2strategy-dev/backtest/alpaca-secret"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$terraformPath = Join-Path $root $TerraformRoot

if (-not (Test-Path -LiteralPath $terraformPath -PathType Container)) {
    throw "Terraform root does not exist: $TerraformRoot"
}

$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $aws) {
    $defaultAwsCli = Join-Path $env:ProgramFiles "Amazon\AWSCLIV2\aws.exe"
    if (Test-Path -LiteralPath $defaultAwsCli -PathType Leaf) {
        $awsExecutable = $defaultAwsCli
    } else {
        throw "AWS CLI is not installed. Install AWS CLI v2, then authenticate with short-lived credentials."
    }
} else {
    $awsExecutable = $aws.Source
}

$strictErrorPreference = $ErrorActionPreference
$previousAwsRegion = $env:AWS_REGION
$previousAwsDefaultRegion = $env:AWS_DEFAULT_REGION
$env:AWS_REGION = $ExpectedRegion
$env:AWS_DEFAULT_REGION = $ExpectedRegion
$ErrorActionPreference = "Continue"
$callerJson = & $awsExecutable sts get-caller-identity --profile $AwsProfile --region $ExpectedRegion --output json 2>$null
$callerExitCode = $LASTEXITCODE
$ErrorActionPreference = $strictErrorPreference
if ($callerExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($callerJson)) {
    throw "AWS authentication is unavailable. Use an approved short-lived profile; do not create long-lived keys for this check."
}
$caller = $callerJson | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$caller.Account) -or [string]::IsNullOrWhiteSpace([string]$caller.Arn)) {
    throw "AWS caller identity was incomplete."
}

$ErrorActionPreference = "Continue"
$configuredRegion = (& $awsExecutable configure get region --profile $AwsProfile 2>$null).Trim()
$regionExitCode = $LASTEXITCODE
$ErrorActionPreference = $strictErrorPreference
if ($regionExitCode -ne 0) {
    $configuredRegion = ""
}
if ([string]::IsNullOrWhiteSpace($configuredRegion)) {
    $configuredRegion = $env:AWS_REGION
}
if ([string]::IsNullOrWhiteSpace($configuredRegion)) {
    $configuredRegion = $env:AWS_DEFAULT_REGION
}
if ($configuredRegion -ne $ExpectedRegion) {
    throw "AWS region mismatch. Expected '$ExpectedRegion', observed '$configuredRegion'."
}

$account = [string]$caller.Account
$maskedAccount = ("*" * [Math]::Max(0, $account.Length - 4)) + $account.Substring([Math]::Max(0, $account.Length - 4))
$principal = ([string]$caller.Arn -split ":")[-1]

$inputPaths = @(
    (Join-Path $terraformPath "backend.hcl"),
    (Join-Path $terraformPath "terraform.tfvars")
)
$missingInputs = @($inputPaths | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($RequireInputs -and $missingInputs.Count -gt 0) {
    $relativeMissing = $missingInputs | ForEach-Object { [IO.Path]::GetRelativePath($root, $_) }
    throw "Ignored deployment inputs are missing: $($relativeMissing -join ', ')"
}

$alpacaSecretsReady = $false
if ($RequireAlpacaSecrets) {
    $requiredSecretFields = @{
        $AlpacaApiKeySecretName = "ALPACA_API_KEY"
        $AlpacaSecretKeySecretName = "ALPACA_SECRET_KEY"
    }
    foreach ($secretName in $requiredSecretFields.Keys) {
        $ErrorActionPreference = "Continue"
        $secretJson = & $awsExecutable secretsmanager get-secret-value `
            --profile $AwsProfile `
            --region $ExpectedRegion `
            --secret-id $secretName `
            --query SecretString `
            --output text 2>$null
        $secretExitCode = $LASTEXITCODE
        $ErrorActionPreference = $strictErrorPreference
        if ($secretExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($secretJson)) {
            throw "Required Alpaca secret is unavailable: $secretName"
        }
        try {
            $secretDocument = $secretJson | ConvertFrom-Json
        } catch {
            throw "Required Alpaca secret must contain a JSON object: $secretName"
        }
        $fieldName = $requiredSecretFields[$secretName]
        $fieldValue = $secretDocument.PSObject.Properties[$fieldName].Value
        if ([string]::IsNullOrWhiteSpace([string]$fieldValue)) {
            throw "Required Alpaca secret field is missing: $secretName/$fieldName"
        }
    }
    $secretJson = $null
    $secretDocument = $null
    $fieldValue = $null
    $alpacaSecretsReady = $true
}

$env:AWS_REGION = $previousAwsRegion
$env:AWS_DEFAULT_REGION = $previousAwsDefaultRegion

[pscustomobject]@{
    authenticated          = $true
    account_masked         = $maskedAccount
    principal              = $principal
    region                 = $configuredRegion
    profile                = $AwsProfile
    terraform_root         = $TerraformRoot
    deployment_inputs_ready = $missingInputs.Count -eq 0
    alpaca_secrets_ready     = $alpacaSecretsReady
} | ConvertTo-Json -Compress
