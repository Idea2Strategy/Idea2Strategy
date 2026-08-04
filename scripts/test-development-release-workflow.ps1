$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$workflowPath = Join-Path $PSScriptRoot "../.github/workflows/development-release.yml"
if (-not (Test-Path -LiteralPath $workflowPath)) {
    throw "The manual Development release workflow is missing."
}

$workflow = Get-Content -LiteralPath $workflowPath -Raw

$required = @(
    "workflow_dispatch:",
    "id-token: write",
    "environment: development",
    "cancel-in-progress: false",
    "aws-actions/configure-aws-credentials@v4",
    "role-to-assume: `${{ vars.AWS_DEPLOY_ROLE_ARN }}",
    "docker/setup-buildx-action@v3",
    "--platform linux/arm64",
    "terraform plan -parallelism=1 -out=deployment.tfplan",
    "terraform apply -parallelism=1 deployment.tfplan",
    "aws s3api put-object",
    "--version-id",
    "Get-FileHash",
    "TF_STATE_BUCKET",
    "TF_VARS_JSON",
    "aws s3 sync frontend",
    "_releases/",
    "create-invalidation",
    "github.event.inputs.apply_reviewed_plan == 'true'"
)

foreach ($token in $required) {
    if (-not $workflow.Contains($token)) {
        throw "Development release workflow is missing required boundary: $token"
    }
}

foreach ($forbidden in @("aws-access-key-id", "aws-secret-access-key", "terraform apply -auto-approve", "docker build --platform linux/amd64")) {
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

Write-Host "Development release workflow policy checks passed."
