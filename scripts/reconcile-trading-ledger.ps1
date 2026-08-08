<#
.SYNOPSIS
    거래 원장 대사를 돌리고 판정한다 (INT09).

.DESCRIPTION
    `db/reconciliation/trading-ledger.sql` 을 실행하고 결과를 판정해 JSON 으로 낸다.

    SQL 을 사람이 직접 돌려도 되지만, 그 출력은 검사당 실패 수만 보여 준다. 원장이 비어 있으면
    모든 실패 수가 0 이므로 눈으로 보면 통과처럼 읽힌다. 이 스크립트가 하는 일의 절반은 그
    오독을 막는 것이다 -- 거래가 하나도 없으면 `passed` 가 아니라 `vacuous` 를 낸다.

    나머지 절반은 이것을 복원본에 돌릴 수 있게 하는 것이다. 원장 균형은 DEFERRABLE 트리거가
    커밋 시점에만 검사하므로, 스냅샷에서 복원한 데이터의 균형은 검증된 적이 없다. INT09 의
    복구 드릴은 복원한 인스턴스에 이 스크립트를 겨누어야 의미가 있다.

.PARAMETER DatabaseUrl
    psql 연결 문자열. 생략하면 DATABASE_URL, 그다음 PIPELINE_WORKER_DATABASE_URL 을 쓴다.

.PARAMETER InContainer
    로컬 조합의 postgres 컨테이너 안에서 psql 을 실행한다. psql 을 따로 설치하지 않은
    기계에서 쓴다.

.PARAMETER AllowEmpty
    거래가 없어도 실패로 보지 않는다. 원장이 비어 있는 것이 정상인 환경(새로 구축한 DB)에서
    파이프라인이 이 스크립트를 돌릴 때만 쓴다. 판정은 여전히 `vacuous` 로 남는다.

.EXAMPLE
    .\scripts\reconcile-trading-ledger.ps1 -InContainer
    .\scripts\reconcile-trading-ledger.ps1 -DatabaseUrl $env:DATABASE_URL
#>
[CmdletBinding()]
param(
    [string]$DatabaseUrl,
    [switch]$InContainer,
    [switch]$AllowEmpty,
    [string]$ContainerName = 'idea2strategy-postgres',
    [string]$ContainerUser = 'idea2strategy',
    [string]$ContainerDatabase = 'idea2strategy'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$sqlPath = Join-Path $root 'db/reconciliation/trading-ledger.sql'
if (-not (Test-Path -LiteralPath $sqlPath -PathType Leaf)) {
    throw "대사 SQL 이 없다: $sqlPath"
}

function Invoke-Sql {
    if ($InContainer) {
        # 컨테이너 안으로 파일을 넣지 않고 표준입력으로 흘린다. docker exec 는 -i 가 없으면
        # 표준입력을 전달하지 않는다 -- 그것 때문에 조용히 0 행이 나오는 것을 이미 겪었다.
        $sql = Get-Content -LiteralPath $sqlPath -Raw -Encoding UTF8
        $output = $sql | & docker exec -i $ContainerName psql -U $ContainerUser -d $ContainerDatabase -v ON_ERROR_STOP=1 -qAt -F '|' 2>&1
    } else {
        $psql = Get-Command psql -ErrorAction SilentlyContinue
        if (-not $psql) {
            throw 'psql 이 PATH 에 없다. -InContainer 를 쓰거나 클라이언트를 설치한다.'
        }
        $output = & $psql.Source $DatabaseUrl -v ON_ERROR_STOP=1 -qAt -F '|' -f $sqlPath 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        ($output | Out-String) | Out-Host
        throw '대사 질의가 실패했다. 위 출력이 이유다.'
    }
    return $output
}

if (-not $InContainer) {
    if (-not $DatabaseUrl) { $DatabaseUrl = $env:DATABASE_URL }
    if (-not $DatabaseUrl) { $DatabaseUrl = $env:PIPELINE_WORKER_DATABASE_URL }
    if (-not $DatabaseUrl) {
        throw '연결 문자열이 없다. -DatabaseUrl 을 주거나 DATABASE_URL 을 설정하거나 -InContainer 를 쓴다.'
    }
}

$rows = @(Invoke-Sql | Where-Object { $_ -match '\|' })
if ($rows.Count -eq 0) { throw '대사 질의가 아무 행도 돌려주지 않았다.' }

$checks = [ordered]@{}
$samples = [ordered]@{}
$failed = @()
foreach ($row in $rows) {
    $parts = $row -split '\|', 3
    if ($parts.Count -lt 2) { continue }
    $name = $parts[0].Trim()
    $count = 0
    if (-not [int]::TryParse($parts[1].Trim(), [ref]$count)) { continue }
    $detail = if ($parts.Count -ge 3) { $parts[2].Trim() } else { '' }

    if ($name -like 'sample_*') {
        $samples[$name] = $count
        continue
    }
    $checks[$name] = $count
    if ($count -ne 0) {
        # 상세를 잘라 낸다. 실패가 수천 건이면 전문을 찍어도 읽히지 않고, 첫 몇 개만 있어도
        # 어디를 볼지 정하는 데 충분하다.
        $trimmed = if ($detail.Length -gt 400) { $detail.Substring(0, 400) + ' …' } else { $detail }
        $failed += [ordered]@{ check = $name; failures = $count; detail = $trimmed }
    }
}

$expected = @(
    'transaction_balanced', 'bot_balanced', 'no_orphan_entries', 'entries_have_accounts',
    'amounts_positive', 'reversals_target_exists', 'reversals_mirror', 'currency_agrees',
    'entry_hash_present', 'no_entries_after_close', 'partition_agrees'
)
$missing = @($expected | Where-Object { -not $checks.Contains($_) })
if ($missing.Count -gt 0) {
    # 검사가 빠졌는데 통과라고 말하는 것이 가장 나쁜 결과다. SQL 이 바뀌었거나 파싱이
    # 어긋났다는 뜻이므로 판정하지 않는다.
    throw ('대사 결과에 검사가 빠졌다: ' + ($missing -join ', ') +
        '. db/reconciliation/trading-ledger.sql 과 이 스크립트의 목록이 어긋났다.')
}

$transactionCount = if ($samples.Contains('sample_transaction_count')) { $samples['sample_transaction_count'] } else { 0 }
$entryCount = if ($samples.Contains('sample_entry_count')) { $samples['sample_entry_count'] } else { 0 }

$status = if ($failed.Count -gt 0) { 'failed' }
    elseif ($transactionCount -eq 0 -or $entryCount -eq 0) { 'vacuous' }
    else { 'passed' }

$result = [ordered]@{
    status              = $status
    checks_run          = $checks.Count
    checks_failed       = $failed.Count
    transaction_count   = $transactionCount
    entry_count         = $entryCount
    bot_count           = if ($samples.Contains('sample_bot_count')) { $samples['sample_bot_count'] } else { 0 }
    failures            = $failed
}
if ($status -eq 'vacuous') {
    $result['note'] = ('원장이 비어 있다. 검사 ' + $checks.Count +
        '개가 모두 0 을 돌려주었지만 그것은 대사가 통과한 것이 아니라 대사할 것이 없다는 뜻이다. ' +
        '봇이 주문을 내고 체결이 기록된 뒤(INT03·INT04) 다시 돌린다.')
}
$result | ConvertTo-Json -Compress -Depth 4

if ($status -eq 'failed') { exit 1 }
if ($status -eq 'vacuous' -and -not $AllowEmpty) { exit 2 }
exit 0
