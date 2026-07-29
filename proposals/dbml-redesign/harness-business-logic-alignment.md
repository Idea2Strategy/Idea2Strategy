# 하네스 정본과 DBML 비즈니스 로직 정렬 제안

상태: 제품 권한 검토가 필요한 격리 제안. 승인된 `specs/**`, `contracts/**` 또는 `db/schema.dbml`을 대체하지 않는다.

기준: 2026-07-29 `origin/develop`을 fetch한 뒤 추적 중인 `.harness/**`, `specs/**`, `contracts/**` 전체와 현재 DBML 제안을 대조했다. `stackcord governance check --json`은 fresh provider 승인 증거를 찾지 못해 `unknown`이므로 보호 정본은 수정하지 않았다.

## 정렬 원칙

1. 제품 의미는 승인 전까지 이 문서와 `schema.draft.dbml`에만 격리한다.
2. Strategy는 수정 가능한 설계 원본이고 Bot은 출시 시점의 독립 실행 스냅샷이다.
3. Bot은 원본 Strategy, Package, Template 또는 복사 원본을 역추적하는 FK와 계보를 저장하지 않는다.
4. 거래·예산·예약·Position Lot·원장 격리 경계는 Bot이 아니라 Partition이다.
5. 실행 의미와 회계 증거는 불변으로 보존하고 description·좌표·layout 같은 presentation만 수정 가능하다.
6. 대용량 불변 상세는 S3 객체로, 관계·상태·해시·매니페스트는 PostgreSQL로 관리한다.

## 보호 정본 충돌과 제안된 대체 의미

| 보호 정본 | 현재 문구 또는 전제 | 확정된 대체 의미 | DBML 제안 반영 |
| --- | --- | --- | --- |
| `policy.strategy.immutable-release` | 출시 Strategy와 실행 Bot 모두 수정 불가, 변경 시 새 Bot | Bot의 실행 semantic은 불변이지만 이름, description, Partition·Flow 좌표와 Flow 내부 presentation은 수정 가능. Strategy는 계속 편집 가능 | `strategy.strategy_documents`, `bot.launch_snapshots`, `edit_sequence` |
| `capability.backtest.automatic` | 출시 Strategy 버전당 자동 백테스트 한 건 | Bot 생성 시 최초 자동 Run 한 건을 만들고 이후 같은 Bot으로 서로 다른 기간의 Run을 여러 건 생성 가능 | `backtest.runs.bot_id` 비유일, 기간·입력별 Run |
| `scenario.strategy.release` | 불변 Strategy 버전을 생성하고 단일 백테스트 시작 | 현재 Strategy를 검증한 뒤 출처 관계 없는 독립 Bot 스냅샷을 원자 생성하고 최초 자동 백테스트를 큐에 등록 | Bot launch 계층과 Backtest 1:N |
| `role.room-participant` | 기존 독립 Bot을 Room에 제출 | 사용자가 Strategy를 선택하면 서버가 독립 새 Bot과 Participation을 한 트랜잭션으로 생성 | `competition.participations.bot_id`, 생성 함수 요구사항 |
| `capability.room.bot-comparison` | 공통 Room 비교만 정의 | LIVE_PAPER와 공식 BACKTEST를 공통 Room 아래 구분. 한 계정은 한 Room에 여러 Bot 참가 가능 | `competition_type`, `per_account_bot_limit` |
| `scenario.room.finish` | 종료 시 미체결 주문 취소 | Bot 중지와 Room 종료는 기존 미체결 주문을 취소하지 않음. 신규 평가·주문만 중단하고 체결·만료·거절·예약 해제·정산을 계속 처리 | `STOPPING`, `order_events`, `resource_reservations` |
| `ui.bot.operations` | `waiting` 상태 필수 | Bot 수명주기는 `RUNNING → STOPPING → STOPPED`만 사용. 평가 전 실행 차단은 `execution_eligible_from`, 장애 차단은 별도 projection | `bot.bots.execution_eligible_from` |
| `ui.room.lifecycle` | `submission`, `waiting` 상태 필수 | Room은 `DRAFT`, `RECRUITING`, `EVALUATING`, terminal 상태를 사용하고 참가 가능 여부는 일정으로 판단 | Competition enum·schedule |
| `journey.backtest.review` | 출시 Strategy의 월별 결과 검토 | Bot별 여러 Run 이력을 기간별로 검토하고 Competition 상세는 Room `ENDED` 뒤 소유자에게만 공개 | Backtest Run 1:N, S3 detail manifests |
| `policy.privacy.strategy-private` | 타 사용자·운영자의 상세 접근 금지 | 그대로 유지. 공식 BACKTEST 종료 후에도 상세 주문·판단은 해당 Participation 소유자만 조회하며 운영자 접근은 별도 감사 권한 필요 | Competition 공개 게이트와 audit 요구사항 |
| `policy.user.no-direct-orders` | 사용자의 직접 주문 금지 | 그대로 유지하며 사용자 주문 취소도 금지. 정상 `CANCELLED`는 자동 replacement 시스템 전이에만 사용 | Trading order 상태 정책 |
| `journey.operator.administer` | 권한 있는 고영향 운영 | 운영자도 비정상 주문을 임의 강제 취소할 수 없음. 운영 조치는 증거·차단·조사에 한정 | Trading production-readiness 요구사항 |

## 공식 백테스팅 대회 규칙

- 플랫폼만 공식 BACKTEST Room을 생성할 수 있다.
- 공식·사용자 LIVE_PAPER Room은 평가 시작 뒤 참가할 수 없다.
- 공식 BACKTEST Room은 `participation_closes_at` 전까지 평가 중에도 참가할 수 있다. 미입력 시 논리적 기본값은 `evaluation_ends_at`이다.
- Strategy 선택 시 독립 Bot과 Participation을 원자 생성한다. 평가 전에 생성된 Bot은 `execution_eligible_from = evaluation_starts_at`이며 별도 waiting 상태를 만들지 않는다.
- 하나의 계정은 `per_account_bot_limit`까지 여러 Bot을 참가시킬 수 있다.
- 평가 중 승인된 공식 BACKTEST Participation은 취소·교체할 수 없고 성공·실패와 관계없이 종료까지 슬롯을 점유한다.
- 평가 계획은 겹치지 않는 최소 두 기간, 양수 중요도 가중치, 정확한 가중치 합 1을 가진다.
- 각 기간은 동일 초기 자금과 빈 주문·예약·Position·원장·Flow 상태에서 독립 실행한다.
- 기간별 원래 지표에 중요도 가중치를 적용하고 0~100 기간 점수는 만들지 않는다.
- 초기 자금, 수수료·고정 0.05% 슬리피지 정책, 채점 공식과 계산 버전은 항상 공개한다.
- 기간·가중치·Dataset Manifest·전체 계획은 Room `ENDED` 뒤 공개하며, 잠금 시 commitment hash로 중간 변경 여부를 증명한다.
- 모든 기간 결과가 검증된 Bot의 최종 점수와 현재 순위는 즉시 공개하지만 기간별 점수와 상세 판단은 종료 전 숨긴다.

## Trading 계약 제안

현재 `contracts/registry.yaml`에는 등록된 계약이 없다. 정본 변경 권한 확인 뒤 다음 계약을 별도 stable ID로 추가해야 한다.

1. **Partition 거래 격리 계약**: 서로 다른 사용자·Bot·Partition의 Intent, Order, Reservation, Fill, Ledger, Position Lot을 연결하거나 상계하지 않는다.
2. **단일 정상 Fill 계약**: Order는 Fill 없이 거절·만료·시스템 replacement 취소되거나, 요청 소수점 수량과 정확히 같은 정상 Fill 한 건만 가진다.
3. **예약 보존 계약**: terminal 예약은 금액 또는 수량 기준 `consumed + released = reserved`를 만족한다.
4. **주문 구성 계약**: `order_components.component_quantity` 합계는 `orders.requested_quantity`와 같고 모든 Component는 같은 Partition의 Intent만 참조한다.
5. **중지 계약**: Bot 중지는 신규 평가·신규 주문만 막고 기존 주문을 취소하지 않는다.
6. **공개 계약**: 공식 BACKTEST의 공개 규칙과 비공개 계획·소유자 상세의 권한 경계를 강제한다.

## 미결정 또는 출시 차단 상태 유지

다음 항목은 이번 제안이 임의로 확정하지 않는다.

- 정확한 Buying Power buffer bps와 호가 기준면
- 종목별 가격·수량·수수료 반올림 공식
- 공매도 담보·대차료 정책의 정확한 수치와 법률 검토
- 시장 데이터 공급자·저장·재배포 권리
- 운영 SLO, 보존 기간, 백업·복구 목표

이 항목은 기존 open question과 `policy.legal.block-uncertain`에 따라 승인된 근거가 생기기 전 production release를 차단한다.

## 정본 반영 순서 제안

1. fresh GitHub provider 관찰로 정확한 HEAD와 보호 fingerprint에 대한 `user:kcrmin` 권한을 확인한다.
2. 위 충돌 문서와 UI 상태를 먼저 같은 제품 의미로 갱신한다.
3. product, business, behavior, interface, data 계약을 등록하고 failure behavior를 명시한다.
4. 승인된 의미에 맞춰 `db/schema.dbml`을 제안본에서 승격한다.
5. PostgreSQL migration·deferred trigger·RLS·append-only 권한을 실패 우선 테스트와 함께 구현한다.
6. dual-read/backfill/검증/rollback 순서가 검증된 뒤 애플리케이션 쓰기 경로를 전환한다.
