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

resource "random_password" "identity_session_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 48
  special = false
}

resource "random_password" "operator_subject_hmac" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 48
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
    IDENTITY_EMAIL_ENCRYPTION_KEY  = base64encode(random_password.identity_email_encryption[0].result)
    IDENTITY_LOOKUP_HMAC_KEY       = base64encode(random_password.identity_lookup_hmac[0].result)
    IDENTITY_VERIFICATION_HMAC_KEY = base64encode(random_password.identity_verification_hmac[0].result)
    IDENTITY_SESSION_HMAC_KEY      = base64encode(random_password.identity_session_hmac[0].result)
    OPERATOR_AUTH_CURRENT_HMAC_KEY = base64encode(random_password.operator_subject_hmac[0].result)
  })
}

resource "aws_secretsmanager_secret" "backtest_internal" {
  count                   = local.enable_service_stack ? 1 : 0
  name                    = "${local.name_prefix}/runtime/backtest-internal"
  description             = "Generated session verification and result-ingestion credentials for Backtest runtimes."
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "backtest_internal" {
  count     = local.enable_service_stack ? 1 : 0
  secret_id = aws_secretsmanager_secret.backtest_internal[0].id
  secret_string = jsonencode({
    BACKTEST_SESSION_HMAC_KEY_BASE64 = base64encode(random_password.identity_session_hmac[0].result)
    BACKTEST_RESULT_INGEST_TOKEN     = random_password.backtest_result_ingest[0].result
    BACKTEST_RESULT_PRINCIPAL_ID     = random_uuid.backtest_result_principal[0].result
  })
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
          local.operator_auth_issuer != "" &&
          local.operator_auth_jwk_set_uri != "" &&
          local.operator_auth_audience != "" &&
          (
            length(setunion(var.operator_auth_allowed_acr_values, var.operator_auth_allowed_amr_values)) > 0 ||
            (local.operator_auth_mfa_claim_name != "" && length(local.operator_auth_allowed_mfa_claim_values) > 0)
          ) &&
          var.operator_rbac_catalog_version != "" &&
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.operator_rbac_catalog_read_permission_id)) &&
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.operator_rbac_assignment_read_permission_id)) &&
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.operator_rbac_grant_permission_id)) &&
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$", var.operator_rbac_revoke_permission_id))
        )
      )
      error_message = "Enabling operator authentication requires the exact OIDC issuer/JWKS/audience, a reviewed MFA assurance claim allow-list, and the reviewed RBAC read/grant/revoke permission UUIDs."
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
