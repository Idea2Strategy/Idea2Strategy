resource "random_password" "identity_email_encryption" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "identity_lookup_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 48
  special = false
}

resource "random_password" "identity_verification_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 48
  special = false
}

resource "random_password" "identity_refresh_token_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 48
  special = false
}

moved {
  from = random_password.identity_session_hmac
  to   = random_password.identity_refresh_token_hmac
}

resource "random_password" "identity_customer_jwt_signing" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 48
  special = false
}

resource "random_password" "operator_totp_encryption" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "operator_session_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "operator_csrf_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "operator_source_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "operator_login_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "backtest_result_ingest" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 48
  special = false
}

resource "random_uuid" "backtest_result_principal" {
  count = local.enable_service_stack ? 1 : 0
}

resource "aws_secretsmanager_secret" "core_internal" {
  count                   = local.enable_service_stack ? 1 : 0
  name                    = "${local.name_prefix}/runtime/core-internal"
  description             = "Generated identity cryptographic material for the Development Core runtime."
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "core_internal" {
  count     = local.enable_service_stack ? 1 : 0
  secret_id = aws_secretsmanager_secret.core_internal[0].id
  secret_string = jsonencode({
    IDENTITY_EMAIL_ENCRYPTION_KEY     = base64encode(random_password.identity_email_encryption[0].result)
    IDENTITY_LOOKUP_HMAC_KEY          = base64encode(random_password.identity_lookup_hmac[0].result)
    IDENTITY_VERIFICATION_HMAC_KEY    = base64encode(random_password.identity_verification_hmac[0].result)
    IDENTITY_REFRESH_TOKEN_HMAC_KEY   = base64encode(random_password.identity_refresh_token_hmac[0].result)
    IDENTITY_CUSTOMER_JWT_SIGNING_KEY = base64encode(random_password.identity_customer_jwt_signing[0].result)
    OPERATOR_AUTH_TOTP_KEY            = base64encode(random_password.operator_totp_encryption[0].result)
    OPERATOR_AUTH_SESSION_HMAC_KEY    = base64encode(random_password.operator_session_hmac[0].result)
    OPERATOR_AUTH_CSRF_HMAC_KEY       = base64encode(random_password.operator_csrf_hmac[0].result)
    OPERATOR_AUTH_SOURCE_HMAC_KEY     = base64encode(random_password.operator_source_hmac[0].result)
    OPERATOR_AUTH_LOGIN_HMAC_KEY      = base64encode(random_password.operator_login_hmac[0].result)
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret" "backtest_internal" {
  count                   = local.enable_service_stack ? 1 : 0
  name                    = "${local.name_prefix}/runtime/backtest-internal"
  description             = "Generated customer JWT verification and result-ingestion credentials for Backtest runtimes."
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "backtest_internal" {
  count     = local.enable_service_stack ? 1 : 0
  secret_id = aws_secretsmanager_secret.backtest_internal[0].id
  secret_string = jsonencode({
    CUSTOMER_JWT_SIGNING_KEY_BASE64 = base64encode(random_password.identity_customer_jwt_signing[0].result)
    BACKTEST_RESULT_INGEST_TOKEN    = random_password.backtest_result_ingest[0].result
    BACKTEST_RESULT_PRINCIPAL_ID    = random_uuid.backtest_result_principal[0].result
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "runtime_artifact_guard" {
  count = local.enable_service_stack ? 1 : 0

  input = {
    backtest = var.backtest_policy_artifacts
    trading  = var.trading_runtime_artifacts
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for required in ["execution-policy", "runtime-policy"] : contains(keys(var.backtest_policy_artifacts), required)
      ])
      error_message = "Full deployment requires versioned execution-policy and runtime-policy Backtest artifacts."
    }

    precondition {
      condition = alltrue([
        for required in ["instrument-mapping", "provider-rights", "warmup-manifest"] : contains(keys(var.trading_runtime_artifacts), required)
      ])
      error_message = "Full deployment requires versioned Trading instrument-mapping, provider-rights, and warmup-manifest artifacts."
    }

    precondition {
      condition = (
        try(var.trading_runtime_artifacts["instrument-mapping"].runtime, "") == "market-gateway" &&
        try(var.trading_runtime_artifacts["instrument-mapping"].local_path, "") == "instruments.json" &&
        try(var.trading_runtime_artifacts["provider-rights"].runtime, "") == "market-gateway" &&
        try(var.trading_runtime_artifacts["provider-rights"].local_path, "") == "alpaca-${var.trading_market_data_feed}-rights.json" &&
        try(var.trading_runtime_artifacts["warmup-manifest"].runtime, "") == "trading-worker" &&
        try(var.trading_runtime_artifacts["warmup-manifest"].local_path, "") == "warmup/manifest.json"
      )
      error_message = "Required Trading artifacts must use their exact runtime and mounted relative paths."
    }

    precondition {
      condition     = var.enable_backtest_outbox_relay
      error_message = "A full release candidate must explicitly enable the verified three-lane Backtest Outbox relay."
    }

    precondition {
      condition = (
        !var.enable_operator_auth || (
          var.operator_rbac_catalog_version != "" &&
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.operator_rbac_catalog_read_permission_id)) &&
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.operator_rbac_assignment_read_permission_id)) &&
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.operator_rbac_grant_permission_id)) &&
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.operator_rbac_revoke_permission_id)) &&
          alltrue([for permission_id in [
            var.operator_case_queue_permission_id,
            var.operator_case_detail_permission_id,
            var.operator_case_assign_permission_id,
            var.operator_case_reassign_permission_id,
            var.operator_case_unassign_permission_id,
            var.operator_case_start_review_permission_id,
            var.operator_case_request_information_permission_id,
            var.operator_case_resolve_permission_id,
            var.operator_case_reject_permission_id,
            var.operator_case_apply_sanction_permission_id,
            var.operator_case_release_sanction_permission_id,
            var.operator_sanction_apply_permission_id,
            var.operator_sanction_lift_permission_id,
          ] : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", permission_id))])
        )
      )
      error_message = "Enabling operator authentication requires reviewed internal-session RBAC permission UUIDs."
    }
  }
}

resource "aws_ssm_parameter" "core_internal_secret" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/runtime/core-internal-secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.core_internal[0].arn
}

resource "aws_ssm_parameter" "backtest_internal_secret" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/runtime/backtest-internal-secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.backtest_internal[0].arn
}
