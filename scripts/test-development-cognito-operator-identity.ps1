[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$environmentRoot = Join-Path $root "infra/terraform/environments/development"
$identity = Get-Content -LiteralPath (Join-Path $environmentRoot "operator-identity.tf") -Raw
$variables = Get-Content -LiteralPath (Join-Path $environmentRoot "variables.tf") -Raw
$outputs = Get-Content -LiteralPath (Join-Path $environmentRoot "outputs.tf") -Raw
$lambda = Get-Content -LiteralPath (Join-Path $environmentRoot "lambda/operator-pre-token/index.mjs") -Raw

foreach ($required in @(
    'variable "enable_cognito_operator_identity"',
    'default     = false',
    'resource "aws_cognito_user_pool" "operator"',
    'user_pool_tier           = "ESSENTIALS"',
    'mfa_configuration        = "ON"',
    'enabled = true',
    'allow_admin_create_user_only = true',
    'resource "aws_cognito_user_pool_client" "operator"',
    'generate_secret                      = false',
    'allowed_oauth_flows                  = ["code"]',
    'allowed_oauth_flows_user_pool_client = true',
    'supported_identity_providers         = ["COGNITO"]',
    'resource "aws_cognito_user_pool_domain" "operator"',
    'managed_login_version = 2',
    'resource "aws_cognito_managed_login_branding" "operator"',
    'use_cognito_provided_values = true',
    'lambda_version = "V2_0"',
    'resource "aws_lambda_permission" "operator_pre_token"'
)) {
    if (-not ($variables.Contains($required) -or $identity.Contains($required))) {
        throw "Cognito operator identity boundary is missing: $required"
    }
}

foreach ($required in @(
    'variable "operator_auth_mfa_claim_name"',
    'variable "operator_auth_allowed_mfa_claim_values"',
    'OPERATOR_AUTH_MFA_CLAIM_NAME=${operator_auth_mfa_claim_name}',
    'OPERATOR_AUTH_ALLOWED_MFA_CLAIM_VALUES=${operator_auth_allowed_mfa_claim_values}',
    'operator_auth_mfa_claim_name',
    'operator_auth_allowed_mfa_claim_values'
)) {
    $all = (Get-ChildItem -LiteralPath $environmentRoot -Recurse -File |
      Where-Object { $_.Extension -in @('.tf', '.tftpl', '.mjs') } | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw
    }) -join "`n"
    if (-not $all.Contains($required)) {
        throw "Cognito namespaced assurance runtime wiring is missing: $required"
    }
}

foreach ($forbidden in @(
    'sms_configuration',
    'mfa_configuration = "OPTIONAL"',
    'allowed_oauth_flows = ["implicit"]',
    'generate_secret = true',
    'device_configuration'
)) {
    if ($identity.Contains($forbidden)) {
        throw "Cognito operator identity enables a prohibited path: $forbidden"
    }
}

foreach ($required in @(
    'event.version !== "2_0"',
    '"TokenGeneration_HostedAuth"',
    '"TokenGeneration_Authentication"',
    '"TokenGeneration_NewPasswordChallenge"',
    '"TokenGeneration_RefreshTokens"',
    'claimsToAddOrOverride',
    '"https://ideatostrategy.com/claims/mfa"',
    'event.callerContext?.clientId',
    'aud:'
)) {
    if (-not $lambda.Contains($required)) {
        throw "Pre-token claim transformer is missing: $required"
    }
}
foreach ($reserved in @('acr:', 'amr:')) {
    if ($lambda.Contains($reserved)) {
        throw "Cognito cannot add the reserved claim $reserved; use the reviewed namespaced claim."
    }
}

foreach ($required in @(
    'output "cognito_operator_oidc"',
    'authorization_endpoint',
    'token_endpoint',
    'end_session_endpoint',
    'client_id',
    'audience',
    'jwk_set_uri',
    'logout_redirect_parameter'
)) {
    if (-not $outputs.Contains($required)) {
        throw "Cognito operator deployment output is missing: $required"
    }
}

Write-Output "Development Cognito operator identity checks passed."
