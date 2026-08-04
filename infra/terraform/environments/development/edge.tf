resource "aws_route53_zone" "this" {
  count = local.enable_service_stack && var.existing_hosted_zone_id == "" ? 1 : 0
  name  = var.domain_name
  tags  = { Name = "${local.name_prefix}-public-zone" }
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
}
