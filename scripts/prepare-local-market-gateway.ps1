<#
.SYNOPSIS
    로컬 조합의 market-gateway 가 요구하는 세 산출물을 만든다.

.DESCRIPTION
    게이트웨이는 fail-closed 다. 종목 매핑, 공급자 권리 증빙, 그리고 그 둘을 체크섬으로
    묶는 materialization 수령증이 없으면 기동을 거부한다. AWS 에서는
    scripts/aws/development-database-bootstrap.sh 가 같은 세 파일을 만들어 S3 에 올린다.
    이 스크립트는 그 절차의 로컬 대응이며, 같은 SQL 과 같은 JSON 형태를 쓴다.

    산출물(기본 .harness/local/market-gateway/, git 이 무시하는 경로):
      instruments.json          symbol -> instrument id. DB 의 시장 카탈로그에서 뽑는다.
      alpaca-sip-rights.json    provider/feed/verifiedAt/expiresAt.
      materialization.properties  위 두 파일의 SHA-256 을 담은 수령증.

    자격증명은 다루지 않는다. ALPACA_API_KEY 와 ALPACA_API_SECRET 은 .env.docker 로만
    들어가며 이 스크립트도, 저장소도 그 값을 갖지 않는다.

.PARAMETER DatabaseUrl
    psql 이 받는 연결 문자열. 생략하면 DATABASE_URL 을 쓴다.

.PARAMETER OutputRoot
    산출 디렉터리. 생략하면 <repo>/.harness/local/market-gateway.

.PARAMETER RightsDays
    권리 증빙 유효 기간(일). AWS 와 같은 30 일이 기본이다.

.EXAMPLE
    .\scripts\prepare-local-market-gateway.ps1
#>
[CmdletBinding()]
param(
    [string]$DatabaseUrl,
    [string]$OutputRoot,
    [int]$RightsDays = 30
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
if (-not $DatabaseUrl) { $DatabaseUrl = $env:DATABASE_URL }
if (-not $DatabaseUrl) {
    throw '연결 문자열이 없다. -DatabaseUrl 을 주거나 DATABASE_URL 을 설정한다. 로컬 조합 기본값 예: postgresql://idea2strategy:...@localhost:5432/idea2strategy'
}
if (-not $OutputRoot) { $OutputRoot = Join-Path $root '.harness/local/market-gateway' }

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    throw 'psql 이 PATH 에 없다. postgres 컨테이너 안에서 실행하거나 클라이언트를 설치한다.'
}

if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}
$mappingPath = Join-Path $OutputRoot 'instruments.json'
$rightsPath = Join-Path $OutputRoot 'alpaca-sip-rights.json'
$receiptPath = Join-Path $OutputRoot 'materialization.properties'

# --------------------------------------------------------------------------
# 1. 종목 매핑. SQL 은 AWS 부트스트랩(scripts/aws/development-database-bootstrap.sh:530)
#    과 동일해야 한다 — 두 환경이 다른 종목 집합을 보면 라이브와 백테스트가 갈린다.
# --------------------------------------------------------------------------
$mappingSql = @'
WITH eligible AS (
  SELECT symbols.symbol, instruments.id
  FROM market_data.instruments instruments
  JOIN market_data.instrument_symbols symbols ON symbols.instrument_id = instruments.id
  WHERE instruments.asset_type::text IN ('STOCK','ETF')
    AND btrim(instruments.currency_code) = 'USD'
    AND (instruments.listed_at IS NULL OR instruments.listed_at <= CURRENT_DATE)
    AND (instruments.delisted_at IS NULL OR instruments.delisted_at > CURRENT_DATE)
    AND symbols.effective_from <= now()
    AND (symbols.effective_to IS NULL OR symbols.effective_to > now())
)
SELECT COALESCE(jsonb_object_agg(symbol, id ORDER BY symbol), '{}'::jsonb)::text FROM eligible;
'@

$mappingJson = (& $psql.Source $DatabaseUrl -X -qAt -v ON_ERROR_STOP=1 -c (($mappingSql -replace '\s+', ' ').Trim()) 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $mappingJson.StartsWith('{')) {
    throw "종목 매핑 조회에 실패했다: $mappingJson"
}
[System.IO.File]::WriteAllText($mappingPath, $mappingJson, [System.Text.UTF8Encoding]::new($false))

$instrumentCount = ([pscustomobject](ConvertFrom-Json $mappingJson)).PSObject.Properties.Name.Count
# 게이트웨이의 minimum-instrument-count 가 500 이다. 미달이면 기동하지 않으므로 여기서 멈춘다.
if ($instrumentCount -lt 500) {
    throw "종목이 $instrumentCount 개다. 게이트웨이는 500 개 이상을 요구한다. 시장 카탈로그를 먼저 시드한다(scripts/invoke-development-market-catalog-bootstrap.ps1 참고)."
}

# --------------------------------------------------------------------------
# 2. 권리 증빙. AWS 부트스트랩(:558-563)과 같은 네 필드다.
# --------------------------------------------------------------------------
$verifiedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$expiresAt = [DateTime]::UtcNow.AddDays($RightsDays).ToString('yyyy-MM-ddTHH:mm:ssZ')
$rightsJson = ([ordered]@{
    provider   = 'alpaca'
    feed       = 'sip'
    verifiedAt = $verifiedAt
    expiresAt  = $expiresAt
} | ConvertTo-Json -Compress)
[System.IO.File]::WriteAllText($rightsPath, $rightsJson, [System.Text.UTF8Encoding]::new($false))

# --------------------------------------------------------------------------
# 3. 수령증. MaterializationReceipt.verify 가 요구하는 정확한 형태다:
#    contract, schema-version, artifact-count, 그리고 artifact.<n>.{id,sha256,local-path}.
#    local-path 는 **컨테이너 안에서 보이는 경로**여야 한다 — 검증이 그 경로를 그대로
#    열어보고, @Value 로 주입된 경로와 같은지까지 비교한다.
# --------------------------------------------------------------------------
function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

$containerRoot = '/etc/market-gateway'
$lines = @(
    '# scripts/prepare-local-market-gateway.ps1 이 생성한다. 손으로 고치지 않는다.',
    'contract=i2s.materialization-receipt',
    'schema-version=1',
    'artifact-count=2',
    'artifact.0.id=instrument-mapping',
    "artifact.0.sha256=$(Get-Sha256 $mappingPath)",
    "artifact.0.local-path=$containerRoot/instruments.json",
    'artifact.1.id=provider-rights',
    "artifact.1.sha256=$(Get-Sha256 $rightsPath)",
    "artifact.1.local-path=$containerRoot/alpaca-sip-rights.json"
)
[System.IO.File]::WriteAllLines($receiptPath, $lines, [System.Text.UTF8Encoding]::new($false))

([ordered]@{
    output_root      = $OutputRoot
    container_root   = $containerRoot
    instrument_count = $instrumentCount
    rights_expires_at = $expiresAt
    files            = @('instruments.json', 'alpaca-sip-rights.json', 'materialization.properties')
    next_step        = 'ALPACA_API_KEY 와 ALPACA_API_SECRET 을 .env.docker 에 넣고 .\scripts\dev.ps1 up -WithBackend 를 실행한다.'
    status           = 'passed'
}) | ConvertTo-Json -Compress
