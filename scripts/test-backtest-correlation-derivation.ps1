[CmdletBinding()]
param(
    [string]$Derivation = "scripts/backtest-worker-correlation-id.sh",
    [string]$Template = "infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl",
    [string]$Rollout = "scripts/deploy-development-core-runtime.ps1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# BACKTEST_WORKER_CORRELATION_ID has to be derived identically by two callers that cannot share code
# at runtime: user data stamps it when an instance boots, and the rollout re-stamps an instance that
# booted before the contract existed. scripts/backtest-worker-correlation-id.sh is the one definition;
# the template carries a copy because Terraform cannot include a file, and this test is what keeps the
# copy honest. A drift here would give a rebooted instance and a rolled-out instance different
# correlation ids for the same host, which is exactly the correlation the field exists to provide.

$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]
function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $failures.Add($Message) }
}
function Read-TextLf([string]$RelativePath) {
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { throw "Required file is missing: $RelativePath" }
    return ([IO.File]::ReadAllText($path) -replace "`r`n", "`n")
}

$derivationText = (Read-TextLf $Derivation).TrimEnd("`n")
$templateText = Read-TextLf $Template
$rolloutText = Read-TextLf $Rollout

$beginMarker = "# BEGIN idea2strategy-backtest-worker-correlation-id"
$endMarker = "# END idea2strategy-backtest-worker-correlation-id"
$beginCount = ([regex]::Matches($templateText, [regex]::Escape($beginMarker))).Count
$endCount = ([regex]::Matches($templateText, [regex]::Escape($endMarker))).Count
Assert-That ($beginCount -eq 1) "The template must delimit the derivation copy with exactly one begin marker, found $beginCount."
Assert-That ($endCount -eq 1) "The template must delimit the derivation copy with exactly one end marker, found $endCount."

if ($beginCount -eq 1 -and $endCount -eq 1) {
    $lines = $templateText -split "`n"
    $begin = [Array]::FindIndex($lines, [Predicate[string]] { param($line) $line.StartsWith($beginMarker) })
    $end = [Array]::FindIndex($lines, [Predicate[string]] { param($line) $line.StartsWith($endMarker) })
    Assert-That ($end -gt $begin) "The end marker must follow the begin marker in the template."
    if ($end -gt $begin) {
        # Terraform doubles every dollar sign it must not interpolate, so the copy is compared after
        # that one mechanical transform is undone. Anything else that differs is drift.
        $raw = ($lines[($begin + 1)..($end - 1)]) -join "`n"
        $copied = $raw.Replace('$$', '$')
        Assert-That ($copied -ceq $derivationText) `
            "The derivation copy in the template no longer matches $Derivation. Regenerate it instead of editing one side."
        # Every dollar sign in the copy has to be doubled. One that is not would make Terraform read the
        # shell expansion as a template variable and fail the render — or worse, substitute into it.
        Assert-That (-not ($raw.Replace('$$', "`0").Contains('$'))) `
            "The copied derivation leaves an unescaped dollar sign; Terraform would interpolate it."
    }
    $callLine = 'backtest_worker_correlation_id="$(idea2strategy_backtest_worker_correlation_id "$instance_id")"'
    Assert-That ($templateText.Contains($callLine)) `
        "The template must stamp the value by calling the shared function, not by repeating the derivation."
    Assert-That ($templateText.Contains("BACKTEST_WORKER_CORRELATION_ID=`$backtest_worker_correlation_id")) `
        "The template must write BACKTEST_WORKER_CORRELATION_ID from the derived value."
    Assert-That ($templateText.Contains("BACKTEST_WORKER_ID=`$instance_id")) `
        "BACKTEST_WORKER_ID must stay the instance id; the two identifiers mean different things."
}

# The rollout reads the canonical file rather than carrying its own copy, so there is nothing to drift
# on that side. What has to hold is that it still reads it, still reconciles, and still replaces the
# container — a restart would keep the environment the container was created with.
Assert-That ($rolloutText.Contains('Join-Path $PSScriptRoot "backtest-worker-correlation-id.sh"')) `
    "The rollout must read the canonical derivation from $Derivation instead of duplicating it."
Assert-That ($rolloutText.Contains("reconcile_backtest_worker_correlation_id")) `
    "The rollout must reconcile BACKTEST_WORKER_CORRELATION_ID on the running instance."
Assert-That ($rolloutText.Contains("docker compose --project-name idea2strategy rm --stop --force backtest-worker")) `
    "A corrected value only reaches the process when the container is replaced, not restarted."
Assert-That ($rolloutText.Contains('__RUNTIME_ROLE_PREPARE__')) `
    "The reconcile step must be injected into the remote rollout script."
Assert-That ($rolloutText.Contains('runtime_settled')) `
    "The rollout must fail a crash-looping container instead of accepting a point-in-time liveness read."

# Git Bash comes first deliberately: on a Windows developer machine `bash` on PATH is often the WSL
# shim, which fails to start when no distribution is installed. Each candidate is smoke tested rather
# than trusted, so the test never reports a pass it did not actually execute.
$bash = $null
$bashCandidates = @()
if ($env:ProgramFiles) { $bashCandidates += (Join-Path $env:ProgramFiles "Git\bin\bash.exe") }
$onPath = Get-Command bash -ErrorAction SilentlyContinue
if ($null -ne $onPath) { $bashCandidates += $onPath.Source }
foreach ($candidate in $bashCandidates) {
    if (-not (Test-Path -LiteralPath $candidate)) { continue }
    $probe = (& $candidate -c "printf ok") 2>&1
    if ($LASTEXITCODE -eq 0 -and ([string]$probe).Trim() -ceq "ok") {
        $bash = Get-Command $candidate
        break
    }
}
if ($null -eq $bash) {
    Write-Warning "bash is unavailable, so the derived value itself was not executed. The comparison above still ran."
} else {
    # Pinned so a change to the namespace string or the layout cannot pass quietly: the derivation is
    # an identity contract, and every event already published under a value has to keep resolving to
    # the same host.
    $expected = "b915ae58-9bfd-5c36-8a36-f28a590403d2"
    $instanceId = "i-07a6870a8c4c199dc"
    $harness = Join-Path ([IO.Path]::GetTempPath()) ("idea2strategy-correlation-" + [Guid]::NewGuid().ToString("n") + ".sh")
    try {
        [IO.File]::WriteAllText($harness, ($derivationText + "`n"), [Text.UTF8Encoding]::new($false))
        $unixHarness = ($harness -replace '\\', '/')
        # Diagnostics stay inside bash. A native command writing to stderr becomes a terminating error
        # under this script's preferences, and the refusal case is supposed to write to stderr.
        $observed = & $bash.Source -c ". '$unixHarness'; idea2strategy_backtest_worker_correlation_id '$instanceId' 2>/dev/null"
        Assert-That ($LASTEXITCODE -eq 0) "Executing the derivation for $instanceId failed with exit $LASTEXITCODE."
        Assert-That (([string]$observed).Trim() -ceq $expected) `
            "The derivation for $instanceId produced '$observed' instead of the pinned '$expected'."

        $rejected = & $bash.Source -c ". '$unixHarness'; idea2strategy_backtest_worker_correlation_id '' >/dev/null 2>&1; echo EXIT=`$?"
        Assert-That (([string]$rejected).Trim() -ceq "EXIT=1") `
            "The derivation must refuse an empty instance id rather than emit a value: $rejected"
    }
    finally {
        Remove-Item -LiteralPath $harness -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "Backtest worker correlation id derivation check failed with $($failures.Count) finding(s)."
}

[pscustomobject]@{
    status              = "passed"
    canonical           = $Derivation
    template_copy       = "matches"
    rollout_reconciles  = $true
    derivation_executed = ($null -ne $bash)
} | ConvertTo-Json -Compress
