data "aws_caller_identity" "current" {}

locals {
  generated_state_bucket_name = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-tfstate"
  state_bucket_name           = var.state_bucket_name != "" ? var.state_bucket_name : local.generated_state_bucket_name
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.state_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.terraform_state]
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
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${var.project_name}-${var.environment}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_deploy_assume.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_deploy_power_user" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "github_deploy_state_and_iam" {
  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid    = "TerraformStateObject"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.terraform_state.arn}/idea2strategy/development/*"]
  }

  statement {
    sid    = "ManagedRuntimeRoles"
    effect = "Allow"
    actions = [
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
      "iam:AddRoleToInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:TagRole",
      "iam:UntagInstanceProfile",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRoleDescription"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project_name}-${var.environment}-*"
    ]
  }

  statement {
    sid       = "ReadAWSManagedPolicies"
    effect    = "Allow"
    actions   = ["iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions"]
    resources = ["arn:aws:iam::aws:policy/*"]
  }

  statement {
    sid    = "CreateRequiredServiceLinkedRoles"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
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
  name   = "${var.project_name}-${var.environment}-terraform-state-and-iam"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy_state_and_iam.json
}
