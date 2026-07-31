# Idea2Strategy 과거 시장 데이터 초기 적재기 구현 명세

상태: 구현 입력 문서
대상: 새로 작성할 독립 Python 프로젝트
작성 기준일: 2026-07-30
대상 환경: Idea2Strategy Development, AWS Seoul(`ap-northeast-2`)

## 1. 문서의 목적

이 문서는 다른 대화나 저장소를 참조하지 않고도 새 Python 적재기를 구현할 수 있도록 필요한 요구사항을 모두 정의한다.

구현자는 이 문서만으로 다음 결과물을 만들어야 한다.

1. 로컬 PC에서 실행되는 Python CLI 애플리케이션
2. Alpaca Historical Market Data API 수집기
3. 미국 정규장 필터와 1시간·4시간·일봉 파생기
4. 고정 스키마의 Parquet 작성기
5. Private Amazon S3 불변 객체 업로더
6. Private Amazon RDS for PostgreSQL 매니페스트 등록기
7. 실패 후 재개·검증·정합성 복구 기능
8. Flyway용 초기 Market Data 스키마 SQL
9. 단위·통합 테스트와 실행 문서

이 구현은 `Idea2Strategy/market_hist_script`의 코드를 복사하거나 import하지 않는다. 해당 저장소는 구현 의존성이 아니며, 새 프로젝트는 독립적으로 작성한다.

## 2. 확정된 목표

### 2.1 데이터 범위

- 공급자: Alpaca
- Feed: SIP
- 자산: 확정된 S&P 500 지원 종목과 주요 미국 ETF
- 세션: 미국 정규장만
- 기간: 운영자가 명시하는 10년 범위
- 원본 해상도: 30분봉
- 가격 조정:
  - `raw`: 기업행사 미조정
  - `all`: Alpaca가 지원하는 모든 기업행사 조정
- 파생 해상도:
  - 1시간봉
  - 4시간봉
  - 일봉
- 영속 저장:
  - 대량 OHLCV 본문: S3 Parquet
  - 종목·데이터셋·객체·품질·계보·실행 상태: RDS PostgreSQL

### 2.2 실행 위치와 연결 방식

- Python 프로그램은 초기 적재 기간 동안 로컬 PC에서 실행한다.
- S3는 항상 Private으로 유지한다.
- RDS는 항상 Private으로 유지한다.
- 로컬 Python은 AWS CLI 임시 로그인 자격 증명으로 S3를 호출한다.
- 로컬 Python은 AWS Systems Manager 포트 포워딩을 통해 Private RDS에 연결한다.
- 데이터 적재를 위해 S3 Block Public Access 또는 RDS Public Accessibility를 해제하지 않는다.
- Alpaca, AWS, DB 자격 증명을 소스·설정 파일·로그·Parquet·S3 메타데이터·RDS 업무 테이블에 저장하지 않는다.

### 2.3 추후 Spring 연동

- 초기 적재는 Python이 직접 S3와 RDS에 기록한다.
- 추후 Spring은 동일한 RDS 스키마에서 `AVAILABLE` 매니페스트를 조회한다.
- Spring과 백테스트 Worker는 RDS에 저장된 버킷·객체 키·S3 Version ID·SHA-256을 사용해 정확한 Parquet 객체를 읽는다.
- Spring 도입 시 과거 데이터를 다시 업로드하거나 임시 테이블에서 이관하지 않아야 한다.
- DB 스키마는 처음부터 Flyway 이력으로 관리한다.

## 3. 비목표

초기 버전에서 다음은 구현하지 않는다.

- 실시간 SIP WebSocket 수집
- 틱·Trade·Quote·NBBO 저장
- 장전·장후·Overnight 세션 저장
- 자동 주문 또는 모의투자
- 백테스트 실행
- Spring API 호출
- S3 공개 읽기 또는 공개 쓰기
- RDS 공개 접속
- Kubernetes, ECS, Lambda, SQS, Kafka
- 종목별 10년짜리 단일 Parquet 파일
- 누락 봉 임의 생성, 가격 보간, 마지막 가격 채우기
- 기존 S3 객체 덮어쓰기
- 적재 실패 시 S3 객체 자동 삭제

## 4. 구현 원칙

아래 문장에서 `MUST`는 필수, `SHOULD`는 특별한 이유가 없으면 따라야 함을 뜻한다.

1. 대량 시장 데이터 행은 S3에만 저장해야 한다(MUST).
2. RDS에는 데이터 관계와 무결성을 확인하는 메타데이터만 저장해야 한다(MUST).
3. S3 Prefix 목록 조회 결과를 공식 데이터 목록으로 취급하면 안 된다(MUST).
4. RDS의 `AVAILABLE` 매니페스트만 공식 사용 가능한 데이터로 취급해야 한다(MUST).
5. 모든 공식 S3 객체는 버킷, 객체 키, Version ID, SHA-256으로 식별해야 한다(MUST).
6. 같은 객체 키에 다른 바이트를 덮어쓰면 안 된다(MUST).
7. RAW와 ALL, 해상도, 기간, Revision을 섞으면 안 된다(MUST).
8. 누락되거나 의심스러운 데이터를 정상 데이터로 조용히 대체하면 안 된다(MUST).
9. 재실행은 이미 성공한 파티션을 중복 생성하지 않아야 한다(MUST).
10. 10년 전체 데이터를 한 DataFrame에 올리면 안 된다(MUST).
11. 외부 API·S3·RDS 오류는 재시도 가능 오류와 영구 오류로 구분해야 한다(MUST).
12. 모든 시간 구간은 시작 포함·끝 미포함인 `[start, end)`로 내부 표현해야 한다(MUST).
13. 로그에는 Secret, Access Key, DB 비밀번호, 전체 연결 문자열을 출력하면 안 된다(MUST).
14. 실제 쓰기 명령은 기본 Dry Run이어야 하며 `--execute`가 있을 때만 쓰기를 수행해야 한다(MUST).

## 5. 권장 프로젝트 구조

다음 구조로 새 프로젝트를 생성한다.

```text
idea2strategy-market-loader/
├── pyproject.toml
├── uv.lock
├── README.md
├── .gitignore
├── .env.example
├── config.example.yaml
├── docker-compose.test.yaml
├── db/
│   └── migration/
│       └── V001__market_data_initial_schema.sql
├── src/
│   └── market_loader/
│       ├── __init__.py
│       ├── __main__.py
│       ├── cli.py
│       ├── config.py
│       ├── logging.py
│       ├── errors.py
│       ├── model/
│       │   ├── bar.py
│       │   ├── catalog.py
│       │   ├── partition.py
│       │   └── status.py
│       ├── alpaca/
│       │   ├── client.py
│       │   ├── pagination.py
│       │   └── mapper.py
│       ├── calendar/
│       │   └── xnys.py
│       ├── pipeline/
│       │   ├── planner.py
│       │   ├── collector.py
│       │   ├── normalizer.py
│       │   ├── resampler.py
│       │   ├── validator.py
│       │   ├── parquet_writer.py
│       │   ├── publisher.py
│       │   ├── registrar.py
│       │   └── reconciler.py
│       ├── storage/
│       │   ├── local_staging.py
│       │   └── s3.py
│       └── database/
│           ├── connection.py
│           ├── repositories.py
│           └── transactions.py
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── fixtures/
│   └── contract/
└── scripts/
    ├── start-rds-tunnel.ps1
    └── stop-rds-tunnel.ps1
```

## 6. 기술 기준

### 6.1 Python과 패키지

- Python 3.12
- 패키지·가상환경 관리: `uv`
- CLI: `Typer`
- HTTP: `httpx`
- 설정 검증: `pydantic-settings`
- AWS: `boto3`
- PostgreSQL: `psycopg[binary,pool]` 3.x
- 컬럼형 처리: `pyarrow`
- 거래소 일정: `exchange-calendars`
- 재시도: `tenacity`
- 구조화 로그: Python 표준 `logging` + JSON Formatter
- 테스트: `pytest`, `pytest-cov`, `hypothesis`, `respx`
- 정적 검사: `ruff`, `mypy`

구현 시점의 호환 버전을 선택하고 `uv.lock`에 정확히 고정한다. Secret 또는 계정별 값은 lock 파일에 들어가면 안 된다.

### 6.2 Alpaca 호출 방식

페이지 경계와 재시도를 명확히 제어하기 위해 직접 REST 호출을 구현한다.

- Base URL: `https://data.alpaca.markets`
- Endpoint: `GET /v2/stocks/bars`
- 인증 Header:
  - `APCA-API-KEY-ID`
  - `APCA-API-SECRET-KEY`
- 필수 Query:
  - `symbols`
  - `timeframe=30Min`
  - `start`
  - `end`
  - `adjustment=raw|all`
  - `feed=sip`
  - `sort=asc`
  - `limit=10000`
- 응답의 `next_page_token`이 존재하면 동일 요청에 `page_token`을 추가하여 끝까지 조회한다.
- 입력·출력 timestamp는 timezone-aware UTC여야 한다.

공식 참고:

- Alpaca Stock Bars 요청: <https://alpaca.markets/sdks/python/api_reference/data/stock/requests.html>
- Alpaca Feed·Adjustment enum: <https://alpaca.markets/sdks/python/api_reference/data/enums.html>
- Alpaca Pagination과 timeframe: <https://alpaca.markets/learn/fetch-historical-data>

## 7. 설정 계약

### 7.1 환경변수

다음 환경변수를 사용한다.

```dotenv
# Alpaca: 필수, 저장·로그 금지
ALPACA_API_KEY=
ALPACA_API_SECRET=

# AWS: 장기 Access Key 대신 AWS CLI 임시 로그인 Profile 사용
AWS_PROFILE=idea2strategy-dev
AWS_REGION=ap-northeast-2
MARKET_DATA_BUCKET=

# RDS: SSM 터널 사용
PGHOST={실제-RDS-endpoint}
PGHOSTADDR=127.0.0.1
PGPORT=15432
PGDATABASE=idea2strategy
PGUSER=market_loader
PGPASSWORD=
PGSSLMODE=verify-full
PGSSLROOTCERT={절대경로}/global-bundle.pem

# 실행 안전장치
PROVIDER_RIGHTS_VERSION=
PROVIDER_RIGHTS_APPROVED=false
```

규칙:

- `.env`는 Git에서 제외한다.
- `.env.example`에는 빈 값만 둔다.
- 실행 로그에는 위 값을 마스킹한다.
- AWS는 `AWS_PROFILE`의 임시 자격 증명을 사용한다.
- RDS 인증은 초기 구현에서 전용 `market_loader` 계정을 사용한다.
- Master 계정은 마이그레이션과 Loader 계정 생성에만 사용한다.
- 가능하면 DB 비밀번호는 프로세스 시작 직전에 Secrets Manager에서 읽어 환경변수로 전달한다.

### 7.2 비밀이 아닌 YAML 설정

`config.example.yaml`은 다음 구조를 사용한다.

```yaml
project:
  environment: development
  processing_version: "market-loader/1.0.0"
  schema_version: "market-bars/1"

alpaca:
  base_url: "https://data.alpaca.markets"
  feed: "sip"
  request_timeframe: "30Min"
  chunk_days: 180
  symbols_per_request: 50
  page_limit: 10000
  connect_timeout_seconds: 10
  read_timeout_seconds: 60
  max_attempts: 5

data:
  session_calendar: "XNYS"
  adjustments: ["raw", "all"]
  output_resolutions: ["30m", "1h", "4h", "1d"]
  shard_count: 8
  parquet_compression: "zstd"
  parquet_compression_level: 3
  parquet_row_group_size: 131072

storage:
  prefix: "historical"
  staging_directory: "./.staging"
  sse_algorithm: "AES256"

quality:
  fail_on_duplicate: true
  fail_on_invalid_ohlc: true
  fail_on_out_of_session: true
  fail_on_negative_activity: true
  warn_on_missing_expected_bar: true
```

`shard_count`, 스키마 버전 또는 시간봉 생성 규칙을 바꾸면 기존 데이터셋을 덮어쓰지 않고 새 Revision을 발행해야 한다.

## 8. 입력 Universe 계약

초기 입력은 UTF-8 CSV 파일이다.

```csv
provider_symbol,asset_type,primary_exchange_mic,effective_from,effective_to,support_status,instrument_id
AAPL,STOCK,XNAS,2016-01-01,,ACTIVE,
SPY,ETF,ARCX,2016-01-01,,ACTIVE,
```

필수 컬럼:

- `provider_symbol`
- `asset_type`: `STOCK` 또는 `ETF`
- `primary_exchange_mic`
- `effective_from`
- `effective_to`: 현재 유효하면 빈 값
- `support_status`

선택 컬럼:

- `instrument_id`

종목 ID 규칙:

1. CSV에 `instrument_id`가 있고 RDS에 같은 종목이 있으면 일치 여부를 확인한다.
2. CSV에 ID가 없고 같은 유효 심볼이 RDS에 있으면 RDS의 기존 ID를 사용한다.
3. 둘 다 없으면 `seed-catalog --execute`가 UUIDv4를 한 번 생성하고 RDS에 저장한다.
4. 저장된 UUID는 이후 모든 실행에서 재사용한다.
5. Python이 실행마다 새로운 UUID를 생성하면 안 된다.
6. 같은 거래소·심볼의 유효 기간이 겹치면 적재를 중단한다.
7. 상장 전·상장 폐지 후 기간에는 데이터를 요구하거나 생성하지 않는다.

## 9. CLI 계약

애플리케이션 진입점은 `market-loader`이다.

### 9.1 `doctor`

```powershell
market-loader doctor --config .\config.yaml
```

쓰기 없이 다음을 검사한다.

- Python과 의존성 버전
- Alpaca 인증과 SIP 권한
- AWS Caller Identity
- 대상 Region
- S3 버킷 존재 여부
- S3 Versioning 활성화
- S3 Block Public Access 네 항목 활성화
- S3 기본 암호화
- RDS 연결
- TLS `verify-full`
- Flyway 스키마 버전
- 필수 DB 테이블과 enum
- Staging 디스크 여유 공간
- Provider 권리 승인 값

하나라도 필수 검사가 실패하면 종료 코드가 0이 아니어야 한다.

### 9.2 `plan`

```powershell
market-loader plan `
  --config .\config.yaml `
  --universe .\universe.csv `
  --start 2016-01-01 `
  --end 2026-01-01
```

외부 쓰기를 하지 않고 다음을 JSON과 사람이 읽을 수 있는 표로 출력한다.

- 대상 종목 수
- 조정 유형
- 원본·파생 해상도
- 180일 API Chunk 수
- 연도·샤드 파티션 수
- 예상 API 요청 수
- 예상 Manifest 수
- 예상 S3 객체 수
- 이미 성공하여 건너뛸 파티션
- 실행 불가능한 입력 오류

### 9.3 `seed-catalog`

```powershell
market-loader seed-catalog `
  --config .\config.yaml `
  --universe .\universe.csv `
  --execute
```

- 기본은 Dry Run이다.
- `--execute`가 있어야 RDS를 변경한다.
- Provider, Feed, Instrument, Symbol, Trading Session 기준정보를 멱등하게 등록한다.
- 수정이 필요한 기존 행을 조용히 덮어쓰지 않고 차이를 출력하고 중단한다.

### 9.4 `backfill`

```powershell
market-loader backfill `
  --config .\config.yaml `
  --universe .\universe.csv `
  --start 2016-01-01 `
  --end 2026-01-01 `
  --adjustments raw,all `
  --resolutions 30m,1h,4h,1d `
  --execute
```

안전 옵션:

- 기본 Dry Run
- `--execute` 필수
- 최초 실제 실행 전 `--max-symbols 5 --start 2024-01-01 --end 2025-01-01` 표본 실행 필수
- `PROVIDER_RIGHTS_APPROVED=true`와 비어 있지 않은 `PROVIDER_RIGHTS_VERSION` 필수
- 기간은 날짜로 명시하며 실행일을 기준으로 자동 10년을 계산하지 않는다.

### 9.5 `resume`

```powershell
market-loader resume --run-id {UUID} --execute
```

- 이미 `SUCCEEDED`인 파티션은 건너뛴다.
- `FAILED` 또는 중단된 파티션만 다시 실행한다.
- 검증된 로컬 Staging과 S3 객체를 재사용할 수 있다.
- 같은 Idempotency Key의 성공 결과를 중복 발행하지 않는다.

### 9.6 `validate`

```powershell
market-loader validate --run-id {UUID}
market-loader validate --manifest-id {UUID}
```

- S3 Object HEAD
- Version ID
- 바이트 크기
- SHA-256
- Parquet Footer
- Parquet 스키마
- 행 수
- 최소·최대 시각
- RDS 객체·Manifest 합계
- Lineage

를 다시 확인한다. 읽기 전용 명령이다.

### 9.7 `reconcile`

```powershell
market-loader reconcile --run-id {UUID}
market-loader reconcile --run-id {UUID} --repair --execute
```

기본은 읽기 전용이다.

다음을 탐지한다.

- S3에는 있으나 RDS에 없는 검증된 Orphan 객체
- RDS에는 있으나 S3에서 찾을 수 없는 객체
- Version ID 불일치
- SHA-256 불일치
- `BUILDING`에 오래 머문 Manifest
- 실행이 끝났지만 `RUNNING`인 파티션

자동 복구는 이미 검증된 동일 객체의 누락된 RDS 등록만 허용한다. 해시 불일치, 객체 누락, 의미 변경은 자동 복구하지 않고 `QUARANTINED` 처리한다.

### 9.8 `status`

```powershell
market-loader status
market-loader status --run-id {UUID}
```

다음을 출력한다.

- 전체·성공·실패·진행 중 파티션 수
- 조정·해상도·연도별 Manifest 상태
- 수집 행 수
- S3 바이트 수
- API 재시도 수
- 품질 Incident 수
- 재개 가능한 실패

## 10. 파티션과 Idempotency

### 10.1 API 수집 단위

- 종목은 설정의 `symbols_per_request` 이하로 묶는다.
- 기간은 최대 180일 Chunk로 나눈다.
- 조정 유형은 `raw`, `all`을 절대 섞지 않는다.
- API 페이지는 `next_page_token`이 없어질 때까지 읽는다.
- Chunk 경계 유실을 막기 위해 바로 앞 Chunk와 최대 30분 겹쳐 조회할 수 있다.
- 수집 후 내부 `[chunk_start, chunk_end)` 범위로 자르고 `(instrument_id, bar_start_at)`으로 중복 제거한다.

### 10.2 발행 단위

하나의 논리 Manifest는 다음 조합이다.

```text
provider
+ feed
+ adjustment
+ session
+ resolution
+ year
+ revision
```

하나의 Manifest는 동일 연도의 여러 Shard Parquet 객체를 가질 수 있다.

### 10.3 Shard

기본 Shard 수는 8이다.

```text
first_unsigned_64_bits(
  SHA256(canonical instrument UUID UTF-8)
) % shard_count
```

- 바이트 순서는 Big Endian으로 고정한다.
- 같은 `instrument_id`는 항상 같은 Shard로 간다.
- Shard 수 변경은 새 Revision을 요구한다.

### 10.4 실행 Idempotency Key

다음 정규화 JSON의 SHA-256을 사용한다.

```json
{
  "pipeline_type": "HISTORICAL_BACKFILL",
  "provider": "ALPACA",
  "feed": "SIP",
  "adjustments": ["all", "raw"],
  "resolutions": ["1d", "1h", "30m", "4h"],
  "session": "XNYS_REGULAR",
  "start": "2016-01-01",
  "end": "2026-01-01",
  "universe_hash": "...",
  "schema_version": "market-bars/1",
  "processing_version": "market-loader/1.0.0",
  "shard_count": 8
}
```

- JSON Key는 사전순으로 정렬한다.
- 배열 값도 의미가 같으면 같은 순서가 되도록 정렬한다.
- 공백 없는 UTF-8 JSON을 해시한다.
- 동일 Key의 `SUCCEEDED` 실행은 기본적으로 재사용한다.
- 강제 재실행은 새 `processing_version` 또는 명시적인 새 Revision으로만 수행한다.

## 11. 시간과 정규장 계약

### 11.1 시간대

- API timestamp는 UTC로 파싱한다.
- Parquet `bar_start_at`은 `timestamp[us, tz=UTC]`이다.
- 거래일은 `America/New_York` 기준 `session_date_et`로 별도 저장한다.
- 시스템 로컬 시간대에 의존하면 안 된다.

### 11.2 거래 일정

- `exchange-calendars`의 `XNYS` 일정을 사용한다.
- 휴장일을 제외한다.
- DST를 자동 반영한다.
- 조기 폐장 시 실제 폐장 시각을 사용한다.
- 정규장 조건은 `market_open <= bar_start_at < market_close`이다.
- 정규장 밖의 행은 저장하지 않는다.

### 11.3 30분봉

- Alpaca `30Min` 응답을 원천으로 사용한다.
- RAW와 ALL을 각각 별도로 호출한다.
- 같은 종목·시각·조정 유형의 중복 행은 허용하지 않는다.
- 상장 전, 상장 폐지 후, 데이터 공급 시작 전 행을 만들지 않는다.
- 거래가 없어 Alpaca가 제공하지 않은 봉을 0 거래량이나 이전 종가로 생성하지 않는다.

## 12. 파생봉 생성 계약

1시간·4시간·일봉은 저장된 30분봉 의미에서 파생하며 Alpaca에 별도로 요청하지 않는다.

### 12.1 공통 집계

```text
open        = 구간의 첫 open
high        = 구간의 max(high)
low         = 구간의 min(low)
close       = 구간의 마지막 close
volume      = sum(volume)
trade_count = 모든 값이 null이면 null, 아니면 null을 제외하고 sum
vwap        = 유효한 vwap과 양수 volume의 가중평균, 계산 불가하면 null
```

파생 행에는 다음을 추가한다.

```text
source_bar_count
source_minutes
```

`source_minutes = source_bar_count * 30`이다.

### 12.2 1시간봉

- 각 거래일의 실제 정규장 개장 시각을 기준으로 Anchor한다.
- 예: 정상 거래일은 `09:30 ET`부터 60분 Bucket을 만든다.
- 마지막 `15:30~16:00` 구간은 30분짜리 부분 봉으로 보존한다.
- 부분 봉임을 `source_minutes=30`으로 명확히 표시한다.

### 12.3 4시간봉

- 정규장 개장 시각을 기준으로 Anchor한다.
- 정상 거래일:
  - `09:30~13:30`
  - `13:30~16:00`
- 마지막 부분 봉은 실제 관측분만 집계하고 `source_minutes`로 표시한다.
- 조기 폐장도 실제 폐장까지의 관측분만 사용한다.

### 12.4 일봉

- 한 `session_date_et`의 정규장 데이터만 집계한다.
- UTC 날짜로 Grouping하면 안 된다.
- 조기 폐장일도 하나의 정상 일봉으로 표현한다.

### 12.5 계보

- 모든 1h·4h·1d Manifest는 사용한 30m Manifest를 `DERIVED_FROM` 관계로 참조한다.
- RAW에서 파생한 데이터와 ALL에서 파생한 데이터를 서로 연결하거나 섞으면 안 된다.
- 원천 30m Revision이 바뀌면 영향받는 파생 데이터는 새 Revision으로 다시 생성한다.

## 13. Parquet 계약

### 13.1 30분봉 스키마

PyArrow 스키마를 명시적으로 선언하며 타입 추론에 맡기지 않는다.

| 컬럼 | PyArrow 타입 | Null |
|---|---|---|
| `instrument_id` | `string` | 불가 |
| `provider_symbol` | `string` | 불가 |
| `bar_start_at` | `timestamp("us", tz="UTC")` | 불가 |
| `session_date_et` | `date32` | 불가 |
| `open` | `float64` | 불가 |
| `high` | `float64` | 불가 |
| `low` | `float64` | 불가 |
| `close` | `float64` | 불가 |
| `volume` | `int64` | 불가 |
| `trade_count` | `int64` | 가능 |
| `vwap` | `float64` | 가능 |

### 13.2 파생봉 스키마

30분봉 스키마에 다음 컬럼을 추가한다.

| 컬럼 | PyArrow 타입 | Null |
|---|---|---|
| `source_bar_count` | `int16` | 불가 |
| `source_minutes` | `int16` | 불가 |

### 13.3 파일 메타데이터

다음을 Parquet Schema Metadata에 UTF-8 문자열로 기록한다.

```text
schema_version
processing_version
provider
feed
adjustment
session_scope
resolution
period_start
period_end
revision
manifest_id
created_at
```

API Key, 사용자명, DB 정보, 로컬 절대 경로는 기록하지 않는다.

### 13.4 정렬·압축

- 정렬: `instrument_id ASC, bar_start_at ASC`
- 압축: Zstandard
- 기본 압축 Level: 3
- Row Group: 131,072행
- `provider_symbol`은 Dictionary Encoding을 사용해도 된다.
- 파일 작성 완료 후 Footer를 다시 읽어 스키마와 행 수를 검증한다.
- 완성 전 파일은 `.staging` 아래 임시 이름으로 작성한다.
- 검증 완료 후에만 S3 업로드 대상으로 전환한다.

## 14. S3 객체 키 계약

버킷 내부 객체 키는 다음 형식을 사용한다.

```text
historical/
  provider=alpaca/
  feed=sip/
  adjustment={raw|all}/
  session=regular/
  resolution={30m|1h|4h|1d}/
  revision={8자리-0-padding}/
  year={YYYY}/
  shard={2자리}-of-{2자리}/
  manifest_id={UUID}/
  part-{5자리}.parquet
```

한 줄 예:

```text
historical/provider=alpaca/feed=sip/adjustment=raw/session=regular/resolution=30m/revision=00000001/year=2024/shard=03-of-08/manifest_id=11111111-1111-1111-1111-111111111111/part-00001.parquet
```

규칙:

- 버킷명은 키에 포함하지 않는다.
- Windows 경로 구분자 `\`를 사용하지 않는다.
- Symbol을 경로의 유일 식별자로 사용하지 않는다.
- 로컬 실행 UUID를 의미 없는 Prefix로 추가하지 않는다.
- 같은 Key가 존재하면 덮어쓰지 않고 충돌로 실패한다.
- Revision은 논리 데이터셋·연도 기준으로 증가한다.

## 15. S3 업로드 계약

### 15.1 권한

로컬 AWS 주체에는 Market Data 버킷의 지정 Prefix에 대해 최소한 다음 권한만 허용한다.

- `s3:GetBucketLocation`
- `s3:ListBucket` — `historical/` Prefix 조건
- `s3:GetObject`
- `s3:GetObjectVersion`
- `s3:PutObject`

Bucket Policy 또는 ACL로 익명 사용자에게 권한을 부여하면 안 된다.

`HeadObject`는 별도 IAM Action이 아니라 `s3:GetObject` 권한으로 허용한다.

### 15.2 업로드

파일별로 로컬 SHA-256을 계산한다.

- Hex SHA-256: RDS `content_sha256`과 S3 사용자 메타데이터에 사용
- Base64 SHA-256: S3 `ChecksumSHA256` 요청 값에 사용

`put_object` 호출은 다음 의미를 충족해야 한다.

```python
s3.put_object(
    Bucket=bucket,
    Key=object_key,
    Body=file_stream,
    ContentLength=byte_size,
    ContentType="application/vnd.apache.parquet",
    ServerSideEncryption="AES256",
    ChecksumAlgorithm="SHA256",
    ChecksumSHA256=base64_sha256,
    IfNoneMatch="*",
    Metadata={
        "content-sha256": hex_sha256,
        "schema-version": schema_version,
        "processing-version": processing_version,
        "manifest-id": str(manifest_id),
    },
)
```

- 성공 응답의 `VersionId`를 반드시 저장한다.
- ETag를 파일 SHA-256으로 해석하면 안 된다.
- 업로드 성공 후 `head_object`를 Version ID와 함께 호출한다.
- 바이트 크기, Checksum 또는 사용자 메타데이터 SHA-256, SSE를 확인한다.
- 공식 참고: <https://docs.aws.amazon.com/boto3/latest/reference/services/s3/client/put_object.html>

### 15.3 불변성

- `IfNoneMatch="*"` 충돌은 새 Revision이 필요하거나 동일 작업의 중복 실행임을 뜻한다.
- 동일한 `BUILDING` Manifest 또는 실패 후 재개 중이고 기존 객체의 해시와 새 파일 해시가 같으면 기존 검증 객체를 재사용할 수 있다.
- 새 Manifest Revision에서는 DBML의 객체 연결 Unique 제약을 지키기 위해 새 `manifest_id` 경로에 새 객체를 발행한다.
- 해시가 다르면 기존 Key에 쓰지 않고 실패한다.
- Versioning이 꺼진 버킷에는 공식 데이터를 업로드하지 않는다.

## 16. RDS 연결 계약

### 16.1 SSM 터널

배치 EC2가 SSM Managed Instance이고 Private RDS에 접근할 수 있어야 한다.

PowerShell 예:

```powershell
aws ssm start-session `
  --target {BATCH_EC2_INSTANCE_ID} `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters host="{RDS_ENDPOINT}",portNumber="5432",localPortNumber="15432" `
  --profile idea2strategy-dev `
  --region ap-northeast-2
```

Python/psycopg 연결은 다음 의미를 가져야 한다.

```text
host={RDS_ENDPOINT}
hostaddr=127.0.0.1
port=15432
dbname=idea2strategy
sslmode=verify-full
sslrootcert={AWS RDS global bundle absolute path}
```

`host`는 인증서 Hostname 검증용이고 `hostaddr`는 실제 SSM 로컬 터널 접속용이다.

AWS RDS TLS 공식 참고:

<https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html>

### 16.2 DB 계정

`market_loader`는 다음만 가능해야 한다.

- `market_data` 스키마 기준정보 읽기
- 적재에 필요한 `market_data` 테이블 Insert·Update
- `storage.objects` Insert·Select
- 자신의 Pipeline Run·Partition 상태 Update
- Flyway 스키마 또는 다른 서비스 스키마 수정 불가
- 사용자·전략·거래·원장 테이블 접근 불가

Master 계정으로 적재 프로그램을 실행하지 않는다.

## 17. RDS 스키마 계약

Flyway Migration은 기존 Idea2Strategy DBML의 이름과 의미를 따라야 한다. Python은 실행 시 필요한 Migration Version이 적용됐는지 확인하고, 누락되면 데이터를 쓰지 않는다.

- Python 적재기는 업무 실행 중 DDL을 자동 적용하지 않는다.
- `V001__market_data_initial_schema.sql`은 배포 전 별도의 Flyway 단계로 적용한다.
- 추후 Spring 프로젝트는 같은 Migration 파일과 `flyway_schema_history`를 이어서 사용한다.
- Python 프로젝트와 Spring 프로젝트에 의미가 다른 `V001`을 각각 만들면 안 된다.

### 17.1 Enum

```sql
market_data.dataset_status:
  BUILDING
  AVAILABLE
  QUARANTINED
  SUPERSEDED
  DELETED

operations.work_status:
  PENDING
  RUNNING
  SUCCEEDED
  FAILED
  CANCELLED
```

### 17.2 기준정보

#### `market_data.providers`

- `id uuid PK`
- `code varchar UNIQUE`: `ALPACA`
- `name`
- `rights_version`
- `status`
- `created_at`

실제 쓰기는 `rights_version`이 승인된 근거 값을 갖고 `status='ACTIVE'`일 때만 허용한다.

#### `market_data.feeds`

DBML의 현재 필드로 RAW/ALL과 해상도를 충돌 없이 구분하기 위해 다음 8개 Code를 사용한다.

```text
ALPACA_SIP_RAW_30M
ALPACA_SIP_RAW_1H
ALPACA_SIP_RAW_4H
ALPACA_SIP_RAW_1D
ALPACA_SIP_ALL_30M
ALPACA_SIP_ALL_1H
ALPACA_SIP_ALL_4H
ALPACA_SIP_ALL_1D
```

공통 필드:

- `provider_id`
- `data_kind='BAR'`
- `resolution`
- `session_scope='REGULAR'`
- `status='ACTIVE'`

#### `market_data.instruments`

- 서비스 내부의 영속 `instrument_id`
- 자산 종류
- 대표 거래소 MIC
- 통화 `USD`
- 지원 상태
- 상장·상장폐지 날짜

#### `market_data.instrument_symbols`

- `instrument_id`
- `symbol`
- `exchange_mic`
- `effective_from`
- `effective_to`
- 유효 기간이 겹치면 안 됨

#### `market_data.trading_sessions`

- `exchange_mic='XNYS'`
- `session_date`
- `opens_at`
- `closes_at`
- `session_type`: `REGULAR`, `EARLY_CLOSE`
- `calendar_version`

휴장일은 `opens_at`, `closes_at`이 필수인 현재 DBML에 맞춰 행을 만들지 않는다. 거래일 목록과 비교할 때 행이 없는 날짜를 휴장일로 해석한다.

### 17.3 실행 상태

#### `market_data.pipeline_runs`

- 한 번의 Backfill 명령을 표현한다.
- `pipeline_type='HISTORICAL_BACKFILL'`
- `processing_version`
- `status`
- `idempotency_key UNIQUE`
- 요청·시작·완료 시각
- Secret을 제외한 입력 설정 JSON
- 요약 결과 JSON
- 실패 코드

#### `market_data.pipeline_partitions`

`partition_key` 형식:

```text
adjustment={value}/resolution={value}/year={YYYY}/shard={NN}
```

- Run과 Partition Key 조합은 Unique
- `PENDING → RUNNING → SUCCEEDED|FAILED`
- 성공하면 `result_manifest_id`를 연결
- 오류 코드와 Secret 없는 요약을 저장

### 17.4 공식 객체

#### `storage.objects`

필수 필드:

- `id`
- `storage_class='S3_STANDARD'`
- `bucket_code='DEVELOPMENT_MARKET_DATA'`
- `object_key`
- `provider_version_id`: S3 Version ID
- `content_sha256`
- `byte_size`
- `media_type='application/vnd.apache.parquet'`
- `format_version`: Parquet/Schema Version
- `encryption_profile='SSE-S3-AES256'`
- `created_at`
- `verified_at`

Unique:

```text
(bucket_code, object_key, provider_version_id)
```

#### `market_data.dataset_manifests`

- `id`
- `feed_id`
- `instrument_id=NULL`: 다종목 Shard Dataset
- `data_layer`: `RAW`, `ADJUSTED`, `DERIVED`
- `resolution`
- `period_start`
- `period_end`
- `revision_number`
- `as_of_at`
- `processing_version`
- `quality_status`
- `status`
- `row_count`
- `manifest_hash`
- `created_at`
- `supersedes_manifest_id`

매핑:

| Adjustment | Resolution | data_layer |
|---|---|---|
| raw | 30m | `RAW` |
| all | 30m | `ADJUSTED` |
| raw | 1h/4h/1d | `DERIVED` |
| all | 1h/4h/1d | `DERIVED` |

RAW 파생과 ALL 파생은 서로 다른 `feed_id`로 구분한다.

Manifest Hash의 정규화 입력에는 반드시 다음을 포함해 전역 충돌을 방지한다.

```text
provider code
feed code
adjustment
session
resolution
period_start/end
revision
schema_version
processing_version
정렬된 object content_sha256 목록
각 object row_count/period/shard/part
```

#### `market_data.dataset_objects`

- Manifest와 `storage.objects`를 연결한다.
- Object Kind: `BAR_PARQUET`
- Partition Key
- 행 수
- 최소·최대 `bar_start_at`
- 한 Storage Object는 하나의 활성 Manifest Snapshot에서 한 번만 연결한다.

#### `market_data.dataset_lineage`

- 파생 Manifest → 30m 원천 Manifest
- `relationship_type='DERIVED_FROM'`

#### `market_data.quality_incidents`

- Manifest 또는 종목
- Incident Type
- Severity
- 기간
- 상태
- Secret 없는 상세 JSON
- 감지·해결 시각

## 18. 상태 전환과 트랜잭션

### 18.1 Run 시작

하나의 짧은 DB Transaction으로 다음을 수행한다.

1. Idempotency Key 확인
2. 새 `pipeline_runs`를 `RUNNING`으로 생성
3. 대상 `pipeline_partitions`를 `PENDING`으로 생성
4. Commit

### 18.2 Manifest 작성

1. 대상 논리 데이터셋·연도 Revision을 DB Lock 아래 결정한다.
2. Manifest UUID를 미리 생성한다.
3. Manifest를 `BUILDING`으로 생성한다.
4. 로컬 파일을 생성하고 검증한다.
5. S3에 불변 업로드한다.
6. S3 Version ID와 HEAD 검증 결과를 얻는다.
7. 하나의 DB Transaction에서 다음을 수행한다.
   - `storage.objects` Insert
   - `dataset_objects` Insert
   - 필요한 `dataset_lineage` Insert
   - Manifest 행 수·Hash·품질 상태 갱신
   - 모든 필수 Shard가 성공했을 때 Manifest를 `AVAILABLE`로 전환
   - 이전 활성 Revision을 `SUPERSEDED`로 전환
   - Partition을 `SUCCEEDED`로 전환
8. Commit

S3와 RDS는 분산 Transaction이 아니다. S3 성공 후 DB 실패 시 객체를 삭제하지 않고 Orphan으로 남긴 뒤 동일 Version ID와 Hash로 RDS 등록을 재시도한다.

### 18.3 실패

- API 또는 네트워크 일시 오류: 지수 Backoff 후 재시도
- 인증·권한·계약 오류: 즉시 중단
- 품질 치명 오류: Manifest `QUARANTINED`
- DB Transaction 실패: Rollback 후 재시도 가능 상태
- S3 Key 충돌·다른 Hash: 자동 덮어쓰기 금지, Partition `FAILED`
- 프로세스 종료: 미완료 Partition은 `resume` 대상

Run은 모든 Partition이 성공해야 `SUCCEEDED`이다. 하나라도 최종 실패하면 `FAILED`이다.

## 19. 재시도 정책

### 19.1 Alpaca

재시도 대상:

- Timeout
- 연결 오류
- HTTP 429
- HTTP 500, 502, 503, 504

정책:

- 최대 5회
- `Retry-After`가 있으면 우선 사용
- 없으면 지수 Backoff + Jitter
- 예: 1초, 2초, 4초, 8초, 16초 상한

재시도하지 않음:

- 400
- 401
- 403
- 잘못된 응답 스키마
- SIP 권한 없음

### 19.2 S3

- SDK 표준 재시도 `adaptive` 모드 사용
- Key 충돌 412는 재시도하지 않고 정합성 검사
- 성공 응답을 받았으나 로컬 상태 저장 전 종료한 경우 `head_object`로 재확인

### 19.3 PostgreSQL

- Deadlock, Serialization Failure, 일시 연결 단절만 제한적으로 재시도
- Unique 위반은 Idempotency 확인 후 동일 의미일 때만 재사용
- Schema 불일치, 권한 부족, FK 오류는 즉시 중단

## 20. 품질 검증

### 20.1 치명 오류

다음 중 하나라도 있으면 Manifest를 `AVAILABLE`로 만들지 않는다.

- 필수 컬럼 누락
- 타입 불일치
- Null 불가 컬럼의 Null
- `(instrument_id, bar_start_at)` 중복
- UTC가 아닌 timestamp
- 정규장 밖 행
- `low > high`
- Open·Close가 `[low, high]` 밖
- 0 이하 또는 유한하지 않은 OHLC 가격
- 음수 Volume
- 음수 Trade Count
- Parquet Footer 읽기 실패
- 로컬과 S3 SHA-256 불일치
- RDS 행 수와 Parquet 행 수 불일치
- 기간 또는 Shard 밖 행
- RAW/ALL 혼합
- 원천 Revision을 찾을 수 없는 파생 데이터

### 20.2 경고

다음은 데이터를 만들지 않고 Incident로 기록한다.

- 기대한 30분 시각에 공급자 Bar 없음
- 전체 거래일 데이터 없음
- `trade_count` Null
- `vwap` Null
- 조기 폐장 부분 봉
- 거래정지 가능 구간
- 상장·상장폐지 경계

경고가 있다고 임의 보간하지 않는다. 전체 거래일 누락 또는 종목 전체 기간 누락은 `ERROR` Incident로 올리고 운영자 검토 전 해당 범위의 공식 사용을 막아야 한다.

### 20.3 Manifest 품질 상태

```text
PASSED
PASSED_WITH_WARNINGS
FAILED
```

- `PASSED`, `PASSED_WITH_WARNINGS`만 `AVAILABLE` 가능
- `FAILED`는 `QUARANTINED`

## 21. 로그와 보고서

모든 로그는 JSON 한 줄 형식으로 출력한다.

필수 공통 필드:

```text
timestamp
level
event
run_id
partition_key
manifest_id
attempt
duration_ms
```

수집 이벤트:

- symbol count
- chunk start/end
- page count
- row count
- HTTP status

파일 이벤트:

- 로컬 상대 경로
- 행 수
- 바이트 수
- SHA-256 앞 12자리
- 기간

금지:

- Alpaca Secret
- AWS Credential
- DB 비밀번호
- 전체 DB DSN
- S3 Presigned URL
- OS 사용자 홈 절대 경로

Run 종료 시 다음 파일을 생성한다.

```text
reports/{run_id}/summary.json
reports/{run_id}/partitions.jsonl
reports/{run_id}/quality-incidents.jsonl
```

보고서는 RDS의 보조 출력이며 공식 정본이 아니다.

## 22. 테스트 요구사항

구현은 테스트 우선으로 진행한다.

### 22.1 단위 테스트

- UTC ↔ ET 거래일 변환
- DST 시작 전후
- 휴장일
- 조기 폐장
- 정규장 필터
- Chunk `[start, end)` 경계
- 페이지 Token 반복
- Chunk 겹침 중복 제거
- UUID Shard 결정성
- 1h·4h·1d 집계
- 부분 봉 `source_minutes`
- VWAP 가중평균
- Parquet 고정 스키마
- Manifest Hash 결정성
- Object Key 결정성
- Secret 로그 마스킹
- 오류 분류

### 22.2 속성 테스트

- 입력 순서를 섞어도 정렬 후 같은 Parquet 논리 행 생성
- 같은 Manifest 입력은 같은 Hash
- 다른 Adjustment는 같은 Manifest Hash가 될 수 없음
- 같은 Instrument UUID는 항상 같은 Shard
- 재실행해도 RDS 공식 객체 수가 증가하지 않음
- 파생 OHLC가 원천 범위를 벗어나지 않음

### 22.3 통합 테스트

테스트 PostgreSQL과 S3 대역을 사용해 다음을 검증한다.

- Flyway Migration
- Catalog Seed 멱등성
- Pipeline Run 상태 전환
- S3 업로드 성공 후 RDS 등록
- S3 성공·RDS 실패 후 Reconcile
- RDS Transaction Rollback
- 같은 Key·같은 Hash 재사용
- 같은 Key·다른 Hash 차단
- Version ID 저장
- Manifest `AVAILABLE`
- 이전 Revision `SUPERSEDED`
- Lineage 연결

로컬 S3 대역은 빠른 테스트용이다. 최종 검증은 Versioning과 조건부 Put을 지원하는 실제 Development S3 표본으로 수행한다.

### 22.4 Contract 테스트

- Parquet 스키마 Snapshot
- S3 Object Key Snapshot
- RDS 테이블·컬럼·Enum 확인
- `AVAILABLE` 조회 Query
- Spring이 사용할 Manifest 조회 DTO 예제

## 23. 표본 검증 절차

전체 10년 실행 전에 반드시 다음 단계를 통과한다.

1. `doctor`
2. `plan`
3. 대표 종목 5개 선정
   - 대형주
   - ETF
   - 티커 변경 또는 기업행사 검증 대상
   - 조기 폐장 기간 포함
4. 1년 범위 RAW·ALL 수집
5. 30m·1h·4h·1d 생성
6. 모든 S3 객체 HEAD·SHA 검증
7. 모든 RDS Manifest와 행 수 검증
8. SQL로 `AVAILABLE` 조회 확인
9. PyArrow로 종목·월 범위 Predicate Filter 조회 시간 측정
10. 팀 검토 후 전체 10년 실행

표본 실행 예:

```powershell
market-loader backfill `
  --config .\config.yaml `
  --universe .\universe.csv `
  --start 2024-01-01 `
  --end 2025-01-01 `
  --max-symbols 5 `
  --execute
```

## 24. 전체 10년 실행 완료 조건

다음을 모두 만족해야 초기 적재 완료로 본다.

- 모든 대상 조정·해상도·연도의 Manifest 존재
- 공식 Manifest가 `AVAILABLE`
- `BUILDING` 또는 장기 `RUNNING` 없음
- 실패 Partition 0개 또는 승인된 제외 사유 존재
- 모든 Manifest의 행 수가 Object 합계와 일치
- 모든 S3 Object에 Version ID 존재
- 모든 S3 Object에 SHA-256 존재
- 모든 Object의 Parquet Footer 검증 성공
- 모든 파생 Manifest에 원천 30m Lineage 존재
- RAW와 ALL이 서로 다른 Feed와 Prefix로 분리
- 정규장 밖 행 0개
- 중복 Key 0개
- 치명 품질 Incident 0개
- 재실행 Plan이 성공 파티션을 모두 건너뜀
- Spring 소비자가 사용할 Manifest 조회 예제가 성공
- 최종 요약 보고서 보관

## 25. Spring 소비 계약

Spring 또는 Backtest Worker는 다음 순서로 데이터를 선택한다.

1. Provider·Feed·Adjustment·해상도·기간 조건으로 Manifest 조회
2. `status='AVAILABLE'`만 선택
3. 고정된 `manifest_id`를 백테스트 입력에 저장
4. `dataset_objects`와 `storage.objects` 조회
5. Bucket, Key, Version ID로 S3 객체 읽기
6. 읽은 바이트의 SHA-256 검증
7. 불일치 또는 누락 시 다른 최신 데이터로 대체하지 않고 실패

소비용 SQL의 의미:

```sql
SELECT
    dm.id AS manifest_id,
    f.code AS feed_code,
    dm.resolution,
    dm.period_start,
    dm.period_end,
    dm.revision_number,
    dm.manifest_hash,
    so.bucket_code,
    so.object_key,
    so.provider_version_id,
    so.content_sha256,
    dmo.partition_key,
    dmo.row_count
FROM market_data.dataset_manifests dm
JOIN market_data.feeds f
  ON f.id = dm.feed_id
JOIN market_data.dataset_objects dmo
  ON dmo.dataset_manifest_id = dm.id
JOIN storage.objects so
  ON so.id = dmo.object_id
WHERE dm.status = 'AVAILABLE'
  AND f.code = %(feed_code)s
  AND dm.resolution = %(resolution)s
  AND dm.period_start <= %(required_start)s
  AND dm.period_end >= %(required_end)s
ORDER BY dm.revision_number DESC, dmo.partition_key ASC;
```

실제 구현에서는 요구 기간을 정확히 덮는지와 활성 Manifest 간 기간 중복이 없는지 추가 검증한다.

## 26. 보안 체크리스트

- [ ] S3 Block Public Access 4개 설정 활성화
- [ ] S3 Versioning 활성화
- [ ] S3 SSE-S3 암호화
- [ ] S3 TLS 강제
- [ ] RDS `publicly_accessible=false`
- [ ] RDS Private DB Subnet
- [ ] RDS Security Group은 배치 EC2 Security Group만 허용
- [ ] 로컬은 SSM 터널만 사용
- [ ] RDS TLS `verify-full`
- [ ] 전용 `market_loader` 최소 권한
- [ ] AWS 장기 Access Key 미사용
- [ ] Secret Git 제외
- [ ] Secret 로그 마스킹
- [ ] Presigned URL 저장 금지
- [ ] 실제 쓰기 `--execute` 안전장치
- [ ] Provider 권리 승인 Gate

## 27. 구현 완료 산출물

구현자는 다음을 제공해야 한다.

- 실행 가능한 Python Package
- `pyproject.toml`
- 고정된 `uv.lock`
- `.env.example`
- `config.example.yaml`
- Flyway Migration
- SSM 터널 PowerShell Script
- Universe CSV 예시
- 모든 CLI 명령
- 단위·속성·통합·Contract 테스트
- Coverage 보고
- Ruff·Mypy 통과
- 표본 실행 결과
- 운영 README
- 실패 복구 Runbook

## 28. 구현자가 임의로 결정하면 안 되는 항목

다음 값이 준비되지 않으면 실제 10년 쓰기를 중단하고 운영자에게 요청해야 한다.

- 정확한 시작일과 종료일
- 최종 Universe CSV
- Alpaca SIP 과거 데이터 사용·저장 권리 승인 근거
- Development Market Data S3 버킷명
- RDS Endpoint와 SSM 대상 배치 EC2 ID
- Flyway Migration 적용 여부
- `market_loader` DB 계정
- AWS RDS CA Bundle 경로
- 초기 `processing_version`

이 값들은 코드에 기본값으로 숨겨 넣지 않는다.

## 29. 참조하는 프로젝트 계약

이 명세는 다음 Idea2Strategy 원칙을 따른다.

- 관계형 DB는 공식 상태와 데이터 관계를 보관한다.
- S3는 대용량 원본·상세 불변 객체를 보관한다.
- 시장 데이터 본문은 RDS에 저장하지 않는다.
- 객체 매니페스트는 형식·스키마 버전·행 수·크기·해시·계보를 보존한다.
- 객체 누락이나 해시 불일치 시 다른 데이터로 조용히 대체하지 않는다.
- 현재는 Development 환경만 구축한다.
- 향후 Production은 별도 RDS·S3·비밀·Terraform State로 신규 생성한다.

현재 저장소의 관련 정본:

- `db/schema.dbml`
- `specs/product/decisions/decision.data.hybrid.md`
- `specs/architecture/technology.need.market-data.md`
- `specs/architecture/technology.need.object-storage.md`
- `specs/quality/quality.auditability.md`
- `specs/quality/quality.failure-safety.md`
- `specs/quality/quality.reproducibility.md`
- `specs/policies/policy.legal.block-uncertain.md`

정본 DBML과 이 문서가 충돌하면 Python 구현을 임의로 맞추지 말고 충돌을 보고해야 한다. DBML 변경은 별도 검토·Flyway Migration·Rollback·Contract Test를 거쳐야 한다.
