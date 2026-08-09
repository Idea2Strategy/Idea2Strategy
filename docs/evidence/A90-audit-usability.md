# A90 (부분) — 감사 계약은 "누가 무엇을 했나"를 재구성할 수 있는가

A90 완료 증거가 **아니다.** 원장이 A90 을 완료로 세는 파일은 `docs/evidence/A90.md` 이고 이 문서는
그것이 아니다. 앞선 문서는 `A90-partial.md` 와 `A90-audit-vocabulary-and-403.md` 이며, 이 문서는
2026-08-09 에 **배포된 데이터베이스에 대조 질의를 처음 실행한 결과**와 그것이 드러낸 결함을 적는다.

## 언제 · 어디서

2026-08-09, AWS Development. 릴리스 31302328826(부트스트랩 포함) 적용 후.
`db/reconciliation/audit-vocabulary.sql` 를 `idea2strategy-dev-core` 에서 SSM 으로 실행했다.
읽기만 했고 감사 행을 만들거나 고치지 않았다.

표본: `operations.audit_events` 435건, `action_type` 8종, `target_domain` 5종, actor 210,
2026-08-08 ~ 2026-08-09. 작은 표본이므로 "문제 없음" 으로 읽을 근거는 되지 않지만, 아래 분화는
표본 크기와 무관하게 **모양 자체**에서 드러난다.

---

## 1. 같은 개념에 `target_domain` 이 두 개다

```
target_domain      action_type                      events
ACCOUNT_SANCTION   LIFT                                  2
ACCOUNT_SANCTION   APPLY                                 1
SANCTION           BATCH_RETRY                         160
```

제재라는 하나의 개념이 `ACCOUNT_SANCTION` 과 `SANCTION` 두 도메인으로 나뉘어 있다. 감사 검토가
`target_domain = 'ACCOUNT_SANCTION'` 으로 필터하면 **160건을 놓친다.** 제약도 grep 도 이것을 잡지
못한다 — 둘 다 유효한 문자열이기 때문이다.

## 2. `action_type` 작명 규칙이 섞여 있다

```
맨 동사        APPLY, LIFT, BATCH_RETRY
도메인 접두     OPERATOR_RBAC_READ_SELF, OPERATOR_RBAC_READ_CATALOG,
              OPERATOR_RBAC_READ_ASSIGNMENTS, BATCH_RUN_COMPLETED, OPERATOR_BOOTSTRAP
```

따라서 `action_type` 만으로는 사건을 식별할 수 없고 `target_domain` 과 짝을 지어야 한다. 그런데 1번
때문에 그 짝도 안정적이지 않다.

## 3. `reason_code` 가 두 가지 의미를 섞어 담는다

```
action_type            reason_code
APPLY                  SANCTION_APPLIED                  ← 행위를 다시 말한다
LIFT                   SANCTION_VERSION_CONFLICT         ← 실패 사유다
BATCH_RETRY            UNCLASSIFIED_EXECUTION_FAILURE    ← 분류되지 않았다는 사실이다
BATCH_RUN_COMPLETED    PARTIAL_FAILURE                   ← 결과 요약이다
OPERATOR_RBAC_READ_*   OPERATOR_*_READ                   ← 행위를 다시 말한다
```

## 근본 원인

`operations.audit_events` 에는 봉투를 채우는 트리거가 없다. `outbox_messages` 는
`prepare_outbox_envelope_before_insert` 가 한 곳에서 `payload_hash` 와 `producer_idempotency_key` 를
만들지만 감사는 그렇지 않다 — 필수 아홉 필드가 전부 기본값 없이 NOT NULL 이고 **열 곳 이상의 어댑터가
직접 채운다.** 누락은 NOT NULL 이 막지만 **어휘 분화는 아무도 막지 않는다.**

소스에서도 확인했다. `insert into operations.audit_events` 를 하는 어댑터는 10개이고
(`BotContinuation`, `OperatorRoom`, `RoomEvaluationAccountResultConsumer`, `AccountPreferencesConsent`,
`IdentityExpiry`, `JdbcOperatorBootstrap`, `OperatorRbacPersistence`, `OperatorRbacReadPersistence`,
`TransactionalOutboxStore`, `AccountSanctionJdbc`, `DelegatedBasicStrategyEdit`),
`action_type` 과 `target_domain` 은 전부 **호출자가 바인드 파라미터로** 넘긴다. 두 컬럼의 허용값이
한 곳에 정의된 자리는 없다.

---

# 4. 대조가 드러낸 실제 결함 — 만료된 제재가 풀리지 않았다

어휘 분화를 보다가 `SANCTION` 도메인의 160건이 **같은 대상 하나**에 대한 것임을 발견했고, 그것을
따라가 결함을 확정했다.

```
identity.account_sanctions
  id            52b9effa-69eb-4281-8bd8-0c842fdc8858
  account_id    91687695-21be-4fd7-8855-6f0552395cc0
  sanction_type SUSPENSION      status ACTIVE
  applied_at    2026-08-09 04:59:19Z
  expires_at    2026-08-09 05:00:00Z          ← 만료
```

```
operations.audit_events
  target_domain=SANCTION  action_type=BATCH_RETRY
  reason_code=UNCLASSIFIED_EXECUTION_FAILURE  actor_type=SYSTEM
  target_id=664a4431-7624-3737-aebc-719c7e1bda8a
  180건, 05:00:36Z ~ 08:14:45Z, 약 60초 주기, 대상 1개
```

CloudWatch `/idea2strategy/dev/core` `backend-batch` 가 남긴 것은 이것뿐이다.

```
DeadlineBatchRunner : Deadline batch completed: runId=3db4fc65-…, claimed=1,
                      completed=0, alreadyCompleted=0, failures=2
```

**예외는 어디에도 없다.** 3시간 동안 180번 실패했는데 무엇이 실패했는지 알 수 있는 기록이 없다.
루프가 멈춘 이유도 수정이 아니라 릴리스 31302328826 이 core 인스턴스를 교체해
`profiles: [manual]` 컨테이너가 사라진 것이다.

원인은 `DeadlineBatchOrchestrator` 가 `RuntimeException` 을 잡아 버리고 항상 재시도 가능한
`UNCLASSIFIED_EXECUTION_FAILURE` 로 바꾸던 것이었다. backend #264 / PR #265 로 고쳤다 — 원인을
handoff 의 별도 `diagnostic` 으로 실어 어댑터가 로그로 남기고(감사 `reason_code` 어휘는 닫힌 채로
유지), 선언된 `attempt.maxAttempts = 3` 을 이 경로에 적용해 마지막 시도는 죽은 편지함으로 보낸다.

**제재 만료가 왜 실패했는지는 여전히 모른다.** 그 원인이 기록되지 않았기 때문이고, 그것이 이 결함의
피해다. 다음 발생 때는 기록된다.

---

# 5. 이 문서로 확정된 것과 남은 것

| 항목 | 상태 |
| --- | --- |
| 미인증 접근 13개 전수 거부 | 통과 (`INT05-partial.md` §2) |
| 인증된 운영자의 권한 읽기가 감사에 남는다 | 통과 (`INT05-partial.md` 2026-08-08 절) |
| **감사 어휘가 한 곳에서 정의된다** | **아니오 — 분화 3건 확정** |
| **감사가 실패를 진단 가능하게 기록한다** | **아니오였음 — backend #264 로 수정, 배포 대기** |
| 권한 부족 토큰의 403 전수 | 미실증 — `DEVELOPMENT_OPERATIONS_OPERATOR` 역할의 두 번째 운영자 필요 |
| `action_type` 어휘를 한 곳에 정의 | 미착수 |

## A90 을 닫기 위해 남은 일

1. **어휘를 한 곳에 정의한다.** 열 개 어댑터가 각자 문자열을 넘기는 대신, 허용된
   `(target_domain, action_type)` 조합을 한 곳에서 선언하고 어댑터가 그것을 참조하게 한다. 그러면
   `ACCOUNT_SANCTION` 과 `SANCTION` 같은 분화가 컴파일 시점에 드러난다.
2. **403 전수** — 두 번째 운영자 계정을 만들 것인지 결정이 필요하다. 만들지 않기로 하면 이 항목은
   "계정 제약으로 미실증" 으로 명시하고 닫는다. **지금 계정의 root 역할을 회수해 403 을 만들려 하면
   안 된다** — 그 역할에 `OPERATOR_RBAC_GRANT`·`REVOKE` 가 포함되므로 회수하는 순간 되돌릴 권한도
   사라진다(`INT05-partial.md` 에 같은 경고가 있다).
3. backend #264 배포 후 재발 시 제재 만료 실패의 실제 원인을 확인한다.

INT08 의 잔여 3건이 A90 에 귀속되므로, 위 1·2 가 끝나면 INT08 도 함께 닫힌다.
