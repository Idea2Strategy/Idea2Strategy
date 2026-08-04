[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$environmentRoot = Join-Path $root "infra/terraform/environments/development"

$requiredFiles = @(
    "frontend.tf",
    "cache.tf",
    "queues.tf",
    "deployment.tf",
    "waf.tf",
    "notifications.tf"
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $environmentRoot $file) -PathType Leaf)) {
        throw "Full Terraform architecture is missing $file."
    }
}

$network = Get-Content -LiteralPath (Join-Path $environmentRoot "network.tf") -Raw
$compute = Get-Content -LiteralPath (Join-Path $environmentRoot "compute.tf") -Raw
$frontend = Get-Content -LiteralPath (Join-Path $environmentRoot "frontend.tf") -Raw
$cache = Get-Content -LiteralPath (Join-Path $environmentRoot "cache.tf") -Raw
$queues = Get-Content -LiteralPath (Join-Path $environmentRoot "queues.tf") -Raw
$security = Get-Content -LiteralPath (Join-Path $environmentRoot "security.tf") -Raw
$edge = Get-Content -LiteralPath (Join-Path $environmentRoot "edge.tf") -Raw
$deployment = Get-Content -LiteralPath (Join-Path $environmentRoot "deployment.tf") -Raw
$providers = Get-Content -LiteralPath (Join-Path $environmentRoot "providers.tf") -Raw

foreach ($required in @(
    'resource "aws_subnet" "private_app"',
    'resource "aws_nat_gateway" "this"',
    'resource "aws_vpc_endpoint" "s3"'
)) {
    if (-not $network.Contains($required)) {
        throw "Network architecture is missing: $required"
    }
}
if (-not $network.Contains('variable "nat_gateway_mode"') -and
    -not (Get-Content -LiteralPath (Join-Path $environmentRoot "variables.tf") -Raw).Contains('variable "nat_gateway_mode"')) {
    throw "The NAT availability/cost choice must remain an explicit reviewed input."
}

foreach ($runtime in @("service", "trading", "compute")) {
    if (-not $compute.Contains("resource `"aws_instance`" `"$runtime`"")) {
        throw "Compute architecture is missing the $runtime runtime."
    }
}
$privateRuntimeCount = ([regex]::Matches($compute, '(?m)^\s*associate_public_ip_address\s*=\s*false')).Count
$publicRuntimeCount = ([regex]::Matches($compute, '(?m)^\s*associate_public_ip_address\s*=\s*true')).Count
if ($privateRuntimeCount -lt 3 -or $publicRuntimeCount -gt 1) {
    throw "Core, Trading and Compute must be private; only the preserved bootstrap host may retain its legacy public-IP setting."
}

foreach ($required in @(
    'resource "aws_cloudfront_origin_access_control" "frontend"',
    'resource "aws_cloudfront_distribution" "frontend"',
    'resource "aws_s3_bucket_policy" "frontend_cloudfront"'
)) {
    if (-not $frontend.Contains($required)) {
        throw "Frontend edge architecture is missing: $required"
    }
}
foreach ($required in @(
    'X-Idea2Strategy-Origin-Verify',
    'random_password.cloudfront_origin_header',
    'fixed-response'
)) {
    if (-not ($frontend.Contains($required) -or $edge.Contains($required) -or $security.Contains($required))) {
        throw "CloudFront-to-ALB origin protection is missing: $required"
    }
}

foreach ($required in @(
    'resource "aws_elasticache_replication_group" "this"',
    'transit_encryption_enabled = true',
    'at_rest_encryption_enabled = true'
)) {
    if (-not $cache.Contains($required)) {
        throw "Cache architecture is missing: $required"
    }
}
foreach ($required in @(
    'auth_token',
    'aws_secretsmanager_secret',
    'aws_elasticache_subnet_group'
)) {
    if (-not $cache.Contains($required)) {
        throw "Cache authentication or private placement is missing: $required"
    }
}

foreach ($required in @(
    'resource "aws_sqs_queue" "work"',
    'resource "aws_sqs_queue" "dead_letter"',
    'redrive_policy'
)) {
    if (-not $queues.Contains($required)) {
        throw "Durable queue architecture is missing: $required"
    }
}
foreach ($required in @("sqs_managed_sse_enabled", "aws_sqs_queue_redrive_allow_policy")) {
    if (-not $queues.Contains($required)) {
        throw "Durable queue safety is missing: $required"
    }
}

if (-not $providers.Contains("allowed_account_ids")) {
    throw "The AWS provider must reject an unexpected account."
}
if (-not $deployment.Contains("container_image_digests") -or -not $deployment.Contains('@${each.value}')) {
    throw "Runtime deployment must use immutable ECR digests."
}
if (-not $deployment.Contains('resource "terraform_data" "full_release_guard"') -or
    -not $deployment.Contains("precondition")) {
    throw "Full release inputs must be enforced by a plan-blocking precondition."
}

Write-Output "Full Terraform architecture boundary checks passed."
