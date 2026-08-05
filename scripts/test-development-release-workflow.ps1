$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$workflowPath = Join-Path $PSScriptRoot "../.github/workflows/development-release.yml"
if (-not (Test-Path -LiteralPath $workflowPath)) {
    throw "The manual Development release workflow is missing."
}

$workflow = Get-Content -LiteralPath $workflowPath -Raw
$ciIdentity = Get-Content -LiteralPath (Join-Path $PSScriptRoot "../infra/terraform/ci-identity/main.tf") -Raw

# Parse every inline PowerShell program, not only selected string boundaries.
# GitHub expressions are substituted before parsing because the runner expands
# them before pwsh receives the generated script.
$workflowLines = [regex]::Split($workflow, "`r?`n")
$parsedPowerShellBlocks = 0
for ($lineIndex = 0; $lineIndex -lt $workflowLines.Count; $lineIndex++) {
    if ($workflowLines[$lineIndex] -notmatch '^(\s*)shell:\s*pwsh\s*$') { continue }
    $shellIndent = $Matches[1].Length
    $runIndex = $lineIndex + 1
    while ($runIndex -lt $workflowLines.Count -and
        $workflowLines[$runIndex] -notmatch '^(\s*)run:\s*\|\s*$') {
        if ($workflowLines[$runIndex] -match '^(\s*)-\s+') { break }
        $runIndex++
    }
    if ($runIndex -ge $workflowLines.Count -or $workflowLines[$runIndex] -notmatch '^(\s*)run:\s*\|\s*$') {
        throw "PowerShell workflow step at line $($lineIndex + 1) has no literal run block."
    }
    $runIndent = $Matches[1].Length
    if ($runIndent -ne $shellIndent) {
        throw "PowerShell shell/run indentation differs at line $($lineIndex + 1)."
    }
    $codeLines = [Collections.Generic.List[string]]::new()
    for ($codeIndex = $runIndex + 1; $codeIndex -lt $workflowLines.Count; $codeIndex++) {
        $line = $workflowLines[$codeIndex]
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $leading = $line.Length - $line.TrimStart().Length
            if ($leading -le $runIndent) { break }
        }
        $contentOffset = [Math]::Min($runIndent + 2, $line.Length)
        $codeLines.Add($line.Substring($contentOffset))
    }
    $code = ($codeLines -join "`n") -replace '\$\{\{.*?\}\}', 'GITHUB_EXPRESSION'
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if (@($parseErrors).Count -ne 0) {
        $messages = @($parseErrors | ForEach-Object { $_.Message }) -join '; '
        throw "Inline PowerShell syntax is invalid near workflow line $($lineIndex + 1): $messages"
    }
    $parsedPowerShellBlocks++
}
if ($parsedPowerShellBlocks -ne 14) {
    throw "Expected to parse exactly 14 inline PowerShell blocks; observed $parsedPowerShellBlocks."
}

$required = @(
    "workflow_dispatch:",
    "id-token: write",
    "github.ref == 'refs/heads/develop'",
    "environment: development-plan",
    "environment: development",
    "cancel-in-progress: false",
    "aws-actions/configure-aws-credentials@e6de054238d6b7531b4efff3b6587d9aade6a06c",
    "role-to-assume: `${{ vars.AWS_PLAN_ROLE_ARN }}",
    "role-to-assume: `${{ vars.AWS_DEPLOY_ROLE_ARN }}",
    "docker/setup-buildx-action@bb05f3f5519dd87d3ba754cc423b652a5edd6d2c",
    "--platform linux/arm64",
    "--tag `$target",
    "idea2strategy-dev/",
    "aws ecr describe-image-scan-findings",
    "docker image inspect",
    "linux/arm64",
    "AWS_RETRY_MODE: adaptive",
    "AWS_MAX_ATTEMPTS: '10'",
    "ECR image scan did not complete",
    "ECR image scan rejected",
    "terraform plan -parallelism=1 -out=deployment.tfplan",
    "terraform show -json deployment.tfplan",
    "assert-development-terraform-plan-safe.ps1",
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
    "VITE_OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID: `${{ vars.OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID }}",
    "VITE_OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID: `${{ vars.OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID }}",
    "OIDC build input is missing",
    "OIDC endpoint must use HTTPS",
    "OIDC redirect URI must use the service origin",
    "OIDC logout redirect parameter is invalid",
    "RBAC permission ID is invalid",
    "test-aws-deployment-prerequisites.ps1",
    "verify-development-database-bootstrap-receipt.ps1",
    "deploy-development-core-runtime.ps1",
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

$deployedVerifier = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'verify-deployed-development.ps1') -Raw
foreach ($token in @('$env:AWS_PROFILE = $AwsProfile', 'Remove-Item Env:AWS_PROFILE', '$previousAwsProfile')) {
    if (-not $deployedVerifier.Contains($token)) {
        throw "The deployed verifier must propagate and restore the selected AWS profile for Terraform: $token"
    }
}

foreach ($forbidden in @("aws-access-key-id", "aws-secret-access-key", "terraform apply -auto-approve", "docker build --platform linux/amd64", "application/vnd.oci.image.index.v1+json", "aws ecr start-image-scan", "idea2strategy-development", "create-invalidation", "s3 sync `"s3://`$env:FRONTEND_BUCKET/_releases")) {
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

if ($workflow -notmatch "(?s)operator_rbac_catalog_read_permission_id.*?OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID.*?operator_rbac_assignment_read_permission_id.*?OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID") {
    throw "The frontend RBAC permission IDs must be cross-checked against the Terraform runtime inputs."
}

if ($workflow -notmatch "(?s)configure-aws-credentials.*?test-aws-deployment-prerequisites\.ps1.*?-RequireRuntimeDatabaseSecrets.*?Create saved Terraform plan") {
    throw "The release plan must fail closed on populated runtime database secrets after AWS authentication and before Terraform planning."
}

if ($workflow -notmatch "(?s)Verify required deployment secrets.*?Verify exact database bootstrap receipt.*?Create saved Terraform plan") {
    throw "The release plan must verify the exact root-and-Flyway database bootstrap receipt before planning."
}

if ($workflow -notmatch "(?s)terraform plan -parallelism=1 -out=deployment\.tfplan.*?terraform show -json deployment\.tfplan.*?assert-development-terraform-plan-safe\.ps1.*?Archive exact plan") {
    throw "The saved Development plan must reject every delete or replacement before it can be archived or approved."
}

if ($workflow -notmatch "(?s)terraform apply -parallelism=1 deployment\.tfplan.*?deploy-development-core-runtime\.ps1.*?verify-deployed-development\.ps1") {
    throw "The exact Core image rollout and rollback guard must run after apply and before deployed verification."
}

if ($workflow -notmatch "(?s)Publish immutable ARM64 images.*?Wait for ECR security scans.*?Publish immutable frontend prefix") {
    throw "Every published runtime image must pass the ECR scan before frontend publication and planning."
}
if ($workflow -notmatch "(?s)Wait for ECR security scans.*?AWS_RETRY_MODE: adaptive.*?AWS_MAX_ATTEMPTS: '10'.*?describe-image-scan-findings") {
    throw "ECR scan reads must use bounded adaptive AWS retries."
}

if ($workflow -notmatch "(?s)findingSeverityCounts.*?CRITICAL.*?HIGH") {
    throw "The release scan gate must reject Critical and High findings."
}
if ($workflow.Contains('ECR image scan rejected $name:')) {
    throw 'The ECR scan gate must delimit a variable immediately followed by a colon.'
}
if (-not $workflow.Contains('ECR image scan rejected ${name}:')) {
    throw 'The ECR scan rejection message must use parser-safe variable delimiting.'
}

$planGatePath = Join-Path $PSScriptRoot "assert-development-terraform-plan-safe.ps1"
$receiptGatePath = Join-Path $PSScriptRoot "verify-development-database-bootstrap-receipt.ps1"
$coreRolloutPath = Join-Path $PSScriptRoot "deploy-development-core-runtime.ps1"
foreach ($scriptPath in @($planGatePath, $receiptGatePath, $coreRolloutPath)) {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "Release safety script is missing: $scriptPath" }
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if (@($parseErrors).Count -ne 0) { throw "Release safety script has invalid PowerShell syntax: $scriptPath" }
}

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("idea2strategy-plan-gate-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $safePlan = Join-Path $temporary "safe.json"
    $deletePlan = Join-Path $temporary "delete.json"
    $replacementPlan = Join-Path $temporary "replacement.json"
    '{"resource_changes":[{"address":"aws_ssm_parameter.safe","change":{"actions":["update"]}}]}' | Set-Content -NoNewline $safePlan
    '{"resource_changes":[{"address":"aws_s3_bucket.data","change":{"actions":["delete"]}}]}' | Set-Content -NoNewline $deletePlan
    '{"resource_changes":[{"address":"aws_instance.core","change":{"actions":["create","delete"]}}]}' | Set-Content -NoNewline $replacementPlan
    $safeResult = & $planGatePath -PlanJsonPath $safePlan | ConvertFrom-Json
    if ($safeResult.status -cne "passed" -or [int]$safeResult.delete_or_replace_count -ne 0) {
        throw "Safe Terraform plan fixture was rejected."
    }
    foreach ($unsafePlan in @($deletePlan, $replacementPlan)) {
        $rejected = $false
        try { & $planGatePath -PlanJsonPath $unsafePlan | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw "Delete or replacement Terraform plan fixture was accepted: $unsafePlan" }
    }
}
finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}

$receiptGate = Get-Content -LiteralPath $receiptGatePath -Raw
foreach ($requiredReceiptBoundary in @(
    'deployment-bootstrap/$RootSha/$($bundle.Digest)/receipt.json',
    'root_sha', 'bundle_sha256', 'migrations', 'secret_versions', 'AWSCURRENT', 'VersionId'
)) {
    if (-not $receiptGate.Contains($requiredReceiptBoundary)) {
        throw "Exact database bootstrap receipt gate is missing: $requiredReceiptBoundary"
    }
}

$coreRollout = Get-Content -LiteralPath $coreRolloutPath -Raw
foreach ($requiredRolloutBoundary in @(
    '/usr/local/sbin/idea2strategy-runtime-start',
    '/idea2strategy/dev/deployment/images/$service',
    "docker inspect --format '{{.Config.Image}}'",
    'CORE_RUNTIME_ROLLBACK_SUCCEEDED',
    'CORE_RUNTIME_ROLLED_OUT',
    '$env:AWS_PROFILE = $AwsProfile',
    '$previousAwsProfile'
)) {
    if (-not $coreRollout.Contains($requiredRolloutBoundary)) {
        throw "Core exact-image rollout/rollback gate is missing: $requiredRolloutBoundary"
    }
}

$bashExecutable = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path -LiteralPath $bashExecutable -PathType Leaf)) {
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($null -eq $bash) { throw "Bash is required to syntax-check the remote Core rollout program." }
    $bashExecutable = $bash.Source
}
$remoteMatch = [regex]::Match($coreRollout, "(?ms)\`$remoteScript = @'\r?\n(?<script>.*?)\r?\n'@\.Replace")
if (-not $remoteMatch.Success) { throw "Unable to extract the remote Core rollout program." }
$remoteEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteMatch.Groups['script'].Value))
& $bashExecutable -c "printf '%s' '$remoteEncoded' | base64 --decode | bash -n"
if ($LASTEXITCODE -ne 0) { throw "The remote Core rollout program has invalid Bash syntax." }

Write-Host "Development release workflow policy checks passed."
