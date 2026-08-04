[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Read-RequiredFile([string]$RelativePath) {
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required database bootstrap file is missing: $RelativePath"
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { throw $Message }
}

$database = Read-RequiredFile "infra/terraform/environments/development/database.tf"
$runtime = Read-RequiredFile "infra/terraform/environments/development/runtime.tf"
$iam = Read-RequiredFile "infra/terraform/environments/development/iam.tf"
$security = Read-RequiredFile "infra/terraform/environments/development/security.tf"
$outputs = Read-RequiredFile "infra/terraform/environments/development/outputs.tf"
$orchestrator = Read-RequiredFile "scripts/invoke-development-database-bootstrap.ps1"
$bootstrap = Read-RequiredFile "scripts/aws/development-database-bootstrap.sh"

Assert-Contains $database 'resource "aws_secretsmanager_secret" "runtime_database"' "Terraform must own runtime database secret metadata."
Assert-Contains $database 'for_each = var.runtime_database_secret_names' "All five configured runtime database secrets must be owned."
Assert-Contains $database 'prevent_destroy = true' "Runtime database secret metadata must be protected from destroy."
if ($database.Contains('aws_secretsmanager_secret_version')) {
    throw "Terraform must not own runtime database secret values."
}
if ($runtime.Contains('data "aws_secretsmanager_secret" "runtime_database"')) {
    throw "Runtime database secrets must not remain unmanaged data sources."
}

foreach ($needle in @(
    'resource "aws_iam_role" "database_bootstrap"',
    'AmazonSSMManagedInstanceCore',
    'resource "aws_iam_instance_profile" "database_bootstrap"',
    'deployment-bootstrap/*',
    'resource "aws_security_group" "database_bootstrap"',
    'resource "aws_vpc_security_group_ingress_rule" "rds_from_database_bootstrap"'
)) {
    Assert-Contains ($iam + $security) $needle "Dedicated database bootstrap IAM/network boundary is missing: $needle"
}
Assert-Contains $outputs 'output "database_bootstrap"' "Terraform must expose a credential-free bootstrap target descriptor."

foreach ($needle in @(
    '[switch]$Execute',
    '[string]$PolicySeedSqlPath',
    '[string]$PolicySeedSha256',
    'policy-seed.sql',
    'policy_seed_sha256',
    'PutRolePolicy',
    'DeleteRolePolicy',
    'TerminateInstances',
    'AWS-RunShellScript',
    'HttpTokens=required',
    'GetSecretValue',
    'PutSecretValue',
    'deployment-bootstrap',
    'finally'
)) {
    Assert-Contains $orchestrator $needle "Orchestrator safety boundary is missing: $needle"
}
if ($orchestrator -match '(?i)Write-(Host|Output).*(password|SecretString)') {
    throw "Orchestrator must not print password or SecretString values."
}

foreach ($consumer in @("backend", "batch", "backtest", "trading", "pipeline")) {
    Assert-Contains $bootstrap "idea2strategy_${consumer}_runtime" "Bootstrap LOGIN role is missing for $consumer."
    Assert-Contains $bootstrap "idea2strategy_${consumer}" "Bootstrap group role is missing for $consumer."
}
foreach ($needle in @(
    'set +x',
    'trap cleanup EXIT',
    'sha256sum --check',
    'redgate/flyway@sha256:',
    'amazon/aws-cli@sha256:',
    'migrate',
    'validate',
    'PIPELINE_WORKER_DATABASE_URL',
    'postgresql+psycopg://',
    'secretsmanager put-secret-value',
    'rolcanlogin',
    'pg_auth_members',
    'idea2strategy_policy_seed_bootstrap',
    'trading.fee_policy_versions',
    'trading.buying_power_buffer_policy_versions',
    'backtest.execution_policy_versions',
    '--single-transaction',
    'policy_seed_sha256',
    'policy_versions',
    '177'
)) {
    Assert-Contains $bootstrap $needle "Host bootstrap safety or verification is missing: $needle"
}
if ($bootstrap -match '(?m)^\s*echo\s+["'']?\$(master_json|master_password|password)\b' -or
    $bootstrap -match '(?m)^\s*printf\s+[^>\r\n]*\$(master_json|master_password)\b') {
    throw "Host bootstrap must not print credential-bearing variables."
}

$terraformFiles = Get-ChildItem -LiteralPath (Join-Path $root 'infra/terraform/environments/development') -Filter '*.tf' -File
$runtimeReferences = @($terraformFiles | Select-String -Pattern 'data\.aws_secretsmanager_secret\.runtime_database')
if ($runtimeReferences.Count -gt 0) {
    throw "Terraform still contains unmanaged runtime database secret references."
}

[pscustomobject]@{
    status = "passed"
    protected_secret_metadata = $true
    terraform_secret_versions = $false
    dedicated_bootstrap_boundary = $true
    consumers = 5
} | ConvertTo-Json -Compress
