# A90 (부분) — 인증 주체·RBAC 배선은 정합적이다. 배포 환경 전수는 남았다

A90 완료 증거가 **아니다**. 원장이 A90 을 완료로 세는 파일은 `docs/evidence/A90.md` 이고, 이
파일은 지금까지 확인한 것과 남은 것을 적는다.

카드 문구: "B~F 가 같은 인증 주체·RBAC·Outbox·감사 계약을 쓰는지".
INT08 이 A90 에 귀속시킨 항목은 둘이다 — **F-2**(인증 주체·RBAC 전수)와
**F-1**(admin-mcp read 도구의 전략 노출 전수).

## 언제 · 어디서

- 2026-08-08. 루트 `1010b5b` 계열(정확히는 `develop` = A91 노트 병합 전 시점).
- 소스 검사는 로컬. 배포 환경 검증은 진행 중인 릴리스
  [31259186323](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31259186323) 이후로
  미룬다.

---

# F-1 — 해소

INT08 의 후속 항목: "admin-mcp 의 read 도구 카탈로그에 전략 상세를 노출하는 도구가 없는지의
전수 확인".

`backend/apps/admin-mcp/src/main/java` 전체를 검사했다.

**전략·봇·백테스트·경쟁·성과를 한 번도 언급하지 않는다.**

```bash
grep -rniE "strategy|bot\.|backtest|competition|performance" \
  backend/apps/admin-mcp/src/main/java --include=*.java | grep -viE "idea2strategy"
→ (결과 없음)
```

SQL 도 전수로 뽑았다. `operations` 스키마 세 테이블만 건드린다.

```
insert into operations.audit_events
insert into operations.outbox_messages
select coalesce(max(aggregate_sequence), 0) + 1
select distinct a.catalog_version
select pg_advisory_xact_lock(...)
select request_hash, evidence_document::text as evidence_document
update …
```

읽는 테이블은 `operations.audit_events`, `operations.operator_accounts`,
`operations.outbox_messages` 다. 전략 스키마에 닿는 경로가 없으므로 **전략 상세를 노출하는 read
도구가 존재하지 않는다.** 배포 계약이 기록한 "read-only + 기업행사 승인 relay 한정" 과 일치한다.

이 확인은 표본이 아니라 전수다 — 앱의 모든 소스 파일과 모든 SQL 문을 대상으로 했다.

---

# F-2 — 배선 정합성은 확인, 배포 환경 전수는 남음

## 확인한 것: 세 가드의 이름이 Terraform 과 Java 사이에서 정확히 맞는다

운영자 변경 권한은 세 가드로 갈린다. 각 가드가 요구하는 프로퍼티 접두와 Terraform 이 내려보내는
환경변수 이름이 일치한다.

| 가드 | Java 프로퍼티 접두 | 선언 위치 |
| --- | --- | --- |
| 케이스 9개 | `idea2strategy.operator-case.guard.*` | `OperatorCaseConfiguration` |
| RBAC grant·revoke | `idea2strategy.operator-rbac.guard.*` | `OperatorRbacConfiguration` |
| 계정 제재 apply·lift | `idea2strategy.operator-sanction.guard.*` | `AccountSanctionConfiguration` |

Terraform 은 `ec2-user-data.sh.tftpl` 에서 `IDEA2STRATEGY_OPERATOR_*_GUARD_*` 형태로 16개를
내려보내며, Spring 의 relaxed binding 이 그것을 위 프로퍼티로 되돌린다.

### 여기서 내가 한 오판을 기록한다

처음에 `OPERATOR_[A-Z_]*PERMISSION_ID` 로 grep 해서 "Terraform 이 17개를 보내는데 backend 는
2개만 읽는다" 고 판단했다. **틀렸다.** 그 정규식이 `IDEA2STRATEGY_` 접두를 잘라 버려서, 접두가
붙은 14개가 접두 없는 것처럼 보였다. 실제로는 이름이 정확히 맞는다.

`application.yaml` 에 나타나는 권한 ID 가 둘(`OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID`,
`OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID`)뿐인 것도 오판을 도왔다. 나머지는 yaml 에 적히지
않고 `@Value` 와 relaxed binding 으로만 들어온다.

이 오판을 남겨 두는 이유는, 같은 검색으로 같은 결론에 도달할 다음 사람을 위해서다. **접두를
포함해서 grep 해야 한다.**

## 확인한 것: 조건부 빈이 권한 없이는 만들어지지 않는다

`OperatorCaseConfiguration` 의 가드 빈은
`@ConditionalOnProperty(prefix = "idea2strategy.operator-case.guard", name = {"queue-permission-id", "detail-permission-id"})`
다. 즉 권한 ID 가 주어지지 않으면 가드가 **아예 만들어지지 않는다.** 가드 없이 통과하는 것이
아니라 그 경로가 존재하지 않게 되는 구조다.

그러므로 "권한 UUID 가 비어 있는데 엔드포인트가 무방비로 열린다" 는 형태의 결함은 이 설계에서
발생하지 않는다. 다만 **그것이 곧 "모든 운영자 엔드포인트가 가드를 지난다" 는 증명은 아니다** —
가드 빈을 주입받지 않는 엔드포인트가 있는지는 아래 남은 항목이다.

## 남은 것: 배포된 조합에서의 전수 검증

INT08 의 F-2 문구가 요구하는 것은 "B~F API·worker 가 동일 인증 주체·RBAC 를 **실제로 사용**"
하는지다. 소스 배선이 맞는 것과 배포된 환경에서 모든 엔드포인트가 그 경로를 지나는 것은 다르다.

이 시점에 배포 환경에서 확인할 수 없었던 이유가 명확하다. `enable_operator_auth` 가 방금까지
`false` 였다.

```
컨테이너 내부(2026-08-08 13:0x): OPERATOR_AUTH_ENABLED=false
                                OPERATOR_RBAC_CATALOG_VERSION=(빈 값)
배포된 운영자 엔드포인트:        /api/v1/operations/cases → 404
```

401 이 아니라 404 다 — 운영자 컨트롤러가 등록조차 되지 않은 상태였다. 그 상태에서 "가드를
지나는가" 를 물을 대상이 없다.

릴리스 [31259186323](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31259186323) 이
`enable_operator_auth = true` 를 적용하고 나면 다음을 수행한다.

1. 컨테이너에서 `OPERATOR_AUTH_ENABLED=true`, `OPERATOR_RBAC_CATALOG_VERSION` 이 채워졌는지 확인.
2. 운영자 엔드포인트가 **404 가 아니라 401** 을 주는지 — 등록되었고 인증을 요구한다는 뜻.
3. 유효한 운영자 토큰 없이 각 엔드포인트를 호출해 전부 거부되는지 전수 확인.
4. 권한이 없는 토큰으로 호출해 **403** 이 되는지(인증은 됐지만 권한 없음) 표본이 아니라 전수로.
5. `operations.audit_events` 에 그 시도들이 기록되는지.

3·4 는 운영자 로그인이 되어야 하고, 그것은 TOTP 등록을 요구한다(§아래).

---

# Outbox 계약 — 데이터베이스에 중앙화되어 있다 (해소)

앞 판에서 "여러 곳에서 쓴다" 는 관찰만 적고 판정을 미뤘다. 이제 확인했다.

## 어떻게 중앙화되는가

`operations.outbox_messages` 에 `BEFORE INSERT` 트리거가 있다.

```
prepare_outbox_envelope_before_insert
```

```sql
IF NEW.payload_hash IS NULL THEN
    NEW.payload_hash := encode(sha256(convert_to(NEW.payload_document::text, 'UTF8')), 'hex');
END IF;
IF NEW.producer_idempotency_key IS NULL THEN
    NEW.producer_idempotency_key := NEW.idempotency_key;
END IF;
```

두 컬럼은 NOT NULL 이고 기본값이 없다. 그런데 어댑터 대부분이 그것을 insert 목록에 넣지 않는다 —
트리거가 채운다. 로컬에서 두 컬럼을 생략한 insert 를 실제로 넣어 확인했다(`INSERT 0 1`, 프로브
삭제).

**그래서 16개 어댑터가 각자 insert 해도 봉투는 한 곳에서 만들어진다.** A90 이 물은 "같은 Outbox
계약을 쓰는가" 의 답이다.

## 예외 둘은 정당하다

`payload_hash` 를 명시하는 곳은 `TransactionalOutboxStore` 의 **replay** insert 하나다. 원본
해시를 승계해야 하므로 새로 계산하면 안 된다(`original_message_id` 가 함께 있다).

`RoomEvaluationStartJooqAdapter` 와 `BacktestRequestOutboxStore` 는 `producer_idempotency_key`
만 명시한다 — 트리거 기본값과 다른 값이 필요한 경우이고, 해시는 여전히 트리거가 만든다.

## 내가 틀렸던 가설을 기록한다

여섯 어댑터에 `MessageDigest` 가 있어 "생산자마다 해시를 다르게 계산한다" 고 의심했다. 근거도
있었다 — `jsonb` 가 텍스트를 정규화하므로 Java 가 원문을 해시하면 값이 갈린다. 실제로 갈린다.

```
DB(jsonb 정규화)  {"a": 2, "b": 1}  → 21501dba…
Java(원문)        {"b": 1, "a":2}   → 4d56a2c3…
```

**그러나 그 `MessageDigest` 들은 payload_hash 를 만들지 않는다.** idempotency key 를 만든다 —
예: `"notification:" + sha256(accountId + "|" + typeCode + …)`. `TransactionalOutboxStore` 의
`sha256` 은 replay 의 `requestHash` 용이다.

가설은 **지지되지 않았다.** 없는 위험을 적지 않기 위해 결론을 뒤집었고, 왜 의심했는지는 남긴다 —
`jsonb` 정규화 문제를 진짜로 만나는 사람에게 위 두 값이 유용하다.

## 해시가 실제로 동작에 쓰인다 — 그래서 일치가 중요했다

장식이 아니다. `NotificationEventConsumer:33` 이 불일치를 거부 조건으로 쓴다.

```java
|| !source.payloadHash().equals(request.sourceEventHash())
```

`TransactionalOutboxStore` 도 저장된 값과 비교한다(`:299`, `:311`). 소비자 쪽 trading-engine 은
`select message.payload_hash` 로 **읽어서 수령증에 넣는다** — 재계산하지 않는다
(`StrategyBotOutboxPoller:53`, `RoomEvaluationAccountOpenPoller:56`).

값을 만드는 곳이 하나이고 나머지는 읽거나 비교한다. 계약이 성립한다.

# 감사(audit) 계약 — 구조가 다르다. 판정 보류

`operations.audit_events` 에는 **채우는 트리거가 없다.** 있는 둘은 가드다.

```
guard_operator_rbac_audit_before_change
guard_operator_bootstrap_audit_before_change
```

필수 필드(`actor_type`, `actor_id`, `action_type`, `target_domain`, `target_id`, `reason_code`,
`correlation_id`, `idempotency_key`, `occurred_at`)가 **전부 기본값 없이 NOT NULL** 이다. 각
어댑터가 직접 채운다. 빠뜨리면 런타임에 실패하므로 누락은 없지만, **같은 종류의 사건에 같은
`action_type`·`reason_code` 를 쓰는지**는 제약이 강제하지 않는다.

## 2026-08-08 1차 실행 — 어휘 분화는 아직 없다. 보증 컬럼은 아예 없다

`db/reconciliation/audit-vocabulary.sql` 을 만들어 AWS 정본 DB 에 돌렸다. 판정하지 않고 분포와
의심 후보만 내놓는 질의다 — 어휘가 갈렸는지는 사람이 판단해야 한다.

| 섹션 | 결과 |
| --- | --- |
| action_type 분포 | 3종 — `OPERATOR_BOOTSTRAP` 1, `OPERATOR_RBAC_READ_SELF` 29, `OPERATOR_RBAC_READ_CATALOG` 3 |
| reason_code 분포 | action_type 마다 정확히 1개. 같은 이유를 다른 코드로 적은 흔적 없음 |
| 같은 접두 후보 | `OPERATOR_RBAC` 에 2종 → **정상 분화**(서로 다른 동작). 설계대로 후보만 냈고 오탐이다 |
| 시제 혼용 후보 | **0건** — `...APPLY` / `...APPLIED` 류가 없다 |
| 보증 관련 컬럼 | **`delegated_authorization_id` 뿐** |
| 표본 | 33건, action_type 3종, 도메인 2종, actor 2명 |

### 아직 판정이 아니다

표본이 **RBAC 읽기와 부트스트랩만** 덮는다. 제재·케이스·방 종료 같은 쓰기 동작이 감사에 들어온
뒤에야 어휘가 갈리는지 볼 수 있다. 지금 결과는 "갈리지 않았다" 가 아니라 **"아직 볼 것이
없다"** 다 — 질의의 마지막 섹션이 표본 크기를 함께 내는 이유가 그것이다.

### 보증 컬럼이 없다는 것은 확정이다

5번 섹션이 감사 테이블에서 `auth`·`mfa`·`assur`·`session` 을 담은 컬럼을 찾는다. 나온 것은
`delegated_authorization_id` 하나뿐이고 그것은 위임 인가 식별자다. **`auth_time` 도, MFA 나이도,
보증 근거도 저장되지 않는다.**

그래서 "이 운영자 행위가 신선한 MFA 에 근거했는가" 를 기록으로 답할 수 없다.
`docs/evidence/INT05-partial.md` 의 89분 관찰이 미결로 남은 이유가 정확히 이것이고, 이것은 INT08
항목이다 — 스키마에 자리가 없으므로 코드만 고쳐서 해결되지 않는다.

### 실행 방법 메모

RDS 가 VPC 안이라 `idea2strategy-dev-core` 에서 SSM 으로 실행했다. 전송 과정에서 SQL 의 한글
섹션 라벨을 ASCII 로 치환했으므로 위 표의 3~6번 라벨은 원격 출력에서 `section` 으로 찍혔다.
**데이터는 그대로다** — 저장된 SQL 파일은 원래 라벨을 유지한다.

그것이 감사 쪽의 실제 위험이다 — 열 곳 이상이 직접 쓰고 어휘의 일관성은 사람만 판별한다.
Outbox 처럼 한 곳에서 만들어지지 않으므로 **여기는 판정하지 않는다.** 남은 일: `action_type` 과
`reason_code` 의 값 분포를 뽑아 같은 사건이 다른 이름을 쓰지 않는지 본다. 그 조회는 감사 행이
쌓인 뒤(INT03·INT05 수행 후)에 의미가 있다.

---

# 요약

| 항목 | 상태 |
| --- | --- |
| F-1 admin-mcp 전략 노출 전수 | **해소** — 전략 스키마에 닿는 경로 없음 |
| F-2 가드 이름 정합성 (Terraform ↔ Java) | 확인 |
| F-2 조건부 빈 구조 | 확인 — 권한 없으면 가드가 생성되지 않음 |
| F-2 미인증 접근 전수 거부 | 확인 — `docs/evidence/INT05-partial.md` (13/13, 서비스 7/7) |
| F-2 인증된 경로의 권한 거부(403) 전수 | **남음** — 운영자 토큰 필요 |
| **Outbox 계약 일치** | **해소** — 봉투를 DB 트리거가 한 곳에서 만든다 |
| 감사 어휘 일관성 | **남음** — 감사 행이 쌓인 뒤 값 분포 조회 |

## 이 카드를 닫는 조건

남은 둘이다. 하나는 유효한 운영자 토큰으로 각 엔드포인트의 403 을 전수 확인하는 것이고, 다른
하나는 `action_type`·`reason_code` 분포를 보는 것이다. 둘 다 **행위가 먼저 일어나야** 하므로
INT03·INT05 수행과 함께 처리한다.

토큰은 자격증명이므로 에이전트가 그것으로 API 를 호출하지 않는다. 사용자가 운영자 화면에서
조작하고, 그 결과를 `operations.audit_events` 에서 확인하는 방식이 이 카드의 마지막 절차다.

### 갱신 (2026-08-08 저녁) — 둘 다 결론까지 밀었다

`docs/evidence/A90-audit-vocabulary-and-403.md` 를 보라. **위 문단의 판단이 하나는 맞고 하나는
틀렸다.**

- **감사 어휘는 해소되었다.** 51행이 쌓였고 `action_type` 4종이 각각 정확히 하나의 `reason_code`
  와 하나의 `target_domain` 에 대응한다. 갈라진 짝이 없다.
- **403 전수는 "토큰이 필요한 일" 이 아니었다.** 유일한 운영자가 카탈로그의 **전 권한 19개**를
  가지므로 403 을 낼 대상이 원리적으로 없다. `DEVELOPMENT_ROOT_OPERATOR` 는
  `DEVELOPMENT_OPERATIONS_OPERATOR`(17)의 상위 집합이고, 배정되지 않은 권한은 0건이다.
  두 번째 운영자를 만들지 않기로 한 결정의 대가가 이 항목이라는 것을 그 문서에 적었다.
