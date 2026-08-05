[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$environmentRoot = Join-Path $root "infra/terraform/environments/development"

function Read-TerraformFile([string]$Name) {
    $path = Join-Path $environmentRoot $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Full Terraform architecture is missing $Name."
    }
    Get-Content -LiteralPath $path -Raw
}

$all = (Get-ChildItem -LiteralPath $environmentRoot -Filter *.tf | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}) -join "`n"
$network = Read-TerraformFile "network.tf"
$compute = Read-TerraformFile "compute.tf"
$frontend = Read-TerraformFile "frontend.tf"
$edge = Read-TerraformFile "edge.tf"
$cache = Read-TerraformFile "cache.tf"
$database = Read-TerraformFile "database.tf"
$queues = Read-TerraformFile "queues.tf"
$security = Read-TerraformFile "security.tf"
$pipeline = Read-TerraformFile "pipeline.tf"
$scheduling = Read-TerraformFile "scheduling.tf"
$providers = Read-TerraformFile "providers.tf"
$storage = Read-TerraformFile "storage.tf"
$userData = Get-Content -LiteralPath (Join-Path $environmentRoot "templates/ec2-user-data.sh.tftpl") -Raw
$ciIdentity = (Get-ChildItem -LiteralPath (Join-Path $root "infra/terraform/ci-identity") -Filter *.tf | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}) -join "`n"
$artifactRoot = Join-Path $root "infra/terraform/artifact-foundation"
$artifactMain = Get-Content -LiteralPath (Join-Path $artifactRoot "main.tf") -Raw

foreach ($forbidden in @(
    'resource "aws_nat_gateway"',
    'resource "aws_lb"',
    'resource "aws_instance" "batch"',
    'resource "aws_instance" "compute"',
    'm7i-flex',
    'x86_64',
    'amd64-server'
)) {
    if ($all.Contains($forbidden)) {
        throw "Low-cost Development architecture forbids: $forbidden"
    }
}

foreach ($required in @(
    'resource "aws_subnet" "public"',
    'resource "aws_subnet" "private_db"',
    'resource "aws_vpc_endpoint" "s3"'
)) {
    if (-not $network.Contains($required)) {
        throw "Network architecture is missing: $required"
    }
}

foreach ($immutableFrontendBoundary in @(
    'count = local.enable_dns_foundation ? 1 : 0',
    'origin_path              = "/_releases/${var.frontend_release_id}"'
)) {
    if (-not $frontend.Contains($immutableFrontendBoundary)) {
        throw "Immutable frontend release boundary is missing: $immutableFrontendBoundary"
    }
}
foreach ($runtimeDependency in @(
    'aws_instance" "service',
    'aws_instance" "trading',
    'aws_launch_template" "backtest'
)) {
    if ($compute -notmatch ('(?s)resource "' + [regex]::Escape($runtimeDependency) + '.*?depends_on\s*=\s*\[.*?aws_ssm_parameter\.runtime_image')) {
        throw "Runtime bootstrap can race its image parameter: $runtimeDependency"
    }
}
foreach ($required in @(
    'resource "aws_ecr_repository" "runtime"',
    'image_tag_mutability = "IMMUTABLE"',
    'scan_on_push = true',
    'prevent_destroy = true'
)) {
    if (-not $artifactMain.Contains($required)) {
        throw "Isolated artifact foundation boundary is missing: $required"
    }
}
if ($storage.Contains('resource "aws_ecr_repository"')) {
    throw "The Development runtime state must not own ECR repositories; the isolated artifact foundation does."
}
if ($compute -notmatch '(?s)resource\s+"aws_launch_template"\s+"backtest".*?credit_specification\s*\{.*?cpu_credits\s*=\s*"standard"') {
    throw "Backtest t4g.medium must use standard CPU credits so saturation is visible without surplus-credit spend."
}
if ($database -notmatch '(?s)name\s*=\s*"rds\.force_ssl".*?apply_method\s*=\s*"pending-reboot"') {
    throw "The static rds.force_ssl parameter must use pending-reboot so an applied configuration converges without perpetual drift."
}
foreach ($required in @(
    'BACKTEST_BASIC_QUEUE_URL',
    'BACKTEST_BASIC_DLQ_URL',
    'BACKTEST_BASIC_MAX_CONCURRENCY',
    'BACKTEST_CUSTOM_QUEUE_URL',
    'BACKTEST_CUSTOM_DLQ_URL',
    'BACKTEST_CUSTOM_MAX_CONCURRENCY',
    'BACKTEST_COMPETITION_QUEUE_URL',
    'BACKTEST_COMPETITION_DLQ_URL',
    'BACKTEST_COMPETITION_MAX_CONCURRENCY',
    'BACKTEST_MAX_TOTAL_CONCURRENCY'
)) {
    if (-not $userData.Contains($required)) {
        throw "Backtest runtime environment injection is missing: $required"
    }
}

foreach ($required in @(
    'resource "aws_instance" "service"',
    'resource "aws_eip" "service"',
    'resource "aws_instance" "trading"',
    'resource "aws_launch_template" "backtest"',
    'resource "aws_autoscaling_group" "backtest"',
    'desired_capacity',
    'max_size',
    'http_put_response_hop_limit'
)) {
    if (-not $compute.Contains($required)) {
        throw "Compute architecture is missing: $required"
    }
}
if ($compute -notmatch 'desired_capacity\s*=\s*0' -or
    $compute -notmatch 'max_size\s*=\s*1' -or
    $compute -notmatch 'http_put_response_hop_limit\s*=\s*1') {
    throw "Backtest must scale from zero to one and every EC2 launch path must enforce IMDS hop limit 1."
}

foreach ($size in @('c7g.xlarge', 't4g.medium')) {
    if ($all -notmatch ('default\s*=\s*"' + [regex]::Escape($size) + '"')) {
        throw "ARM64 sizing boundary is missing: $size"
    }
}
if ($all -match '(?s)variable\s+"service_instance_type"\s*\{.*?default\s*=\s*"t4g\.small"') {
    throw "Core must start on the approved t4g.medium boundary, not t4g.small."
}
if ($all -notmatch '(?s)variable\s+"monthly_budget_usd"\s*\{.*?default\s*=\s*180') {
    throw "The accepted Development monthly budget must default to USD 180."
}
foreach ($dnsBoundary in @(
    'enable_dns_foundation = contains(["dns_foundation", "host_ready", "full"], var.deployment_phase)',
    'local.enable_dns_foundation && var.existing_hosted_zone_id == ""',
    'variable "dns_delegation_verified"',
    'condition     = var.dns_delegation_verified'
)) {
    if (-not ($all.Contains($dnsBoundary) -or $edge.Contains($dnsBoundary))) {
        throw "Staged Route 53 delegation boundary is missing: $dnsBoundary"
    }
}
if ($all -notmatch 'contains\(\["market_data_bootstrap", "dns_foundation", "host_ready", "full"\], var\.deployment_phase\)') {
    throw "Development deployment phases must expose DNS-only and pre-DNS host-ready stages before the public runtime."
}

foreach ($required in @(
    'resource "aws_cloudfront_origin_access_control" "frontend"',
    'resource "aws_cloudfront_distribution" "frontend"',
    'resource "aws_s3_bucket_policy" "frontend_cloudfront"',
    'X-Idea2Strategy-Origin-Verify',
    'aws_eip.service[0].public_ip'
)) {
    if (-not ($frontend.Contains($required) -or $security.Contains($required))) {
        throw "CloudFront-to-Core boundary is missing: $required"
    }
}
if ($frontend -notmatch 'origin_protocol_policy\s*=\s*"https-only"') {
    throw "CloudFront must use HTTPS to the fixed Core origin."
}
if ($frontend -match 'custom_error_response') {
    throw "Distribution-wide custom error responses must not convert API 403/404 responses into SPA success pages."
}
foreach ($spaBoundary in @(
    'resource "aws_cloudfront_function" "spa_rewrite"',
    'event_type   = "viewer-request"',
    'function_arn = aws_cloudfront_function.spa_rewrite[0].arn',
    "request.uri = '/index.html'"
)) {
    if (-not $frontend.Contains($spaBoundary)) {
        throw "The frontend-only SPA rewrite boundary is missing: $spaBoundary"
    }
}
foreach ($required in @('certbot', '--dns-route53', 'secretsmanager get-secret-value', 'http_x_idea2strategy_origin_verify', 'proxy_pass http://127.0.0.1')) {
    if (-not $userData.Contains($required)) {
        throw "Core reverse-proxy bootstrap is missing: $required"
    }
}

if (-not $security.Contains('prefix_list_id') -or
    -not $security.Contains('cloudfront_origin') -or
    $security -match '(?s)ingress[^}]*cidr_ipv4\s*=\s*"0\.0\.0\.0/0"' -or
    $security -match '(?s)from_port\s*=\s*22') {
    throw "Core ingress must be CloudFront-prefix-list-only and SSH-free."
}

foreach ($required in @(
    'resource "aws_elasticache_serverless_cache" "this"',
    'resource "aws_elasticache_serverless_cache"'
)) {
    if (-not $cache.Contains($required)) {
        throw "Private Valkey Serverless architecture is missing: $required"
    }
}
if ($cache -notmatch 'engine\s*=\s*"valkey"') {
    throw "The serverless cache must use Valkey."
}

foreach ($lane in @('basic', 'custom', 'competition')) {
    if (-not $all.Contains($lane)) {
        throw "Backtest queue lane is missing: $lane"
    }
}
foreach ($required in @('resource "aws_sqs_queue" "backtest"', 'resource "aws_sqs_queue" "backtest_dlq"', 'redrive_policy', 'sqs_managed_sse_enabled')) {
    if (-not $queues.Contains($required)) {
        throw "Durable backtest queue safety is missing: $required"
    }
}
foreach ($required in @('ALPACA_API_KEY', 'ALPACA_SECRET_KEY', 'alpaca-api-key-secret-arn', 'alpaca-secret-key-secret-arn')) {
    if (-not $all.Contains($required)) {
        throw "Alpaca secret reference boundary is missing: $required"
    }
}
foreach ($required in @(
    'aws_iam_openid_connect_provider',
    'token.actions.githubusercontent.com:aud',
    'token.actions.githubusercontent.com:sub',
    'environment:${var.github_plan_environment}',
    'environment:${var.github_environment}',
    'ReadOnlyAccess',
    'PowerUserAccess',
    'github_plan_role_arn',
    'PublishImmutableFrontendRelease',
    'TerraformStateObject',
    'iam:PassRole'
)) {
    if (-not $ciIdentity.Contains($required)) {
        throw "GitHub OIDC deployment boundary is missing: $required"
    }
}
if (-not $queues.Contains('resource "aws_ssm_parameter" "backtest_dlq_url"')) {
    throw "Each Backtest lane DLQ URL must be published for worker runtime injection."
}
if ($queues -notmatch 'value\s*=\s*each\.key\s*==\s*"basic"\s*\?\s*"2"\s*:\s*"1"') {
    throw "Backtest lane concurrency must be basic=2, custom=1, competition=1."
}
if ($queues -notmatch '(?s)resource\s+"aws_ssm_parameter"\s+"backtest_total_concurrency".*?value\s*=\s*"4"') {
    throw "Backtest total concurrency must allow all four lane slots on the single worker host."
}
foreach ($required in @(
    'resource "aws_cloudwatch_metric_alarm" "backtest_cpu_high"',
    'resource "aws_cloudwatch_metric_alarm" "backtest_cpu_credit_low"',
    'resource "aws_cloudwatch_metric_alarm" "backtest_memory_high"',
    'CPUCreditBalance',
    'AutoScalingGroupName'
)) {
    if (-not $all.Contains($required)) {
        throw "Backtest t4g.medium saturation monitoring is missing: $required"
    }
}

foreach ($required in @(
    'resource "aws_scheduler_schedule" "trading_start"',
    'resource "aws_scheduler_schedule" "trading_stop"',
    'America/New_York',
    'start',
    'stop'
)) {
    if (-not $scheduling.Contains($required)) {
        throw "Trading time-control boundary is missing: $required"
    }
}

foreach ($required in @(
    'resource "aws_ecs_cluster" "pipeline"',
    'resource "aws_ecs_task_definition" "pipeline"',
    'capacity_provider_strategy',
    'FARGATE_SPOT',
    'cpu_architecture',
    'ARM64',
    'assign_public_ip'
)) {
    if (-not $pipeline.Contains($required)) {
        throw "Scale-to-zero ARM64 pipeline boundary is missing: $required"
    }
}
if ($pipeline -notmatch 'assign_public_ip\s*=\s*true') {
    throw "The desired-zero Fargate task needs public-IP egress because the design intentionally has no NAT gateway."
}

foreach ($required in @('allowed_account_ids', 'architecture', 'arm64')) {
    if (-not $providers.Contains($required)) {
        throw "Provider/AMI safety is missing: $required"
    }
}

Write-Output "Low-cost full Terraform architecture boundary checks passed."
