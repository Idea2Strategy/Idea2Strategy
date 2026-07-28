# Trading production-readiness proposal

> 상태: 제품 권한 승인 전 격리 제안. `db/schema.dbml` 정본이나 운영 마이그레이션이 아니다.
> 기준 DBML: `proposals/dbml-redesign/schema.draft.dbml`
> 새 정책은 기존 `docs/product-discovery.md`의 부분 체결 전제와 충돌하므로 정본 승인 전 배포할 수 없다.

## 확정한 거래 경계

- Partition이 주문 통합·상계·예산·예약·보유수량·원장·lot·손익의 최상위 거래 격리 경계다.
- 서로 다른 Bot 또는 Partition의 Intent는 종목·방향이 같아도 같은 Batch, Order, Reservation, Fill, Ledger Transaction 또는 Lot 소비 경로에 들어갈 수 없다.
- 같은 Partition 안의 여러 Flow Intent만 하나의 Order로 통합할 수 있다.
- Bot 예산은 전체 상한 검증용이고 주문 승인에는 Partition 예산과 활성 예약만 사용한다. 형제 Partition의 남는 예산이나 lot을 빌리지 않는다.
- 정상 Order는 Fill 없이 `REJECTED`, `CANCELLED`, `EXPIRED`로 끝나거나 정확히 한 정상 Fill로 전량 `FILLED`가 된다.
- 부분 체결, 누적 체결, Fill별 Flow 재배분은 지원하지 않는다.

## 처리 흐름과 트랜잭션 경계

1. Bot Event가 Flow별 `bot.evaluation_runs`와 불변 `trading.order_intents`를 만든다.
2. `(bot_id, partition_id, source_event_id)`당 하나의 `order_intent_batches`가 같은 Partition Intent만 수집한다.
3. `(bot_id, partition_id)` advisory transaction lock을 얻고 `partition_budget_projections` 행을 `FOR UPDATE`로 잠근다.
4. 같은 Partition 안에서만 충돌 처리·상계·통합하고 최종 실행 수량을 확정한다.
5. Partition 예산·Flow 소유 FIFO lot·숏 자원을 검사하고 `resource_reservations`를 만든다.
6. 최신 유효 가격으로 5 bps 고정 슬리피지와 20 bps 수수료를 재계산한다. 부족하면 Order 생성 전에 수량을 축소하거나 거절한다.
7. 불변 Order, `order_intent_allocations`, `order_reservation_allocations`, 최초 Order Event와 Outbox를 한 트랜잭션으로 커밋한다.
8. 정상 체결 시 Order 수량과 같은 Fill 한 건, FILLED 사건, 예약 최종 정산, 원장, lot movement와 Projection watermark를 한 멱등 트랜잭션으로 커밋한다.
9. 취소·만료·거절·replacement는 Fill을 만들지 않고 해당 예약을 전액 해제한다.

### 퍼센트 주문 규모와 재활성화

- 매수·매도 주문 Element의 주문 규모 단위는 퍼센트만 사용한다.
- 매수는 실행 시점 `partition_budget_projections`의 예약 차감 후 가용 현금에 퍼센트를 적용한다. 예: 1,000,000에서 40%를 체결해 600,000이 남으면 다음 적격 실행 상한은 240,000이다.
- 매도는 해당 Flow가 소유한 lot 중 활성 예약을 제외한 매도 가능 소수점 수량에 퍼센트를 적용한다. 다른 Flow·Partition의 lot은 계산에 포함하지 않는다.
- 금액 상한에서 최신 가격, 고정 5 bps 슬리피지, 수수료와 Buying Power 버퍼를 역산하고 허용 수량 정밀도로 내림해 소수점 Order 수량을 만든다.
- 주문 Element별 `minReactivationIntervalSeconds`는 마지막 정상 전량 Fill 시각부터 계산한다. 거절·만료·미체결 Order 생성은 재활성화 시각을 갱신하지 않는다.
- 기간 경과 외에도 동일 Element·종목의 OPEN Order/ACTIVE Reservation 부재와 최소 주문 금액·수량 충족을 함께 검사해 계속 참인 조건의 미세 주문 반복을 차단한다.

`CANCELLED`는 일반 사용자가 요청하는 기능이 아니다. 사용자에게 주문 취소 권한을 제공하지 않고, Bot 중지·실행 차단도 기존 미체결 주문을 취소하지 않으며, 운영자 강제 취소 경로도 두지 않는다. 이 모델에서 서비스가 만드는 `CANCELLED`는 이미 OPEN인 Order를 자동 replacement할 때 불변 원본을 철회하는 전이로만 허용한다. Bot 중지는 신규 평가·신규 Order 생성만 막고 기존 Order가 FILLED·EXPIRED·REJECTED 중 하나로 끝날 때까지 결과 처리를 계속한다.

## DBML에서 직접 강제하는 조건

- `orders`, `order_intent_batches`, `order_intent_allocations`, `fills`에 `partition_id NOT NULL`을 둔다.
- 부모가 제공하는 `(bot_id, partition_id, id)` UNIQUE와 자식의 같은 복합 FK로 파티션 불일치를 차단한다.
- Batch FK는 `(bot_id, partition_id, batch_id)`라 다른 Partition Intent를 담을 수 없다.
- Allocation은 Order와 Intent 양쪽에 `(bot_id, partition_id, ...)` 복합 FK를 사용한다.
- 정상 Fill은 `UNIQUE(order_id)`이며 `(bot_id, partition_id, order_id)`로 Order를 참조한다.
- `PARTIALLY_FILLED`, `PARTIALLY_CONSUMED` enum 값을 제거했다.
- 예약 종료 상태는 금액·수량 모두 `consumed + released = reserved` CHECK를 만족해야 한다.
- ACTIVE 예약은 소비·해제가 모두 0이고, SETTLED 예약은 실제 소비량이 양수이며, RELEASED 예약은 소비량이 0이다.
- `reservation_lot_allocations`는 Reservation과 Lot 양쪽에 `(bot_id, partition_id, flow_id, ...)` 복합 FK를 사용한다.
- replacement는 동일 Partition Order만 참조하고 한 원본 Order당 후속 Order를 최대 하나로 제한한다.
- `fill_allocations`는 제거했다. 하류 Flow 귀속은 `order_intent_allocation_id`로 유지한다.
- Bot 전체 `position_projections`는 `partition_position_projections`로 바꿔 주문 가능 보유량을 Partition별로 계산한다.

## PostgreSQL migration trigger가 필요한 조건

DBML CHECK와 FK만으로 교차 행·시간 순서 불변식을 표현할 수 없으므로 다음은 `DEFERRABLE INITIALLY DEFERRED` constraint trigger로 구현한다.

1. **Order Allocation 보존**
   - Order별 `SUM(allocated_quantity) = orders.requested_quantity`.
   - Intent별 배분 합계가 `final_quantity`를 넘지 않고 Batch 최종화 시 정확히 일치.
   - Order·Intent의 instrument, side, order contract가 통합 가능한지 확인.
2. **전량 Fill과 상태 전이**
   - Fill.quantity가 Order.requested_quantity와 정확히 일치.
   - Fill 삽입 트랜잭션에 같은 Order의 최종 FILLED Event와 Projection이 존재.
   - FILLED Order에는 정상 Fill이 정확히 하나, CANCELLED·EXPIRED·REJECTED Order에는 0개.
   - 허용 전이 밖의 Order Event, sequence gap, 같은 idempotency event의 재적용을 거절.
3. **예약 보존과 일회 정산**
   - Reservation Event를 sequence 순으로 접은 합계가 mutable Reservation 누계·상태와 일치.
   - SETTLED_BY_FILL은 같은 Partition Fill과 해당 Order Allocation에 연결된 Reservation만 사용.
   - Fill 하나가 Reservation을 두 번 정산하거나 종료 Reservation을 다시 소비·해제하지 못함.
4. **원장**
   - `source_type = 'FILL'`이면 같은 Partition 정상 Fill이 반드시 존재.
   - Fill Transaction의 Entry는 같은 Partition Account와 해당 Order의 `order_intent_allocation_id`만 참조.
   - Flow별 gross·fee·settlement 배분 합계가 Fill 총액과 정확히 일치.
   - 같은 통화의 차변·대변 합계가 같고 최소 2개 Entry가 존재.
5. **Position Lot**
   - opening allocation의 Intent가 OPEN_LONG 또는 OPEN_SHORT이고 그 Order에 정상 Fill이 존재해야 Lot 생성 가능.
   - OPEN·CLOSE movement의 allocation이 같은 Partition이며 CLOSE는 같은 Flow FIFO lot만 소비.
   - 활성 lot 예약 합계가 남은 수량을 초과하지 않고 movement의 after 값이 이전 값과 연속.
6. **replacement**
   - 원본 Order가 같은 트랜잭션 또는 이전 사건에서 CANCELLED로 끝난 뒤에만 replacement 접수.
   - 원본 예약은 전액 RELEASED되고 replacement는 새 Reservation·Allocation을 사용.
7. **정정·반전**
   - `fill_adjustments.REVERSAL`은 원 Fill의 경제 효과를 정확히 반대로 기록하고 한 번만 적용.
   - CORRECTION은 Fill 수량을 바꾸지 않으며 원장·lot 조정 사건과 같은 트랜잭션에서 커밋.

이 트리거들은 영향받은 Order·Intent·Reservation·Transaction·Lot ID를 transition table 또는 임시 변경 집합에 모은 뒤 커밋 시 집합 단위로 검사한다. 행마다 전체 테이블을 스캔하지 않는다.

## 동시성·멱등성

- Queue routing과 예약 경합 키는 `bot_id`가 아니라 `(bot_id, partition_id)`다.
- advisory lock 이후 `partition_budget_projections`를 `FOR UPDATE`해 같은 Partition의 이중 예약을 막는다.
- 형제 Partition 상한 합이 100% 이하이므로 다른 Partition을 직렬화하지 않아도 Bot 초기자본을 초과할 수 없다. Bot Projection은 승인 정본이 아니다.
- Batch: `(bot_id, partition_id, source_event_id)` UNIQUE.
- Intent: `(batch_id, intent_key)` UNIQUE.
- Order: `(bot_id, partition_id, order_key)` UNIQUE.
- Fill: `UNIQUE(order_id)`와 `(bot_id, partition_id, provider_fill_key)` UNIQUE.
- Event: 소유 Aggregate별 sequence UNIQUE와 도메인 event key UNIQUE.
- 동일 key 재처리는 기존 결과를 반환하고 새로운 Fill·원장·예약 효과를 만들지 않는다.

## 정밀도와 반올림 제안

- 수량은 `numeric(28,8)`, 가격·금액은 `numeric(24,8)`로 저장하고 이보다 높은 내부 정밀도로 계산한 뒤 저장 경계에서만 반올림한다.
- 슬리피지는 매수 `+5 bps`, 매도 `-5 bps`이며 Fill 기준가격에 한 번 적용한다.
- 수수료는 슬리피지 적용 후 gross의 `20 bps`다.
- Buying Power 버퍼는 예약액 계산에서만 통화 저장 정밀도 단위로 보수적으로 올림하고 Fill·수수료·손익에는 포함하지 않는다.
- Flow 금액 배분은 수량 비율의 정확한 몫을 계산하고 저장 단위 미만 잔여를 largest-remainder 방식으로 배분한다. 동률은 `allocation_rank ASC`가 우선한다.
- `precision_rules_version`과 `allocation_rules_version`이 위 규칙을 고정한다.
- 종목별 최소 수량·가격 tick과 최종 법률·회계 검토가 아직 정본에서 미결정이므로 실제 배포 전 승인된 정책 버전이 필요하다.

## append-only와 mutable Projection

추가 전용 정본:

- `order_intents`, `orders`, `order_intent_allocations`
- `order_events`, `fills`, `fill_adjustments`
- `reservation_events`
- `ledger_transactions`, `ledger_entries`
- `position_lots`, `lot_movements`
- 숏 검사·의무 사건·차입비용·강제 조치

현재 상태이며 삭제 후 재구축 가능한 mutable Projection:

- `resource_reservations`
- `order_state_projections`
- `position_lot_projections`
- `flow_position_projections`, `partition_position_projections`
- `bot_budget_projections`, `partition_budget_projections`

append-only 테이블은 일반 UPDATE/DELETE 권한을 제거하고 correction/reversal 행만 추가한다. Projection은 마지막 event sequence와 hash가 정확히 다음 사건일 때만 CAS 갱신한다.

## 주요 조회 인덱스

- 미완료 주문: `(bot_id, partition_id, status, updated_at)`.
- 파티션 예약 경합·합계: `(bot_id, partition_id, status, created_at)`.
- Flow FIFO lot: `(partition_id, flow_id, instrument_id, opened_at)`.
- Partition 종목 포지션: PK `(partition_id, instrument_id)`.
- 감사 타임라인: Order·Reservation·Lot별 sequence UNIQUE, Bot Event별 복합 조회 인덱스.
- 멱등 쓰기: Batch, Intent, Order, Fill, Reservation Event의 각 도메인 key UNIQUE.

부분 인덱스와 `INCLUDE`는 DBML 표현력이 부족하므로 migration에서 실제 조회 계획을 기준으로 다음을 추가한다.

- `order_state_projections ... WHERE status IN ('PENDING','OPEN')`
- `resource_reservations ... WHERE status = 'ACTIVE'`
- `position_lot_projections ... WHERE remaining_quantity > 0`

## 예시 흐름

### 일반 주문 성공

- P1 Flow A가 AAPL `2.00000000`주, Flow B가 `1.12110526`주 BUY Intent를 만든다.
- P1 Batch만 두 Intent를 모아 Order `3.12110526`주와 같은 합계의 Allocation 두 건을 만든다.
- 기준가 100, Fill가 100.05, gross 312.26658126, 수수료 0.62453316이라면 실제 소비는 312.89111442다.
- 예시 예약 312.92240353 중 312.89111442를 소비하고 버퍼 0.03128911을 같은 SETTLED_BY_FILL 사건에서 해제한다.
- Fill은 `3.12110526`주 한 건뿐이며 원장·lot은 두 Allocation을 기준으로 Flow A/B에 결정적으로 귀속된다.

### 예산 부족 사전 축소

- Flow가 가용 예산의 40%로 계산한 `3.12110526`주를 요청했지만 최신 가격 재검사에서 P1 예산으로 `2.80411573`주만 가능하다.
- Intent에는 requested `3.12110526`, approved/final `2.80411573`과 REDUCED 사유를 보존한다.
- 처음부터 Order·Allocation·Reservation을 `2.80411573`주 기준으로 만들고 정상 Fill도 정확히 `2.80411573`주 한 건만 생성한다.
- Order `3.12110526`주에 Fill `2.80411573`주를 연결하지 않는다.

### 대기 지정가 주문 replacement

- 기존 P1 LIMIT Order `3.12110526`주가 OPEN 상태다.
- 자동 재검사 결과 P1 예산으로 `2.80411573`주만 가능하면 원본을 시스템이 CANCELLED 처리하고 예약을 전액 해제한다.
- `replaces_order_id = 원본`인 새 `2.80411573`주 Order와 새 예약·Allocation을 만든다.
- 새 Order는 `2.80411573`주 전량 Fill 또는 미체결 종료만 가능하다. 사용자, Bot 중지, 운영자는 이 전이를 직접 요청할 수 없다.

### 취소·만료·거절

- CANCELLED: 자동 replacement가 기존 OPEN Order를 철회할 때만 발생한다.
- EXPIRED: Order의 유효기간 또는 거래 세션이 끝났지만 체결되지 않았을 때 발생한다.
- REJECTED: 유효성·예산·정밀도·시장 규칙 검사 또는 제출 대상의 접수 검사에서 Order를 받아들이지 못했을 때 발생한다.
- Order 종료 사건과 같은 트랜잭션에서 정상 Fill이 0건인지 확인한다.
- ACTIVE Reservation은 소비 0, 해제 = reserved로 RELEASED가 된다.
- CANCELLED, EXPIRED, REJECTED Order에 이후 Fill을 삽입하면 지연 트리거가 커밋을 거절한다.

## 안전한 migration 순서

1. 운영 쓰기 경로와 관련 worker 버전을 고정하고 DB snapshot·PITR 복구 지점을 만든다.
2. 사전 검사로 부분 상태, Order당 다중 Fill, Fill/Order 수량 불일치, 파티션을 유일하게 역추적할 수 없는 행, 예약 보존 불일치를 분류한다.
3. 새 `partition_id`와 새 귀속 컬럼을 nullable로 추가하고 기존 Intent→Flow→Partition 경로에서 backfill한다.
4. 새 UNIQUE 인덱스를 `CONCURRENTLY`, FK를 `NOT VALID`로 추가한 뒤 검증한다.
5. `fill_adjustments`, 새 파티션 Position Projection과 새 Reservation 상태를 side-by-side로 배포한다.
6. 새 코드가 구·신 구조를 비교 기록하되 정본 효과는 한 경로만 쓰는 shadow 검증 기간을 둔다.
7. 호환 가능한 과거 Fill은 각 Order의 유일 전량 Fill인지 확인해 전환한다. 비호환 부분 체결 이력은 자동 합치거나 삭제하지 않고 migration을 중단해 별도 승인된 변환 정책을 요구한다.
8. 모든 지연 트리거와 append-only 권한을 설치하고 FK 검증 후 `partition_id NOT NULL`을 적용한다.
9. 읽기와 쓰기를 새 구조로 전환하고 Projection을 정본 사건에서 재구축해 hash·합계를 대조한다.
10. 안정화·감사 승인 뒤에만 `fill_allocations`, 이전 컬럼과 enum 값을 제거한다.

## rollback

- 8단계 전: 새 쓰기를 중단하고 애플리케이션을 이전 버전으로 되돌린 뒤 새 nullable 컬럼·shadow 테이블을 제거할 수 있다.
- 8~10단계: 새 구조 쓰기를 중단하고 보존한 이전 테이블·컬럼으로 전환한다. 전량 Fill은 Order Allocation 비율로 이전 `fill_allocations`를 결정적으로 재구성할 수 있다.
- 10단계 후: 자동 down migration을 제공하지 않는다. 새 거래를 차단하고 검증된 snapshot/PITR로 복구한 뒤 Outbox를 재처리한다.
- 어떤 rollback도 Fill, 원장, lot 사건을 임의 삭제하거나 재작성하지 않는다.

## 제거·이름 변경 영향

- 제거: `trading.fill_allocations`, `PARTIALLY_FILLED`, `PARTIALLY_CONSUMED`.
- 컬럼 교체:
  - `reservation_events.source_fill_allocation_id` → `source_fill_id`
  - `ledger_entries.fill_allocation_id` → `order_intent_allocation_id`
  - `position_lots.opening_fill_allocation_id` → `opening_order_intent_allocation_id`
  - `lot_movements.source_fill_allocation_id` → `source_order_intent_allocation_id`
- 이름 변경: `position_projections` → `partition_position_projections`.
- 추가: `fill_adjustments`는 정상 Fill과 분리된 correction/reversal 사건이다.
- 코드·API·Projection builder·성과 계산·알림·UI의 부분 체결 상태와 기존 FK 이름을 함께 제거해야 한다. 현재 UI에 부분 체결 문구가 남아 있으므로 DB만 먼저 배포하면 안 된다.

## 남아 있는 위험과 배포 차단 사항

- 새 정책과 기존 정본 제품 문서·UI의 부분 체결 의미가 충돌한다.
- 과거 부분 체결 데이터가 실제로 존재하면 무손실 자동 변환 정책이 없다.
- 종목별 tick/lot size, stale quote 시간, 숏 담보·차입비용, 기업행사 회계 공식이 미승인이다.
- DBML은 지연 트리거, 부분 인덱스, append-only 권한, RLS와 online migration DDL을 직접 표현하지 못한다.
- 실제 PostgreSQL migration, trigger 함수, 실패 우선 통합 테스트와 운영 부하 테스트는 아직 구현되지 않았다.

따라서 이 산출물은 production-ready한 **논리 설계 제안**이지만, fresh 제품 권한 승인과 실제 migration/TDD 증거 없이는 production release candidate가 아니다.
