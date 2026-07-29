# Competition schema PostgreSQL implementation requirements

상태: DBML 재설계 격리 제안. 제품 정본 승인 또는 운영 마이그레이션이 아니다.

## Room 유형과 주최자 무결성

- `BACKTEST` Room은 `PLATFORM`만 허용한다.
- `PLATFORM`은 `created_by_operator_id`, `USER`는 `creator_account_id`만 가진다.
- `LIVE_PAPER` Room에는 `live_room_rules`가 정확히 하나 존재하고 `BACKTEST` Room에는 존재하지 않는다.
- `BACKTEST` Room에는 잠긴 `backtest_evaluation_plans`가 정확히 하나 존재하고 `LIVE_PAPER` Room에는 존재하지 않는다.
- 위 하위 타입 존재 조건은 Room 잠금 트랜잭션의 deferred constraint trigger로 검증한다.

## 일정과 참가 마감

`competition.room_schedules.participation_closes_at`의 논리적 기본값은 `evaluation_ends_at`이다. PostgreSQL DEFAULT는 같은 행의 다른 컬럼을 참조할 수 없으므로 Room 생성 함수가 미입력 값을 복사한다.

- `LIVE_PAPER`: `participation_closes_at <= evaluation_starts_at`
- `BACKTEST`: `participation_closes_at <= evaluation_ends_at`
- 공통: `evaluation_ends_at <= finalization_deadline_at`

일정과 잠긴 규칙은 평가 시작 후 일반 UPDATE를 금지한다.

## Strategy 선택과 참가 Bot 원자 생성

참가 함수는 Room 행을 `FOR UPDATE`로 잠그고 다음을 한 트랜잭션으로 처리한다.

1. Room 유형·상태·참가 가능 시각과 계정 자격을 검증한다.
2. Room 전체 `bot_participation_limit`과 계정의 `per_account_bot_limit`을 승인된 Participation 기준으로 검사한다.
3. 선택한 Strategy의 현재 실행 의미를 복사한 독립 Bot과 파티션·Flow 스냅샷을 생성한다. 원본 Strategy FK는 남기지 않는다.
4. Bot, Participation, 최초 Bot/Participation Event와 Outbox를 함께 생성한다.
5. 평가 전에 생성한 Bot은 `execution_eligible_from = evaluation_starts_at`, 진행 중 BACKTEST 참가 Bot은 입력 잠금 완료 시각을 사용한다.

동시 참가 요청은 같은 Room 잠금 아래 직렬화하여 정원과 계정 한도를 초과하지 못하게 한다. 기존 개인 Bot을 Participation에 연결하는 API는 제공하지 않는다.

평가 전 취소는 Participation Event, `WITHDRAWN`, Bot `deleted_at`과 슬롯 반환을 한 트랜잭션으로 처리한다. 이미 `EVALUATING`인 공식 BACKTEST Room에서 승인된 Participation은 사용자 취소·교체를 거절하고 성공·실패와 관계없이 슬롯을 유지한다.

## 라이브와 백테스트 실행 격리

Trigger Router는 `bot.bots.lifecycle_status`, `execution_eligible_from`과 Competition 관계를 함께 확인한다.

- `LIVE_PAPER` Participation Bot만 라이브 시장 사건 평가 대상으로 라우팅한다.
- `BACKTEST` Participation Bot은 라이브 평가에서 제외하고 Competition Backtest Orchestrator만 실행한다.
- BACKTEST Room 종료 뒤 `CONTINUE_PRIVATE`가 확정된 Bot만 독립 라이브 실행으로 전환할 수 있다.

## 비공개 다중 기간 계획

계획 잠금 함수는 다음을 단일 serializable 트랜잭션에서 검증한다.

- 기간 수가 `period_count`와 같고 최소 2개다.
- 기간 순번이 1부터 연속적이다.
- 모든 `importance_weight` 합계가 정확히 1이다.
- `daterange(evaluation_start, evaluation_end, '[]')`가 같은 계획 안에서 겹치지 않는다. `btree_gist`와 exclusion constraint 또는 동등한 advisory lock 검사를 사용한다.
- 각 기간에 필요한 Dataset Manifest와 Feature Materialization이 모두 AVAILABLE이고 잠긴 해시와 일치한다.
- 기간·입력·가중치·규칙으로 `plan_hash`를 계산하고 비밀 nonce를 포함한 `commitment_hash`를 만든다.

nonce 평문은 KMS 관리 비밀로 두고 DB에는 암호문과 key version만 저장한다. `ENDED` 전 일반 사용자 역할은 기간·가중치·입력 테이블을 읽지 못한다. 공개 API는 초기 자금, 수수료·슬리피지 정책, 채점 공식·계산 버전과 commitment hash만 반환한다. `ENDED` 뒤 계획·nonce·Manifest 메타데이터를 공개하되 라이선스 대상 원본 S3 객체는 공개하지 않는다.

## 기간 Run과 최종 집계

`backtest_period_runs` 생성 trigger는 다음 교차 행 불변식을 검증한다.

- Participation과 평가 기간이 같은 Room에 속한다.
- `backtest.runs.bot_id = participations.bot_id`다.
- Run 기간, 초기 자금, 수수료, 슬리피지, Buying Power와 정밀도 버전이 잠긴 Room·기간 규칙과 같다.
- Run의 input bundle이 기간이 잠근 Dataset·Feature 집합과 정확히 같다.

각 기간은 동일 초기 자금, 빈 포지션·주문·예약·원장 변동·Flow 상태에서 독립 시작한다. Run 재시도는 `backtest.run_attempts`만 추가하고 새 공식 Run이나 부분 점수를 만들지 않는다.

`backtest_aggregate_results`는 모든 필수 기간 Run이 COMPLETED이고 검증 해시가 존재할 때만 생성한다. 기간별 원래 지표에 중요도 가중치를 적용하고 `weighted_max_drawdown`과 `worst_period_max_drawdown`을 모두 계산한다. 일부 성공 기간만으로 가중치를 재정규화하지 않는다.

Bot 고유 결정적 실패는 Participation을 `EVALUATION_FAILED`, 공통 데이터·플랫폼 복구 불가 실패는 Room을 `INVALIDATED`로 전환한다. `finalization_deadline_at`에 terminal 상태가 아닌 작업은 같은 원인 분류 절차로 종결한다.

## 점수 공개와 리더보드

검증된 aggregate result가 생성되면 같은 트랜잭션의 Outbox로 리더보드 재계산을 요청한다. 새 불변 `PUBLISHED` snapshot은 공개 완료 Bot만 포함하며 별도 임시 표시는 하지 않는다. 이후 결과가 추가되면 새 snapshot으로 순위가 변경될 수 있다. 모든 승인 Participation이 terminal이면 `FINAL` snapshot을 만든다.

`leaderboard_entries` trigger는 Snapshot, Participation과 결과 근거가 같은 Room에 속하는지 확인한다. LIVE_PAPER는 `performance_snapshot_id`, BACKTEST는 `backtest_aggregate_result_id`만 허용한다.

기간별 점수와 매수·매도·판단 상세는 `ENDED` 전 공개하지 않는다. `ENDED` 뒤에도 상세 S3 객체는 Participation 소유 계정만 읽을 수 있고 다른 Bot의 상세는 공개하지 않는다. 운영자 접근은 별도 감사 권한과 audit event가 필요하다.

## 불변·삭제 정책

Room Event, Participation Event, 평가 계획, 기간, 입력 잠금, 기간 Run 연결, aggregate result와 leaderboard snapshot은 append-only다. 일반 역할의 UPDATE·DELETE를 trigger와 권한으로 차단한다. Room·Participation·Bot 논리 삭제가 Backtest Run, 결과, 리더보드와 감사 증거를 연쇄 삭제하지 않게 FK에 cascade를 사용하지 않는다.

## 안전한 마이그레이션 순서

1. 새 enum·Competition 하위 테이블과 nullable 호환 컬럼을 먼저 추가한다.
2. 기존 Room은 `competition_type = LIVE_PAPER`, 고객 생성 Room은 `organizer_type = USER`로 backfill한다.
3. 기존 `SUBMISSION`·`WAITING` Room은 평가 시작 전이면 `RECRUITING`, 기존 `WAITING` Participation은 `REGISTERED`로 변환하고 사건 근거를 남긴다.
4. `submission_opens_at`은 `participation_opens_at`, 기존 라이브 `submission_closes_at`은 `participation_closes_at`으로 backfill한다. `finalization_deadline_at`은 검증된 운영 유예값으로 채운다.
5. 기존 Bot의 `execution_eligible_from`은 실제 `started_at` 또는 생성 시각으로 backfill하고 `started_at` nullable 전환 뒤 CHECK를 검증한다.
6. `evaluation_segments`를 `live_evaluation_segments`로 rename하고 기존 행의 Room이 LIVE_PAPER인지 감사한다.
7. 애플리케이션을 새 컬럼 dual-read로 배포한 뒤 참가 생성 함수·한도 잠금·유형별 실행 라우팅·공개 게이트를 활성화한다.
8. `(room_id, owner_account_id) UNIQUE`를 제거하고 새 비유일 조회 인덱스를 만든다. 이 순서는 다중 Bot 참가 쓰기 기능을 켜기 직전에 수행한다.
9. NOT NULL, CHECK, FK와 deferred trigger를 `NOT VALID`로 추가하고 backfill 감사 후 VALIDATE한다.
10. 공식 BACKTEST 대회 생성·참가·기간 Run·aggregate·리더보드 통합 검증이 통과한 뒤에만 기존 상태값·컬럼 읽기를 제거한다.

## Rollback

새 공식 BACKTEST 데이터가 생성되기 전에는 애플리케이션 feature flag를 끄고 dual-read 이전 코드로 돌아갈 수 있다. 공식 BACKTEST Participation 또는 공개 aggregate result가 생성된 뒤에는 테이블을 삭제하거나 기존 단일-Bot UNIQUE를 복원하지 않는다. 기능을 비활성화하되 새 행 생성을 차단하고 append-only 증거를 유지한 상태에서 forward fix한다. enum 값 제거가 필요한 rollback은 직접 ALTER TYPE 삭제 대신 호환 새 enum 생성·검증·교체 마이그레이션으로 수행한다.
