[CmdletBinding()]
param(
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$ExpectedRegion = "ap-northeast-2",
    [switch]$RequireInputs
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$terraformPath = Join-Path $root $TerraformRoot

if (-not (Test-Path -LiteralPath $terraformPath -PathType Container)) {
    throw "Terraform root does not exist: $TerraformRoot"
}

$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $aws) {
    throw "AWS CLI is not installed. Install AWS CLI v2, then authenticate with short-lived credentials."
}

$callerJson = & aws sts get-caller-identity --output json 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($callerJson)) {
    throw "AWS authentication is unavailable. Use an approved short-lived profile; do not create long-lived keys for this check."
}
$caller = $callerJson | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$caller.Account) -or [string]::IsNullOrWhiteSpace([string]$caller.Arn)) {
    throw "AWS caller identity was incomplete."
}

$configuredRegion = (& aws configure get region 2>$null).Trim()
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

[pscustomobject]@{
    authenticated          = $true
    account_masked         = $maskedAccount
    principal              = $principal
    region                 = $configuredRegion
    terraform_root         = $TerraformRoot
    deployment_inputs_ready = $missingInputs.Count -eq 0
} | ConvertTo-Json -Compress
