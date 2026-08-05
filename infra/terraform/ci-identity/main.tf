data "aws_caller_identity" "current" {}

locals {
  name_prefix                    = "${var.project_name}-${var.environment}"
  github_repository_parts        = split("/", var.github_repository)
  github_oidc_repository_subject = "${local.github_repository_parts[0]}@${var.github_repository_owner_id}/${local.github_repository_parts[1]}@${var.github_repository_id}"
  state_bucket_name              = var.state_bucket_name != "" ? var.state_bucket_name : "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-tfstate"
  state_bucket_arn               = "arn:aws:s3:::${local.state_bucket_name}"
  frontend_bucket_arn            = "arn:aws:s3:::${local.name_prefix}-${data.aws_caller_identity.current.account_id}-frontend"
  ecr_repository_arn             = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${local.name_prefix}/*"
  deployment_prerequisite_secret_names = [
    "${local.name_prefix}/backtest/alpaca",
    "${local.name_prefix}/backtest/alpaca-secret",
    "${local.name_prefix}/database/backend-runtime",
    "${local.name_prefix}/database/batch-runtime",
    "${local.name_prefix}/database/backtest-runtime",
    "${local.name_prefix}/database/trading-runtime",
    "${local.name_prefix}/database/pipeline-runtime"
  ]
  deployment_prerequisite_secret_arns = [
    for secret_name in local.deployment_prerequisite_secret_names :
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${secret_name}-*"
  ]
}

data "aws_iam_policy_document" "github_plan_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_oidc_repository_subject}:environment:${var.github_plan_environment}"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "${local.name_prefix}-github-plan"
  assume_role_policy   = data.aws_iam_policy_document.github_plan_assume.json
  max_session_duration = 3600

  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role_policy_attachment" "github_plan_read_only" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "github_plan_artifacts" {
  statement {
    sid       = "ReadDeploymentPrerequisiteSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = local.deployment_prerequisite_secret_arns
  }

  statement {
    sid       = "ECRAuthorization"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PublishImmutableRuntimeImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:StartImageScan",
      "ecr:UploadLayerPart"
    ]
    resources = [local.ecr_repository_arn]
  }

  statement {
    sid       = "ReadStateBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid    = "ReadStateAndPublishCandidate"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]
    resources = [
      "${local.state_bucket_arn}/idea2strategy/development/terraform.tfstate",
      "${local.state_bucket_arn}/idea2strategy/development/release-candidates/*"
    ]
  }

  statement {
    sid       = "ManageTerraformLock"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/idea2strategy/development/terraform.tfstate.tflock"]
  }

  statement {
    sid       = "PublishImmutableFrontendRelease"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.frontend_bucket_arn}/_releases/*"]
  }

  statement {
    sid       = "ListImmutableFrontendReleases"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.frontend_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["_releases/*"]
    }
  }
}

resource "aws_iam_role_policy" "github_plan_artifacts" {
  name   = "${local.name_prefix}-plan-artifacts"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_artifacts.json
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_deploy_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_oidc_repository_subject}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${local.name_prefix}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_deploy_assume.json
  max_session_duration = 3600

  lifecycle { prevent_destroy = true }
}

resource "aws_iam_role_policy_attachment" "github_deploy_power_user" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "github_deploy_state_and_iam" {
  statement {
    sid       = "TerraformStateBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid    = "TerraformStateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${local.state_bucket_arn}/idea2strategy/development/*",
      "${local.state_bucket_arn}/idea2strategy/artifact-foundation/*",
      "${local.state_bucket_arn}/idea2strategy/ci-identity/*"
    ]
  }

  statement {
    sid    = "ManagedRuntimeRoles"
    effect = "Allow"
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:CreateRole",
      "iam:DeleteInstanceProfile",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetInstanceProfile",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:TagRole",
      "iam:UntagInstanceProfile",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRoleDescription"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${local.name_prefix}-*"
    ]
  }

  statement {
    sid       = "ReadAWSManagedPolicies"
    effect    = "Allow"
    actions   = ["iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions"]
    resources = ["arn:aws:iam::aws:policy/*"]
  }

  statement {
    sid       = "CreateRequiredServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::*:role/aws-service-role/*"]

    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values = [
        "autoscaling.amazonaws.com",
        "elasticache.amazonaws.com",
        "ecs.amazonaws.com",
        "spot.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy_state_and_iam" {
  name   = "${local.name_prefix}-terraform-state-and-iam"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy_state_and_iam.json
}
