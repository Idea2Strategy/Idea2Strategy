<#
.SYNOPSIS
    출시 준비 작업의 완료·준비·차단 상태를 계산한다.

.DESCRIPTION
    docs/launch-readiness-tasks.yaml 을 읽어 각 작업의 완료 조건을 실제로 검사하고,
    의존성을 풀어 담당자별로 "지금 할 수 있는 것"을 고른다.

    상태를 손으로 관리하지 않는 것이 요점이다. 완료 여부는 검사 결과에서 나오므로
    누가 체크박스를 켜는 것을 잊어도 틀리지 않는다.

    검사가 판정할 수 없으면 done 이라고 하지 않고 unknown 이라고 한다. 모르는 것을
    끝났다고 말하는 쪽이 훨씬 비싸다.

.PARAMETER Owner
    한 담당자로 좁힌다. kcrmin | pjy008008 | hjcud

.PARAMETER Json
    기계가 읽을 형태로 출력한다.

.EXAMPLE
    ./scripts/launch-status.ps1
    ./scripts/launch-status.ps1 -Owner hjcud
#>
[CmdletBinding()]
param(
    [string]$Owner,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$ledgerPath = Join-Path $root 'docs/launch-readiness-tasks.json'
if (-not (Test-Path -LiteralPath $ledgerPath)) {
    throw "작업 원장이 없다: $ledgerPath"
}

# 원장이 JSON 인 이유: PowerShell 5.1 에 YAML 파서가 없다. 손으로 파싱한 첫 시도는
# 조용히 틀렸다. ConvertFrom-Json 은 표준이고, Codex·Python·Node 도 같은 파일을 읽는다.
function Read-Ledger([string]$Path) {
    $document = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $tasks = @()
    foreach ($item in $document.tasks) {
        $tasks += [ordered]@{
            id            = [string]$item.id
            title         = [string]$item.title
            owner         = [string]$item.owner
            repository    = if ($item.repository) { [string]$item.repository } else { '.' }
            depends_on    = @($item.depends_on)
            kind          = if ($item.kind) { [string]$item.kind } else { 'manual' }
            check         = if ($item.PSObject.Properties.Name -contains 'check') { $item.check } else { $null }
            evidence      = if ($item.PSObject.Properties.Name -contains 'evidence') { [string]$item.evidence } else { '' }
            blocks_reason = if ($item.PSObject.Properties.Name -contains 'blocks_reason') { [string]$item.blocks_reason } else { '' }
        }
    }
    return $tasks
}

# --------------------------------------------------------------------------
# db 검사용. DATABASE_URL 이 없으면 판정하지 않는다.
# --------------------------------------------------------------------------
function Invoke-CanonicalQuery([string]$Sql) {
    $url = $env:DATABASE_URL
    if ([string]::IsNullOrWhiteSpace($url)) { $url = $env:PIPELINE_WORKER_DATABASE_URL }
    if ([string]::IsNullOrWhiteSpace($url)) { return $null }
    $psql = Get-Command psql -ErrorAction SilentlyContinue
    if (-not $psql) { return $null }
    $flat = ($Sql -replace '\s+', ' ').Trim()
    $out = & $psql.Source $url -tAc $flat 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $text = ($out | Out-String).Trim()
    $parsed = 0
    if ([int]::TryParse($text, [ref]$parsed)) { return $parsed }
    return $text
}

# 원장의 검사는 선언적이다. 특정 셸의 코드를 실행하지 않으므로 다른 실행기가 같은 판정을
# 낼 수 있고, 원장 내용이 곧 실행 코드가 되는 위험도 없다.
# 판정할 수 없으면 $false 가 아니라 $null 을 돌려준다 — 모르는 것을 끝났다고 말하는 쪽이
# 훨씬 비싸다.
function Test-Check($Check, [string]$Base) {
    if ($null -eq $Check) { return $null }
    $kind = [string]$Check.kind

    if ($kind -eq 'all') {
        $verdict = $true
        foreach ($inner in @($Check.checks)) {
            $one = Test-Check $inner $Base
            if ($null -eq $one) { return $null }
            if (-not $one) { $verdict = $false }
        }
        return $verdict
    }

    if ($kind -eq 'sql-equals') {
        $value = Invoke-CanonicalQuery ([string]$Check.sql)
        if ($null -eq $value) { return $null }
        return ([string]$value -eq [string]$Check.expected)
    }

    if ($kind -eq 'glob-contains') {
        $matched = @(Get-ChildItem -Path (Join-Path $Base ([string]$Check.glob)) -File -ErrorAction SilentlyContinue)
        if ($matched.Count -eq 0) { return $false }
        foreach ($file in $matched) {
            if (Select-String -LiteralPath $file.FullName -Pattern ([string]$Check.pattern) -SimpleMatch -Quiet) {
                return $true
            }
        }
        return $false
    }

    $path = Join-Path $Base ([string]$Check.path)
    switch ($kind) {
        'file-exists' { return (Test-Path -LiteralPath $path) }
        'file-contains' {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
            return [bool](Select-String -LiteralPath $path -Pattern ([string]$Check.pattern) -SimpleMatch -Quiet)
        }
        'file-not-contains' {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
            return -not (Select-String -LiteralPath $path -Pattern ([string]$Check.pattern) -SimpleMatch -Quiet)
        }
        default { return $null }
    }
}

function Test-TaskComplete($Task) {
    if ($Task.kind -eq 'manual') {
        if ([string]::IsNullOrWhiteSpace($Task.evidence)) { return $null }
        return (Test-Path -LiteralPath (Join-Path $root $Task.evidence))
    }
    if ($null -eq $Task.check) { return $null }
    $repoRoot = if ($Task.repository -eq '.') { $root } else { Join-Path $root $Task.repository }
    if (-not (Test-Path -LiteralPath $repoRoot)) { return $null }
    try {
        return Test-Check $Task.check $repoRoot
    } catch {
        return $null
    }
}

$tasks = Read-Ledger $ledgerPath
if ($tasks.Count -eq 0) { throw "작업 원장에서 작업을 읽지 못했다." }

$state = @{}
foreach ($task in $tasks) {
    $complete = Test-TaskComplete $task
    $state[$task.id] = [ordered]@{
        id = $task.id; title = $task.title; owner = $task.owner
        repository = $task.repository; depends_on = @($task.depends_on)
        kind = $task.kind; blocks_reason = $task.blocks_reason
        complete = $complete
    }
}

foreach ($id in @($state.Keys)) {
    $entry = $state[$id]
    $blockers = @()
    foreach ($dep in $entry.depends_on) {
        if (-not $state.ContainsKey($dep)) { continue }
        if ($state[$dep].complete -ne $true) { $blockers += $dep }
    }
    $entry['blocked_by'] = $blockers
    $entry['status'] = if ($entry.complete -eq $true) { 'done' }
        elseif ($blockers.Count -gt 0) { 'blocked' }
        elseif ($entry.complete -eq $null) { 'ready-unverified' }
        else { 'ready' }
}

$ordered = @($tasks | ForEach-Object { $state[$_.id] })
if ($Owner) { $ordered = @($ordered | Where-Object { $_.owner -eq $Owner }) }

if ($Json) {
    $ordered | ConvertTo-Json -Depth 6
    exit 0
}

$mark = @{ 'done' = '[x]'; 'ready' = '[>]'; 'ready-unverified' = '[?]'; 'blocked' = '[ ]' }
Write-Host ''
Write-Host '출시 준비 상태  ([x] 완료  [>] 지금 가능  [?] 가능하나 검사 미확정  [ ] 차단)' -ForegroundColor Cyan
Write-Host ''
foreach ($entry in $ordered) {
    $line = "{0} {1,-7} {2,-11} {3}" -f $mark[$entry.status], $entry.id, $entry.owner, $entry.title
    $colour = switch ($entry.status) {
        'done' { 'DarkGray' } 'ready' { 'Green' } 'ready-unverified' { 'Yellow' } default { 'DarkYellow' }
    }
    Write-Host $line -ForegroundColor $colour
    # 완료된 작업의 선행은 알려줄 것이 없다. 끝난 일에 "대기" 를 붙이면 읽는 사람이 혼란스럽다.
    if ($entry.status -ne 'done' -and $entry.blocked_by.Count -gt 0) {
        Write-Host ("         대기: " + ($entry.blocked_by -join ', ')) -ForegroundColor DarkYellow
    }
}

Write-Host ''
Write-Host '담당자별 다음 작업' -ForegroundColor Cyan
foreach ($who in @('kcrmin', 'pjy008008', 'hjcud')) {
    if ($Owner -and $who -ne $Owner) { continue }
    $mine = @($ordered | Where-Object { $_.owner -eq $who -and $_.status -in @('ready', 'ready-unverified') })
    if ($mine.Count -gt 0) {
        $next = $mine[0]
        Write-Host ("  {0,-11} → {1}  {2}" -f $who, $next.id, $next.title) -ForegroundColor Green
    } else {
        $waiting = @($ordered | Where-Object { $_.owner -eq $who -and $_.status -eq 'blocked' })
        if ($waiting.Count -gt 0) {
            $first = $waiting[0]
            $owners = @($first.blocked_by | ForEach-Object { if ($state.ContainsKey($_)) { "$_($($state[$_].owner))" } else { $_ } })
            Write-Host ("  {0,-11} → 지금 할 것이 없다. {1} 이(가) {2} 완료를 기다린다." -f $who, $first.id, ($owners -join ', ')) -ForegroundColor DarkYellow
        } else {
            Write-Host ("  {0,-11} → 남은 작업이 없다." -f $who) -ForegroundColor DarkGray
        }
    }
}
Write-Host ''
Write-Host 'DATABASE_URL 이 없으면 데이터 관련 작업(2.4·2.5)은 [?] 로 남는다. 조합을 띄우고 다시 실행한다.' -ForegroundColor DarkGray

# 한 담당자로 좁혀 실행했고 할 일이 있으면, 그 작업을 지시하는 프롬프트를 그대로 찍어 준다.
# `/start-work` 슬래시 명령은 도구와 버전에 따라 없을 수 있다(Claude 는 저장소의
# .claude/skills 를, Codex 는 사용자 홈의 프롬프트를 읽고, 둘 다 설치가 선행되어야 한다).
# 이 출력은 아무 설치도 요구하지 않으므로 어느 도구에서든 붙여넣기만 하면 된다.
if ($Owner) {
    $ready = @($ordered | Where-Object { $_.owner -eq $Owner -and $_.status -in @('ready', 'ready-unverified') })
    if ($ready.Count -gt 0) {
        $task = $ready[0]
        Write-Host ''
        Write-Host '─────────── 아래를 그대로 복사해 에이전트에 붙여넣는다 (설치 불필요) ───────────' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "docs/launch-readiness-plan.md 의 §$($task.id) 를 수행해줘. 담당자는 $Owner 다."
        Write-Host ''
        Write-Host 'AGENTS.md 의 "Launch work loop" 절을 먼저 읽고 그대로 따른다. 내 소유'
        Write-Host "리포지터리($($task.repository)) 밖의 파일은 수정하지 않는다. feature 브랜치에서"
        Write-Host '작업하고 해당 develop 으로 PR 을 연다. 완료 판정은'
        Write-Host "powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/launch-status.ps1"
        Write-Host "-Owner $Owner 가 §$($task.id) 를 [x] 로 보고할 때다."
        Write-Host ''
        Write-Host '────────────────────────────────────────────────────────────────────────────' -ForegroundColor Cyan
    }
}
Write-Host ''
