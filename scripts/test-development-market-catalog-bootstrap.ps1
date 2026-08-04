[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Read-RequiredFile([string]$RelativePath) {
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required market catalog bootstrap file is missing: $RelativePath"
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Assert-NotContains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.Contains($Needle)) { throw $Message }
}

$orchestrator = Read-RequiredFile "scripts/invoke-development-market-catalog-bootstrap.ps1"
$hostScript = Read-RequiredFile "scripts/aws/development-market-catalog-bootstrap.sh"
$runbook = Read-RequiredFile "docs/infrastructure/development-market-catalog-bootstrap-runbook.md"
$workflow = Read-RequiredFile ".github/workflows/ci.yml"

foreach ($needle in @(
    '[ValidateSet("DryRun", "Apply")]',
    '[switch]$Execute',
    '[string]$PipelineImageDigest',
    '[string]$ReviewedDryRunSourceDigest',
    '[string]$ReviewedDryRunReceiptVersionId',
    '41ea8bc1e5939aa9841100d2b06c5e9b34e0494e',
    'ExpectedObjectCount = 768',
    'ExpectedManifestCount = 96',
    'architecture,Values=arm64',
    'ubuntu-noble-24.04-arm64-server-',
    'terraform output -json',
    'market_loader_secret_arn',
    'runtime_database_secrets.pipeline',
    'describe-repositories',
    'GetSecretValue',
    'ecr:GetAuthorizationToken',
    's3:GetObjectVersion',
    'PutRolePolicy',
    'DeleteRolePolicy',
    'AWS-RunShellScript',
    'Sanitized bootstrap diagnostics:',
    'HttpTokens=required',
    'sha256sum --check',
    'market-catalog-bootstrap/',
    'VersionId',
    'TerminateInstances',
    'finally'
)) {
    Assert-Contains $orchestrator $needle "Market catalog orchestrator safety boundary is missing: $needle"
}

if ($orchestrator.Contains('Get-TerraformOutput "ecr_repository_urls"')) {
    throw "Artifact-foundation ECR must be discovered from the authenticated AWS account, not the runtime Terraform state."
}

foreach ($needle in @(
    'set +x',
    'trap cleanup EXIT',
    'sed -E',
    'command-error.log',
    'LEGACY_DATABASE_URL',
    'DATABASE_URL',
    '--env-file',
    '--entrypoint market-pipeline',
    'bootstrap-legacy-catalog',
    '--expected-object-count',
    '--expected-manifest-count',
    'DRY_RUN',
    'source_digest',
    'APPLIED',
    'ALREADY_APPLIED',
    '--execute',
    'secretsmanager get-secret-value',
    'docker login --username AWS --password-stdin'
)) {
    Assert-Contains $hostScript $needle "Host bootstrap safety or lifecycle check is missing: $needle"
}

Assert-NotContains $orchestrator 'SecretString --output text' "Secret values must be fetched only on the temporary host."
if ($orchestrator -match '(?i)Write-(Host|Output).*(password|SecretString|DATABASE_URL)') {
    throw "Orchestrator must not print credential-bearing values."
}
if ($hostScript -match '(?m)^\s*(echo|printf)\s+[^>\r\n]*\$(LEGACY_DATABASE_URL|DATABASE_URL|source_secret|target_secret)\b') {
    throw "Host bootstrap must not print credential-bearing values."
}
Assert-Contains $hostScript 'chmod 0600 "$credentials_env"' "Credential env file must be owner-only."
Assert-Contains $hostScript 'rm -f -- "$credentials_env"' "Credential env file must be removed in cleanup."
Assert-Contains $hostScript 'install -d -o 10001 -g 10001 -m 0700 "$work_directory/evidence"' "The non-root pipeline image must own its evidence directory."
Assert-Contains $workflow './scripts/test-development-market-catalog-bootstrap.ps1' "CI must run the market catalog source test."

foreach ($needle in @(
    '-Phase DryRun -Execute',
    '-Phase Apply -ReviewedDryRunSourceDigest',
    '-ReviewedDryRunReceiptVersionId',
    '768',
    '96',
    'append-only',
    'ALREADY_APPLIED',
    'temporary',
    'versioned'
)) {
    Assert-Contains $runbook $needle "Runbook is missing an operator safety instruction: $needle"
}

[pscustomobject]@{
    status = "passed"
    pipeline_source_commit = "41ea8bc1e5939aa9841100d2b06c5e9b34e0494e"
    expected_objects = 768
    expected_manifests = 96
    secret_values_in_argv = $false
    replay_required = $true
} | ConvertTo-Json -Compress
