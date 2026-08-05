resource "aws_ses_domain_identity" "transactional" {
  count  = local.enable_dns_foundation ? 1 : 0
  domain = var.domain_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "ses_verification" {
  count   = local.enable_dns_foundation ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.transactional[0].verification_token]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ses_domain_identity_verification" "transactional" {
  count  = local.enable_public_edge ? 1 : 0
  domain = aws_ses_domain_identity.transactional[0].domain

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [aws_route53_record.ses_verification]
}

resource "aws_ses_domain_dkim" "transactional" {
  count  = local.enable_dns_foundation ? 1 : 0
  domain = aws_ses_domain_identity.transactional[0].domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "ses_dkim" {
  count   = local.enable_dns_foundation ? 3 : 0
  zone_id = local.hosted_zone_id
  name    = "${aws_ses_domain_dkim.transactional[0].dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.transactional[0].dkim_tokens[count.index]}.dkim.amazonses.com"]

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "service_email_delivery" {
  count = local.enable_service_stack ? 1 : 0

  statement {
    sid       = "SendTransactionalEmailFromVerifiedIdentity"
    effect    = "Allow"
    actions   = ["ses:SendEmail"]
    resources = [aws_ses_domain_identity.transactional[0].arn]

    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = [var.transactional_email_from_address]
    }
  }

  statement {
    sid       = "ReadDevelopmentSuppressionStatus"
    effect    = "Allow"
    actions   = ["ses:GetSuppressedDestination"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
}

resource "aws_iam_role_policy" "service_email_delivery" {
  count = local.enable_service_stack ? 1 : 0

  name   = "${local.name_prefix}-service-email-delivery"
  role   = aws_iam_role.service[0].id
  policy = data.aws_iam_policy_document.service_email_delivery[0].json
}

resource "aws_ssm_parameter" "email_runtime" {
  for_each = local.enable_service_stack ? {
    enabled      = local.enable_public_edge ? "true" : "false"
    provider     = "ses"
    from-address = var.transactional_email_from_address
    aws-region   = var.aws_region
    base-url     = "https://${var.frontend_domain_name}"
  } : {}

  name  = "${local.parameter_path}/email/${each.key}"
  type  = "String"
  value = each.value
}

check "transactional_email_identity" {
  assert {
    condition = (
      lower(var.transactional_email_from_address) == var.transactional_email_from_address &&
      endswith(var.transactional_email_from_address, "@${lower(var.domain_name)}")
    )
    error_message = "transactional_email_from_address must be a lowercase mailbox under domain_name."
  }
}
