$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$workflowPath = Join-Path $PSScriptRoot "../.github/workflows/development-frontend-release.yml"
$planGatePath = Join-Path $PSScriptRoot "assert-development-frontend-plan-safe.ps1"

if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
    throw "The manual Development frontend release workflow is missing."
}
if (-not (Test-Path -LiteralPath $planGatePath -PathType Leaf)) {
    throw "The Development frontend-only Terraform plan gate is missing."
}

$workflow = Get-Content -LiteralPath $workflowPath -Raw

if ($workflow -match '(?m)^\s*pwsh .* \+\s+-PlanJsonPath') {
    throw "The frontend plan safety gate invocation contains patch-marker text instead of Bash continuations."
}

foreach ($required in @(
    "name: Development frontend release",
    "workflow_dispatch:",
    "release_authorization:",
    "DEPLOY_DEVELOPMENT_FRONTEND",
    "apply_reviewed_plan:",
    "if ('`${{ github.ref }}' -cne 'refs/heads/develop')",
    "concurrency:",
    "group: development-release",
    "cancel-in-progress: false",
    "id-token: write",
    "submodules: recursive",
    "Confirm exact root frontend pointer",
    "pnpm typecheck",
    "pnpm exec vitest run",
    "pnpm build",
    "assert-production-bundle.mjs",
    "VITE_OPERATOR_OIDC_ENABLED: 'true'",
    "OIDC build input is missing",
    "OIDC endpoint must use HTTPS",
    "RBAC permission ID is invalid",
    "environment: development-plan",
    "role-to-assume: `${{ vars.AWS_PLAN_ROLE_ARN }}",
    "Publish immutable frontend prefix before planning",
    "_releases/",
    "release-content.sha256",
    "public,max-age=31536000,immutable",
    "--cache-control 'no-store'",
    "/idea2strategy/dev/deployment/images/",
    "Current runtime image parameter is missing or invalid",
    "frontend_release_id",
    "terraform plan -out=frontend.tfplan",
    "assert-development-frontend-plan-safe.ps1",
    "Archive exact frontend plan in protected state storage",
    "environment: development",
    "role-to-assume: `${{ vars.AWS_DEPLOY_ROLE_ARN }}",
    "terraform apply frontend.tfplan",
    "aws cloudfront wait distribution-deployed",
    "Verified immutable frontend release"
)) {
    if (-not $workflow.Contains($required)) {
        throw "The Development frontend release workflow is missing: $required"
    }
}

foreach ($forbiddenTrigger in @("push", "pull_request", "schedule")) {
    if ($workflow -match "(?m)^\s{2}$([regex]::Escape($forbiddenTrigger)):\s*$") {
        throw "The frontend release must not have an automatic $forbiddenTrigger trigger."
    }
}

foreach ($forbiddenBoundary in @(
    "docker build",
    "docker buildx",
    "aws ecr",
    "BOOTSTRAP_DEVELOPMENT_DATABASE",
    "verify-development-database-bootstrap-receipt.ps1",
    "invoke-development-database-bootstrap.ps1",
    "deploy-development-core-runtime.ps1",
    "RuntimeRole trading",
    "rollback"
)) {
    if ($workflow.IndexOf($forbiddenBoundary, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "The frontend-only workflow crossed a forbidden release boundary: $forbiddenBoundary"
    }
}

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
if ($parsedPowerShellBlocks -lt 6) {
    throw "Expected at least six inline PowerShell safety blocks; observed $parsedPowerShellBlocks."
}

$gateTokens = $null
$gateParseErrors = $null
[Management.Automation.Language.Parser]::ParseFile($planGatePath, [ref]$gateTokens, [ref]$gateParseErrors) | Out-Null
if (@($gateParseErrors).Count -ne 0) {
    throw "The frontend-only Terraform plan gate has invalid PowerShell syntax."
}

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("idea2strategy-frontend-plan-gate-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $releaseId = "0123456789abcdef0123456789abcdef01234567-12345"
    $safePlan = Join-Path $temporary "safe.json"
    $unrelatedPlan = Join-Path $temporary "unrelated.json"
    $deletePlan = Join-Path $temporary "delete.json"
    $driftPlan = Join-Path $temporary "drift.json"
    $missingPlan = Join-Path $temporary "missing.json"

    @"
{"resource_changes":[
  {"address":"aws_cloudfront_distribution.frontend[0]","mode":"managed","type":"aws_cloudfront_distribution","provider_name":"registry.terraform.io/hashicorp/aws","change":{"actions":["update"],"before":{"enabled":true,"is_ipv6_enabled":true,"comment":"frontend","default_root_object":"index.html","price_class":"PriceClass_200","aliases":["example.com"],"web_acl_id":null,"origin":[{"origin_id":"frontend-s3","origin_path":"/_releases/old"},{"origin_id":"core-ec2","origin_path":""}],"default_cache_behavior":[{"target_origin_id":"frontend-s3"}],"ordered_cache_behavior":[{"path_pattern":"/api/*"}],"restrictions":[{"geo_restriction":[{"restriction_type":"none"}]}],"viewer_certificate":[{"minimum_protocol_version":"TLSv1.2_2021"}]},"after":{"enabled":true,"is_ipv6_enabled":true,"comment":"frontend","default_root_object":"index.html","price_class":"PriceClass_200","aliases":["example.com"],"web_acl_id":null,"origin":[{"origin_id":"frontend-s3","origin_path":"/_releases/$releaseId"},{"origin_id":"core-ec2","origin_path":""}],"default_cache_behavior":[{"target_origin_id":"frontend-s3"}],"ordered_cache_behavior":[{"path_pattern":"/api/*"}],"restrictions":[{"geo_restriction":[{"restriction_type":"none"}]}],"viewer_certificate":[{"minimum_protocol_version":"TLSv1.2_2021"}]}}},
  {"address":"aws_ssm_parameter.frontend_release[0]","mode":"managed","type":"aws_ssm_parameter","provider_name":"registry.terraform.io/hashicorp/aws","change":{"actions":["update"],"before":{"name":"/idea2strategy/dev/deployment/frontend-release","type":"String","value":"old"},"after":{"name":"/idea2strategy/dev/deployment/frontend-release","type":"String","value":"$releaseId"}}},
  {"address":"terraform_data.public_release_guard[0]","mode":"managed","type":"terraform_data","provider_name":"registry.terraform.io/hashicorp/terraform","change":{"actions":["update"],"before":{"input":{"frontend_release_id":"old"},"output":{"frontend_release_id":"old"}},"after":{"input":{"frontend_release_id":"$releaseId"},"output":null},"after_unknown":{"output":true}}}
]}
"@ | Set-Content -LiteralPath $safePlan -NoNewline

    $safe = & $planGatePath -PlanJsonPath $safePlan -ExpectedReleaseId $releaseId | ConvertFrom-Json
    if ($safe.status -cne "passed" -or [int]$safe.resource_change_count -ne 3) {
        throw "The exact frontend-only Terraform plan fixture was rejected."
    }

    $safeJson = Get-Content -LiteralPath $safePlan -Raw
    $safeJson.Replace('aws_ssm_parameter.frontend_release[0]', 'aws_instance.service[0]') |
        Set-Content -LiteralPath $unrelatedPlan -NoNewline
    $safeJson.Replace('"actions":["update"]', '"actions":["delete"]') |
        Set-Content -LiteralPath $deletePlan -NoNewline
    $safeJson.Replace('"after":{"enabled":true', '"after":{"enabled":false') |
        Set-Content -LiteralPath $driftPlan -NoNewline
    '{"resource_changes":[]}' | Set-Content -LiteralPath $missingPlan -NoNewline

    foreach ($unsafePlan in @($unrelatedPlan, $deletePlan, $driftPlan, $missingPlan)) {
        $rejected = $false
        try { & $planGatePath -PlanJsonPath $unsafePlan -ExpectedReleaseId $releaseId | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw "An unsafe frontend Terraform plan fixture was accepted: $unsafePlan" }
    }
}
finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Development frontend release workflow policy checks passed."
