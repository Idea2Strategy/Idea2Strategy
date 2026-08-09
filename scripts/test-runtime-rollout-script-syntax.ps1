[CmdletBinding()]
param(
    [string[]]$Source = @(
        "scripts/deploy-development-core-runtime.ps1",
        "scripts/backtest-worker-correlation-id.sh"
    ),
    [string]$Template = "infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# The rollout's real work is shell text assembled in PowerShell and handed to SSM, so a syntax error in
# it is invisible until a release is already applying changes to the Development environment — twenty
# minutes in, on the one shared environment. `bash -n` parses every embedded fragment here instead, in
# under a second, which is where a typo should be caught.

$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

$bash = $null
$candidates = @()
if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles "Git\bin\bash.exe") }
$onPath = Get-Command bash -ErrorAction SilentlyContinue
if ($null -ne $onPath) { $candidates += $onPath.Source }
foreach ($candidate in $candidates) {
    if (-not (Test-Path -LiteralPath $candidate)) { continue }
    $probe = (& $candidate -c "printf ok") 2>&1
    if ($LASTEXITCODE -eq 0 -and ([string]$probe).Trim() -ceq "ok") { $bash = $candidate; break }
}
if ($null -eq $bash) {
    Write-Warning "bash is unavailable, so no fragment was parsed. This check cannot substitute for one that runs."
    [pscustomobject]@{ status = "skipped"; reason = "bash unavailable" } | ConvertTo-Json -Compress
    exit 0
}

# Representative substitutions. They only have to make the fragment parseable — the placeholders are
# covered for content by scripts/test-runtime-rollout-coverage.ps1 and the wiring tests.
$substitutions = [ordered]@{
    "__AWS_REGION__"           = "ap-northeast-2"
    "__RUNTIME_SERVICES__"     = "backtest-worker"
    "__SETTLE_SECONDS__"       = "20"
    "__CLOUD_INIT_TIMEOUT__"   = "840"
    "__RUNTIME_ROLE__"         = "BACKTEST-WORKER"
    "__CORE_ORIGIN_READINESS__" = "true"
    "__RUNTIME_ROLE_PREPARE__" = "true"
}

$fragments = New-Object System.Collections.Generic.List[object]
foreach ($relative in $Source) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) { throw "Required file is missing: $relative" }
    $text = [IO.File]::ReadAllText($path) -replace "`r`n", "`n"
    if ($relative.EndsWith(".sh")) {
        $fragments.Add([pscustomobject]@{ source = $relative; label = "whole file"; body = $text })
        continue
    }
    # Single-quoted PowerShell here-strings are the only place shell text lives in these scripts.
    $matched = [regex]::Matches($text, "(?s)@'\n(.*?)\n'@")
    foreach ($match in $matched) {
        $body = $match.Groups[1].Value
        if (-not ($body -match "(?m)^\s*(set -|test |cd |for |if |echo |systemctl|docker|timeout|reconcile_)")) { continue }
        $line = ($text.Substring(0, $match.Index) -split "`n").Count
        $fragments.Add([pscustomobject]@{ source = $relative; label = "here-string at line $line"; body = $body })
    }
}

# The shipped backtest rollout is the main fragment with the canonical derivation and the reconcile
# function spliced into it, so that combination is what gets parsed rather than a stand-in.
$derivationFragment = $fragments | Where-Object { $_.source.EndsWith("backtest-worker-correlation-id.sh") } | Select-Object -First 1
$reconcileFragment = $fragments | Where-Object { $_.body -match "(?m)^reconcile_backtest_worker_correlation_id\(\)" } | Select-Object -First 1
if ($null -eq $derivationFragment -or $null -eq $reconcileFragment) {
    $failures.Add("The canonical derivation and its reconcile function must both be present; the rollout splices them together at run time.")
} else {
    $substitutions["__RUNTIME_ROLE_PREPARE__"] = $derivationFragment.body.TrimEnd("`n") + "`n" + $reconcileFragment.body
}

if ($fragments.Count -lt 4) {
    $failures.Add("Expected at least four shell fragments across $($Source -join ', '), found $($fragments.Count). The extraction is probably no longer finding them.")
}

# The host template is rendered the way Terraform renders it: variables are substituted while the
# dollar sign is still single, then `$$` collapses to `$`. Doing it in that order matters, because a
# shell expansion written `$${name}` becomes indistinguishable from a variable once it is collapsed.
$templatePath = Join-Path $root $Template
if (-not (Test-Path -LiteralPath $templatePath)) {
    $failures.Add("Required file is missing: $Template")
} else {
    $rendered = [IO.File]::ReadAllText($templatePath) -replace "`r`n", "`n"
    $rendered = [regex]::Replace($rendered, '(?<!\$)\$\{([a-z_][a-z0-9_]*)\}', 'rendered-$1')
    $rendered = $rendered.Replace('$$', '$')
    # No check for leftover `${name}` here: after the collapse an escaped shell expansion is spelled
    # exactly like an unrendered variable, so the two cannot be told apart. What is decidable is whether
    # the result parses, and whether the derivation copy escapes every dollar sign — the latter is
    # scripts/test-backtest-correlation-derivation.ps1's job.
    $fragments.Add([pscustomobject]@{ source = $Template; label = "rendered host template"; body = $rendered })
}

foreach ($fragment in $fragments) {
    $body = $fragment.body
    foreach ($key in $substitutions.Keys) { $body = $body.Replace($key, [string]$substitutions[$key]) }
    $leftover = [regex]::Matches($body, "__[A-Z_]+__")
    if ($leftover.Count -gt 0) {
        $failures.Add("$($fragment.source) $($fragment.label) uses unknown placeholders: $(($leftover | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ', '). Add them to this test's substitutions so the fragment can be parsed.")
        continue
    }
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ("idea2strategy-fragment-" + [Guid]::NewGuid().ToString("n") + ".sh")
    try {
        [IO.File]::WriteAllText($temporary, ($body + "`n"), [Text.UTF8Encoding]::new($false))
        $unix = ($temporary -replace '\\', '/')
        $output = & $bash -c "bash -n '$unix' 2>&1"
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("$($fragment.source) $($fragment.label) is not valid bash: $(($output | Out-String).Trim())")
        }
    }
    finally {
        Remove-Item -LiteralPath $temporary -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "Runtime rollout shell syntax check failed with $($failures.Count) finding(s)."
}

[pscustomobject]@{
    status    = "passed"
    fragments = $fragments.Count
    parsed_by = "bash -n"
} | ConvertTo-Json -Compress
