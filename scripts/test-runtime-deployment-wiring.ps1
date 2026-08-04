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
$queues = Get-Content -LiteralPath (Join-Path $environmentRoot "queues.tf") -Raw
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

foreach ($required in @(
    'resource "aws_sqs_queue" "room_ledger_opened"',
    'resource "aws_sqs_queue" "room_ledger_open_rejected"',
    'resource "aws_sqs_queue" "room_ledger_opened_dlq"',
    'resource "aws_sqs_queue" "room_ledger_open_rejected_dlq"'
)) {
    if (-not $queues.Contains($required)) {
        throw "Room-ledger result queue wiring is missing: $required"
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
    "backtest_engine.production:backtest_request_handler"
    "backtest_engine.production:postgres_request_receipt_store"
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
    "BACKTEST_JOB_HANDLER=backtest_engine.production:orchestrator_job_handler",
    "BACKTEST_REQUEST_HANDLER=backtest_engine.production:backtest_request_handler",
    "BACKTEST_REQUEST_RECEIPT_STORE=backtest_engine.production:postgres_request_receipt_store",
    "BACKTEST_BASIC_REQUEST_QUEUE_URL=",
    "BACKTEST_BASIC_REQUEST_DLQ_URL=",
    "BACKTEST_CUSTOM_REQUEST_QUEUE_URL=",
    "BACKTEST_CUSTOM_REQUEST_DLQ_URL=",
    "BACKTEST_COMPETITION_REQUEST_QUEUE_URL=",
    "BACKTEST_COMPETITION_REQUEST_DLQ_URL=",
    "BACKTEST_SCALE_DOWN_ENABLED=true",
    "BACKTEST_ASG_NAME=",
    "BACKTEST_SCALE_DOWN_POLL_SECONDS=60"
)) {
    if (-not $userData.Contains($required)) {
        throw "Backtest bounded worker runtime is missing: $required"
    }
}

foreach ($required in @(
    'resource "aws_sqs_queue" "backtest_request"',
    'resource "aws_sqs_queue" "backtest_request_dlq"',
    'resource "aws_sqs_queue_redrive_allow_policy" "backtest_request_dlq"',
    '/queues/backtest-basic-request/url',
    '/queues/backtest-custom-request/url',
    '/queues/backtest-competition-request/url',
    'values(aws_sqs_queue.backtest_request)[*].arn',
    'values(aws_sqs_queue.backtest_request_dlq)[*].arn'
)) {
    if (-not ($queues.Contains($required) -or $iam.Contains($required) -or $userData.Contains($required))) {
        throw "Backtest producer-request trust boundary is missing: $required"
    }
}


foreach ($required in @(
    'ROOM_LEDGER_RESULT_CONSUMER_ENABLED=true',
    'ROOM_LEDGER_OPENED_QUEUE_URL=',
    'ROOM_LEDGER_REJECTED_QUEUE_URL=',
    'TRADING_ROOM_ACCOUNT_OPEN_ENABLED=true',
    'aws_sqs_queue.room_ledger_opened[0].arn',
    'aws_sqs_queue.room_ledger_open_rejected[0].arn',
    'sqs:ReceiveMessage',
    'sqs:DeleteMessage',
    'sqs:ChangeMessageVisibility'
)) {
    if (-not ($userData.Contains($required) -or $iam.Contains($required))) {
        throw "Room-ledger provider/consumer deployment wiring is missing: $required"
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

foreach ($variable in @(
    "operator_auth_issuer", "operator_auth_jwk_set_uri", "operator_auth_audience",
    "operator_auth_allowed_acr_values", "operator_auth_allowed_amr_values",
    "operator_rbac_catalog_version", "operator_rbac_catalog_read_permission_id",
    "operator_rbac_assignment_read_permission_id"
)) {
    if (-not $variables.Contains(('variable "' + $variable + '"'))) {
        throw "Production operator trust input is missing: $variable"
    }
}
foreach ($required in @(
    "OPERATOR_AUTH_ENABLED=true", "OPERATOR_AUTH_ISSUER=", "OPERATOR_AUTH_JWK_SET_URI=",
    "OPERATOR_AUTH_AUDIENCE=", "OPERATOR_AUTH_ALLOWED_ACR_VALUES=",
    "OPERATOR_AUTH_ALLOWED_AMR_VALUES=", "OPERATOR_AUTH_CURRENT_HMAC_KEY_VERSION=1",
    "OPERATOR_AUTH_CURRENT_HMAC_KEY", "OPERATOR_RBAC_READ_ENABLED=true",
    "OPERATOR_RBAC_CATALOG_VERSION=", "OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID=",
    "OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID="
)) {
    if (-not $userData.Contains($required)) {
        throw "Production operator trust runtime wiring is missing: $required"
    }
}

# Corporate-action approvals are a durable Backend -> Pipeline handoff.  The
# desired-zero Fargate worker must wake from SQS backlog; an in-process source
# would silently strand an approved decision after deployment.
$queues = Get-Content (Join-Path $root "infra/terraform/environments/development/queues.tf") -Raw
$pipeline = Get-Content (Join-Path $root "infra/terraform/environments/development/pipeline.tf") -Raw
$iam = Get-Content (Join-Path $root "infra/terraform/environments/development/iam.tf") -Raw
$userData = Get-Content (Join-Path $root "infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl") -Raw

foreach ($required in @(
    'resource "aws_sqs_queue" "corporate_action_approval"',
    'resource "aws_sqs_queue" "corporate_action_approval_dlq"',
    'resource "aws_ssm_parameter" "corporate_action_approval_queue_url"',
    'resource "aws_ssm_parameter" "corporate_action_approval_dlq_url"'
)) {
    if (-not $queues.Contains($required)) {
        throw "Corporate-action durable queue wiring is missing: $required"
    }
}

foreach ($required in @(
    '{ name = "PIPELINE_WORKER_MESSAGE_SOURCE", value = "sqs" }',
    'PIPELINE_WORKER_QUEUE_URL',
    'PIPELINE_WORKER_DEAD_LETTER_QUEUE_URL',
    'PIPELINE_WORKER_CORPORATE_ACTION_APPROVAL',
    '706f33aa-a461-5376-ae25-9c1bb64b9277',
    '20000000-0000-4000-8000-000000000012',
    'request_schema_version',
    'readonlyRootFilesystem = true',
    'resource "aws_ecs_service" "pipeline"',
    'desired_count   = 0',
    'capacity_provider = "FARGATE_SPOT"',
    'resource "aws_appautoscaling_target" "pipeline"',
    'min_capacity       = 0',
    'max_capacity       = 1',
    'resource "aws_cloudwatch_metric_alarm" "pipeline_queue_has_work"',
    'resource "aws_cloudwatch_metric_alarm" "pipeline_queue_idle"'
)) {
    if (-not $pipeline.Contains($required)) {
        throw "Desired-zero Pipeline SQS wake-up wiring is missing: $required"
    }
}

foreach ($required in @(
    'CORPORATE_ACTION_APPROVAL_QUEUE_URL=',
    'aws_sqs_queue.corporate_action_approval[0].arn',
    'aws_sqs_queue.corporate_action_approval_dlq[0].arn'
)) {
    if (-not ($userData.Contains($required) -or $iam.Contains($required) -or $pipeline.Contains($required))) {
        throw "Corporate-action runtime IAM/environment wiring is missing: $required"
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
foreach ($secretCapture in @('$secretJson = (& $awsExecutable', '$databaseSecretJson = (& $awsExecutable')) {
    if (-not $prerequisites.Contains($secretCapture)) {
        throw "AWS prerequisite check must capture multiline SecretString output before parsing: $secretCapture"
    }
}
if (([regex]::Matches($prerequisites, '\) -join "`n"')).Count -lt 2) {
    throw "AWS prerequisite check must join multiline Alpaca and database SecretString output before ConvertFrom-Json."
}
if (-not $pipeline.Contains('PIPELINE_WORKER_DATABASE_URL') -or
    -not $pipeline.Contains('runtime_database["pipeline"]')) {
    throw "Pipeline database URL is not injected from its dedicated runtime secret."
}
if ($iam.Contains('master_user_secret')) {
    throw "Application runtime roles must not read the RDS master secret."
}
foreach ($required in @('autoscaling:SetDesiredCapacity', 'aws_autoscaling_group.backtest[0].arn')) {
    if (-not $iam.Contains($required)) {
        throw "Fenced Backtest scale-down IAM is missing: $required"
    }
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
