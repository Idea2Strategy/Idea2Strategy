data "archive_file" "operator_pre_token" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/operator-pre-token/index.mjs"
  output_path = "${path.module}/.terraform/operator-pre-token.zip"
}

resource "random_id" "operator_domain" {
  count       = var.enable_cognito_operator_identity ? 1 : 0
  byte_length = 4
}

data "aws_iam_policy_document" "operator_pre_token_assume" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "operator_pre_token" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  name               = "${local.name_prefix}-operator-pre-token"
  assume_role_policy = data.aws_iam_policy_document.operator_pre_token_assume[0].json
}

resource "aws_cloudwatch_log_group" "operator_pre_token" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-operator-pre-token"
  retention_in_days = 30
}

data "aws_iam_policy_document" "operator_pre_token_logs" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.operator_pre_token[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "operator_pre_token_logs" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  name   = "cloudwatch-logs"
  role   = aws_iam_role.operator_pre_token[0].id
  policy = data.aws_iam_policy_document.operator_pre_token_logs[0].json
}

resource "aws_lambda_function" "operator_pre_token" {
  #checkov:skip=CKV_AWS_117:Cognito invokes this synchronous pre-token transformer through the AWS control plane; VPC attachment adds cold-start and network dependencies without protecting data access.
  #checkov:skip=CKV_AWS_116:Cognito pre-token generation is synchronous and fail-closed; Cognito receives invocation errors directly, so an asynchronous Lambda DLQ is not applicable.
  #checkov:skip=CKV_AWS_272:The immutable source hash and reviewed Terraform package pin this small first-party transformer; a separate Lambda code-signing profile is outside the Development trust boundary.
  count = var.enable_cognito_operator_identity ? 1 : 0

  function_name                  = "${local.name_prefix}-operator-pre-token"
  role                           = aws_iam_role.operator_pre_token[0].arn
  handler                        = "index.handler"
  runtime                        = "nodejs22.x"
  architectures                  = ["arm64"]
  filename                       = data.archive_file.operator_pre_token[0].output_path
  source_code_hash               = data.archive_file.operator_pre_token[0].output_base64sha256
  memory_size                    = 128
  timeout                        = 3
  reserved_concurrent_executions = 5

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_cloudwatch_log_group.operator_pre_token,
    aws_iam_role_policy.operator_pre_token_logs,
  ]
}

resource "aws_cognito_user_pool" "operator" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  name                     = "${local.name_prefix}-operators"
  user_pool_tier           = "ESSENTIALS"
  mfa_configuration        = "ON"
  username_attributes      = ["email"]
  deletion_protection      = "ACTIVE"
  auto_verified_attributes = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  software_token_mfa_configuration {
    enabled = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  password_policy {
    minimum_length                   = 14
    password_history_size            = 5
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 3
  }

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.operator_pre_token[0].arn
      lambda_version = "V2_0"
    }
  }
}

resource "aws_lambda_permission" "operator_pre_token" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  statement_id  = "AllowCognitoUserPool"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.operator_pre_token[0].function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.operator[0].arn
}

resource "aws_cognito_user_pool_client" "operator" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  name         = "${local.name_prefix}-operator-browser"
  user_pool_id = aws_cognito_user_pool.operator[0].id

  generate_secret                      = false
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = ["https://${var.frontend_domain_name}/operations/callback"]
  logout_urls                          = ["https://${var.frontend_domain_name}/operations/login"]
  default_redirect_uri                 = "https://${var.frontend_domain_name}/operations/callback"
  explicit_auth_flows                  = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  access_token_validity                = 5
  id_token_validity                    = 5
  refresh_token_validity               = 60

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "minutes"
  }
}

resource "aws_cognito_user_pool_domain" "operator" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  domain                = "${var.project_name}-${var.environment}-operators-${random_id.operator_domain[0].hex}"
  user_pool_id          = aws_cognito_user_pool.operator[0].id
  managed_login_version = 2
}

resource "aws_cognito_managed_login_branding" "operator" {
  count = var.enable_cognito_operator_identity ? 1 : 0

  client_id                   = aws_cognito_user_pool_client.operator[0].id
  user_pool_id                = aws_cognito_user_pool.operator[0].id
  use_cognito_provided_values = true

  depends_on = [aws_cognito_user_pool_domain.operator]
}
