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

$fullE2eGate = "github.event_name == 'pull_request' || github.ref == 'refs/heads/main'"
if ($workflow -notmatch "(?ms)^  three-lane-feature-e2e:\r?\n    if: $([regex]::Escape($fullE2eGate))\r?\n") {
    throw "The full three-lane E2E suite must run before merge or on main, not after every develop merge."
}

Write-Host "CI scheduling policy checks passed."
