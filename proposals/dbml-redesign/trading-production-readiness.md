# Trading production-readiness proposal

> 상태: 제품 권한 승인 전 격리 제안. `db/schema.dbml` 정본이나 운영 마이그레이션이 아니다.

## 처리 경계

1. `bot.evaluation_runs` 또는 시스템 안전 사건이 `order_intent_batches`와 불변 `order_intents`를 만든다.
2. 같은 Bot의 batch finalization은 `bot_id` advisory transaction lock 아래 예산 검사, 보유수량 검사, 숏 검사, 충돌 해소와 상계를 결정론적으로 수행한다.
3. 상계 후 잔여 의도만 `resource_reservations`를 만든다. 현금은 Bot 다음 Partition 순서로 잠그고, 보유수량은 Flow의 FIFO lot 순서로 잠근다.
4. 주문 계약, `order_intent_allocations`, `order_reservation_allocations`, 최초 주문 사건과 outbox를 한 PostgreSQL 트랜잭션에서 커밋한다.
5. 각 부분 체결은 최신 유효 가격으로 고정 5 bps 슬리피지와 공식 20 bps 수수료를 재계산한다. 부족하면 체결 전에 수량을 축소하거나 거절한다.
6. Fill, Fill allocation, 예약 소비·해제 사건, 원장 트랜잭션·분개, lot movement와 Projection watermark를 하나의 멱등 트랜잭션에서 커밋한다.
7. 취소·만료·거절은 체결되지 않은 예약 잔량을 같은 사건에서 해제한다. 재처리는 기존 idempotency key와 sequence를 확인하고 같은 경제 사건을 두 번 반영하지 않는다.

## PostgreSQL 마이그레이션에서 반드시 강제할 조건

- 주문별 `order_intent_allocations.allocated_quantity` 합계가 `orders.requested_quantity`와 같다.
- 의도별 주문 배분 합계가 `order_intents.final_quantity`를 넘지 않으며 제출 완료 시 정확히 같다.
- Fill별 배분 수량·gross·fee 합계가 Fill 값과 정확히 같다.
- Fill allocation이 같은 Order의 `order_intent_allocation`만 참조한다.
- 예약의 소비 + 해제가 최초 예약을 넘지 않고 종료 상태에서는 정확히 같아진다.
- 활성 `POSITION_QUANTITY` 예약 합계가 해당 lot 잔량을 넘지 않는다.
- `resource_reservations`와 연결된 Intent의 Bot·Partition·Flow 소유가 모두 같다.
- Transaction마다 동일 통화 차변 합계와 대변 합계가 같고 최소 두 Entry가 존재한다.
- Ledger Entry의 Account와 Transaction이 같은 Bot에 속한다.
- Lot movement의 직전 `remaining_after`·`cost_basis_after`와 다음 movement가 연속된다.
- Flow lot FIFO 밖의 CLOSE 배분은 거부한다.
- `OPEN_SHORT`는 승인된 `short_trade_checks`, 차입수량 예약과 담보 예약을 모두 가져야 한다.
- SHORT lot의 반환수량은 차입수량을 넘지 않고, 격리 매도대금은 일반 가용현금으로 계산되지 않는다.
- Projection update는 저장된 마지막 Bot event sequence보다 큰 사건만 적용하며 sequence/hash 불일치 시 Bot 신규 평가를 차단한다.

합계·교차행 조건은 단순 `CHECK`로 충분하지 않으므로 `DEFERRABLE INITIALLY DEFERRED` constraint trigger와 트랜잭션 테스트로 구현한다.

## 장애 및 복구

- 공식 정본은 Intent, Order event, Fill, Reservation event, Ledger, Lot movement다.
- `order_state_projections`, `position_lot_projections`, 포지션·예산 Projection은 모두 삭제 후 재생성 가능해야 한다.
- Projection 재구축 중 신규 평가만 차단하고 기존 주문 취소, 체결 반영, 예약 해제와 원장 정산은 계속한다.
- 서버 장애 시 미체결 주문을 플랫폼 장애 사유로 취소하고 예약을 해제한다. 놓친 평가나 체결을 소급 생성하지 않는다.
- outbox publish 실패는 같은 PostgreSQL 커밋을 되돌리지 않으며 멱등 재전송한다.

## 아직 운영 배포를 막는 외부 결정

- 가격·수량·금액의 종목별 최소 단위와 정확한 반올림 규칙
- 유효 호가의 기준면과 stale 판정 시간
- Pro 숏 추가 담보의 구간·비율과 차입비용 일할 계산식
- 기업행사별 원장·로트 조정 공식

이 값들은 DB 컬럼에 임의 상수로 넣지 않고 승인된 정책 버전과 해시로 고정한다.
