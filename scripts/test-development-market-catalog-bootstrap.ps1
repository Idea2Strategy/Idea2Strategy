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
    '$pipelineSourceCommit = $Matches[1]',
    'ls-tree HEAD data-pipeline',
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
    'HttpTokens=required',
    'HttpPutResponseHopLimit=2',
    'sha256sum --check',
    'market-catalog-bootstrap/',
    'VersionId',
    'TerminateInstances',
    'finally'
)) {
    Assert-Contains $orchestrator $needle "Market catalog orchestrator safety boundary is missing: $needle"
}
Assert-NotContains $orchestrator 'HttpPutResponseHopLimit=1' "The pinned AWS CLI container requires two IMDSv2 network hops to use the instance role."
Assert-NotContains $orchestrator 'ssm wait command-executed' "The AWS CLI command-executed waiter expires before the one-hour catalog command timeout."
Assert-NotContains $orchestrator 'Write-Warning "Sanitized bootstrap diagnostics:' "Remote stderr must remain protected instead of being printed without structural redaction."
Assert-Contains $orchestrator 'ssm get-command-invocation' "The orchestrator must poll the exact SSM invocation until a terminal status."
Assert-Contains $orchestrator '$commandDeadline' "SSM invocation polling must have an explicit deadline matching the remote timeout."
Assert-Contains $orchestrator 'Start-Sleep -Seconds 5' "SSM invocation polling must be bounded without a hot loop."

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

$gitlinkLine = ((& git -C $root ls-tree HEAD data-pipeline) -join "`n").Trim()
if ($LASTEXITCODE -ne 0 -or $gitlinkLine -notmatch '^160000\s+commit\s+([0-9a-f]{40})\s+data-pipeline$') {
    throw "Unable to resolve the current data-pipeline gitlink."
}

[pscustomobject]@{
    status = "passed"
    pipeline_source_commit = $Matches[1]
    expected_objects = 768
    expected_manifests = 96
    secret_values_in_argv = $false
    replay_required = $true
} | ConvertTo-Json -Compress
