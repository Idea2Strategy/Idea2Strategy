# F 중단 정산·기업행사 적용의 canonical 표현 제안

- 상태: **격리된 제안 — 제품 정본 아님**. 승인 전에는 통합·출시 대상이 아니다.
- 작성일: 2026-08-02
- 제안자: 민경철 (`kcrmin`, F 담당)
- 기준 저장소: `Idea2Strategy/Idea2Strategy`
- 기준 브랜치: `develop`
- 기준 커밋: `8c7a5e1`
- 기준 Stackcord fingerprint: `sha256:65b40c52947bc8530e1fe224bea9e5b0c9914fb6d33c366c2fcccc7f685b4736`
- 관련 이슈: 부모 F [#28](https://github.com/Idea2Strategy/Idea2Strategy/issues/28),
  F-CAN03 [#80](https://github.com/Idea2Strategy/Idea2Strategy-trading-engine/issues/80),
  F16 [#61](https://github.com/Idea2Strategy/Idea2Strategy-trading-engine/issues/61)

이 문서는 `db/schema.dbml`을 수정하지 않는다. 승인된 뒤에 별도 변경으로 반영한다.

---

## 왜 이 제안이 필요한가

F 쓰기 경로를 canonical 스키마로 옮기는 작업(F-CAN03) 중, canonical 모델이
**표현하지 못하는 제품 의미 두 가지**를 확인했다. 나머지 쓰기 경로는 canonical로
그대로 옮길 수 있다. 이 두 가지만 canonical에 대응하는 자리가 없다.

두 항목 모두 이미 구현되어 병합된 기능(F13, F14)의 의미이므로, 제안의 성격은
새 기능 추가가 아니라 **이미 승인된 제품 행동을 canonical이 담을 수 있게 하는 것**이다.

---

## 제안 1. 봇 중단 정산의 진행 상태를 canonical에 남긴다

### 현재 canonical이 가진 것

`bot.bots`

```
lifecycle_status        bot.lifecycle_status  (RUNNING | STOPPING | STOPPED)
stop_requested_at       timestamptz
stopped_at              timestamptz
stop_reason_code        varchar(80)
execution_blocked_at    timestamptz
execution_block_reason_code varchar(80)
execution_block_event_id    uuid
edit_sequence           bigint
```

`trading.system_close_actions` — 강제 청산 **근거** 1행/종목. `reason_type`에
`BOT_STOP`이 있다.

### F14가 실제로 요구하는 것

중단은 순서가 있는 다단계 절차이고 각 단계가 실패·부분 성공할 수 있다.

```
REQUESTED -> BLOCK_NEW_WORK -> CANCEL_ORDERS_AND_RELEASE -> LIQUIDATE_POSITIONS -> STOPPED
                                                                              \-> SETTLEMENT_FAILED
```

각 단계 결과는 `COMPLETED | PARTIAL | RETRYABLE | TERMINAL_FAILURE`다.

### 대응 관계

| F14 개념 | canonical 대응 | 판정 |
| --- | --- | --- |
| `StopReason`, `requestedAt`, 최종 `STOPPED` | `stop_reason_code`, `stop_requested_at`, `stopped_at` | 표현 가능 |
| `BLOCK_NEW_WORK` 완료 | `execution_blocked_at` 또는 `lifecycle_status='STOPPING'` | 근사 가능 |
| **`ORDERS_CLEANED` 체크포인트** | 없음 | **불가** |
| **`LIQUIDATING` 체크포인트** | 없음 | **불가** |
| **`SETTLEMENT_FAILED` 상태 + 실패 단계 + 사유** | 없음 | **불가** |
| **단계별 재시도 attempt 기록** | 없음 | **불가** |
| **낙관적 동시성 version** | `edit_sequence`는 표현 편집 전용 | **불가** |

### 이것이 막는 구체적 결과

`BotStopOrchestrator.resumeRecoverable()`은 프로세스 재기동 뒤 미완료 정산을
읽어 **중단된 지점부터** 재개한다. canonical에는 그 지점을 적을 자리가 없으므로
읽어올 수 있는 최선은 `lifecycle_status = 'STOPPING'` 뿐이고, 이는
`ORDERS_CLEANED`인 봇과 `LIQUIDATING`인 봇을 구분하지 못한다. 재개가 항상 첫
단계로 되돌아가고 `BotStopSettlement.requireMutableStep`이 예외를 던진다.

즉 **F16 이슈 #61의 "프로세스 재기동 뒤에도 동일한 공식 상태를 보장한다"가
canonical 위에서는 성립하지 않는다.** 이것이 F16 완료를 막는 유일한 구조적
장애물이다.

### 제안하는 최소 추가

새 테이블을 만들지 않는다. `trading.bot_stop_settlement`의 `bot_id`가 이미
unique(봇당 정산 1건)이므로 `bot.bots.id`가 곧 정산 키다.

`bot.bots`에 컬럼 4개를 추가한다.

```
stop_checkpoint          varchar(32)
    REQUESTED | WORK_BLOCKED | ORDERS_CLEANED | LIQUIDATING | STOPPED | SETTLEMENT_FAILED
    중단 절차가 시작되지 않은 봇은 NULL.

stop_settlement_version  bigint
    중단 정산 전용 낙관적 동시성 번호. 표현 편집용 edit_sequence와 분리한다.

stop_failed_step         varchar(40)
    BLOCK_NEW_WORK | CANCEL_ORDERS_AND_RELEASE | LIQUIDATE_POSITIONS

stop_terminal_reason     text
```

무결성 제약

```
CHECK (
  (stop_checkpoint = 'SETTLEMENT_FAILED'
     AND stop_failed_step IS NOT NULL AND stop_terminal_reason IS NOT NULL)
  OR
  (stop_checkpoint IS DISTINCT FROM 'SETTLEMENT_FAILED'
     AND stop_failed_step IS NULL AND stop_terminal_reason IS NULL)
)
CHECK (stop_checkpoint IS NULL OR stop_settlement_version > 0)
```

복구 조회용 부분 인덱스

```
(stop_checkpoint) WHERE stop_checkpoint IS NOT NULL
                    AND stop_checkpoint NOT IN ('STOPPED', 'SETTLEMENT_FAILED')
```

이 인덱스가 `resumeRecoverable()`의 질의를 그대로 만족시킨다.

### 재시도 감사 기록 (선택)

`operationId`는 `uuid5(settlementId, step)`로 이미 결정적이라 **멱등성에는 이
테이블이 필요 없다**. `PARTIAL`/`RETRYABLE` 시도 이력을 남길 필요가 있을 때만
추가하면 된다.

```
bot.bot_stop_step_attempts
  bot_id            uuid    not null
  resulting_version bigint  not null
  operation_id      uuid    not null
  step              varchar(40) not null
  result_status     varchar(20) not null   -- COMPLETED|PARTIAL|RETRYABLE|TERMINAL_FAILURE
  detail            text    not null
  occurred_at       timestamptz not null

  indexes {
    (bot_id, resulting_version) [pk]
    (operation_id)
  }
```

**판단이 필요한 지점:** 이 테이블을 지금 넣을지, 아니면 체크포인트 4컬럼만으로
시작할지. 4컬럼만으로도 F16의 재기동 복구는 성립한다.

---

## 제안 2. 기업행사 적용의 승인 봉투를 canonical에 남긴다

### 현재 canonical이 가진 것

`market_data.corporate_actions` — 기업행사 **시장 데이터 사실**.

```
instrument_id, source_manifest_id, provider_event_key, action_type,
effective_at, terms_document, terms_hash, supersedes_action_id
```

`trading.lot_movements.corporate_action_id` + `movement_type =
'CORPORATE_ACTION_ADJUSTMENT'` — 로트별 **적용 결과**.

### 무엇이 없는가

로트별 결과는 표현되지만, **어떤 운영자가 언제 승인해 어느 봇에 한 번 적용했는가**를
담을 자리가 없다. F13이 구현한 `execution_corporate_action_application`은 다음을
가진다.

```
approval_id          unique      -- 승인 식별자
approved_by_operator_id
approved_at
request_fingerprint  unique      -- 멱등 재적용 차단
policy_version
evidence_digest
adjusted_lots / adjusted_flow_positions / ledger_effect
applied_at
```

`market_data.corporate_actions`는 시장 데이터라 운영자·승인·봇별 적용 개념이
없고, 있어서도 안 된다(D 담당 영역의 ingest 기록이다).

### 이것이 막는 구체적 결과

**같은 기업행사를 같은 봇에 두 번 적용하는 것을 canonical이 막지 못한다.**
멱등 fingerprint를 저장할 자리가 없기 때문이다. 분할이 두 번 적용되면 포지션
수량과 원가가 조용히 어긋난다.

또한 "승인된 기업행사만 적용한다"는 F13 요구(임의 AI 결과 사용 금지)의 근거인
운영자 승인 기록이 남지 않는다.

### 제안하는 최소 추가

`trading` 스키마(F 소유)에 적용 헤더 테이블 하나를 추가한다.

```
trading.corporate_action_applications
  id                       uuid pk
  bot_id                   uuid not null
  corporate_action_id      uuid not null   -- market_data.corporate_actions
  approval_id              uuid not null
  approved_by_operator_id  uuid not null
  approved_at              timestamptz not null
  request_fingerprint      varchar(128) not null
  policy_version           varchar(40)  not null
  evidence_digest          varchar(128) not null
  applied_at               timestamptz not null

  indexes {
    (bot_id, corporate_action_id) [unique]   -- 봇당 행사 1회 적용
    (approval_id) [unique]
    (request_fingerprint) [unique]
    (bot_id, applied_at)
  }
```

그리고 `trading.lot_movements`에 nullable FK 한 개를 더한다.

```
corporate_action_application_id uuid   -- trading.corporate_action_applications
CHECK (movement_type <> 'CORPORATE_ACTION_ADJUSTMENT'
       OR corporate_action_application_id IS NOT NULL)
```

이렇게 하면 로트 이동이 시장 데이터 사실(`corporate_action_id`)과 승인 봉투
(`corporate_action_application_id`) 양쪽을 모두 증명한다.

**판단이 필요한 지점:** `adjusted_lots`·`adjusted_flow_positions`·`ledger_effect`
같은 집계 필드는 `lot_movements`에서 재계산 가능하므로 제외했다. 감사 목적으로
고정 저장이 필요하면 다시 넣는다.

---

## 제안하지 않는 것

조사 과정에서 확인했지만 **canonical 변경이 필요 없다고 판단한** 항목을 함께
남긴다. 승인 범위를 좁히기 위해서다.

- **복식 원장 균형 강제**, **대차료 기간 겹침 차단** — canonical이 이미 명시한
  불변식인데 강제되지 않고 있었다. 제품 의미 변경이 아니므로 trading 기여
  migration으로 이미 처리했다(trading PR #84, 루트 PR #116).
- **예약 크기 변경(resize)** — canonical `reservation_event_type`에 대응 값이
  없지만, `db/schema.dbml`이 이미 "원본 예약을 전액 해제하고 replacement Order를
  만든다"고 규정한다. 구현을 canonical 의미에 맞추면 되므로 스키마 변경이 아니다.
- **`bot.bot_events` 쓰기 권한** — `docs/backend-and-aws-architecture.md`의
  테이블별 쓰기 책임표와 `DatabaseAccessPolicy`가 이미 trading-engine 소유로
  규정한다. 새 권한이 필요 없다.
- **주문 의도·주문·예약·체결·원장·포지션·예산 projection의 쓰기 경로 이전** —
  canonical에 전부 대응 테이블이 있다. 코드 작업이며 스키마 변경이 아니다.

---

## 승인 후 진행 순서

1. 승인된 범위만 `db/schema.dbml`에 반영한다(별도 변경).
2. `bot` 스키마 변경은 backend 소유 migration, `trading` 스키마 변경은
   `db/migration-contributions/migrations` 기여로 각각 올린다.
3. `PostgresBotStopSettlementStore`와 기업행사 저장소를 canonical로 이전한다.
4. F16의 재기동 복구 E2E를 canonical 위에서 완성한다.

## 승인이 필요한 판단 목록

1. 제안 1의 `bot.bots` 컬럼 4개 추가 — 수용 / 수정 / 거절
2. 제안 1의 `bot.bot_stop_step_attempts` 테이블 — 지금 포함 / 나중 / 불필요
3. 제안 2의 `trading.corporate_action_applications` 테이블 — 수용 / 수정 / 거절
4. 제안 2의 `lot_movements.corporate_action_application_id` FK — 수용 / 거절
5. 제안하지 않기로 한 4개 항목의 판단에 동의하는지
