resource "aws_route53_zone" "this" {
  count = local.enable_dns_foundation && var.existing_hosted_zone_id == "" ? 1 : 0
  name  = var.domain_name
  tags  = { Name = "${local.name_prefix}-public-zone" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "legacy_www" {
  #checkov:skip=CKV2_AWS_23:This migration-safety record intentionally preserves the registrar-era external IPv4 target until a separately reviewed CloudFront cutover.
  count   = local.enable_dns_foundation ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.legacy_www_ipv4_address]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "service" {
  count   = local.enable_service_stack && var.enable_https ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = var.frontend_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend[0].domain_name
    zone_id                = aws_cloudfront_distribution.frontend[0].hosted_zone_id
    evaluate_target_health = false
  }

  lifecycle {
    prevent_destroy = true
  }
}
