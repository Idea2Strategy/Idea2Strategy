data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service" {
  count = local.enable_service_stack ? 1 : 0

  name               = "${local.name_prefix}-service-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role" "batch" {
  name               = "${local.name_prefix}-batch-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role" "trading" {
  count = local.enable_service_stack ? 1 : 0

  name               = "${local.name_prefix}-trading-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

locals {
  ec2_managed_policy_arns = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ])
}

resource "aws_iam_role_policy_attachment" "service_managed" {
  for_each = local.enable_service_stack ? local.ec2_managed_policy_arns : toset([])

  role       = aws_iam_role.service[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "batch_managed" {
  for_each = local.ec2_managed_policy_arns

  role       = aws_iam_role.batch.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "trading_managed" {
  for_each = local.enable_service_stack ? local.ec2_managed_policy_arns : toset([])

  role       = aws_iam_role.trading[0].name
  policy_arn = each.value
}

data "aws_iam_policy_document" "service_workload" {
  count = local.enable_service_stack ? 1 : 0

  statement {
    sid    = "ListMarketAndResultBuckets"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration"
    ]
    resources = [aws_s3_bucket.market_data.arn, aws_s3_bucket.results[0].arn]
  }

  statement {
    sid    = "ReadWriteMarketData"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${aws_s3_bucket.market_data.arn}/*"]
  }

  statement {
    sid       = "ReadApprovedResults"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.results[0].arn}/*"]
  }

  statement {
    sid    = "ReadDevelopmentParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_path}/*"]
  }
}

resource "aws_iam_role_policy" "service_workload" {
  count = local.enable_service_stack ? 1 : 0

  name   = "${local.name_prefix}-service-workload"
  role   = aws_iam_role.service[0].id
  policy = data.aws_iam_policy_document.service_workload[0].json
}

data "aws_iam_policy_document" "batch_workload" {
  statement {
    sid    = "ListMarketAndResultBuckets"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration"
    ]
    resources = concat(
      [aws_s3_bucket.market_data.arn],
      local.enable_service_stack ? [aws_s3_bucket.results[0].arn] : []
    )
  }

  statement {
    sid    = "ReadWriteMarketAndResults"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = concat(
      ["${aws_s3_bucket.market_data.arn}/*"],
      local.enable_service_stack ? ["${aws_s3_bucket.results[0].arn}/*"] : []
    )
  }

  statement {
    sid    = "ReadDevelopmentParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_path}/*"]
  }
}

resource "aws_iam_role_policy" "batch_workload" {
  name   = "${local.name_prefix}-batch-workload"
  role   = aws_iam_role.batch.id
  policy = data.aws_iam_policy_document.batch_workload.json
}

data "aws_iam_policy_document" "trading_workload" {
  count = local.enable_service_stack ? 1 : 0

  statement {
    sid    = "ReadDevelopmentParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_path}/*"]
  }

  statement {
    sid       = "ReadAlpacaDataFeedCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [data.aws_secretsmanager_secret.alpaca_api_key[0].arn, data.aws_secretsmanager_secret.alpaca_secret_key[0].arn]
  }
}

resource "aws_iam_role_policy" "trading_workload" {
  count = local.enable_service_stack ? 1 : 0

  name   = "${local.name_prefix}-trading-workload"
  role   = aws_iam_role.trading[0].id
  policy = data.aws_iam_policy_document.trading_workload[0].json
}

resource "aws_iam_instance_profile" "service" {
  count = local.enable_service_stack ? 1 : 0

  name = "${local.name_prefix}-service-instance-profile"
  role = aws_iam_role.service[0].name
}

resource "aws_iam_instance_profile" "batch" {
  name = "${local.name_prefix}-batch-instance-profile"
  role = aws_iam_role.batch.name
}

resource "aws_iam_instance_profile" "trading" {
  count = local.enable_service_stack ? 1 : 0

  name = "${local.name_prefix}-trading-instance-profile"
  role = aws_iam_role.trading[0].name
}

data "aws_iam_policy_document" "rds_secret_access" {
  statement {
    sid     = "ReadDatabaseCredentials"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      aws_db_instance.this.master_user_secret[0].secret_arn,
      aws_secretsmanager_secret.market_loader.arn
    ]
  }
}

resource "aws_iam_role_policy" "service_rds_secret" {
  count = local.enable_service_stack ? 1 : 0

  name   = "${local.name_prefix}-service-rds-secret"
  role   = aws_iam_role.service[0].id
  policy = data.aws_iam_policy_document.rds_secret_access.json
}

resource "aws_iam_role_policy" "batch_rds_secret" {
  name   = "${local.name_prefix}-batch-rds-secret"
  role   = aws_iam_role.batch.id
  policy = data.aws_iam_policy_document.rds_secret_access.json
}

resource "aws_iam_role_policy" "trading_rds_secret" {
  count = local.enable_service_stack ? 1 : 0

  name   = "${local.name_prefix}-trading-rds-secret"
  role   = aws_iam_role.trading[0].id
  policy = data.aws_iam_policy_document.rds_secret_access.json
}

data "aws_iam_policy_document" "service_queue_publish" {
  count = local.enable_service_stack ? 1 : 0

  statement {
    sid       = "PublishDurableWork"
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    resources = values(aws_sqs_queue.backtest)[*].arn
  }
}

resource "aws_iam_role_policy" "service_queue_publish" {
  count = local.enable_service_stack ? 1 : 0

  name   = "${local.name_prefix}-service-queue-publish"
  role   = aws_iam_role.service[0].id
  policy = data.aws_iam_policy_document.service_queue_publish[0].json
}

data "aws_iam_policy_document" "batch_queue_consume" {
  count = local.enable_service_stack ? 1 : 0

  statement {
    sid    = "ConsumeDurableWork"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = values(aws_sqs_queue.backtest)[*].arn
  }

  statement {
    sid       = "PublishPoisonMessages"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = values(aws_sqs_queue.backtest_dlq)[*].arn
  }


  statement {
    sid       = "ReadAlpacaHistoricalDataCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [data.aws_secretsmanager_secret.alpaca_api_key[0].arn, data.aws_secretsmanager_secret.alpaca_secret_key[0].arn]
  }
}

resource "aws_iam_role_policy" "batch_queue_consume" {
  count = local.enable_service_stack ? 1 : 0

  name   = "${local.name_prefix}-batch-queue-consume"
  role   = aws_iam_role.batch.id
  policy = data.aws_iam_policy_document.batch_queue_consume[0].json
}

data "aws_iam_policy_document" "backtest_scale_down" {
  count = local.enable_service_stack ? 1 : 0
  statement {
    actions   = ["autoscaling:DescribeAutoScalingGroups", "autoscaling:SetDesiredCapacity"]
    resources = [aws_autoscaling_group.backtest[0].arn]
  }
}

resource "aws_iam_role_policy" "backtest_scale_down" {
  count  = local.enable_service_stack ? 1 : 0
  name   = "${local.name_prefix}-backtest-safe-scale-down"
  role   = aws_iam_role.batch.id
  policy = data.aws_iam_policy_document.backtest_scale_down[0].json
}

data "aws_iam_policy_document" "service_origin_tls" {
  count = local.enable_service_stack ? 1 : 0
  statement {
    actions   = ["route53:ChangeResourceRecordSets", "route53:GetChange"]
    resources = ["arn:aws:route53:::hostedzone/${local.hosted_zone_id}", "arn:aws:route53:::change/*"]
  }
  statement {
    actions   = ["route53:ListHostedZones", "route53:ListHostedZonesByName"]
    resources = ["*"]
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.cloudfront_origin_header[0].arn]
  }
}

resource "aws_iam_role_policy" "service_origin_tls" {
  count  = local.enable_service_stack ? 1 : 0
  name   = "${local.name_prefix}-service-origin-tls"
  role   = aws_iam_role.service[0].id
  policy = data.aws_iam_policy_document.service_origin_tls[0].json
}
