#!/usr/bin/env pwsh
# Every runtime role the host template knows about must be rolled out by the release.
#
# The defect this exists to prevent: `deploy-development-core-runtime.ps1` already rolls out and
# verifies images, comparing the running container's configured digest against the SSM parameter and
# rolling back when they disagree. It was simply never called for `backtest-worker`. A release
# therefore published that image to ECR, updated SSM, reported success, and left the running worker on
# the previous digest for two consecutive releases (root #454).
#
# A hardcoded list of roles would have the same hole: the role set grew and the call site did not. So
# the role set is derived from the one place that enumerates it — the `runtime_role` branches in the
# EC2 user-data template — and compared against the release workflow and the script's own ValidateSet.
#
# This check is read-only and needs no AWS access, so it runs in ordinary root CI.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$template = Join-Path $root 'infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl'
$workflow = Join-Path $root '.github/workflows/development-release.yml'
$deployScript = Join-Path $root 'scripts/deploy-development-core-runtime.ps1'

foreach ($required in @($template, $workflow, $deployScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file is missing: $required"
    }
}

$templateText = Get-Content -LiteralPath $template -Raw
$workflowText = Get-Content -LiteralPath $workflow -Raw
$deployText = Get-Content -LiteralPath $deployScript -Raw

# ---- derive the roles the host template distinguishes -------------------------------------------

$roles = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($match in [regex]::Matches($templateText, 'runtime_role\s*==\s*"([a-z-]+)"')) {
    [void]$roles.Add($match.Groups[1].Value)
}
if ($roles.Count -lt 3) {
    throw ("Derived only $($roles.Count) runtime role(s) from the host template " +
        "($($roles -join ', ')). That is fewer than this project has had since the backtest worker " +
        'was introduced, so the pattern is broken rather than the template. Fix this check.')
}

# The template names the core role `service`; the release script and the EC2 tag call it `core`. That
# disagreement is exactly the kind of thing that hides a missing role, so it is mapped explicitly
# rather than normalised away silently.
$scriptRoleFor = @{ service = 'core' }
$expectedScriptRoles = @($roles | ForEach-Object {
        if ($scriptRoleFor.ContainsKey($_)) { $scriptRoleFor[$_] } else { $_ }
    })

# ---- the script must accept every role ----------------------------------------------------------

$validateSet = [regex]::Match($deployText, '\[ValidateSet\(([^)]*)\)\]\[string\]\$RuntimeRole')
if (-not $validateSet.Success) {
    throw 'Could not find the $RuntimeRole ValidateSet in deploy-development-core-runtime.ps1.'
}
$acceptedRoles = @([regex]::Matches($validateSet.Groups[1].Value, '"([a-z-]+)"') |
        ForEach-Object { $_.Groups[1].Value })

foreach ($role in $expectedScriptRoles) {
    if ($acceptedRoles -notcontains $role) {
        throw ("The host template defines a '$role' runtime role but " +
            "deploy-development-core-runtime.ps1 does not accept it. Rolling out images is not " +
            'optional per role: without it a release publishes an image the role never runs.')
    }
}

# ---- the release must invoke the script for every role ------------------------------------------

$invocations = @([regex]::Matches(
        $workflowText,
        'deploy-development-core-runtime\.ps1(?<args>(?:[^\r\n]|\r?\n\s{10,})*)'))
if ($invocations.Count -eq 0) {
    throw 'The release workflow never invokes deploy-development-core-runtime.ps1.'
}

$invokedRoles = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($invocation in $invocations) {
    $roleArgument = [regex]::Match($invocation.Groups['args'].Value, '-RuntimeRole\s+([a-z-]+)')
    # No -RuntimeRole means the script default, which is core.
    [void]$invokedRoles.Add($(if ($roleArgument.Success) { $roleArgument.Groups[1].Value } else { 'core' }))
}

$missing = @($expectedScriptRoles | Where-Object { -not $invokedRoles.Contains($_) })
if ($missing.Count -gt 0) {
    throw ("The release does not roll out to $($missing.Count) runtime role(s): " +
        "$($missing -join ', '). The workflow invokes: $($invokedRoles -join ', '). " +
        'A role the release skips keeps running whatever digest it booted with, and the release ' +
        'still reports success — which is the defect recorded in root #454.')
}

# ---- the rollout must fail closed --------------------------------------------------------------

# The remote script compares the configured image against the SSM digest and restores the previous
# compose file when they disagree. Losing either half would turn a failed rollout into a silent pass.
foreach ($guard in @(
        'test "$configured" = "$expected"',
        'rollback()')) {
    if (-not $deployText.Contains($guard)) {
        throw "The rollout lost its fail-closed guard: $guard"
    }
}

# An empty desired-zero group is a legitimate pass, but it must say so rather than resemble a rollout
# that happened. Both halves are asserted so the branch cannot decay into a silent skip.
foreach ($marker in @('no-running-instance', 'Resolve-BacktestWorkerInstanceId')) {
    if (-not $deployText.Contains($marker)) {
        throw "The backtest worker rollout is missing its desired-zero handling: $marker"
    }
}

Write-Output ("Runtime rollout coverage: roles $($expectedScriptRoles -join ', ') " +
    "are all accepted by the script and invoked by the release.")
