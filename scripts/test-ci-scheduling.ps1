$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$workflowPath = Join-Path $PSScriptRoot "../.github/workflows/ci.yml"
if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
    throw "The root CI workflow is missing."
}

$workflow = Get-Content -LiteralPath $workflowPath -Raw
if (-not $workflow.Contains("branches: [develop, main]")) {
    throw "Root CI must retain fast develop checks and run the full suite on main."
}

foreach ($required in @("schedule:", "workflow_dispatch:", "  classify:", "  ci-summary:")) {
    if (-not $workflow.Contains($required)) {
        throw "Root CI scheduling is missing: $required"
    }
}

if ($workflow -notmatch "(?ms)^  full-e2e:\r?\n    needs: classify\r?\n    if: needs\.classify\.outputs\.full_e2e == 'true'") {
    throw "Full E2E must be gated by the change-scope classifier."
}
if ($workflow -notmatch "(?ms)^  infrastructure-readiness:\r?\n    needs: classify\r?\n    if: needs\.classify\.outputs\.terraform == 'true'") {
    throw "Terraform must be gated by infrastructure/main/manual scope."
}
if ($workflow -match "github\.event_name == 'pull_request'.*full-e2e") {
    throw "Ordinary pull requests must not force the full E2E suite."
}

Write-Host "CI scheduling policy checks passed."
