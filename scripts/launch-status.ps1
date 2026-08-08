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
            check         = if ($item.PSObject.Properties.Name -contains 'check') { [string]$item.check } else { '' }
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

function Test-TaskComplete($Task) {
    switch ($Task.kind) {
        'manual' {
            if ([string]::IsNullOrWhiteSpace($Task.evidence)) { return $null }
            return (Test-Path -LiteralPath (Join-Path $root $Task.evidence))
        }
        default {
            if ([string]::IsNullOrWhiteSpace($Task.check)) { return $null }
            $repoRoot = if ($Task.repository -eq '.') { $root } else { Join-Path $root $Task.repository }
            if (-not (Test-Path -LiteralPath $repoRoot)) { return $null }
            Push-Location $repoRoot
            try {
                $result = Invoke-Expression $Task.check
                if ($null -eq $result) { return $null }
                return [bool]$result
            } catch {
                # 검사 자체가 실패하면 모르는 것이다. done 으로 넘기지 않는다.
                return $null
            } finally {
                Pop-Location
            }
        }
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
Write-Host ''
