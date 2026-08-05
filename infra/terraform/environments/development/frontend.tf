provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  profile             = var.aws_profile != "" ? var.aws_profile : null
  allowed_account_ids = var.expected_aws_account_id != "" ? [var.expected_aws_account_id] : null

  default_tags {
    tags = local.common_tags
  }
}

resource "aws_s3_bucket" "frontend" {
  count = local.enable_dns_foundation ? 1 : 0

  bucket        = local.frontend_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  count = local.enable_dns_foundation ? 1 : 0

  bucket                  = aws_s3_bucket.frontend[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  count = local.enable_dns_foundation ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  count = local.enable_dns_foundation ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  count = local.enable_dns_foundation ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  count = local.enable_public_edge ? 1 : 0

  name                              = "${local.name_prefix}-frontend-oac"
  description                       = "SigV4 access from CloudFront to the private frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_function" "spa_rewrite" {
  count   = local.enable_public_edge ? 1 : 0
  name    = "${local.name_prefix}-spa-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite only frontend navigation routes to index.html without masking API errors"
  publish = true
  code    = <<-JAVASCRIPT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
      } else if (uri.lastIndexOf('.') < uri.lastIndexOf('/')) {
        request.uri = '/index.html';
      }
      return request;
    }
  JAVASCRIPT

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_acm_certificate" "frontend" {
  count    = local.enable_public_edge ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.frontend_domain_name
  subject_alternative_names = [local.www_domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
  }
}

resource "aws_route53_record" "frontend_certificate_validation" {
  for_each = local.enable_public_edge ? {
    for option in aws_acm_certificate.frontend[0].domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  } : {}

  allow_overwrite = true
  zone_id         = local.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_acm_certificate_validation" "frontend" {
  count    = local.enable_public_edge ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = [for record in aws_route53_record.frontend_certificate_validation : record.fqdn]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "cloudfront_origin" {
  count = local.enable_public_edge ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.origin_domain_name
  type    = "A"
  ttl     = 60
  records = [aws_eip.service[0].public_ip]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudfront_distribution" "frontend" {
  count = local.enable_public_edge ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name_prefix} frontend and application edge"
  default_root_object = "index.html"
  price_class         = "PriceClass_200"
  aliases             = var.enable_https ? [var.frontend_domain_name, local.www_domain_name] : []
  web_acl_id          = var.enable_waf ? aws_wafv2_web_acl.frontend[0].arn : null

  origin {
    domain_name              = aws_s3_bucket.frontend[0].bucket_regional_domain_name
    origin_id                = "frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend[0].id
    origin_path              = "/_releases/${var.frontend_release_id}"
  }

  origin {
    domain_name = var.origin_domain_name
    origin_id   = "core-ec2"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 5
      origin_read_timeout      = 60
    }

    custom_header {
      name  = "X-Idea2Strategy-Origin-Verify"
      value = random_password.cloudfront_origin_header[0].result
    }
  }

  default_cache_behavior {
    target_origin_id       = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite[0].arn
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "core-ec2"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id            = "413f1600-996d-4c66-baf4-05b711d5fe6c"
    origin_request_policy_id   = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id
  }

  ordered_cache_behavior {
    path_pattern           = "/ws/*"
    target_origin_id       = "core-ec2"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false

    cache_policy_id            = "413f1600-996d-4c66-baf4-05b711d5fe6c"
    origin_request_policy_id   = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.enable_https ? aws_acm_certificate_validation.frontend[0].certificate_arn : null
    cloudfront_default_certificate = !var.enable_https
    minimum_protocol_version       = var.enable_https ? "TLSv1.2_2021" : null
    ssl_support_method             = var.enable_https ? "sni-only" : null
  }

  depends_on = [
    aws_s3_bucket_public_access_block.frontend,
    aws_s3_bucket_ownership_controls.frontend,
    aws_s3_bucket_server_side_encryption_configuration.frontend
  ]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "frontend_cloudfront" {
  count = local.enable_public_edge ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.frontend[0].arn,
          "${aws_s3_bucket.frontend[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowCloudFrontReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend[0].arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]

  lifecycle {
    prevent_destroy = true
  }
}
