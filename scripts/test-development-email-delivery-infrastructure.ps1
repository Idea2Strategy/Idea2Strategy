[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$environmentRoot = Join-Path $root "infra/terraform/environments/development"

$email = Get-Content -LiteralPath (Join-Path $environmentRoot "email.tf") -Raw
$edge = Get-Content -LiteralPath (Join-Path $environmentRoot "edge.tf") -Raw
$frontend = Get-Content -LiteralPath (Join-Path $environmentRoot "frontend.tf") -Raw
$userData = Get-Content -LiteralPath (Join-Path $environmentRoot "templates/ec2-user-data.sh.tftpl") -Raw
$variables = Get-Content -LiteralPath (Join-Path $environmentRoot "variables.tf") -Raw
$compute = Get-Content -LiteralPath (Join-Path $environmentRoot "compute.tf") -Raw
$preflight = Get-Content -LiteralPath (Join-Path $root "scripts/test-development-email-delivery-prerequisites.ps1") -Raw
$runbook = Get-Content -LiteralPath (Join-Path $root "docs/infrastructure/deploy-readiness-runbook.md") -Raw

function Assert-ResourcePreventsDestroy {
    param(
        [Parameter(Mandatory = $true)][string]$Terraform,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $resourcePattern = '(?s)resource\s+"' + [regex]::Escape($Type) + '"\s+"' +
        [regex]::Escape($Name) + '"\s*\{(?:(?!\nresource\s+").)*?lifecycle\s*\{(?:(?!\n\s*\}).)*?prevent_destroy\s*=\s*true'
    if ($Terraform -notmatch $resourcePattern) {
        throw "Phase-owned resource must fail closed on downgrade: $Type.$Name"
    }
}

foreach ($required in @(
    'resource "aws_ses_domain_identity" "transactional"',
    'resource "aws_ses_domain_dkim" "transactional"',
    'resource "aws_ses_domain_identity_verification" "transactional"',
    'resource "aws_route53_record" "ses_verification"',
    'resource "aws_route53_record" "ses_dkim"',
    'resource "aws_iam_role_policy" "service_email_delivery"',
    'ses:SendEmail',
    'ses:GetSuppressedDestination',
    'ses:FromAddress',
    'aws:RequestedRegion',
    'aws_ses_domain_identity.transactional[0].arn'
)) {
    if (-not $email.Contains($required)) {
        throw "Development SES infrastructure is missing: $required"
    }
}

if ($email.Contains('ses:SendRawEmail')) {
    throw "Core IAM must not grant unused raw-email delivery."
}

if ($email -match '(?i)access[_-]?key|secret[_-]?access[_-]?key|smtp[_-]?password') {
    throw "SES delivery must use the Core instance role and must not provision long-lived credentials."
}

foreach ($required in @(
    'resource "aws_route53_record" "legacy_www"',
    'www.${var.domain_name}',
    'var.legacy_www_ipv4_address'
)) {
    if (-not $edge.Contains($required)) {
        throw "Legacy www DNS preservation is missing: $required"
    }
}

foreach ($variable in @("transactional_email_from_address", "legacy_www_ipv4_address")) {
    if (-not $variables.Contains(('variable "' + $variable + '"'))) {
        throw "Email/DNS deployment input is missing: $variable"
    }
}

foreach ($required in @(
    'EMAIL_DELIVERY_ENABLED',
    'EMAIL_DELIVERY_PROVIDER',
    'EMAIL_DELIVERY_FROM_ADDRESS',
    'EMAIL_DELIVERY_AWS_REGION',
    'EMAIL_DELIVERY_BASE_URL'
)) {
    if (-not $userData.Contains($required)) {
        throw "Core runtime email configuration is missing: $required"
    }
}

foreach ($required in @(
    '"sesv2", "get-account"',
    '"sesv2", "get-email-identity"',
    'ProductionAccessEnabled',
    'VerifiedForSendingStatus',
    'DkimAttributes.Status',
    'RequireProductionAccess',
    '$strictErrorPreference = $ErrorActionPreference'
)) {
    if (-not $preflight.Contains($required)) {
        throw "SES preflight is missing: $required"
    }
}

foreach ($resource in @(
    @($edge, "aws_route53_zone", "this"),
    @($edge, "aws_route53_record", "legacy_www"),
    @($edge, "aws_route53_record", "service"),
    @($email, "aws_ses_domain_identity", "transactional"),
    @($email, "aws_route53_record", "ses_verification"),
    @($email, "aws_ses_domain_identity_verification", "transactional"),
    @($email, "aws_ses_domain_dkim", "transactional"),
    @($email, "aws_route53_record", "ses_dkim"),
    @($frontend, "aws_s3_bucket", "frontend"),
    @($frontend, "aws_s3_bucket_public_access_block", "frontend"),
    @($frontend, "aws_s3_bucket_ownership_controls", "frontend"),
    @($frontend, "aws_s3_bucket_versioning", "frontend"),
    @($frontend, "aws_s3_bucket_server_side_encryption_configuration", "frontend"),
    @($frontend, "aws_cloudfront_origin_access_control", "frontend"),
    @($frontend, "aws_cloudfront_function", "spa_rewrite"),
    @($frontend, "aws_acm_certificate", "frontend"),
    @($frontend, "aws_route53_record", "frontend_certificate_validation"),
    @($frontend, "aws_acm_certificate_validation", "frontend"),
    @($frontend, "aws_route53_record", "cloudfront_origin"),
    @($frontend, "aws_cloudfront_distribution", "frontend"),
    @($frontend, "aws_s3_bucket_policy", "frontend_cloudfront")
)) {
    Assert-ResourcePreventsDestroy -Terraform $resource[0] -Type $resource[1] -Name $resource[2]
}

foreach ($dependency in @('aws_ssm_parameter.email_runtime', 'aws_iam_role_policy.service_email_delivery')) {
    if (-not $compute.Contains($dependency)) {
        throw "Core EC2 email startup dependency is missing: $dependency"
    }
}

foreach ($required in @(
    'SES sandbox',
    'DKIM',
    'test-development-email-delivery-prerequisites.ps1',
    'www.ideatostrategy.com'
)) {
    if (-not $runbook.Contains($required)) {
        throw "Email deployment runbook is missing: $required"
    }
}

Write-Output "Development email delivery infrastructure checks passed."
