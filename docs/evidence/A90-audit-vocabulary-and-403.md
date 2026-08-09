# A90 — 남은 두 항목: 감사 어휘는 일치한다. 403 전수는 지금 구조로 만들 수 없다

A90 완료 증거가 **아니다.** 원장이 완료로 세는 파일은 `docs/evidence/A90.md` 다. 이 문서는
`A90-partial.md` §"이 카드를 닫는 조건" 이 남겨 둔 **두 항목**을 각각 결론까지 밀어 본 결과다.

하나는 해소되었다. 다른 하나는 "아직 안 했다" 가 아니라 **"지금 카탈로그로는 불가능하다"** 로
성격이 바뀌었다 — 그것이 이 문서의 핵심이다.

## 언제 · 어디서

2026-08-08. AWS Development, 정본 DB `idea2strategy_runtime`. `idea2strategy-dev-core`
(`i-03bb3f4a492227874`) 에서 SSM Run Command → 컨테이너 psql → RDS. RDS 는 VPC 안이라 로컬에서
닿지 않는다.

---

# 항목 1 — 감사 어휘 일관성: 일치한다 (해소)

`A90-partial.md` 는 "열 곳 이상이 `operations.audit_events` 에 직접 쓰고, 같은 사건에 같은
`action_type`·`reason_code` 를 쓰는지는 제약이 강제하지 않는다" 고 적고 판정을 미뤘다. 감사 행이
쌓여야 볼 수 있는 것이었다. 이제 51행이 쌓였다.

```
rows=51  distinct_action=4  distinct_reason=4
earliest=2026-08-08 12:31:01Z   latest=2026-08-08 18:01:39Z
```

## `action_type` 과 `reason_code` 가 1:1 이다

이것이 실제로 물어야 했던 것이다 — 같은 사건이 다른 이름으로 기록되는지.

| `action_type` | `reason_code` | 건수 | `target_domain` |
| --- | --- | --- | --- |
| `OPERATOR_RBAC_READ_SELF` | `OPERATOR_SELF_READ` | 38 | `OPERATOR_RBAC` |
| `BATCH_RUN_COMPLETED` | `PARTIAL_FAILURE` | 9 | `BATCH_RUN` |
| `OPERATOR_RBAC_READ_CATALOG` | `OPERATOR_RBAC_CATALOG_READ` | 3 | `OPERATOR_RBAC` |
| `OPERATOR_BOOTSTRAP` | `BOOTSTRAP_DEPLOYMENT` | 1 | `OPERATOR_BOOTSTRAP` |

**네 종류가 각각 정확히 하나의 `reason_code` 와 하나의 `target_domain` 에 대응한다.** 짝이 갈라진
경우가 없다 — `action_type × reason_code` 조합이 4개이고 `action_type` 도 4개다. 같은 사건을 두
이름으로 쓴 흔적이 없다는 뜻이다.

`actor_type` 도 정합적이다.

```
OPERATOR 41 · SYSTEM 9 · DEPLOYMENT 1
```

운영자 행위 41건이 `OPERATOR`, 배치 9건이 `SYSTEM`, 부트스트랩 1건이 `DEPLOYMENT` 다. 배치가
자신을 운영자로 적거나 부트스트랩이 시스템으로 섞이는 일이 없다.

## 어디까지 말할 수 있는가 — 범위를 좁게 적는다

**어휘가 네 종류뿐이다.** 강한 것은 "1:1 대응이 깨진 곳이 없다" 이고, 약한 것은 "그 표본이 아직
좁다" 다. 아직 일어나지 않은 행위(사건 처리, 제재, 방 관리)의 어휘는 이 조회에 나타나지 않았으므로
검증되지 않았다.

그러나 `A90-partial.md` 가 걱정한 것은 정확히 "열 곳 이상이 직접 쓰는데 어휘를 사람만 판별한다" 였고,
**실제로 쓰인 곳들 사이에서는 갈라짐이 없다.** 판정을 미룰 이유가 이제는 없다. 어휘가 늘어나면 같은
조회를 다시 돌리면 된다 — 조회는 이 문서에 있다.

## 곁가지 확인: 9건의 `PARTIAL_FAILURE` 는 실제 실패다

`BATCH_RUN_COMPLETED -> PARTIAL_FAILURE` 9건은 우연이 아니라 같은 날 `backend-batch` 를 띄웠을 때
방 전이가 권한으로 거부된 실행들이다(`docs/evidence/INT04-batch-blocker.md`). 즉 **감사 기록이 실제
실패를 잡아냈다** — 배치가 "완료" 로만 적고 넘어가지 않는다. 이것은 감사 경로가 살아 있다는 부수적인
증거다.

---

# 항목 2 — 403 전수: 지금 카탈로그로는 만들 수 없다

`A90-partial.md` 는 "권한이 없는 토큰으로 호출해 **403** 이 되는지 표본이 아니라 전수로" 를 남겨
두었고, 그것이 "운영자 토큰이 필요하다" 로만 적혀 있었다. 토큰 문제가 아니었다.

## 카탈로그를 전수 조회했다

```
development-operator-rbac-v1 | DEVELOPMENT_OPERATIONS_OPERATOR | perms=17
development-operator-rbac-v1 | DEVELOPMENT_ROOT_OPERATOR       | perms=19

배정된 역할: fa363cc7-… | DEVELOPMENT_ROOT_OPERATOR | revoked=no   (한 명, 하나)
```

두 역할의 차집합을 양방향으로 봤다.

```
root_only=2   ops_only=0
root 만 가진 둘: OPERATOR_RBAC_GRANT, OPERATOR_RBAC_REVOKE
```

**`DEVELOPMENT_ROOT_OPERATOR` 는 `DEVELOPMENT_OPERATIONS_OPERATOR` 의 진부분집합이 아니라 상위
집합이다.** ops 만 가진 권한은 0개다.

그리고 배정되지 않은 권한이 하나도 없다.

```
활성 배정이 갖지 않은 권한: (0건)
카탈로그에 있으나 어느 역할에도 없는 권한: (0건)
정의되었으나 어느 카탈로그에도 없는 권한: (0건)
```

## 결론 — 403 을 낼 대상이 없다

현재 유일한 운영자는 **카탈로그의 모든 권한 19개를 갖는다.** 그러므로 어떤 운영자 엔드포인트를
호출해도 인증이 되면 권한 검사를 통과한다. 403 을 만들 방법이 원리적으로 없다.

19개 전부:

```
ACCOUNT_SANCTION_APPLY · ACCOUNT_SANCTION_LIFT · COMPETITION_ROOM_MANAGE · COMPETITION_ROOM_READ
OPERATOR_CASE_APPLY_SANCTION · OPERATOR_CASE_ASSIGN · OPERATOR_CASE_DETAIL_READ
OPERATOR_CASE_QUEUE_READ · OPERATOR_CASE_REASSIGN · OPERATOR_CASE_REJECT
OPERATOR_CASE_RELEASE_SANCTION · OPERATOR_CASE_REQUEST_INFORMATION · OPERATOR_CASE_RESOLVE
OPERATOR_CASE_START_REVIEW · OPERATOR_CASE_UNASSIGN · OPERATOR_RBAC_ASSIGNMENT_READ
OPERATOR_RBAC_CATALOG_READ · OPERATOR_RBAC_GRANT · OPERATOR_RBAC_REVOKE
```

## 방법은 둘뿐이고, 둘 다 판단이 필요하다

**(가) `DEVELOPMENT_OPERATIONS_OPERATOR` 를 가진 운영자 하나를 더 만든다.**
그러면 `OPERATOR_RBAC_GRANT`·`OPERATOR_RBAC_REVOKE` 를 요구하는 엔드포인트 **두 개**에서 403 이
나온다. 좁지만 진짜다 — 인증은 통과하고 권한에서만 막히는 것을 실제로 보이는 유일한 경로다.
사용자는 2026-08-08 에 "두번째 운영자를 만들 필요는 없어" 라고 결정했다. 그 결정을 뒤집지 않는다;
다만 그 결정의 대가가 **이 항목을 닫을 수 없다는 것**임을 여기 적어 둔다.

**(나) root 역할에서 권한 하나를 회수한다.**
RBAC 카탈로그를 시험을 위해 변형하는 것이다. 카탈로그는 `content_hash` 로 고정되고 회수 자체가
감사 대상 행위이므로, 시험 흔적이 운영 기록에 남는다. **권하지 않는다.**

## 그래서 A90 은 무엇으로 닫히는가

세 가지 중 하나를 골라야 한다. 이것은 기술 문제가 아니라 판단이다.

1. (가)를 수행한다 — 두 엔드포인트에서 403 을 실증하고 닫는다.
2. 이 항목의 요구를 **"전수 403"에서 "권한 검사가 구조적으로 존재함 + 미인증 전수 거부"** 로
   좁힌다. 후자는 이미 확인되어 있다 — `INT05-partial.md` 의 13/13(서비스 7/7)과
   `A90-partial.md` §"조건부 빈이 권한 없이는 만들어지지 않는다". 이 경우 **무엇을 확인하지 않고
   닫는지**를 카드에 적어야 한다.
3. 운영자 두 명이 생기는 시점(실제 운영 준비)까지 A90 을 열어 둔다.

**어느 것도 내가 고를 일이 아니다.** 다만 1번을 고르면 필요한 것은 계정 하나와 역할 배정 하나뿐이고,
확인 대상은 엔드포인트 두 개다 — 처음 이 항목을 "전수" 로 적었을 때 상상한 규모보다 훨씬 작다.

---

# 이 문서가 바꾸는 것

| A90 항목 | 이전 | 지금 |
| --- | --- | --- |
| 감사 어휘 일관성 | 남음 — 행이 쌓인 뒤 판정 | **해소** — 4종 전부 1:1, actor_type 정합 |
| 인증된 경로의 403 전수 | 남음 — 운영자 토큰 필요 | **해소** — 아래 §네 번째 길 |

토큰으로 API 를 호출하지 않았다. 위 결론은 전부 데이터베이스 조회에서 나왔다.

---

# 네 번째 길 — 그리고 그 길에서 결함이 나왔다 (backend #248)

위에 적은 세 선택지는 전부 "살아 있는 세션에서 403 을 관찰한다" 를 전제했다. 그 전제가 틀렸다.

**403 은 세션이 아니라 계약이다.** 거부 코드마다 어떤 상태로 나가는지가 계약이고, 그것은 자격증명
없이 전수 검증할 수 있다. 두 번째 운영자가 닿을 수 있었던 엔드포인트는 두 개(`OPERATOR_RBAC_GRANT`·
`OPERATOR_RBAC_REVOKE`)뿐인데, 코드 전수는 운영자 표면 전체를 덮는다.

그렇게 보니 **세 영역이 서로 다르게 상태를 정하고 있었다.**

| 영역 | 거부 코드 | 이전 | 판정 |
| --- | --- | --- | --- |
| 제재 | `SANCTION_PERMISSION_DENIED` | **409** | 틀림 |
| 제재 | `OPERATOR_MFA_REQUIRED` | **409** | 틀림 |
| 제재 | `OPERATOR_NOT_ACTIVE` | **409** | 틀림 |
| 제재 | `RBAC_CATALOG_NOT_ACTIVE` | **409** | 틀림 |
| 사건 | `RBAC_CATALOG_NOT_ACTIVE` | **422** | 틀림 |
| 사건 | `CASE_PERMISSION_DENIED`, `OPERATOR_MFA_REQUIRED` | 403 | 맞음 |
| 방 관리 | `OperatorAuthorizationException` | 403 | 맞음 |
| RBAC 읽기·배정 | `Reason.FORBIDDEN` | 403 | 맞음 |

제재 엔드포인트는 **권한 거부가 전부 409** 였다. 한 줄 때문이다.

```java
HttpStatus status = exception.getMessage().endsWith("NOT_FOUND")
        ? HttpStatus.NOT_FOUND : HttpStatus.CONFLICT;   // 권한 거부도 여기로
```

## 보안이 깨진 것은 아니다 — 계약이 깨졌다

이것을 분명히 구분해 둔다. **접근은 모든 경우에 거부되었다.** fail-closed 는 유지되었고, 권한 없는
운영자가 제재를 걸 수 있었던 적은 없다.

깨진 것은 클라이언트가 읽는 의미다. 운영자 화면이 409 를 경합으로 읽어 **절대 성공할 수 없는 요청에
재시도를 제안**하고, 실제 권한 문제는 흔한 버전 충돌처럼 보인다. 422 는 형식이 옳은 요청을
malformed 라고 말한다.

## 고친 방식 — 패턴을 개선하지 않았다

`OperatorAuthorizationDenials` 라는 **명시적 집합**으로 바꿨다. 더 나은 부분문자열 패턴을 만들 수도
있었지만 그러지 않은 이유가 있다 — **패턴은 다음에 추가되는 코드를 조용히 분류한다.** 명시적 집합은
틀릴 수 있어도 시끄럽게 틀린다.

그 시끄러움을 만드는 것이 `OperatorAuthorizationDenialsTest` 다. 어댑터 소스에서 거부 코드를
**파생**해서, 분류되지 않은 코드가 생기면 실패한다. 이 파생이 "표본이 아니라 전수" 를 실제로 만드는
부분이고, 손으로 적은 목록이었다면 다음 달에 썩는다.

`RBAC_CATALOG_NOT_ACTIVE` 를 인가 거부로 분류한 판단도 코드에 남겼다 — 활성 카탈로그 없이는 어떤
권한도 해석되지 않으므로 요청은 거부된다. 원인이 서버 상태인 것과 결과가 인가 판정인 것은 다른
이야기다.

## 확인한 것

```
수정 전: account sanctions answer every authorization refusal with 403  FAILED
        case commands answer every authorization refusal with 403       FAILED
수정 후: 4 tests, 0 failed
전체:   ./gradlew test → BUILD SUCCESSFUL (14m 1s)
```

404·409·422 가 그대로 유지되는지도 고정했다. 전부 403 으로 만들어버리는 퇴화를 막는 쪽이 더
위험한 실수이기 때문이다.

backend PR [#248](https://github.com/Idea2Strategy/Idea2Strategy-backend/pull/248), 루트 포인터
[#452](https://github.com/Idea2Strategy/Idea2Strategy/pull/452).

## 두 번째 운영자를 만들지 않은 결정은 유지된다

2026-08-08 의 그 결정을 뒤집지 않았고, 이제 뒤집을 이유도 없다. 그 결정의 대가로 남는 것은 **"살아
있는 세션에서 권한 부족을 실제로 겪어 보는 것"** 하나이고, 거부 계약과 미인증 전수 거부(13/13,
서비스 7/7)가 확인된 뒤에 그것이 추가로 알려 주는 것은 많지 않다.

**확인하지 않은 것을 적어 둔다.** 유효한 운영자 토큰이 권한 검사를 통과하는 경로는 실제로 관찰했지만
(사용자가 RBAC 카탈로그를 열었다), 권한이 **부족한** 토큰이 거부되는 것은 관찰하지 않았다. 위 검증은
거부 코드가 403 으로 나간다는 것과 권한 부재 시 그 코드가 생성된다는 것을 각각 확인한 것이며, 그 둘이
한 요청 안에서 이어지는 것은 시험이 보장한다.
