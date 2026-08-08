[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$environmentRoot = Join-Path $root "infra/terraform/environments/development"

function Read-Terraform([string]$Name) {
    Get-Content -LiteralPath (Join-Path $environmentRoot $Name) -Raw
}

function Contains-NormalizedWhitespace([string]$Text, [string]$Required) {
    return (($Text -replace '\s+', ' ').Contains(($Required -replace '\s+', ' ')))
}

$all = (Get-ChildItem -LiteralPath $environmentRoot -Filter *.tf | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}) -join "`n"
$locals = Read-Terraform "locals.tf"
$variables = Read-Terraform "variables.tf"
$deployment = Read-Terraform "deployment.tf"
$compute = Read-Terraform "compute.tf"
$runtime = Read-Terraform "runtime.tf"
$security = Read-Terraform "security.tf"
$iam = Read-Terraform "iam.tf"
$frontend = Read-Terraform "frontend.tf"
$edge = Read-Terraform "edge.tf"
$email = Read-Terraform "email.tf"
$userData = Get-Content -LiteralPath (Join-Path $environmentRoot "templates/ec2-user-data.sh.tftpl") -Raw
$coreDeploy = Get-Content -LiteralPath (Join-Path $root "scripts/deploy-development-core-runtime.ps1") -Raw
$runbook = Get-Content -LiteralPath (Join-Path $root "docs/infrastructure/deploy-readiness-runbook.md") -Raw

foreach ($required in @(
    'contains(["market_data_bootstrap", "dns_foundation", "host_ready", "full"], var.deployment_phase)',
    'enable_service_stack  = contains(["host_ready", "full"], var.deployment_phase)',
    'enable_public_edge    = var.deployment_phase == "full"',
    '!local.enable_public_edge || var.dns_delegation_verified'
)) {
    if (-not $all.Contains($required)) {
        throw "Host-ready phase boundary is missing: $required"
    }
}

if ($userData -notmatch '(?s)systemctl daemon-reload\s+systemctl start idea2strategy-origin-cert\.service\s+systemctl enable --now idea2strategy-origin-cert\.timer') {
    throw "Core public-origin bootstrap must synchronously configure Nginx and TLS before it enables the renewal timer."
}

foreach ($required in @(
    'test -s /etc/nginx/conf.d/idea2strategy-origin.conf',
    'test "$(systemctl show -p Result --value idea2strategy-origin-cert.service)" = success',
    'systemctl is-enabled --quiet idea2strategy-origin-cert.timer',
    'systemctl is-active --quiet nginx',
    'nginx -t',
    'ss -H -ltn sport = :443'
)) {
    if (-not $coreDeploy.Contains($required)) {
        throw "Core host readiness does not prove the public origin is serving TLS: $required"
    }
}

foreach ($required in @(
    'variable "enable_operator_auth"',
    'enable_operator_auth                        = var.enable_operator_auth',
    '!var.enable_operator_auth || (',
    'OPERATOR_AUTH_ENABLED=${enable_operator_auth}',
    'OPERATOR_RBAC_READ_ENABLED=${enable_operator_auth}'
)) {
    if (-not ((Contains-NormalizedWhitespace $variables $required) -or
        (Contains-NormalizedWhitespace $compute $required) -or
        (Contains-NormalizedWhitespace $runtime $required) -or
        (Contains-NormalizedWhitespace $userData $required))) {
        throw "Fail-closed optional operator plane wiring is missing: $required"
    }
}

foreach ($runtimeResource in @(
    'resource "aws_instance" "service"',
    'resource "aws_instance" "trading"',
    'resource "aws_autoscaling_group" "backtest"',
    'resource "aws_elasticache_serverless_cache" "this"',
    'resource "aws_sqs_queue" "backtest"'
)) {
    if (-not $all.Contains($runtimeResource)) {
        throw "Host-ready runtime resource is missing: $runtimeResource"
    }
}

foreach ($publicEdgeBoundary in @(
    @($frontend, 'resource "aws_cloudfront_distribution" "frontend"'),
    @($frontend, 'resource "aws_acm_certificate" "frontend"'),
    @($frontend, 'resource "aws_route53_record" "cloudfront_origin"'),
    @($edge, 'resource "aws_route53_record" "service"'),
    @($security, 'resource "random_password" "cloudfront_origin_header"')
)) {
    $pattern = '(?s)' + [regex]::Escape($publicEdgeBoundary[1]) + '.*?\b(?:count|for_each)\s*=\s*local\.enable_public_edge'
    if ($publicEdgeBoundary[0] -notmatch $pattern) {
        throw "Public edge resource is not isolated from host_ready: $($publicEdgeBoundary[1])"
    }
}

foreach ($required in @(
    'configure_public_origin                     = local.enable_public_edge',
    'origin_header_secret_arn                    = try(aws_secretsmanager_secret.cloudfront_origin_header[0].arn, "")',
    'origin_certificate_secret_arn               = try(aws_secretsmanager_secret.core_origin_certificate[0].arn, "")',
    'runtime_role == "service" && configure_public_origin'
)) {
    if (-not ((Contains-NormalizedWhitespace $compute $required) -or
        (Contains-NormalizedWhitespace $userData $required))) {
        throw "Pre-delegation Core bootstrap boundary is missing: $required"
    }
}

foreach ($required in @(
    'resource "aws_secretsmanager_secret" "core_origin_certificate"',
    'name                    = "${local.name_prefix}/edge/origin-certificate"',
    'recovery_window_in_days = 30',
    'prevent_destroy = true'
)) {
    if (-not $security.Contains($required)) {
        throw "Persistent Core origin certificate boundary is missing: $required"
    }
}
if ($security.Contains('resource "aws_secretsmanager_secret_version" "core_origin_certificate"')) {
    throw "Terraform must not own the runtime-renewed Core origin certificate value."
}
foreach ($required in @(
    'secretsmanager:GetSecretValue',
    'secretsmanager:PutSecretValue',
    'aws_secretsmanager_secret.core_origin_certificate[0].arn'
)) {
    if (-not $iam.Contains($required)) {
        throw "Core certificate persistence IAM boundary is missing: $required"
    }
}
foreach ($required in @(
    'openssl x509 -checkend 2592000 -noout',
    '--domain ''tls.${origin_domain_name}''',
    '--secret-string "file://$certificate_bundle"',
    '/etc/idea2strategy/origin-tls/fullchain.pem',
    '/etc/idea2strategy/origin-tls/privkey.pem'
)) {
    if (-not $userData.Contains($required)) {
        throw "Core certificate restore/renewal boundary is missing: $required"
    }
}

if ($email -notmatch 'enabled\s*=\s*local\.enable_public_edge\s*\?\s*"true"\s*:\s*"false"') {
    throw "Transactional email must remain disabled until the public DNS/SES cutover is verified."
}

$batchPolicy = [regex]::Match($iam, '(?s)resource\s+"aws_iam_role_policy"\s+"batch_loader_secret"\s*\{.*?\n\}').Value
if ($batchPolicy -eq "" -or $batchPolicy -match '\bcount\s*=' -or
    $batchPolicy -notmatch 'policy\s*=\s*data\.aws_iam_policy_document\.rds_secret_access\.json') {
    throw "host_ready must narrow the existing Batch inline policy in place instead of destroying it."
}

foreach ($required in @(
    'deployment_phase=host_ready',
    'AWS-StartPortForwardingSession',
    '127.0.0.1:8080/actuator/health',
    'CloudFront, ACM, or public DNS'
)) {
    if (-not $runbook.Contains($required)) {
        throw "Host-ready verification runbook is missing: $required"
    }
}

Write-Output "Pre-DNS host-ready phase checks passed."
