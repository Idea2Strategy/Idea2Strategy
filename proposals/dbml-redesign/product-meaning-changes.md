# DBML 재설계에 따른 제품 의미 변경 제안

## 2026-07-28 시장 데이터 다단계 Compaction 제안

- 시장 데이터 수집 객체는 일 단위 또는 더 작은 불변 마이크로배치로 게시할 수 있다.
- 누적된 작은 객체는 ET 달력 기준 주·월·연 단위로 합쳐 장기 백테스트가 읽는 파일 수를 줄인다.
- Compaction은 원본을 덮어쓰지 않고 새 객체와 새 Manifest 개정을 만들며 Manifest 계보와 Object 계보를 모두 보존한다.
- 공개 Manifest는 같은 shard와 기간에 겹치는 일·주·월·연 객체를 동시에 선택하지 않는다.
- 이미 완료된 백테스트는 잠근 입력 객체를 유지하고 새 Compaction 결과로 소급 교체하지 않는다.
- 700개 이상 종목은 종목별 파일이 아니라 결정론적인 다종목 shard로 묶고, 정확한 shard 수와 목표 파일 크기는 대표 10년 백테스트로 검증한다.

- 상태: 격리된 제안 — 제품 정본 아님
- 작성일: 2026-07-23
- 기준 저장소: `Idea2Strategy/Idea2Strategy`
- 기준 브랜치: `develop`
- 기준 커밋: `6a53eb36a0cc9769f0220c8e3ea4a7d26036f34c`
기준 Stackcord fingerprint: `sha256:3cb632a0a1d1b75fd1e879be6da23c95d884a8250e4da3aba22f94cf5e59d7f2`
DBML 초안: `proposals/dbml-redesign/schema.draft.dbml`

Trading 운영 제약: `proposals/dbml-redesign/trading-production-readiness.md`

## Trading 정합성 재구성 제안

- 2026-07-28 사용자 보정에 따라 Bot이 아니라 Partition을 주문 통합·상계·예산·예약·보유수량·원장·lot의 최상위 거래 격리 경계로 바꾼다.
- `order_intent_batches`, Order, Allocation, Fill과 모든 하류 체결 경로에 `(bot_id, partition_id)`를 전달하고 복합 FK로 다른 Partition 연결을 차단한다.
- 같은 Partition 내부 Flow Intent만 하나의 Order로 통합하며 `order_intent_allocations`가 Flow 귀속의 유일 주문 단계 관계다.
- 부분 체결을 폐지한다. Order는 정상 Fill 없이 REJECTED/CANCELLED/EXPIRED 또는 정확히 한 정상 Fill로 전량 FILLED만 가능하다.
- `fill_allocations`를 제거하고 Ledger Entry, Position Lot, Lot Movement는 `order_intent_allocation_id`를 통해 Flow 귀속을 유지한다.
- `resource_reservations`는 ACTIVE에서 종료 상태로 한 번만 전이한다. Fill 시 실제 사용액을 소비하고 Buying Power 버퍼와 차액을 동시에 해제해 최종 `consumed + released = reserved`를 강제한다.
- 매수·매도 주문 Element의 주문 규모는 퍼센트만 허용한다. 매수는 실행 시점 Partition 가용 현금, 매도는 해당 Flow의 예약되지 않은 매도 가능 수량을 기준으로 하며 마지막 정상 전량 Fill부터 설정된 최소 재활성화 기간이 지나야 같은 Element가 새 Intent를 만들 수 있다.
- Order 생성 전 축소를 원칙으로 하고, 이미 OPEN인 지정가·스탑 주문은 원본 취소·예약 전액 해제 후 더 작은 replacement Order와 새 예약을 만든다.
- 정상 Fill 정정은 두 번째 Fill이 아니라 `fill_adjustments` CORRECTION/REVERSAL과 원장·lot 조정 사건으로 기록한다.
- Bot 전체 순포지션 읽기 모델을 `partition_position_projections`로 바꿔 다른 Partition 보유량을 주문 가능 수량으로 상계하지 않는다.
- 고정 5 bps 슬리피지, 20 bps 수수료, Pro 숏의 차입·담보·강제 바이인 구조는 유지하되 모두 Partition 격리 경계를 따른다.
- 정확한 합계, 상태 전이, 원장 균형, FIFO, Fill 존재 조건은 PostgreSQL 지연 제약 트리거와 동일 트랜잭션 경계로 강제한다.

## 2026-07-28 Strategy 출시와 Bot 독립 스냅샷 제안

사용자 확정 결정에 따라 Strategy는 수정 가능한 설계 원본이고, Bot은 Strategy 출시 시점의 검증된 상태를 복사해 만든 완전 독립 실행 객체다. 이 절은 아래 문서에 남아 있는 `Strategy가 Bot을 소유한다`, `bot_workspaces에서 Bot을 편집한다`, `Bot에서 원본 Strategy를 참조한다`는 이전 설명을 대체한다.

- Strategy 편집 현재값은 `strategy.strategies`와 1:1 `strategy.strategy_documents`가 소유한다.
- `strategy_documents.semantic_document`에는 파티션 예산 상한, Flow, Element, edge, 매개변수와 선택 종목을 저장한다.
- `strategy_documents.presentation_document`에는 파티션·Flow·Element 좌표, 크기, edge route와 viewport를 저장한다.
- Strategy는 계속 수정 가능하며 사용자 Strategy 버전·커밋·출시 계보 테이블을 만들지 않는다.
- 출시 전 완전성, JSON Schema, 안정 키 참조, 포트 타입, DAG, 파티션 예산 합, 종목 의존성과 필수 주문 경로를 검증한다.
- 출시 트랜잭션은 새 `bot.bots`, `bot.launch_snapshots`, `bot.launch_configurations`, `bot.bot_partitions`, `bot.flows`, 종목·피처·시간 의존성을 원자적으로 생성한다.
- Bot에는 원본 Strategy 식별자, 출처 FK, 복사 계보, 출시 버전 연결을 저장하지 않는다. 운영자와 사용자 모두 Bot만으로 원본 Strategy를 역추적할 수 없다.
- 같은 Strategy를 여러 번 출시해도 각 Bot은 서로 독립이며 이후 Strategy 수정은 기존 Bot에 전파되지 않는다.
- `bot.launch_snapshots`는 출시 당시 semantic과 presentation 증적을 1:1로 보존한다. Strategy 식별자는 스냅샷 JSON Schema에서 금지한다.
- 출시된 Bot의 mode, 파티션 예산, Flow 의미, Element, 종목과 실행 설정은 불변이다.
- Bot 이름, 파티션·Flow 설명과 좌표, Flow 내부 Element 레이아웃 같은 presentation은 수정할 수 있다. 현재 배치를 수정해도 불변 출시 스냅샷을 덮어쓰지 않는다.
- `bot.bot_workspaces`는 제거한다. 미완성 편집 상태는 Strategy 문서만 소유한다.
- Package는 Basic Strategy 문서에 완성 Flow를 복사하고 Template은 Pro Strategy 문서에 시작 골격을 복사한다. Package·Template 출처 역시 사용자 Strategy나 출시 Bot에 남기지 않는다.
- `strategy.compiled_flow_plans`와 Element 카탈로그 참조는 원본 사용자 Strategy 계보가 아니라 재현 가능한 실행을 위한 content-addressed 플랫폼 인프라다.

출시 실패는 일부 Bot 행을 남기지 않고 전체 트랜잭션을 롤백한다. 스냅샷과 정규화된 실행 계층 또는 `launch_configurations`의 해시가 불일치하면 Bot 실행을 시작하지 않는다.

## 2026-07-27 봇 실행 아키텍처 재설계 제안

봇 하나마다 전용 실행 파일·프로세스·컨테이너·스레드를 서버에 상주시키는 구조는 사용하지 않는다. 봇은 PostgreSQL에 저장된 불변 실행 설정과 복구 가능한 런타임 상태 데이터이며, 이벤트가 발생했을 때 공용 Worker Pool이 관련 전략만 평가한다. 상시 실행 주체는 Market Data Consumer, Trigger Router, Schedule Event Producer, Evaluation Worker Pool, Order/Fill Processor, Settlement Worker, Outbox Publisher, Projection Builder뿐이고, 이들은 봇 수가 아니라 Queue 처리량에 따라 수평 확장한다.

사용자 확정 결정(2026-07-27 A/B 질문):

1. **트리거 이벤트 정본 = 봇별 `bot_events`만 (A).** 전역 트리거 테이블은 두지 않는다. Trigger Router가 라우팅된 봇마다 결정적 `idempotency_key`(전역 이벤트 식별 내장, 예: `PRICE:AAPL:<bar-close>` / `SCHEDULE:ONE_MINUTE:<minute>`)로 bot_events를 append하며, `(bot_id, idempotency_key)` 유니크가 at-least-once 재전달을 흡수한다.
2. **평가 단위 = Flow×트리거 (B).** `bot.evaluation_runs`가 Flow 단위 행이고 판단 기록의 제품 단위도 Flow별 평가다. 같은 봇의 Flow 평가는 병렬 실행 가능하지만 예산·충돌 해소·상계 적용은 파티션별 `order_intent_batches`와 `(bot_id, partition_id)` advisory lock 경계에서 직렬화한다.
3. **지연·차단 해소 후 재개 = 최신만 평가 (A).** 밀린 트리거는 `SKIPPED`(`CATCHUP_SUPERSEDED`)로 기록만 남기고 과거 가격으로는 절대 평가하지 않는다. `operations.work_status`에 `SKIPPED`를 추가했다.

서버가 선택한 동시성 조합(제품 의미 불변): Queue partition key = `(bot_id, partition_id)` + Flow당 활성(PENDING/RUNNING) 평가 1개 부분 유니크 + 적용 시점 `(bot_id, partition_id)` advisory lock. Worker 승계는 `evaluation_runs.lease_expires_at` 만료로 판정한다.

헬스 모델 분리:

- **인프라·파이프라인(전역)**: `market_data.stream_watermarks`(신규, 재생성 가능 Projection) + `quality_incidents` + operations 관측이 소유한다. 평가 직전 실행 게이트가 이를 읽으며, 전역 장애가 bot 행을 일괄 갱신하는 일은 없다.
- **봇별 실행 차단**: `bot.bots.health_status` enum(HEALTHY/ACTION_REQUIRED/DATA_DEGRADED/SETTLEMENT_FAILED)을 제거하고 nullable Projection `execution_blocked_at` / `execution_block_reason_code` / `execution_block_event_id`로 대체한다. 정상 = `execution_blocked_at IS NULL`. 차단·해제 공식 이력은 append-only bot_events(`BOT_EXECUTION_BLOCKED`, `BOT_EXECUTION_UNBLOCKED`, `SETTLEMENT_FAILED`, `LEDGER_INVARIANT_VIOLATED`, `STATE_REBUILD_COMPLETED`)로 남는다. 차단 중에도 기존 미체결 주문을 취소하지 않고 체결·만료·거절 등 이후 결과와 예약 해제·원장·정산·STOPPING 처리를 계속한다.
- `lifecycle_status`의 의미를 재정의한다: RUNNING은 "새 트리거 발생 시 평가 대상이 될 수 있음"이지 프로세스 실행이 아니다. heartbeat/process_id/worker_id/last_alive_at 류 컬럼은 금지한다.

Trigger Dependency는 두 번째 정본이 아니라 완성 시 `semantic_document`에서 서버가 검증·추출한 관계형 Projection이다. 종목·피처 의존성은 기존 `bot.strategy_instruments`와 `bot.strategy_feature_requirements`를 재사용하고, 비종목(시간·세션) 트리거만 신규 `bot.strategy_time_triggers`(MARKET_OPEN/MARKET_CLOSE/SCHEDULE + schedule_key)가 담는다. 시장 이벤트마다 전체 봇·전략을 조회하지 않는다.

DBML 반영: `proposals/dbml-redesign/schema.draft.dbml`에서 bots 컬럼 교체, evaluation_runs 재구조화(Flow 소유 복합 FK, queued_at/attempt_count/lease_expires_at, 스냅샷 컬럼 nullable), evaluation_strategy_results 삭제, order_intent_batches를 `(bot_id, partition_id, source_event_id)` 유니크의 파티션 충돌 경계로 변경, order_intents에 evaluation_run_id 추가, flow_time_triggers·stream_watermarks 신설.

## 2026-07-27 identity 재구성 제안

사용자 결정에 따라 하나의 계정은 서비스 이메일을 최대 한 개만 소유한다. 기존 다중 이메일·대표 이메일 모델은 제거한다.

- `identity.accounts`는 식별자와 현재 생명주기 상태만 갖는 최소 루트로 축소한다.
- 언어·표시 시간대는 `identity.account_preferences` 1:1 확장 테이블로 분리한다.
- `identity.account_emails.account_id`를 PK로 사용하여 계정당 이메일을 DB 수준에서 0개 또는 1개로 제한한다.
- 이메일 확인 토큰 이력은 `identity.email_verification_requests`에 분리하여 재발송 시 기존 증거를 덮어쓰지 않는다.
- 로그인 제공자 설정은 `identity.auth_providers`에 두고, 제공 이메일·프로필 JSON은 서비스 정본으로 복제하지 않는다.
- `identity.login_identities`는 PASSWORD 또는 OIDC 제공자 식별자를 계정에 연결하되 이메일 일치만으로 계정을 병합하지 않는다.
- 계정 동의와 제재 변경은 append-only 이력으로 보존한다.
- 사용자 역할·공개 프로필·마케팅 설정은 현재 제품 요구가 아니므로 참고 DBML에서 가져오지 않는다. 운영자 권한은 기존 `operations` RBAC가 소유하고, 알림 선택은 `operations.notification_preferences`가 소유한다.

이 내용은 격리된 DBML 제안이며 제품 권한 검토 전에는 `db/schema.dbml` 정본에 반영하지 않는다.

## 문서 목적

이 문서는 DBML 재설계 대화에서 사용자가 선택한 내용 중 현재 `specs/`와 `contracts/`의 제품 의미를 바꾸거나 보완해야 하는 항목을 운영자 컴퓨터로 전달하기 위한 제안서다.

- 이 문서는 제품 정본을 대체하지 않는다.
- 이 문서의 내용은 승인·통합·출시 가능한 변경으로 표현하지 않는다.
- 운영자 컴퓨터에서 실제 저장소와 provider 상태를 다시 확인한 뒤 영향받는 정본 문서를 수정한다.
- 정본 수정 전 `stackcord governance check --json`을 실행하고 정확한 저장소, HEAD와 보호 fingerprint에 대해 `user:kcrmin`의 fresh provider 승인이 확인돼야 한다.
- Git 사용자 이름과 이메일은 제품 권한 증명이 아니다.

세부 데이터 모델 결정과 DBML 반영 계획은 `db/data-model-decisions.md`가 소유한다.

## 제안된 제품 의미

### 1. 봇·파티션·전략 계층

2026-07-27 봇 스키마 재검토 질문 1의 `A`로, 제안 구조는 `봇 1 ─ N 파티션 1 ─ N 전략(블록 묶음)`으로 다시 확정했다.

- 전략은 정확히 하나의 파티션에 종속된다.
- 완성된 봇에는 최소 하나의 파티션이 있고, 각 파티션에는 최소 하나의 완성된 전략이 있어야 한다. 빈 봇과 빈 파티션은 편집 워크스페이스에서만 허용한다.
- 전략은 파티션이 직접 소유하는 블록 묶음이며 독립 라이브러리 항목이나 버전 관리 대상이 아니다.
- 다른 파티션이 같은 전략 행 또는 블록 묶음을 공유하거나 재사용하지 않는다.
- `BASIC` 또는 `PRO` 모드는 봇 전체가 하나만 가지며 같은 봇의 모든 파티션과 전략은 해당 모드의 작성·검증 규칙을 따른다. 한 봇 안에서 두 모드를 혼합하지 않는다.
- 봇·파티션·전략을 복사할 때는 새 식별자로 단순 복제하며 원본과의 FK, 계보 또는 버전 연결을 남기지 않는다.
- 원본 런타임 상태, 현금, 주문, 체결, 포지션, 원장과 성과는 복사하지 않는다.
- 편집 중인 미완성 구성은 별도 `bot_workspaces`의 단일 JSONB 문서로 자동 저장한다. 워크스페이스는 봇이나 전략의 버전이 아니며, 완성·검증 후 새 봇 계층을 원자적으로 생성할 때 원본 FK나 계보를 남기지 않는다.

현재 정본과의 차이:

- 현재 정본은 계정 소유의 독립 전략 작업본·출시 버전·재사용 흐름을 전제로 한다.
- 제안은 전략을 파티션 종속 구성으로 바꾸므로 전략 라이브러리, 출시 여정, 복사와 자동 백테스트 의미를 함께 재검토해야 한다.

### 2. 종목 선택 책임

- 파티션은 종목을 직접 소유하지 않고 예산 상한, 캔버스 좌표와 내부 전략 실행 범위를 소유한다. 별도 위험 정책 컬럼은 두지 않으며 위험 통제는 각 전략의 `RISK_POLICY` 블록으로 구성한다.
- 현재 제품에서는 각 전략이 개별 종목을 명시적으로 선택한다. Universe 기반 선택은 향후 실제 기능이 확정될 때 별도 모델·무결성 규칙·마이그레이션으로 도입하며 현재 초안에 선제 저장하지 않는다.
- 같은 파티션 또는 다른 파티션의 여러 전략이 같은 종목을 선택할 수 있다.
- `bot.strategy_instruments`는 완성된 `semantic_document`에서 추출한 불변 종목 의존성 집합이다. 종목의 매매·참조 용도는 타입이 지정된 블록과 연결이 이미 소유하므로 관계 테이블에 역할 문자열을 중복 저장하지 않는다.
- 파티션과 전략은 `display_order`가 아니라 각각의 `position_x`, `position_y`로 배치한다. 좌표 중복은 허용하고 `id`는 동일 좌표 조회의 결정적 타이브레이커로만 사용한다.
- 개별 전략 안의 요소 좌표·크기, 그룹 배치·접힘, 선택 상태, edge routing hint, viewport와 zoom은 `layout_document`에 저장한다. 요소·엣지 키는 실행 의미를 가진 `semantic_document`의 안정 식별자를 참조한다.
- `layout_document`와 `layout_hash`는 UI 화면 복원만 담당하며 의미 해시, 실행 구성 해시, 실행 계획, 검증과 백테스트에 영향을 주지 않는다. 자동 배치는 새 흐름이나 레이아웃이 없는 과거 데이터의 초기값 생성·복구에만 사용한다.
- 편집 중 `bot_workspaces.workspace_document`도 각 전략의 의미 문서와 레이아웃 문서를 분리해 포함하며, 완성 시 안정 요소·엣지 키 참조와 `layout_schema_version`을 검증한다.
- 플랫폼 전략 템플릿은 의미 골격만 제공할 수 있으며, 템플릿으로 흐름을 만들 때 생성된 초기 레이아웃을 새 흐름의 `layout_document`에 저장한다.

### 3. 예산 계층

- 봇의 가상 초기 자본은 생성 시 확정되는 불변 실행 입력이다. 실행 중 입금·출금·증액할 수 없으며 다른 봇이나 계정 공용 Buying Power와 공유하지 않는다.
- 다른 초기 자본으로 운용하려면 새 봇을 생성한다.
- 봇 초기 자본을 기준으로 파티션별 백분율 상한을 둔다.
- 파티션 상한 합계는 100% 이하이며 미배정 자금은 봇 현금으로 남는다.
- 예산은 파티션까지만 할당하며 Basic·Pro 모두 하위 전략에는 예산이나 상한을 배정하지 않는다.
- 같은 파티션의 모든 전략은 해당 파티션의 하나의 예산 경계를 공유한다.
- 사용하지 않은 예산을 형제 파티션이 빌려 쓰지 않는다.
- 파티션에 귀속된 보유 금액과 미체결 주문 예약액을 파티션 상한 사용량에 포함한다.

### 4. 시장가·Buying Power

- 시장가 주문을 IOC 시장성 지정가로 변환하지 않는다.
- 랜덤 슬리피지를 사용하지 않는다.
- 매수에는 `+0.05%`, 매도에는 `-0.05%`의 고정 슬리피지를 사용한다.
- 별도 Buying Power 완충액은 미체결 자금 예약에만 사용하고 체결가격, 손익과 성과에는 반영하지 않는다.
- 완충액은 플랫폼이 관리하는 버전 고정 `buffer_bps`를 기준 주문금액에 적용해 계산한다.
- 체결 시 최신 유효 가격에 고정 슬리피지와 수수료를 적용해 다시 검사한다.
- 전량 Fill에서는 실제 사용액을 소비하고 완충액·남은 차액을 같은 최종 사건에서 해제한다. 부족하면 최초 Order 생성 전에 수량을 축소·거절하고, 이미 OPEN인 주문은 취소 후 더 작은 replacement Order로 교체한다.

추가 근거가 필요한 항목:

- 정확한 `buffer_bps`
- 호가 기준면
- 가격·수수료·수량 정밀도와 반올림

### 5. 동일 종목 주문 충돌

- 같은 평가 주기의 전략들은 동일한 입력 스냅샷을 사용한다.
- 전략별 원래 주문 의도와 판단 근거는 보존한다.
- `(bot_id, partition_id, 종목, 주문계약)` 단위로 같은 방향 의도는 합산하고 반대 방향은 결정론적으로 상계한다.
- 서로 다른 Partition 또는 Bot의 Intent는 같은 사용자 소유라도 통합하지 않는다.
- 상계 후 하나의 정상 전량 Fill은 Order Allocation에 따라 같은 Partition의 Flow로 귀속한다.
- 상계는 예산, 현금, position lot 또는 손익을 형제 Partition으로 이전하지 않는다.

### 6. 완성된 구성으로 봇 생성

- 별도의 봇 구성·파티션·전략 버전 테이블을 만들지 않는다.
- 봇은 포함된 모든 전략이 완성되고 출시 검증을 통과한 뒤에만 생성한다.
- 봇의 실행 수명주기와 운영 건강 상태는 별도로 저장한다. 실행 상태 변화와 데이터 지연·조치 필요·정산 실패가 서로를 덮어쓰지 않는다.
- 봇, 실행 설정, 파티션, 전략과 관계형 의존성은 한 트랜잭션에서 새 식별자로 삽입한다.
- 봇은 완성도와 실행 가능성 검증을 모두 통과한 생성 트랜잭션이 커밋되면 즉시 `RUNNING`으로 시작한다. 수명주기는 `RUNNING -> STOPPING -> STOPPED`만 사용하며 `WAITING`, `PAUSED`, `DRAFT`, `LOCKING`, `ENDED` 상태는 두지 않는다. `STOPPED`는 영구 종료다.
- 데이터 지연·조치 필요·정산 실패가 발생해도 수명주기는 `RUNNING`으로 유지하고 실행 차단 Projection만 변경한다. 차단 중에는 신규 전략 평가와 신규 주문 생성을 막되 기존 미체결 주문은 취소하지 않고 그 주문의 체결·만료·거절 등 이후 결과와 필요한 정산을 계속 처리한다. 원인이 해소되어 정상 상태가 확인되면 자동으로 신규 평가를 재개한다.
- 종료된 봇을 일반 목록에서 되돌릴 수 있게 숨기는 것은 실행 상태가 아니라 `archived_at`으로 관리한다.
- 사용자의 삭제는 `deleted_at`을 기록하는 논리 삭제로 처리한다. 보관 후 삭제와 즉시 삭제를 모두 허용하지만, 실행 중 삭제 요청은 먼저 멱등적인 중단·정산 절차를 거쳐 `STOPPED`가 된 뒤에만 삭제를 확정한다. 삭제된 봇은 사용자가 복구할 수 없으며 실제 물리 제거와 공식 주문·체결·원장·사건·증거의 보존은 별도 보존·법적 정책으로 관리한다.
- 생성된 실행 의미는 처음부터 불변이며 별도의 `locked_at`이나 잠금 사건을 두지 않는다. 다만 봇 이름과 알림 설정, 파티션·전략의 `description`, `position_x`, `position_y`는 실행 의미를 바꾸지 않는 표시·운영 정보로서 수정할 수 있다.
- 수정 가능한 표시·운영 정보는 실행 구성 해시와 전략 의미 해시에서 제외한다. 좌표·설명 수정은 새 버전이나 새 봇·파티션·전략을 만들지 않는다.
- 봇의 `edit_sequence`는 버전 이력이나 복사 계보가 아니라 이름·보관·삭제 같은 수정 가능 필드의 동시 수정 충돌을 막는 0부터 시작하는 낙관적 잠금 번호다. 수정이 성공할 때마다 정확히 1 증가하며 `updated_at`에 해당 commit 시각을 기록한다.
- 파티션도 같은 원칙으로 `edit_sequence`와 `updated_at`을 사용하여 이름·설명·좌표의 동시 수정을 보호한다.
- 전략 역시 `edit_sequence`와 `updated_at`을 사용하여 이름·설명·파티션 캔버스 좌표의 동시 수정을 보호한다.
- 복사·붙여넣기는 새 독립 집합을 만들 뿐 원본 봇·파티션·전략과의 연결을 보존하지 않는다.
- 봇에는 `PERSONAL`, `ROOM` 같은 종류를 두지 않는다. 모든 봇은 계정이 소유하는 동일한 객체이며 방·대회 참여는 `competition` 스키마의 별도 참가 관계가 관리한다.
- 방 참가 종료·탈퇴는 참가 관계의 수명주기만 끝내며 봇을 중단하거나 별도 연장 상태로 전환하지 않는다.

현재 정본과의 차이:

- 현재 정본은 별도의 불변 전략 출시 버전을 요구한다.
- 제안은 완성된 현재 구성을 새 봇의 불변 실행 입력으로 삽입하므로 출시·보관·자동 백테스트와 UI의 버전 표시 의미를 다시 정의해야 한다.

### 7. 공식 자동 백테스트

- 공식 자동 백테스트는 개별 전략이 아니라 잠긴 봇 전체 구성을 입력으로 한다.
- 잠긴 봇마다 최대 한 번 생성한다.
- 모든 파티션, 파티션 예산, 전략 블록 묶음, 동일 종목 상계, Buying Power, 슬리피지, 수수료와 회계 규칙을 함께 재현한다.
- 대용량 거래·재생 원장·포지션·계산 시계열은 S3 불변 객체에 두고 PostgreSQL에는 실행 상태, 잠긴 입력, 요약과 무결성 매니페스트를 둔다.
- 라이브 봇의 현금·주문·원장과 백테스트 상태를 공유하지 않는다.

현재 정본과의 차이:

- 현재 정본은 출시 전략 버전당 최대 한 번의 공식 자동 백테스트를 요구한다.
- 자동 백테스트 UI, 출시 실패, 백테스트 불가, 보관과 조회 관계를 봇 전체 구성 기준으로 다시 작성해야 한다.

### 8. 백테스트와 봇 실행의 독립성

- 완성·검증된 봇 집합 생성이 성공하면 자동 백테스트를 큐에 넣고 봇은 백테스트 완료를 기다리지 않고 즉시 실행한다.
- 구성 검증, 자격, 라이브 데이터와 실행 인프라 준비 실패는 봇 시작을 차단한다.
- 백테스트 지연·실패·불가는 사용자에게 표시하지만 봇 상태나 라이브 공식 원장을 바꾸지 않는다.
- 봇 중단도 이미 시작한 백테스트를 취소하거나 결과를 숨기지 않는다.

### 9. 가상 공매도와 시스템 청산

- 서비스는 실제 증권사 주문, 실제 주식 차입 또는 대여기관을 모델링하지 않는다.
- 가상 공매도는 `SHORT` Position Lot, 파티션 담보, 격리 매도대금, 고정 연간 대차료와 손익으로 관리한다.
- 실제 차입 가능 수량, 대여기관과 `BORROW_RECALL` 사건은 생성하거나 저장하지 않는다.
- 공매도 진입 전에는 가상 노출, 최초·유지 담보, 플랫폼 위험 한도와 Regulation SHO Rule 201 가격 제한을 검사한다.
- 전일 정규장 종가 대비 장중 10% 이상 하락하여 Rule 201이 발동하면 유효한 national best bid보다 높은 가격에서만 가상 공매도 Fill을 허용한다. 필수 가격 데이터가 없으면 주문을 차단한다.
- 공매도 매도대금은 파티션의 일반 가용 현금과 분리하고 새 주문의 Buying Power로 사용할 수 없게 한다.
- 열린 SHORT Lot에는 플랫폼이 정한 고정 연간 대차료 정책을 기간별로 적용하고 공식 원장 비용으로 기록한다. 정확한 bps는 별도 승인된 정책 버전에서 정한다.
- 위험 한도 위반, Bot 중단, 대회 종료 또는 데이터 무결성 차단 시 시스템 청산 근거를 남기고 `SYSTEM_*` 주문 의도를 생성한다.
- 데이터 무결성 차단은 청산 필요성을 기록하되 유효한 최신 가격이 확보되기 전에는 낙관적인 가상 Fill을 만들지 않는다.
- 시스템 청산도 사용자 Flow 판단과 구분할 뿐 파티션 전용 Order, 전량 Fill, 원장과 Lot이라는 동일한 공식 거래 경로를 사용한다.
- 실제 차입·반환 의무와 차입 사건 테이블은 두지 않는다.

## 정본 영향 후보

운영자 컴퓨터에서 다음 문서의 실제 최신 상태와 의미 중복을 다시 확인한다.

- `specs/product/summary.md`
- `specs/product/capabilities/capability.strategy.basic.md`
- `specs/product/capabilities/capability.strategy.pro.md`
- `specs/product/capabilities/capability.backtest.automatic.md`
- `specs/product/capabilities/capability.bot.server-execution.md`
- `specs/product/journeys/journey.strategy.author.md`
- `specs/product/journeys/journey.bot.operate.md`
- `specs/scenarios/scenario.strategy.release.md`
- `specs/scenarios/scenario.bot.evaluate.md`
- `specs/policies/policy.strategy.immutable-release.md`
- `specs/product/decisions/decision.data.hybrid.md`
- `specs/ui/ui.strategy.authoring.md`
- `specs/ui/ui.backtest.results.md`
- `specs/ui/ui.bot.operations.md`
- `contracts/business/index.md`
- `contracts/behaviors/index.md`
- `contracts/data/index.md`

## 운영자 컴퓨터 적용 전 체크리스트

1. 저장소·브랜치·HEAD·dirty 상태를 다시 확인한다.
2. `stackcord status --json`으로 실제 정본과 영향 관계를 갱신한다.
3. `stackcord governance check --json`에서 정확한 HEAD와 보호 fingerprint에 대한 `user:kcrmin` 승인을 확인한다.
4. 이 제안과 최신 `db/data-model-decisions.md`, `db/schema.dbml`의 차이를 함께 검토한다.
5. 제품 의미를 먼저 정본 문서에 반영하고 계약·실패 동작·UI 의무를 같은 변경에서 맞춘다.
6. DBML과 마이그레이션은 승인된 정본을 참조하도록 조정한다.
7. 변경된 불변 조건에 대한 실패 우선 테스트와 롤백 계획을 준비한다.
8. fresh exact-commit 승인을 다시 확인한 뒤에만 통합·릴리스 상태로 전환한다.
