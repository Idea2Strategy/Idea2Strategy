# 계정 수명주기 계약 v1

상태: `user:kcrmin`이 승인한 권고를 반영한 정본 제안. 병합 전 이 정확한 commit에 대한 GitHub 제품 권한자 리뷰가 필요함

대상 이슈: Idea2Strategy/Idea2Strategy#107

범위: 이메일 또는 OIDC 인증을 마친 계정의 휴면, 탈퇴 요청·취소, 최종 종료, 보존 및 비식별 처리

정본 근거: `docs/product-discovery.md` 66, 75~79, 1367번 결정

## 1. 목적과 적용 원칙

이 문서는 계정 서비스와 backend, trading, bot, competition 등 소비 서비스가 동일하게 따라야 하는 수명주기 경계를 정의한다. 계정의 현재 상태와 추가 전용 수명주기 사건은 하나의 원자적 트랜잭션에서 변경되어야 한다.

- 모든 기준 시각은 UTC instant로 저장하고 비교한다. 화면만 사용자 시간대로 표현한다.
- `PENDING_VERIFICATION`은 가입 계약의 상태이며 이 문서의 네 가지 운영 상태 밖에 있다. 인증 완료 시에만 `ACTIVE`로 진입한다.
- 이 계약의 운영 상태는 `ACTIVE`, `DORMANT`, `CLOSING`, `CLOSED`이다.
- `CLOSED`는 종단 상태다. 재가입은 새 계정을 만드는 절차이며 과거 계정을 되살리지 않는다.
- 수명주기 사건은 수정·삭제하지 않는다. 정정은 새 보상 사건으로만 남긴다.
- 법률상 보존기간을 이 문서가 추정하지 않는다. 보존 정책 레지스트리의 승인된 버전이 사건 발생 시점의 기간과 처리 방식을 결정한다.

## 2. 상태와 허용 전이

| 현재 상태 | 다음 상태 | 원인 | 필수 조건과 결과 |
| --- | --- | --- | --- |
| `ACTIVE` | `DORMANT` | 휴면 판정 배치 | 12개월 동안 성공 인증이 없다는 판정, 즉시 인증 권한 폐기 |
| `DORMANT` | `ACTIVE` | 사용자 재활성화 | 기본 인증과 단계 상승 인증, 필수 정책 재동의, 제재 확인 성공 |
| `ACTIVE` | `CLOSING` | 사용자 탈퇴 요청 또는 승인된 운영자 조치 | 탈퇴 시각과 취소 deadline 고정, 즉시 접근 폐기와 신규 작업 동결 |
| `DORMANT` | `CLOSING` | 재인증을 거친 사용자 탈퇴 요청 또는 승인된 운영자 조치 | 휴면 해제 없이 탈퇴 가능하되 요청 자체에는 단계 상승 인증 필요 |
| `CLOSING` | `ACTIVE` 또는 `DORMANT` | deadline 전 사용자 취소 | 탈퇴 직전 상태로 복원하되 새 인증 세션을 발급하기 전 재인증 필요 |
| `CLOSING` | `CLOSED` | 취소 deadline 경과 및 종료 선행조건 충족 | 종단 상태 전환, 비식별·삭제 작업 예약 |

표에 없는 전이는 금지한다. 특히 `CLOSED`에서의 모든 전이, `ACTIVE`와 `DORMANT`에서 `CLOSED`로의 직접 전이, `CLOSING`에서 임의 상태 변경은 허용하지 않는다. 내부 장애 때문에 종료 선행조건을 충족하지 못하면 `CLOSING`을 유지하고 운영자 경보를 발생시킨다. 증적이나 미정산 값을 버리고 `CLOSED`로 강제 전환하지 않는다.

## 3. 탈퇴 요청과 취소 기간

### 3.1 요청

- 탈퇴 요청은 최근 단계 상승 인증을 요구한다. 이 계약에서 최근 인증은 서버가 명령을 수신한 시각을 기준으로 **최근 10분 이내**에 완료한 현재 계정의 활성 `PASSWORD` 또는 `OIDC` 수단 재인증만 인정한다. 복구 코드는 계정 복구 전용이며 탈퇴 요청·취소의 재인증 수단으로 인정하지 않는다. 성공 요청 시 `withdrawal_requested_at`을 서버 수신 시각으로, `cancellation_deadline_at`을 정확히 `withdrawal_requested_at + 30일(30 × 24시간)`로 저장한다.
- deadline은 달력 날짜나 사용자의 시간대가 아니라 UTC instant로 비교한다.
- 취소는 서버가 수신한 시각이 `cancellation_deadline_at`보다 **엄격히 이른 경우**에만 가능하다. deadline과 같은 시각부터는 취소할 수 없다.
- `CLOSING` 진입 사건에는 `previous_state`, `requested_at`, `cancellation_deadline_at`, `reason_code`, 적용 정책 버전을 기록한다. 자유 입력 사유와 인증 수단 원문은 기록하지 않는다.
- 이미 `CLOSING`인 계정의 동일 요청은 기존 요청 결과를 반환한다. 새로운 deadline을 만들거나 연장하지 않는다.

### 3.2 취소

- deadline 전 취소는 `previous_state`로 복원한다. 이전 상태가 `DORMANT`이면 취소만으로 `ACTIVE`가 되지 않는다.
- 취소 성공과 상태 복원은 하나의 트랜잭션으로 처리하며 별도의 `WITHDRAWAL_CANCELLED` 사건을 추가한다.
- deadline 이후의 취소는 `409 WITHDRAWAL_CANCELLATION_EXPIRED`로 거절하고 상태와 사건 이력을 변경하지 않는다.
- 취소 후 기존 세션·토큰·위임을 되살리지 않는다. 사용자는 재인증을 통해 새 자격을 받아야 한다.
- 취소는 이미 완료된 하위 도메인 조치를 되돌리지 않는다. 철회된 방 참여, 중단된 봇, 취소된 주문과 완료된 정산은 자동 복원하지 않으며 사용자는 현재 유효한 규칙으로 새 독립 작업을 시작해야 한다.

## 4. 휴면 판정과 재활성화

### 4.1 v1 휴면 기준

휴면 기준은 **최근 성공 인증 시각부터 연속 12개월**이다. 이 12개월 기준은 법적 의무에 대한 주장이 아니라 제품 운영 기준이다.

- 기준 입력은 계정 서비스가 기록한 `last_successful_auth_at` 하나다. 토큰 갱신, 실패한 로그인, 백그라운드 작업, 봇 실행, 알림 열람은 성공 인증으로 보지 않는다.
- 판정 시각 `evaluated_at`에 `last_successful_auth_at + 12개월 <= evaluated_at`이면 휴면 후보이다. 여기서 12개월은 UTC 달력 연산이며, 해당 월에 같은 일이 없으면 그 달의 마지막 날 같은 시각을 사용한다.
- 배치는 후보를 찾을 뿐이며 최종 전이는 계정 행 잠금 후 조건을 다시 검사한다. 잠금 전에 성공 인증이 발생했다면 전이하지 않는다.
- `DORMANT`에서는 일반 로그인, 토큰 갱신, API 접근, 신규 봇·주문·평가·방 참가를 거절한다. 오직 재활성화·탈퇴·법정/운영 지원 경로만 허용한다.

### 4.2 재활성화

재활성화는 다음을 모두 만족해야 한다.

1. 현재 계정에 연결된 활성 `PASSWORD` 또는 `OIDC` 로그인 수단으로 단계 상승 인증에 성공한다. 복구 코드, 과거 로그인 흔적, 클라이언트가 선언한 인증 수단·시각은 인정하지 않는다.
2. `PASSWORD`는 서버가 현재 credential을 직접 검증한다. `OIDC`는 서버가 발급한 단일 사용 nonce를 포함한 ID token을 backend가 제공자 JWKS로 직접 검증한다. 정확한 issuer, configured audience와 필요한 `azp`, 만료, nonce, 불변 subject 및 `auth_time` 중 하나라도 불명확하면 기본 거부한다.
3. OIDC 단계 상승의 경과 시간은 IdP `auth_time`과 backend 검증 시각 중 더 오래된 시각을 기준으로 서버 수신 시각에서 최대 10분이다. nonce는 제공자에 결속하고 원문 대신 키 버전이 있는 HMAC만 저장하며, 만료·재사용·시도 한도 초과를 거절한다. ID token과 원문 nonce는 영속화하거나 로그에 남기지 않는다.
4. 요청이 제출한 동의 문서 식별자 집합과 이미 저장된 동의를 합쳐 현재 필수 정책 문서의 정확한 집합을 충족해야 한다. 새 동의와 재활성화 사건·현재 head/version·명령 영수증은 하나의 트랜잭션으로 기록한다.
5. 계정 제재, 보호 잠금 또는 서비스별 접근 금지가 재활성화를 막도록 설정되어 있지 않다. 데이터 보존만을 위한 legal hold는 그 자체로 계정 접근을 제한하지 않는다.

성공 시 `DORMANT -> ACTIVE` 사건과 현재 상태를 원자적으로 기록하지만 세션은 발급하지 않는다. 사용자는 정상 로그인 절차를 다시 거쳐야 하며 휴면 전에 발급되었거나 폐기된 세션·토큰은 계속 무효다. 같은 멱등 키의 성공 응답 재생도 세션이나 새 nonce를 만들지 않는다.

## 5. 접근 권한의 즉시 폐기

`ACTIVE/DORMANT -> CLOSING` 또는 `ACTIVE -> DORMANT` 전이가 커밋될 때 계정 서비스는 다음을 같은 트랜잭션 또는 원자적으로 결합된 outbox 사건으로 보장한다.

- `auth_epoch`를 단조 증가시킨다.
- 모든 서버 세션과 refresh token을 폐기한다.
- 이미 발급된 access token은 각 서비스가 `auth_epoch` 또는 중앙 introspection으로 거절한다. 캐시 허용 시간 때문에 계속 유효해지는 설계는 금지한다.
- API key, 기기 자격, 서비스 계정 연결, 사용자 위임 및 대리 권한을 폐기한다.
- `ACCOUNT_ACCESS_REVOKED` outbox 사건을 발행한다. 소비 서비스는 중복 수신을 멱등 처리한다.

폐기 실패 때문에 상태 전이만 성공한 채 접근이 남아서는 안 된다. 같은 DB에서 처리할 수 없는 소비 서비스에는 기본 거부(fail closed) 정책을 적용하고, outbox 재처리가 끝날 때까지 접근을 허용하지 않는다.

## 6. 서비스 간 동결·정리·정산 경계

`CLOSING` 진입 직후부터 모든 서비스는 신규 위험과 신규 사용자 작업을 만들지 않는다.

| 영역 | `CLOSING` 진입 즉시 | `CLOSED` 전 선행조건 | 종료 후 보존 경계 |
| --- | --- | --- | --- |
| backend/account | 로그인·토큰·환경설정 변경 차단, 취소와 상태 조회만 허용 | deadline 경과, 모든 종료 작업 상태 확인 | 계정 식별 정보 처리 작업 예약 |
| bot | 신규 생성·시작·재시작 차단, 실행 중 봇 정지 요청 | 모든 봇이 종단/정지 상태이며 미확인 명령 없음 | 전략·실행 증적은 해당 보존 정책에 따름 |
| trading | 신규 주문·주문 수정 차단 | 미체결 주문, 포지션 또는 잔여 자산이 하나라도 있으면 차단; 승인된 외부 정리 뒤 `settled` 필요 | 주문·체결·원장 증적은 불변 보존 대상으로 취급 |
| competition/evaluation | 신규 참가·제출·평가 시작 차단; `REGISTERED` 참가를 멱등하게 `WITHDRAWN` 처리 | `EVALUATING` 참가는 평가 완료와 보상·순위 확정까지 차단 | 공개 결과는 계정 표시명 대신 비식별 참가자 키 사용 |
| notification/integration | 신규 마케팅·일반 알림 중단, 종료 필수 알림만 허용 | webhook·외부 연결 폐기 확인 | 전송 증적은 최소 메타데이터만 정책에 따라 보존 |

필수 readiness 도메인은 `BOT`, `TRADING`, `COMPETITION`, `NOTIFICATION`, `INTEGRATION` 다섯 개다. 각 도메인은 `freeze_requested`, `frozen`, `settlement_required`, `settled`, `blocked` 중 하나와 안정적인 이유 코드를 반환한다. 조정자는 같은 `correlation_id`와 generation에 대해 `TRADING=settled`, 나머지 네 도메인=`frozen`인 증적이 모두 있을 때만 정확히 한 번 `CLOSED`로 전환한다. 누락, 알 수 없음, 오류, timeout, 역순·이전 generation 응답은 성공으로 추정하지 않고 `CLOSING`을 유지하며 새 generation으로 재시도하고 운영 경보를 중복 제거한다. 금융·외부 시스템의 정리 방법은 해당 도메인 계약이 결정하며 자동 주문 취소, 자동 매도 또는 강제 청산은 금지한다.

## 7. 보존·비식별 행렬

### 7.1 공통 규칙

- 수명주기 사건마다 승인된 `retention_policy_version`을 고정하고, 각 데이터 분류의 `retain_until`과 처리 방식(`DELETE`, `ANONYMIZE`, `RETAIN`)을 계산해 기록한다.
- 정책 버전은 적용 시작 시각, 데이터 분류, 기간, 처리 방식, 근거 식별자와 승인자를 가져야 한다. 근거의 본문이나 민감한 법률 의견은 감사 로그에 복제하지 않는다.
- 보존기간은 `CLOSED` 시각부터 계산한다. 사건 시각에 `effective_from <= closed_at`인 완전한 정책 중 가장 최신 한 개만 선택하며 같은 효력 시각은 허용하지 않는다. 정책이 없거나 모든 데이터 분류를 정확히 한 번 포함하지 않거나 선택 결과가 모호하면 `RETENTION_POLICY_MISSING` 실패 obligation을 남기고 물리 삭제·비식별·식별자 해제를 모두 기본 거부한다.
- 정책이 나중에 바뀌어도 기존 사건의 버전을 덮어쓰지 않는다. 더 긴 보존이 필요한 경우 새 정책 적용 사건으로 `retain_until`을 연장할 수 있지만 이미 삭제된 데이터를 복구할 수 있다고 가정하지 않는다.
- legal hold는 `hold_id`, 범위, 시작 시각, 해제 권한자, 근거 식별자를 별도로 기록한다. 활성 hold 범위의 데이터는 `retain_until`이 지나도 삭제·비식별하지 않는다. 해제 후에는 현재 승인 정책으로 새 처리 예정 시각을 계산한다.
- `BOT_STRATEGY_EVALUATION`은 이전 정책 호환용 결합 분류다. 새 데이터는 이 분류에 배정하지 않고 기존 obligation은 `RETAIN`으로만 fail closed 한다. 새 데이터는 목적에 따라 `BOT_STRATEGY_PRIVATE_DATA` 또는 `COMPETITION_RESULT_EVIDENCE`로 분리한다.

### 7.2 데이터 분류별 처리

| 데이터 분류 | `CLOSED` 시 기본 처리 | 보존 종료 시 처리 | legal hold | 비고 |
| --- | --- | --- | --- | --- |
| `PROFILE` | 서비스 노출 즉시 중단 | 즉시 복원 불가능하게 `ANONYMIZE` | 범위에 포함된 필드만 보류 | 공개 결과에는 비식별 참가자 키 사용 |
| `CONTACT_IDENTIFIER` | 이메일/OIDC 활성 바인딩 폐기, 재사용 격리 | 30일 뒤 원문·조회 바인딩 삭제 및 격리 해제 | `blocks_identifier_reuse` hold가 있으면 해제도 보류 | fresh ownership verification 필수 |
| `AUTH_CREDENTIAL` | 비밀번호·refresh token·secret 즉시 사용 불가 | 즉시 `DELETE` | 인증 secret은 hold 대상이 아님 | 해시라도 인증 목적으로 재사용 금지 |
| `POLICY_CONSENT` | 식별자 노출 최소화 후 보존 | 최소 1,825일 `RETAIN` | 적용 | 동의 문서 버전·시각·증적 식별자 유지 |
| `ACCOUNT_LIFECYCLE_AUDIT` | 추가 전용 보안·수명주기 증적 보존 | 최소 1,825일 `RETAIN` | 적용 | 토큰·이메일 원문 금지 |
| `TRADING_FINANCIAL_RECORD` | 계정 접근과 분리해 보존 | 최소 1,825일 `RETAIN` | 적용 | 주문·체결·원장 연결 무결성 유지 |
| `BOT_STRATEGY_PRIVATE_DATA` | 비공개 전환 | 30일 뒤 `DELETE` | 적용 | 개인 Strategy 원본과 대회 증적이 아닌 Bot·평가 데이터 |
| `COMPETITION_RESULT_EVIDENCE` | 참가·결과·순위와 재현 증적 보존 | 365일 뒤 계정 연결을 제거해 `ANONYMIZE` | 적용 | 공식 결과에 필요한 독립 Bot·성과·백테스트 증적도 이 분류이며 30일 삭제 대상이 아님 |
| `OPERATIONS_DELIVERY_LOG` | 최소 필드만 보존 | 365일 뒤 `DELETE` | 적용 가능 | 자유 입력과 불필요한 식별자 금지 |

`RETAIN`의 숫자 기간은 최소 보존기간이며 기간 경과만으로 자동 삭제하지 않는다. `COMPETITION_RESULT_EVIDENCE` 비식별화는 사용자 개설 Room의 `creator_account_id`, `competition.participations.owner_account_id`, 해당 독립 대회 Bot과 공식 backtest run의 `owner_account_id`를 같은 작업에서 제거하고 대응하는 `*_anonymized_at`을 기록한다. `anonymous_alias`, 공식 결과·순위와 재현에 필요한 비식별 증적은 유지한다. 초대 자격처럼 결과 재현에 필요 없는 부수 자료는 이 분류에 포함하지 않는다. private Bot/Strategy 30일 삭제가 이 증적의 FK를 끊어서는 안 된다.

## 8. 식별자 재사용과 재가입

- `CLOSING` 동안 이메일과 OIDC 식별자는 다른 계정에 연결할 수 없다.
- `CLOSED` 후 30일 격리 기간에는 재사용을 거절한다. 경계는 `closed_at + 30일`이며 그 시각부터 정상 가입 검증을 시작할 수 있다.
- 격리 종료 후 이메일은 새 계정에서 이메일 소유 검증을 다시 통과한 경우에만 사용할 수 있다.
- 동일 OIDC `issuer + subject`도 격리 종료 후 공급자 인증과 현재 필수 동의를 다시 완료한 경우 새 계정에 연결할 수 있다. 과거 권한·데이터·공개 소유권은 자동 이전하지 않는다.
- legal hold가 `blocks_identifier_reuse=true`로 해당 식별자에 명시 적용된 경우 격리 종료 후에도 재사용을 막는다. 단순히 다른 증적이 hold 대상이라는 이유만으로 재사용을 무기한 차단하지 않는다.
- 중복 가입 경쟁은 정규화된 이메일 및 `issuer + subject`의 활성/격리 바인딩에 대한 DB 유일성 제약으로 직렬화한다.
- 격리는 원문 대신 키 버전이 있는 식별자 fingerprint와 `reuse_eligible_at = closed_at + 30일`을 별도 tombstone으로 저장한다. 미해제 fingerprint는 하나만 허용한다. 격리 해제는 활성 `blocks_identifier_reuse` hold가 없음을 확인하고 기존 이메일/OIDC 바인딩의 조회 fingerprint를 제거하는 작업과 같은 트랜잭션에서 수행한다.
- HMAC 키 회전 중 재사용 판정은 현재 키와 아직 비교 대상인 모든 이전 키 버전을 확인한다. 어떤 키의 비교 결과라도 불명확하거나 사용할 수 없으면 재사용을 거절한다. 격리 해제 뒤에도 이메일 또는 OIDC 소유권을 새로 검증해야 한다.

## 9. 멱등성·동시성·DB 불변식

모든 상태 변경 명령은 `Idempotency-Key`를 요구한다. 키 범위는 `(account_id, command_type, key)`이고 보존기간은 적어도 해당 명령의 재시도 가능 기간보다 길어야 한다.

- 성공 또는 상태 변경 없는 성공(no-op)은 완성된 최초 응답을 불변 명령 영수증으로 저장한다. 같은 키와 같은 정규화 요청은 영수증의 동일한 상태 코드, 응답 코드, 응답 본문을 반환한다.
- 같은 키에 다른 요청은 `409 IDEMPOTENCY_KEY_REUSED`로 거절한다.
- 영수증은 `(account_id, command_type, key)`, 정규화 요청 hash, 응답 상태·코드·본문, 완료 시각을 고정한다. 상태가 변경된 성공은 같은 계정의 `lifecycle_event_id`를 함께 고정하고, no-op 성공은 사건 없이 `NULL`을 기록할 수 있다.
- 실패 응답은 영수증에 안전하게 저장된 경우에만 재시도 시 동일하게 재현한다. 트랜잭션 예외로 롤백되어 영수증이 남지 않은 실패까지 재현한다고 보장하지 않는다.
- 명령은 계정 현재 행을 `FOR UPDATE`로 잠근 뒤 현재 상태, deadline, 정책, 서비스 종료 조건을 다시 평가한다.
- 상태 변경 성공은 현재 행의 `lifecycle_version`을 1 증가시키고 정확히 하나의 사건과 완성된 명령 영수증을 같은 DB 트랜잭션에 추가한다. no-op 성공은 현재 상태·버전을 바꾸지 않고 완성된 영수증만 추가한다.
- 사건의 `(account_id, sequence)`는 유일하고 `sequence`는 1씩 증가한다. 사건에는 `from_state`, `to_state`, `lifecycle_version`, `occurred_at`, `actor_type`, `reason_code`, `correlation_id`, 정책 버전을 기록한다.
- 상태를 바꾸는 사건의 마지막 `to_state`와 계정 현재 상태·버전은 항상 일치해야 한다. 분기된 sequence나 사건 없는 현재 상태 변경을 허용하지 않는다.
- 탈퇴 요청과 취소가 동시에 도착하면 DB 잠금 획득 순서로 직렬화한다. 요청이 먼저면 취소는 새 deadline을 보고 판단한다. 취소가 먼저이고 아직 `CLOSING`이 아니면 `409 WITHDRAWAL_NOT_PENDING`이며 이후 요청을 방해하지 않는다.
- 내부 소비는 `event_id`를 멱등 키로 사용한다. outbox 발행과 상태 변경은 동일 트랜잭션이며, 전송은 at-least-once를 전제로 한다.

## 10. API 및 오류 의미

권장 명령 표면은 다음과 같다. 실제 URI가 달라도 의미는 동일해야 한다.

| 명령 | 성공 | 대표 오류 |
| --- | --- | --- |
| `POST /v1/account/withdrawal-requests` | `202`, 상태·요청 시각·deadline | `409 INVALID_LIFECYCLE_TRANSITION`, `403 STEP_UP_REQUIRED` |
| `POST /v1/account/withdrawal-cancellations` | `200`, 복원 상태 | `409 WITHDRAWAL_NOT_PENDING`, `409 WITHDRAWAL_CANCELLATION_EXPIRED` |
| `POST /v1/account/oidc-step-up-challenges` | `200`, 제공자 결속 단일 사용 nonce와 만료 시각 | 비활성·미지원 제공자 오류 |
| `POST /v1/account/reactivations/password` | `200`, `ACTIVE` 상태; 세션 없음, 재로그인 필요 | `403 REACTIVATION_REQUIREMENTS_NOT_MET`, `423 ACCOUNT_RESTRICTED` |
| `POST /v1/account/reactivations/oidc` | `200`, `ACTIVE` 상태; 세션 없음, 재로그인 필요 | OIDC 검증 오류, `403 REACTIVATION_REQUIREMENTS_NOT_MET`, `423 ACCOUNT_RESTRICTED` |
| `GET /v1/account/lifecycle` | `200`, 현재 상태·버전·허용된 다음 행동 | 인증/권한 오류 |

- 오류 응답은 안정적인 `code`, 사용자 안전 메시지, `correlation_id`만 제공한다. 내부 hold 근거, 제재 규칙, 타 서비스 상세, 식별자 존재 여부는 노출하지 않는다.
- 경쟁으로 기대 버전이 달라지면 `409 LIFECYCLE_VERSION_CONFLICT`와 최신 안전 상태를 반환한다.
- 일시적인 의존 서비스 장애는 `503 LIFECYCLE_DEPENDENCY_UNAVAILABLE`로 반환하되 이미 커밋된 요청을 실패로 오인하게 하지 않는다. 멱등 조회로 확정 결과를 재전달한다.
- `CLOSED` 계정의 로그인은 계정 존재 여부를 구분할 수 없는 일반 인증 실패로 응답한다.

## 11. 감사와 관측

- 요청, 성공, 정책 거절, 동시성 충돌, 서비스 동결·정산 상태, 보존 작업, hold 적용·해제를 구조화 사건으로 남긴다.
- 사건에는 주체 유형, 계정 내부 키, 명령 유형, 결과 코드, 이전/다음 상태, 정책 버전, correlation ID만 기록하고 요청 본문·토큰·secret·이메일 원문은 기록하지 않는다.
- `CLOSING`이 deadline 뒤에도 남아 있거나 소비 서비스 폐기 확인이 지연되면 경보한다. 경보는 자동 `CLOSED` 전환의 근거가 아니다.
- 정기 무결성 검사는 현재 상태와 마지막 사건, sequence 연속성, outbox 처리, 활성 자격 존재 여부를 대조한다.

## 12. 배포, 롤백과 forward-fix

1. 상태·사건·outbox·보존 정책 필드는 먼저 additive migration으로 배포한다.
2. 기존 계정은 `ACTIVE`로 추정 변경하지 말고, 기존 상태를 보존한 명시적 backfill 사건과 근거 버전을 남긴다.
3. 소비 서비스가 `DORMANT`와 `CLOSING`을 기본 거부하도록 배포한 뒤 상태 전이 writer를 활성화한다.
4. 기능 플래그를 끄면 신규 전이만 중단한다. 이미 기록한 사건을 삭제하거나 상태를 과거로 되감지 않는다.
5. 잘못된 전이는 승인된 보상 명령과 새 사건으로 정정한다. `CLOSED`는 자동 복원하지 않으며 데이터 복구 가능성을 보장하지 않는다.
6. migration 롤백이 데이터 손실이나 사건 삭제를 요구하면 롤백하지 않고 forward-fix한다. 읽기 호환 코드는 최소 한 배포 주기 유지한다.
7. 긴급 차단 시 인증과 신규 위험 작업은 fail closed로 유지하되 정산·증적 보존 작업은 계속할 수 있어야 한다.

## 13. 정본 병합 승인 게이트

이 제안에는 30 × 24시간의 탈퇴 취소 기간, UTC 달력 기준 12개월의 휴면 판정, backend 직접 OIDC 검증과 단일 사용 nonce, 재활성화 후 세션 미발급, 다섯 도메인 종료 readiness, CLOSED 기준 30일 식별자 격리, 분리된 Bot/Strategy·Competition 보존 분류와 제품 권한자가 승인한 기간 권고를 반영했다.

권고안 자체는 `user:kcrmin`이 Idea2Strategy-backend#127에서 승인했지만 현재 로컬 거버넌스 검사는 이 제안의 정확한 commit에 대한 fresh 승인 증거를 확인하지 못했다. 이 변경을 정본으로 병합하려면 해당 정확한 HEAD에 대한 GitHub 제품 권한자 리뷰 승인이 필요하다. 이전 댓글 승인, Git 사용자 이름·이메일, 이슈 할당만으로 이 게이트를 통과했다고 간주하지 않는다.

정확한 commit이 승인·병합되기 전 `account-retention-a12-proposal` 값은 운영 정본이나 seed가 아니다. 구현자는 선택 가능한 완전한 승인 정책이 없는 물리 삭제·비식별·식별자 해제나 금융 정리 행위를 임의로 실행하지 않는다.
