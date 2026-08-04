[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$environmentRoot = Join-Path $root "infra/terraform/environments/development"
$userData = Get-Content -LiteralPath (Join-Path $environmentRoot "templates/ec2-user-data.sh.tftpl") -Raw
$compute = Get-Content -LiteralPath (Join-Path $environmentRoot "compute.tf") -Raw
$iam = Get-Content -LiteralPath (Join-Path $environmentRoot "iam.tf") -Raw
$runtime = Get-Content -LiteralPath (Join-Path $environmentRoot "runtime.tf") -Raw
$variables = Get-Content -LiteralPath (Join-Path $environmentRoot "variables.tf") -Raw
$pipeline = Get-Content -LiteralPath (Join-Path $environmentRoot "pipeline.tf") -Raw
$prerequisites = Get-Content -LiteralPath (Join-Path $root "scripts/test-aws-deployment-prerequisites.ps1") -Raw

foreach ($required in @(
    "BACKTEST_OUTBOX_RELAY_ENABLED",
    "idea2strategy-runtime.service",
    "docker compose --project-name idea2strategy",
    "restart: unless-stopped",
    "read_only: true",
    "no-new-privileges:true",
    "amazon-cloudwatch-agent",
    "aws ecr get-login-password",
    "@sha256:",
    "umask 077",
    "secretsmanager get-secret-value",
    "chmod 0600",
    "config --quiet"
)) {
    if (-not $userData.Contains($required)) {
        throw "EC2 runtime bootstrap is missing: $required"
    }
}
if (-not $userData.Contains('runtime_role == "trading"') -or -not $userData.Contains('shutdown -h now')) {
    throw "A newly provisioned scheduled Trading host must not remain running after bootstrap."
}
if (-not $userData.Contains('chmod 0600 /etc/nginx/conf.d/idea2strategy-origin.conf')) {
    throw "The Nginx origin-header secret configuration must be root-readable only."
}
foreach ($forbiddenSecretTransport in @('--arg value', 'DB_PASSWORD=', 'DB_USERNAME=')) {
    if ($userData.Contains($forbiddenSecretTransport)) {
        throw "Runtime bootstrap must not expose secret values through process argv/environment: $forbiddenSecretTransport"
    }
}
if (-not $userData.Contains("jq -Rrs --arg name") -or
    -not $userData.Contains("json.load(sys.stdin)")) {
    throw "Runtime bootstrap must pass generated env values and database credentials through stdin."
}

foreach ($service in @("backend-api", "backend-worker", "backtest-api")) {
    if (-not $userData.Contains($service)) {
        throw "Core runtime does not start required service: $service"
    }
}
foreach ($healthBoundary in @(
    "location = /api/healthz/backend",
    "proxy_pass http://127.0.0.1:8080/actuator/health",
    "location = /api/healthz/backtest",
    "proxy_pass http://127.0.0.1:8082/health"
)) {
    if (-not $userData.Contains($healthBoundary)) {
        throw "Public deployment verification health boundary is missing: $healthBoundary"
    }
}
foreach ($manual in @("backend-batch", "admin-mcp", "profiles: [manual]")) {
    if (-not $userData.Contains($manual)) {
        throw "Core manual runtime boundary is missing: $manual"
    }
}
foreach ($factory in @(
    "backtest_engine.production:api_authenticator",
    "backtest_engine.production:s3_object_store",
    "backtest_engine.production:postgres_owner_directory",
    "backtest_engine.production:postgres_compiled_plan_source",
    "backtest_engine.production:postgres_dataset_manifest_source",
    "backtest_engine.production:execution_policy_catalog",
    "backtest_engine.production:sqs_dead_letter_sink",
    "backtest_engine.production:orchestrator_job_handler",
    "backtest_engine.production:postgres_execution_key_store"
)) {
    if (-not $userData.Contains($factory)) {
        throw "Backtest production adapter is not wired: $factory"
    }
}
foreach ($required in @(
    "BACKTEST_BASIC_MAX_CONCURRENCY=2",
    "BACKTEST_CUSTOM_MAX_CONCURRENCY=1",
    "BACKTEST_COMPETITION_MAX_CONCURRENCY=1",
    "BACKTEST_MAX_TOTAL_CONCURRENCY=4",
    "BACKTEST_MARKET_DATA_BATCH_SIZE=65536",
    "BACKTEST_JOB_HANDLER=backtest_engine.production:orchestrator_job_handler"
)) {
    if (-not $userData.Contains($required)) {
        throw "Backtest bounded worker runtime is missing: $required"
    }
}

foreach ($required in @(
    "market-gateway",
    "trading-worker",
    "ALPACA_API_SECRET",
    "TRADING_WARMUP_MATERIALIZATION_RECEIPT_PATH",
    "MARKET_GATEWAY_MATERIALIZATION_RECEIPT_PATH",
    "source-version-id",
    "sha256sum --check",
    "stop_grace_period: 45s",
    'user: "10001:10001"',
    "cap_drop: [ALL]"
)) {
    if (-not $userData.Contains($required)) {
        throw "Trading runtime safety is missing: $required"
    }
}

foreach ($required in @(
    'resource "aws_secretsmanager_secret" "core_internal"',
    'resource "aws_secretsmanager_secret_version" "core_internal"',
    'resource "aws_secretsmanager_secret" "backtest_internal"',
    'resource "aws_secretsmanager_secret_version" "backtest_internal"',
    'resource "random_password" "identity_email_encryption"',
    'resource "random_password" "backtest_result_ingest"',
    'prevent_destroy = true'
)) {
    if (-not $runtime.Contains($required)) {
        throw "Generated internal runtime secret boundary is missing: $required"
    }
}
if ($runtime -match '(?m)^\s*output\s+".*secret') {
    throw "Runtime secret material must never be a Terraform output."
}

foreach ($required in @(
    'core_internal_secret',
    'backtest_internal_secret',
    's3:GetObjectVersion',
    'AmazonEC2ContainerRegistryReadOnly'
)) {
    if (-not ($compute.Contains($required) -or $iam.Contains($required))) {
        throw "Runtime IAM or bootstrap dependency is missing: $required"
    }
}

foreach ($variable in @("backtest_policy_artifacts", "trading_runtime_artifacts", "runtime_database_secret_names")) {
    if (-not $variables.Contains(('variable "' + $variable + '"'))) {
        throw "Immutable runtime artifact input is missing: $variable"
    }
}
if (-not $variables.Contains('variable "enable_backtest_outbox_relay"') -or
    -not $runtime.Contains('condition     = var.enable_backtest_outbox_relay')) {
    throw "Full runtime must fail closed until the verified Backtest Outbox relay is explicitly enabled."
}
if (-not $variables.Contains('version_id') -or -not $variables.Contains('sha256')) {
    throw "Runtime artifacts must be pinned by S3 version and SHA-256."
}
foreach ($consumer in @("backend", "batch", "backtest", "trading", "pipeline")) {
    if ($variables -notmatch ('(?m)^\s*' + [regex]::Escape($consumer) + '\s*=\s*"idea2strategy-dev/database/')) {
        throw "Least-privilege runtime database secret is missing: $consumer"
    }
}
foreach ($field in @("engine", "host", "port", "dbname", "username", "password", "PIPELINE_WORKER_DATABASE_URL")) {
    if (-not $prerequisites.Contains($field)) {
        throw "AWS prerequisite check does not validate runtime database field: $field"
    }
}
if (-not $pipeline.Contains('PIPELINE_WORKER_DATABASE_URL') -or
    -not $pipeline.Contains('runtime_database["pipeline"]')) {
    throw "Pipeline database URL is not injected from its dedicated runtime secret."
}
if ($iam.Contains('master_user_secret') -or $iam.Contains('autoscaling:SetDesiredCapacity')) {
    throw "Application runtime roles must not read the RDS master secret or self-scale before fenced leases exist."
}
if ($userData -notmatch '(?s)admin-mcp:.*?env_file: \[/etc/idea2strategy/runtime-secret\.env\]' -or
    $userData -notmatch '(?s)backend-batch:.*?env_file: \[/etc/idea2strategy/batch-secret\.env\]') {
    throw "Core manual processes do not use their exact backend/batch database credential boundary."
}

$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($null -eq $docker) {
    throw "Docker Compose is required to verify runtime env-file quoting."
}
& docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose v2 is required to verify runtime env-file quoting."
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("idea2strategy-compose-env-" + [guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
try {
    $expected = 'spaces # quotes " dollar $ and slash \ remain exact'
    $encoded = ConvertTo-Json $expected -Compress
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $tempRoot "runtime.env"), ("TEST_VALUE=" + $encoded + "`n"), $utf8NoBom)
    $composeFixture = @'
services:
  probe:
    image: alpine:3.22
    env_file: [runtime.env]
'@
    [IO.File]::WriteAllText((Join-Path $tempRoot "compose.yaml"), $composeFixture, $utf8NoBom)
    $rendered = & docker compose --project-directory $tempRoot config --format json
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose rejected JSON-quoted runtime env values."
    }
    $parsed = $rendered | ConvertFrom-Json
    # Compose serializes literal dollars/backslashes escaped in `config` output;
    # normalize that representation and verify the container value remains exact.
    $normalized = $parsed.services.probe.environment.TEST_VALUE.Replace('$$', '$').Replace('\\', '\')
    if ($normalized -cne $expected) {
        throw "Docker Compose did not preserve JSON-quoted runtime env values exactly."
    }
} finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $resolvedBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($resolvedBase, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTemp).StartsWith("idea2strategy-compose-env-")) {
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}

foreach ($required in @(
    "FARGATE_SPOT",
    "ARM64",
    "stopTimeout",
    "awslogs",
    "PIPELINE_WORKER_ENVIRONMENT",
    "PIPELINE_WORKER_MESSAGE_SOURCE",
    "PIPELINE_WORKER_CATALOG_ROOT",
    "PIPELINE_WORKER_OBJECT_STORE_ROOT",
    "PIPELINE_WORKER_HEALTH_FILE",
    "healthCheck"
)) {
    if (-not $pipeline.Contains($required)) {
        throw "Desired-zero pipeline runtime is missing: $required"
    }
}

Write-Output "Deployment runtime wiring checks passed."
