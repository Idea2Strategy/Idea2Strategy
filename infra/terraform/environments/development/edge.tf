resource "aws_route53_zone" "this" {
  count = local.enable_dns_foundation && var.existing_hosted_zone_id == "" ? 1 : 0
  name  = var.domain_name
  tags  = { Name = "${local.name_prefix}-public-zone" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "legacy_www" {
  #checkov:skip=CKV2_AWS_23:This migration-safety record preserves the registrar-era IPv4 rollback target before full and becomes a CloudFront alias only at the reviewed cutover.
  # Keep this resource address stable across the staged cutover: dns_foundation
  # and host_ready preserve the registrar-era A target, while full changes the
  # same record in place to the reviewed CloudFront distribution. Reverting the
  # phase restores the explicit legacy_www_ipv4_address rollback target.
  count   = local.enable_dns_foundation ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = local.www_domain_name
  type    = "A"
  ttl     = local.enable_public_edge ? null : 300
  records = local.enable_public_edge ? null : [var.legacy_www_ipv4_address]

  dynamic "alias" {
    for_each = local.enable_public_edge ? [1] : []

    content {
      name                   = aws_cloudfront_distribution.frontend[0].domain_name
      zone_id                = aws_cloudfront_distribution.frontend[0].hosted_zone_id
      evaluate_target_health = false
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "service" {
  count   = local.enable_public_edge ? 1 : 0
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
