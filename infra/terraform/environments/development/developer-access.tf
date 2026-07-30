locals {
  development_developer_group_name = "Idea2StrategyDevelopmentSsmUsers"
  development_bucket_arns = [
    "arn:aws:s3:::${local.market_data_bucket_name}",
    "arn:aws:s3:::${local.result_bucket_name}"
  ]
  development_object_arns = [for arn in local.development_bucket_arns : "${arn}/*"]
  development_ecr_repository_arns = [
    for name in ["frontend", "backend", "batch", "backtest", "market-data-worker"] :
    "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${local.name_prefix}/${name}"
  ]
}

resource "aws_iam_user" "developer" {
  for_each = var.development_iam_user_names

  name          = each.value
  force_destroy = false
  tags          = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_group" "development_developers" {
  name = local.development_developer_group_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_user_group_membership" "development_developer" {
  for_each = aws_iam_user.developer

  user   = each.value.name
  groups = [aws_iam_group.development_developers.name]
}

data "aws_iam_policy_document" "development_ssm_access" {
  statement {
    sid    = "DescribeDevelopmentCompute"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeTags"
    ]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid     = "StartSessionOnDevelopmentBatchInstance"
    effect  = "Allow"
    actions = ["ssm:StartSession"]
    resources = [
      aws_instance.batch.arn,
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/SSM-SessionManagerRunShell",
      "arn:aws:ssm:${var.aws_region}::document/AWS-StartPortForwardingSession",
      "arn:aws:ssm:${var.aws_region}::document/AWS-StartPortForwardingSessionToRemoteHost"
    ]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ManageOwnSessions"
    effect = "Allow"
    actions = [
      "ssm:ResumeSession",
      "ssm:TerminateSession"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/$${aws:username}-*",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/$${aws:userid}-*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ReadSessionState"
    effect = "Allow"
    actions = [
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
      "ssm:DescribeInstanceInformation",
      "ssm:DescribeInstanceProperties"
    ]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid     = "OpenOwnSessionDataChannel"
    effect  = "Allow"
    actions = ["ssmmessages:OpenDataChannel"]
    resources = [
      "arn:aws:ssm:*:*:session/$${aws:userid}-*",
      "arn:aws:ssm:*:*:session/$${aws:username}-*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ReadEc2ConsoleConnectionPrerequisites"
    effect = "Allow"
    actions = [
      "ssm:GetServiceSetting",
      "iam:GetInstanceProfile"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:servicesetting/ssm/managed-instance/default-ec2-instance-management-role",
      aws_iam_instance_profile.batch.arn
    ]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_group_policy" "development_ssm_access" {
  name   = "Idea2StrategyDevelopmentSsmAccess"
  group  = aws_iam_group.development_developers.name
  policy = data.aws_iam_policy_document.development_ssm_access.json
}

data "aws_iam_policy_document" "self_manage_credentials" {
  statement {
    sid    = "ViewAccountAndOwnMfa"
    effect = "Allow"
    actions = [
      "iam:GetAccountPasswordPolicy",
      "iam:ListAccountAliases",
      "iam:ListVirtualMFADevices"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ChangeOwnPassword"
    effect    = "Allow"
    actions   = ["iam:ChangePassword"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}"]
  }

  statement {
    sid       = "CreateVirtualMfaDeviceForEnrollment"
    effect    = "Allow"
    actions   = ["iam:CreateVirtualMFADevice"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/*"]
  }

  statement {
    sid    = "EnrollAndViewOwnMfa"
    effect = "Allow"
    actions = [
      "iam:EnableMFADevice",
      "iam:GetUser",
      "iam:GetMFADevice",
      "iam:ListMFADevices",
      "iam:ResyncMFADevice"
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}"]
  }

  statement {
    sid       = "DeactivateOwnMfaOnlyWithMfa"
    effect    = "Allow"
    actions   = ["iam:DeactivateMFADevice"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid       = "DeleteVirtualMfaOnlyWithMfa"
    effect    = "Allow"
    actions   = ["iam:DeleteVirtualMFADevice"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_group_policy" "self_manage_credentials" {
  name   = "Idea2StrategySelfManageCredentials"
  group  = aws_iam_group.development_developers.name
  policy = data.aws_iam_policy_document.self_manage_credentials.json
}

data "aws_iam_policy_document" "development_developer_access" {
  statement {
    sid    = "ListBucketsForConsole"
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetAccountPublicAccessBlock"
    ]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "UseDevelopmentBuckets"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketPolicyStatus",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketTagging",
      "s3:GetBucketCORS"
    ]
    resources = local.development_bucket_arns

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ManageDevelopmentObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTagging",
      "s3:GetObjectAttributes",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:RestoreObject"
    ]
    resources = local.development_object_arns

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ReadComputeAndNetwork"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "autoscaling:Describe*"
    ]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ReadDatabase"
    effect = "Allow"
    actions = [
      "rds:Describe*",
      "rds:ListTagsForResource",
      "rds:DownloadDBLogFilePortion",
      "pi:GetResourceMetrics",
      "pi:DescribeDimensionKeys",
      "pi:GetDimensionKeyDetails"
    ]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
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

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ReadSystemsManagerState"
    effect = "Allow"
    actions = [
      "ssm:Describe*",
      "ssm:List*",
      "ssm:GetInventory",
      "ssm:GetInventorySchema",
      "ssm:GetOpsSummary"
    ]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ReadMetricsAndDevelopmentLogs"
    effect = "Allow"
    actions = [
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "cloudwatch:Describe*",
      "logs:Describe*",
      "logs:Get*",
      "logs:List*",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:TestMetricFilter",
      "logs:FilterLogEvents",
      "logs:StartLiveTail",
      "logs:StopLiveTail"
    ]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid       = "AuthenticateToEcr"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "PullAndPushDevelopmentImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:GetRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = local.development_ecr_repository_arns

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ReadDnsCertificatesAndTags"
    effect = "Allow"
    actions = [
      "route53:Get*",
      "route53:List*",
      "acm:DescribeCertificate",
      "acm:GetAccountConfiguration",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues",
      "resource-groups:Get*",
      "resource-groups:List*",
      "resource-groups:SearchResources"
    ]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "development_developer_access" {
  name        = "Idea2StrategyDevelopmentDeveloperAccess"
  description = "MFA-protected access to Idea2Strategy Development application resources; excludes infrastructure administration and secrets."
  policy      = data.aws_iam_policy_document.development_developer_access.json
  tags        = local.common_tags
}

resource "aws_iam_group_policy_attachment" "signin_local" {
  group      = aws_iam_group.development_developers.name
  policy_arn = "arn:aws:iam::aws:policy/SignInLocalDevelopmentAccess"
}

resource "aws_iam_group_policy_attachment" "development_developer_access" {
  group      = aws_iam_group.development_developers.name
  policy_arn = aws_iam_policy.development_developer_access.arn
}
