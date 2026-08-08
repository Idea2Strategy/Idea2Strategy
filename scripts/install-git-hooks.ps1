<#
.SYNOPSIS
    추적되는 .githooks 를 이 체크아웃의 훅 경로로 지정한다.

.DESCRIPTION
    가드를 git 쪽에 두는 이유는 도구가 섞여 있기 때문이다. Claude Code 훅은 Claude
    세션에만 걸리고 Codex 세션에는 걸리지 않는다. git 훅은 편집기·에이전트와 무관하게
    모두에게 걸린다.

    .git/hooks 에 손으로 넣은 훅은 그 체크아웃에만 있고 커밋되지 않는다. 실제로 이
    저장소의 pre-push 가 그런 상태였다 — 한 사람의 기계에만 있었다. core.hooksPath 를
    추적되는 디렉터리로 옮기면 clone 한 사람 전부가 같은 가드를 받는다.

    멱등하다. 여러 번 실행해도 안전하다.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$hooksDirectory = Join-Path $root '.githooks'
if (-not (Test-Path -LiteralPath $hooksDirectory -PathType Container)) {
    throw "추적되는 훅 디렉터리가 없다: $hooksDirectory"
}

$current = ''
try { $current = (& git -C $root config --local core.hooksPath) } catch { $current = '' }
if ($null -eq $current) { $current = '' }
$current = "$current".Trim()

if ($current -ne '.githooks') {
    & git -C $root config --local core.hooksPath '.githooks'
    if ($LASTEXITCODE -ne 0) { throw 'core.hooksPath 를 설정하지 못했다.' }
}

# 손으로 넣어 두었던 훅이 남아 있으면 이제 실행되지 않는다. 조용히 사라진 것처럼
# 보이지 않도록 알려준다.
$legacy = @()
foreach ($name in @('pre-commit', 'pre-push', 'commit-msg')) {
    $path = Join-Path $root ".git/hooks/$name"
    if (Test-Path -LiteralPath $path) { $legacy += $name }
}

$hooks = @(Get-ChildItem -LiteralPath $hooksDirectory -File | Select-Object -ExpandProperty Name)
([ordered]@{
    hooks_path = '.githooks'
    installed  = $hooks
    superseded_local_hooks = $legacy
    status = 'passed'
}) | ConvertTo-Json -Compress
