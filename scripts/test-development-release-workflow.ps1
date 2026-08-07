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
if ($parsedPowerShellBlocks -ne 17) {
    throw "Expected to parse exactly 17 inline PowerShell blocks; observed $parsedPowerShellBlocks."
}

$required = @(
    "workflow_dispatch:",
    "force_rebuild_all_images:",
    "database_bootstrap_authorization:",
    "default: REUSE_EXISTING_RECEIPT",
    "BOOTSTRAP_DEVELOPMENT_DATABASE",
    "id-token: write",
    "actions: read",
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
    "aws s3 sync `"`$frontendRoot`"",
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
    "VITE_GOOGLE_OAUTH_CLIENT_ID: `${{ vars.VITE_GOOGLE_OAUTH_CLIENT_ID }}",
    "`$config.google_oauth_client_id -cne '`${{ vars.VITE_GOOGLE_OAUTH_CLIENT_ID }}'",
    "OIDC build input is missing",
    "OIDC endpoint must use HTTPS",
    "OIDC redirect URI must use the service origin",
    "OIDC logout redirect parameter is invalid",
    "RBAC permission ID is invalid",
    "test-aws-deployment-prerequisites.ps1",
    "verify-development-database-bootstrap-receipt.ps1",
    "invoke-development-database-bootstrap.ps1",
    "-ExecutionId '`${{ github.run_id }}-`${{ github.run_attempt }}'",
    "-ReclaimPriorExecution",
    "-AllowMissingReceipt",
    "-Execute -Confirm:`$false",
    "deploy-development-core-runtime.ps1",
    "-RuntimeRole trading",
    "trading_market_data_feed = 'sip'",
    "instrument_count -lt 500",
    "-RequireRuntimeDatabaseSecrets",
    "-RequireAlpacaSecrets",
    "verify-deployed-development.ps1",
    "github.event.inputs.apply_reviewed_plan == 'true'",
    "api.github.com/repos/`$env:GITHUB_REPOSITORY/actions/workflows/development-release.yml/runs",
    "runtime-image-manifest.json",
    "`$cacheScope = `"development-`$(`$image.name)-arm64`"",
    "--cache-from `"type=gha,scope=`$cacheScope`"",
    "--cache-to `"type=gha,mode=max,scope=`$cacheScope`"",
    "Reusing unchanged runtime image",
    "aws ecr batch-get-image",
    "aws ecr put-image",
    "Server-side reuse digest mismatch",
    "No reusable runtime image exists; rerun with force_rebuild_all_images enabled"
)

foreach ($token in $required) {
    if (-not $workflow.Contains($token)) {
        throw "Development release workflow is missing required boundary: $token"
    }
}

$immutableReleaseExpression = '${{ github.sha }}-${{ github.run_id }}'
if (([regex]::Matches($workflow, [regex]::Escape($immutableReleaseExpression))).Count -lt 5) {
    throw "Every release artifact, image tag, and release bundle must include the immutable GitHub run_id."
}
if ($workflow.Contains('${{ github.sha }}-${{ github.run_attempt }}')) {
    throw "A sha-plus-attempt identifier can collide across workflow runs; github.run_id is mandatory."
}
foreach ($attemptCoupledArtifact in @(
    'development-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}',
    'rc-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
)) {
    if ($workflow.Contains($attemptCoupledArtifact)) {
        throw "Build outputs must remain reusable when only a failed downstream job is rerun: $attemptCoupledArtifact"
    }
}
foreach ($artifactRecoveryBoundary in @(
    'retention-days: 7',
    'overwrite: true'
)) {
    if (-not $workflow.Contains($artifactRecoveryBoundary)) {
        throw "Build artifacts must survive approval delays and full-run retries: $artifactRecoveryBoundary"
    }
}
foreach ($imageRecoveryBoundary in @(
    'aws ecr list-images',
    "imageIds[?imageTag=='`$tag'].imageDigest | [0]",
    '$sourceImageId',
    '$existingImageId',
    'Immutable ECR image fingerprint collision',
    'Reusing verified immutable ECR image'
)) {
    if (-not $workflow.Contains($imageRecoveryBoundary)) {
        throw "Immutable ECR publication must be safely reusable after a downstream job retry: $imageRecoveryBoundary"
    }
}

foreach ($frontendPrefixBoundary in @(
    '$releaseMarkerKey = "_releases/$release/.release-content.sha256"',
    '$contentFingerprint',
    'Frontend release content fingerprint collision',
    '--delete',
    'Frontend asset sync failed',
    'Frontend index publication failed',
    'Frontend completion marker publication failed'
)) {
    if (-not $workflow.Contains($frontendPrefixBoundary)) {
        throw "Idempotent immutable frontend publication is missing: $frontendPrefixBoundary"
    }
}
if ($workflow.Contains('--max-items 1 --query KeyCount --output text')) {
    throw "AWS CLI text output returns None for an empty frontend prefix; parse the JSON response instead."
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

foreach ($developerGroupBoundary in @(
    'ManagedDevelopmentDeveloperGroupPolicies',
    '"iam:PutGroupPolicy"',
    '"iam:DeleteGroupPolicy"',
    'group/Idea2StrategyDevelopmentSsmUsers'
)) {
    if (-not $ciIdentity.Contains($developerGroupBoundary)) {
        throw "The deploy role cannot reconcile the Terraform-managed Development developer group policy: $developerGroupBoundary"
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

if ($workflow -notmatch "(?s)bootstrap-database:.*?github\.event\.inputs\.database_bootstrap_authorization == 'BOOTSTRAP_DEVELOPMENT_DATABASE'.*?environment: development.*?AWS_DEPLOY_ROLE_ARN.*?verify-development-database-bootstrap-receipt\.ps1.*?-AllowMissingReceipt.*?invoke-development-database-bootstrap\.ps1.*?-Execute.*?verify-development-database-bootstrap-receipt\.ps1.*?build:") {
    throw "An explicitly authorized, environment-gated bootstrap must create and re-verify a missing receipt before any release build."
}
if ($workflow -notmatch '(?s)bootstrap-database:.*?timeout-minutes:\s*75.*?build:') {
    throw "Database bootstrap job timeout must cover EC2, SSM, migration, credential staging, and cleanup budgets."
}

if ($workflow -match "(?s)bootstrap-database:.*?terraform -chdir=infra/terraform/environments/development init.*?build:") {
    throw "Database bootstrap must discover the applied AWS boundary without requiring the next release's Terraform state schema."
}

if ($workflow -notmatch "(?s)build:.*?needs: bootstrap-database.*?needs\.bootstrap-database\.result == 'skipped'.*?Build untrusted ARM64 runtime inputs without AWS credentials") {
    throw "The release build must wait for an authorized bootstrap while allowing the safe receipt-reuse path to skip it."
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

if ($workflow -notmatch "(?s)Verify required deployment secrets.*?Verify database bootstrap artifact receipt.*?Create saved Terraform plan") {
    throw "The release plan must verify the artifact-fingerprinted database bootstrap receipt before planning."
}

if ($workflow -notmatch "(?s)terraform plan -parallelism=1 -out=deployment\.tfplan.*?terraform show -json deployment\.tfplan.*?assert-development-terraform-plan-safe\.ps1.*?-AllowedReplacementAddresses.*?aws_ecs_task_definition\.pipeline\[0\].*?aws_instance\.service\[0\].*?aws_instance\.trading\[0\].*?Archive exact plan") {
    throw "The saved Development plan must reject destructive changes except the exact reviewed create-before-destroy runtime replacement allowlist."
}
if (-not $workflow.Contains('pwsh "$GITHUB_WORKSPACE/scripts/assert-development-terraform-plan-safe.ps1"')) {
    throw "The saved-plan safety gate must resolve its script from the GitHub workspace root."
}
if ($workflow.Contains('pwsh ../../../scripts/assert-development-terraform-plan-safe.ps1')) {
    throw "The saved-plan safety gate path resolves under infra/ instead of the repository root."
}
if ($workflow -notmatch '(?s)Archive exact plan in protected state storage.*?\.terraform/operator-pre-token\.zip.*?lambda_package_key.*?lambda_package_version.*?lambda_package_sha256.*?Download and verify exact reviewed plan.*?operator-pre-token\.zip.*?Lambda package hash mismatch.*?terraform init.*?Move-Item.*?\.terraform/operator-pre-token\.zip.*?terraform apply -parallelism=1 deployment\.tfplan') {
    throw "The reviewed saved plan must carry its exact versioned and hash-verified local Lambda package into the apply runner."
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

$coreRollout = Get-Content -LiteralPath $coreRolloutPath -Raw
foreach ($readinessBoundary in @(
    'ec2 wait instance-running',
    'describe-instance-information',
    'PingStatus',
    'cloud-init status --wait',
    '/opt/idea2strategy/bootstrap-complete',
    'systemctl is-active --quiet idea2strategy-runtime.service',
    'CORE_HOST_READY',
    'Invoke-SsmShellCommand',
    'ReadinessTimeoutSeconds'
)) {
    if (-not $coreRollout.Contains($readinessBoundary)) {
        throw "Core rollout is missing a bounded host-readiness boundary: $readinessBoundary"
    }
}
if ($coreRollout.IndexOf('CORE_HOST_READY') -gt $coreRollout.IndexOf('CORE_RUNTIME_ROLLED_OUT')) {
    throw "Core host readiness must complete before the runtime rollout command is constructed."
}

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("idea2strategy-plan-gate-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $safePlan = Join-Path $temporary "safe.json"
    $deletePlan = Join-Path $temporary "delete.json"
    $replacementPlan = Join-Path $temporary "replacement.json"
    $destroyFirstReplacementPlan = Join-Path $temporary "destroy-first-replacement.json"
    $unexplainedReplacementPlan = Join-Path $temporary "unexplained-replacement.json"
    $wrongTypeReplacementPlan = Join-Path $temporary "wrong-type-replacement.json"
    $identityDriftReplacementPlan = Join-Path $temporary "identity-drift-replacement.json"
    $deposedDeletePlan = Join-Path $temporary "deposed-delete.json"
    $orphanDeposedDeletePlan = Join-Path $temporary "orphan-deposed-delete.json"
    $currentDeletePlan = Join-Path $temporary "current-delete.json"
    $wrongTypeDeposedDeletePlan = Join-Path $temporary "wrong-type-deposed-delete.json"
    '{"resource_changes":[{"address":"aws_ssm_parameter.safe","change":{"actions":["update"]}}]}' | Set-Content -NoNewline $safePlan
    '{"resource_changes":[{"address":"aws_s3_bucket.data","change":{"actions":["delete"]}}]}' | Set-Content -NoNewline $deletePlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_instance","provider_name":"registry.terraform.io/hashicorp/aws","action_reason":"replace_because_cannot_update","change":{"actions":["create","delete"],"before":{"id":"i-old","instance_type":"t4g.medium","subnet_id":"subnet-a","iam_instance_profile":"profile-a","associate_public_ip_address":true,"vpc_security_group_ids":["sg-a"]},"after":{"instance_type":"t4g.medium","subnet_id":"subnet-a","iam_instance_profile":"profile-a","associate_public_ip_address":true,"vpc_security_group_ids":["sg-a"]}}}]}' | Set-Content -NoNewline $replacementPlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_instance","provider_name":"registry.terraform.io/hashicorp/aws","action_reason":"replace_because_cannot_update","change":{"actions":["delete","create"],"before":{"id":"i-old","instance_type":"t4g.medium","subnet_id":"subnet-a"},"after":{"instance_type":"t4g.medium","subnet_id":"subnet-a"}}}]}' | Set-Content -NoNewline $destroyFirstReplacementPlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_instance","provider_name":"registry.terraform.io/hashicorp/aws","change":{"actions":["create","delete"],"before":{"id":"i-old","instance_type":"t4g.medium","subnet_id":"subnet-a"},"after":{"instance_type":"t4g.medium","subnet_id":"subnet-a"}}}]}' | Set-Content -NoNewline $unexplainedReplacementPlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_s3_bucket","provider_name":"registry.terraform.io/hashicorp/aws","action_reason":"replace_because_cannot_update","change":{"actions":["create","delete"],"before":{"id":"bucket"},"after":{}}}]}' | Set-Content -NoNewline $wrongTypeReplacementPlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_instance","provider_name":"registry.terraform.io/hashicorp/aws","action_reason":"replace_because_cannot_update","change":{"actions":["create","delete"],"before":{"id":"i-old","instance_type":"t4g.medium","subnet_id":"subnet-a","iam_instance_profile":"profile-a","associate_public_ip_address":true,"vpc_security_group_ids":["sg-a"]},"after":{"instance_type":"m7g.large","subnet_id":"subnet-b","iam_instance_profile":"profile-b","associate_public_ip_address":false,"vpc_security_group_ids":["sg-b"]}}}]}' | Set-Content -NoNewline $identityDriftReplacementPlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_instance","provider_name":"registry.terraform.io/hashicorp/aws","change":{"actions":["no-op"],"before":{"id":"i-current"},"after":{"id":"i-current"}}},{"address":"aws_instance.service[0]","mode":"managed","type":"aws_instance","provider_name":"registry.terraform.io/hashicorp/aws","deposed":"deadbeef","change":{"actions":["delete"],"before":{"id":"i-old"},"after":null}}]}' | Set-Content -NoNewline $deposedDeletePlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_instance","provider_name":"registry.terraform.io/hashicorp/aws","deposed":"deadbeef","change":{"actions":["delete"],"before":{"id":"i-old"},"after":null}}]}' | Set-Content -NoNewline $orphanDeposedDeletePlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_instance","provider_name":"registry.terraform.io/hashicorp/aws","change":{"actions":["delete"],"before":{"id":"i-current"},"after":null}}]}' | Set-Content -NoNewline $currentDeletePlan
    '{"resource_changes":[{"address":"aws_instance.service[0]","mode":"managed","type":"aws_s3_bucket","provider_name":"registry.terraform.io/hashicorp/aws","deposed":"deadbeef","change":{"actions":["delete"],"before":{"id":"bucket"},"after":null}}]}' | Set-Content -NoNewline $wrongTypeDeposedDeletePlan
    $safeResult = & $planGatePath -PlanJsonPath $safePlan | ConvertFrom-Json
    if ($safeResult.status -cne "passed" -or [int]$safeResult.delete_or_replace_count -ne 0) {
        throw "Safe Terraform plan fixture was rejected."
    }
    foreach ($unsafePlan in @($deletePlan, $replacementPlan, $destroyFirstReplacementPlan, $unexplainedReplacementPlan)) {
        $rejected = $false
        try { & $planGatePath -PlanJsonPath $unsafePlan | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw "Delete or replacement Terraform plan fixture was accepted: $unsafePlan" }
    }
    $allowedReplacement = & $planGatePath `
        -PlanJsonPath $replacementPlan `
        -AllowedReplacementAddresses 'aws_instance.service[0]' |
        ConvertFrom-Json
    if ($allowedReplacement.status -cne "passed" -or
        [int]$allowedReplacement.allowed_replacement_count -ne 1 -or
        [int]$allowedReplacement.delete_or_replace_count -ne 0) {
        throw "The exact create-before-destroy replacement allowlist was not enforced."
    }
    $allowedDeposedDelete = & $planGatePath `
        -PlanJsonPath $deposedDeletePlan `
        -AllowedReplacementAddresses 'aws_instance.service[0]' |
        ConvertFrom-Json
    if ($allowedDeposedDelete.status -cne "passed" -or
        [int]$allowedDeposedDelete.allowed_deposed_delete_count -ne 1 -or
        [int]$allowedDeposedDelete.delete_or_replace_count -ne 0) {
        throw "An exact deposed object cleanup from an approved create-before-destroy runtime was not accepted."
    }
    foreach ($unsafeDeletePlan in @($orphanDeposedDeletePlan, $currentDeletePlan, $wrongTypeDeposedDeletePlan)) {
        $rejected = $false
        try {
            & $planGatePath `
                -PlanJsonPath $unsafeDeletePlan `
                -AllowedReplacementAddresses 'aws_instance.service[0]' |
                Out-Null
        }
        catch { $rejected = $true }
        if (-not $rejected) { throw "A non-deposed or wrong-type delete was accepted: $unsafeDeletePlan" }
    }
    foreach ($unsafeAllowedPlan in @($wrongTypeReplacementPlan, $identityDriftReplacementPlan)) {
        $rejected = $false
        try {
            & $planGatePath `
                -PlanJsonPath $unsafeAllowedPlan `
                -AllowedReplacementAddresses 'aws_instance.service[0]' |
                Out-Null
        }
        catch { $rejected = $true }
        if (-not $rejected) { throw "A replacement with a drifted resource identity was accepted: $unsafeAllowedPlan" }
    }
}
finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}

$receiptGate = Get-Content -LiteralPath $receiptGatePath -Raw
foreach ($requiredReceiptBoundary in @(
    'deployment-bootstrap/$RootSha/$($bundle.Digest)/receipt.json',
    'deployment-bootstrap/artifacts/$artifactFingerprint/receipt.json',
    'root_sha', 'bundle_sha256', 'policy_seed_sha256', 'scoring_seed_sha256',
    'migrations', 'secret_versions', 'AWSCURRENT', 'VersionId'
)) {
    if (-not $receiptGate.Contains($requiredReceiptBoundary)) {
        throw "Artifact-fingerprinted database bootstrap receipt gate is missing: $requiredReceiptBoundary"
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
