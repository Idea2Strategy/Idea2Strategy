#!/usr/bin/env pwsh
# Every property backend-batch reads without a default must be supplied by batch-secret.env.
#
# Why this exists as its own check: the string assertions in test-runtime-deployment-wiring.ps1
# only prove that the keys someone already thought of are present. They cannot notice a *new*
# @Value("${...}") with no default, which is exactly how backend-batch shipped unable to start —
# SesNotificationEmailConfiguration read identity.crypto.email-encryption-key, nothing supplied it,
# and the context refresh was cancelled before any scheduled job ran. Nothing failed loudly: the
# container exited 1 and, because it carries `profiles: [manual]`, no health check watched it.
#
# So this check derives the requirement from the batch source instead of restating it. It reads
# what the application actually asks for and compares that against what the host writes.
#
# It needs the backend submodule checked out. The root CI job that validates Terraform runs with
# submodules: false, so there this prints that it skipped and exits 0 — it is a local and
# submodule-aware guard, not a gate. The concrete regression it was written for is *also* pinned as
# a string in test-runtime-deployment-wiring.ps1, which does run in that job. Both are deliberate:
# the string check gates, this one finds what the string check cannot know to look for.

[CmdletBinding()]
param(
    # Both default to this checkout. They are overridable so this script can be pointed at a
    # worktree's template while reading sources from a checkout that has submodules populated —
    # `git worktree add` does not populate them, and that is the ordinary way this repository is
    # worked on.
    [string] $BatchSource,
    [string] $Template
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$batchSource = if ($BatchSource) { $BatchSource } else { Join-Path $root 'backend/apps/backend-batch/src/main' }
$template = if ($Template) { $Template } else { Join-Path $root 'infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl' }

if (-not (Test-Path $template)) {
    throw "Development host template is missing: $template"
}

if (-not (Test-Path $batchSource)) {
    Write-Host "skipped: backend submodule is not checked out ($batchSource)."
    Write-Host "         Run this where submodules are present; the terraform CI job checks out none."
    exit 0
}

# ---- what the application asks for -------------------------------------------------------------

$java = Get-ChildItem -Path $batchSource -Filter *.java -Recurse -File
if ($java.Count -eq 0) {
    throw "No backend-batch sources found under $batchSource — refusing to report a vacuous pass."
}

# @Value("${some.property}") requires a value. @Value("${some.property:fallback}") does not.
# The property name stops at the first ':' because that is where Spring's default begins.
$required = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($file in $java) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in [regex]::Matches($text, '@Value\(\s*"\$\{([^}"]+)\}"')) {
        $placeholder = $match.Groups[1].Value
        if ($placeholder.Contains(':')) { continue }
        [void]$required.Add($placeholder)
    }
}

if ($required.Count -eq 0) {
    throw "Parsed $($java.Count) backend-batch sources and found no mandatory @Value placeholder. " +
          "That is more likely a broken pattern in this script than a batch with no configuration."
}

# application.yaml can satisfy a property itself, with or without an environment fallback.
$resources = Join-Path $batchSource 'resources'
$declaredInYaml = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
if (Test-Path $resources) {
    foreach ($yaml in Get-ChildItem -Path $resources -Include 'application*.yaml', 'application*.yml' -File) {
        $path = New-Object System.Collections.Generic.List[string]
        foreach ($line in Get-Content -LiteralPath $yaml.FullName) {
            if ($line -notmatch '^(\s*)([A-Za-z0-9_.-]+):(.*)$') { continue }
            $depth = [int]([math]::Floor($Matches[1].Length / 2))
            $key = $Matches[2]
            $value = $Matches[3].Trim()
            while ($path.Count -gt $depth) { $path.RemoveAt($path.Count - 1) }
            $path.Add($key)
            if ($value -ne '') { [void]$declaredInYaml.Add(($path -join '.')) }
        }
    }
}

# ---- what the host supplies --------------------------------------------------------------------

$userData = Get-Content -LiteralPath $template -Raw
$supplied = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($match in [regex]::Matches($userData, '(?m)^\s*append_(?:env_value|json_field) "\$(?:batch_secret_env|refreshed_batch_env)" ([A-Z0-9_]+)')) {
    [void]$supplied.Add($match.Groups[1].Value)
}

if ($supplied.Count -eq 0) {
    throw "Found no batch-secret.env assignment in the host template. The template shape changed; " +
          "fix this script rather than letting it pass on an empty set."
}

# Spring relaxed binding: identity.crypto.email-encryption-key <- IDENTITY_CRYPTO_EMAIL_ENCRYPTION_KEY
function ConvertTo-EnvName([string] $property) {
    return ($property -replace '[.\-]', '_').ToUpperInvariant()
}

$missing = New-Object System.Collections.Generic.List[string]
foreach ($property in $required) {
    if ($declaredInYaml.Contains($property)) { continue }
    $env = ConvertTo-EnvName $property
    if (-not $supplied.Contains($env)) {
        $missing.Add("$property (expected $env in batch-secret.env)")
    }
}

if ($missing.Count -gt 0) {
    throw ("backend-batch would fail to start: $($missing.Count) mandatory property is not supplied " +
           "by the development host.`n  " + ($missing -join "`n  ") +
           "`nAdd it to the batch_secret_env block in $template, and to the refresh block so a " +
           "credential rotation does not drop it again.")
}

Write-Host "backend-batch runtime properties: $($required.Count) mandatory placeholder(s) checked, all supplied."
