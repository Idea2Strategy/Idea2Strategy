[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$environmentRoot = Join-Path $root "infra/terraform/environments/development"
$locals = Get-Content -LiteralPath (Join-Path $environmentRoot "locals.tf") -Raw
$edge = Get-Content -LiteralPath (Join-Path $environmentRoot "edge.tf") -Raw
$frontend = Get-Content -LiteralPath (Join-Path $environmentRoot "frontend.tf") -Raw

function Contains-NormalizedWhitespace([string]$Text, [string]$Required) {
    return (($Text -replace '\s+', ' ').Contains(($Required -replace '\s+', ' ')))
}

foreach ($required in @(
    'www_domain_name = "www.${var.domain_name}"',
    'count   = local.enable_dns_foundation ? 1 : 0',
    'records = local.enable_public_edge ? null : [var.legacy_www_ipv4_address]',
    'ttl     = local.enable_public_edge ? null : 300',
    'for_each = local.enable_public_edge ? [1] : []',
    'name                   = aws_cloudfront_distribution.frontend[0].domain_name',
    'zone_id                = aws_cloudfront_distribution.frontend[0].hosted_zone_id'
)) {
    if (-not ((Contains-NormalizedWhitespace $locals $required) -or
        (Contains-NormalizedWhitespace $edge $required))) {
        throw "The staged www cutover boundary is missing: $required"
    }
}

foreach ($required in @(
    'subject_alternative_names = [local.www_domain_name]',
    'aliases             = var.enable_https ? [var.frontend_domain_name, local.www_domain_name] : []'
)) {
    if (-not (Contains-NormalizedWhitespace $frontend $required)) {
        throw "The CloudFront/ACM www binding is missing: $required"
    }
}

if ($edge -match 'resource\s+"aws_route53_record"\s+"www_service"') {
    throw "www must retain its existing Terraform address so full cutover does not destroy the protected legacy record."
}

Write-Output "Development www edge checks passed."
