$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$workflowPath = Join-Path $PSScriptRoot "../.github/workflows/development-release.yml"
if (-not (Test-Path -LiteralPath $workflowPath)) {
    throw "The manual Development release workflow is missing."
}

$workflow = Get-Content -LiteralPath $workflowPath -Raw
$ciIdentity = Get-Content -LiteralPath (Join-Path $PSScriptRoot "../infra/terraform/ci-identity/main.tf") -Raw

$required = @(
    "workflow_dispatch:",
    "id-token: write",
    "github.ref == 'refs/heads/develop'",
    "environment: development-plan",
    "environment: development",
    "cancel-in-progress: false",
    "aws-actions/configure-aws-credentials@7474bc4690e29a8392af63c5b98e7449536d5c3a",
    "role-to-assume: `${{ vars.AWS_PLAN_ROLE_ARN }}",
    "role-to-assume: `${{ vars.AWS_DEPLOY_ROLE_ARN }}",
    "docker/setup-buildx-action@8d2750c68a42422c14e847fe6c8ac0403b4cbd6f",
    "--platform linux/arm64",
    "--tag `$target",
    "idea2strategy-dev/",
    "aws ecr describe-image-scan-findings",
    "aws ecr batch-get-image",
    "aws ecr start-image-scan",
    "ECR image scan did not complete",
    "ECR image scan rejected",
    "terraform plan -parallelism=1 -out=deployment.tfplan",
    "terraform apply -parallelism=1 deployment.tfplan",
    "aws s3api put-object",
    "--version-id",
    "Get-FileHash",
    "TF_STATE_BUCKET",
    "TF_VARS_JSON",
    "must carry independently reviewed public DNS delegation evidence",
    "aws s3 sync `"`$env:RUNNER_TEMP/frontend`"",
    "_releases/",
    "VITE_OPERATOR_OIDC_ENABLED: 'true'",
    "VITE_OPERATOR_OIDC_ISSUER: `${{ vars.OPERATOR_OIDC_ISSUER }}",
    "VITE_OPERATOR_OIDC_AUTHORIZATION_ENDPOINT: `${{ vars.OPERATOR_OIDC_AUTHORIZATION_ENDPOINT }}",
    "VITE_OPERATOR_OIDC_TOKEN_ENDPOINT: `${{ vars.OPERATOR_OIDC_TOKEN_ENDPOINT }}",
    "VITE_OPERATOR_OIDC_CLIENT_ID: `${{ vars.OPERATOR_OIDC_CLIENT_ID }}",
    "VITE_OPERATOR_OIDC_AUDIENCE: `${{ vars.OPERATOR_OIDC_AUDIENCE }}",
    "VITE_OPERATOR_OIDC_REDIRECT_URI: `${{ vars.OPERATOR_OIDC_REDIRECT_URI }}",
    "VITE_OPERATOR_OIDC_POST_LOGOUT_REDIRECT_URI: `${{ vars.OPERATOR_OIDC_POST_LOGOUT_REDIRECT_URI }}",
    "VITE_OPERATOR_OIDC_LOGOUT_REDIRECT_PARAMETER: `${{ vars.OPERATOR_OIDC_LOGOUT_REDIRECT_PARAMETER }}",
    "VITE_OPERATOR_OIDC_SCOPES: `${{ vars.OPERATOR_OIDC_SCOPES }}",
    "VITE_OPERATOR_OIDC_SIGNING_ALGORITHM: `${{ vars.OPERATOR_OIDC_SIGNING_ALGORITHM }}",
    "OIDC build input is missing",
    "OIDC endpoint must use HTTPS",
    "OIDC redirect URI must use the service origin",
    "OIDC logout redirect parameter is invalid",
    "test-aws-deployment-prerequisites.ps1",
    "-RequireRuntimeDatabaseSecrets",
    "-RequireAlpacaSecrets",
    "verify-deployed-development.ps1",
    "github.event.inputs.apply_reviewed_plan == 'true'"
)

foreach ($token in $required) {
    if (-not $workflow.Contains($token)) {
        throw "Development release workflow is missing required boundary: $token"
    }
}

foreach ($forbidden in @("aws-access-key-id", "aws-secret-access-key", "terraform apply -auto-approve", "docker build --platform linux/amd64", "idea2strategy-development", "create-invalidation", "s3 sync `"s3://`$env:FRONTEND_BUCKET/_releases")) {
    if ($workflow.Contains($forbidden)) {
        throw "Development release workflow contains forbidden boundary: $forbidden"
    }
}

$requiredImages = @(
    "admin-mcp",
    "backend-api",
    "backend-batch",
    "backend-worker",
    "backtest-api",
    "backtest-worker",
    "market-gateway",
    "pipeline-worker",
    "trading-worker"
)

foreach ($image in $requiredImages) {
    if (-not $workflow.Contains("name='$image'")) {
        throw "Development release workflow does not publish required image: $image"
    }
}

if ($workflow -notmatch "(?s)apply-reviewed-plan:.*?needs: prepare-and-plan.*?environment: development") {
    throw "Apply must consume the reviewed plan and cross the Development environment gate."
}

if ($workflow -notmatch "(?s)build:.*?Build untrusted ARM64 runtime inputs without AWS credentials.*?prepare-and-plan:.*?environment: development-plan.*?configure-aws-credentials") {
    throw "Untrusted image and frontend builds must complete before the scoped AWS planning credential is issued."
}

if ($workflow -notmatch "(?s)Build same-origin frontend without AWS credentials.*?env:.*?VITE_OPERATOR_OIDC_ENABLED: 'true'.*?run:.*?pnpm build") {
    throw "The production frontend build must fail closed with the reviewed public OIDC inputs before pnpm build."
}

if ($workflow -notmatch "(?s)operator_auth_issuer.*?OPERATOR_OIDC_ISSUER.*?operator_auth_audience.*?OPERATOR_OIDC_AUDIENCE") {
    throw "The frontend OIDC issuer and audience must be cross-checked against the Terraform runtime inputs."
}

if ($workflow -notmatch "(?s)configure-aws-credentials.*?test-aws-deployment-prerequisites\.ps1.*?-RequireRuntimeDatabaseSecrets.*?Create saved Terraform plan") {
    throw "The release plan must fail closed on populated runtime database secrets after AWS authentication and before Terraform planning."
}

if ($workflow -notmatch "(?s)Publish immutable ARM64 images.*?Wait for ECR security scans.*?Publish immutable frontend prefix") {
    throw "Every published runtime image must pass the ECR scan before frontend publication and planning."
}

if ($workflow -notmatch "(?s)findingSeverityCounts.*?CRITICAL.*?HIGH") {
    throw "The release scan gate must reject Critical and High findings."
}

if (-not $ciIdentity.Contains('"ecr:StartImageScan"')) {
    throw "The scoped plan role must be allowed to start scans for its exact ECR repositories."
}

Write-Host "Development release workflow policy checks passed."
