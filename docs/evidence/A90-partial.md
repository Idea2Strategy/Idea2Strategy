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

# Outbox·감사 계약 — 관찰만 기록한다

`outbox_messages` 에 쓰는 어댑터가 여덟 곳 이상, `audit_events` 에 쓰는 곳이 열 곳 이상이다.
공용 컴포넌트 하나를 지나지 않고 각 도메인 어댑터가 직접 insert 한다.

**그 자체를 결함으로 보지 않는다.** 필수 컬럼은 테이블의 NOT NULL 과 CHECK 제약이 강제하므로,
컬럼을 빠뜨린 insert 는 런타임에 실패한다(로컬에서 `operations.outbox_messages` 의 제약 6개를
직접 확인했다 — 상태별 claim/dead-letter/published 정합성, 금액 부호, replay 계보).

남는 위험은 **의미의 불일치**다 — `payload_hash` 를 서로 다르게 계산하거나 `idempotency_key`
형식이 다른 경우. 이것은 제약이 잡지 못하고 기계적으로도 판별되지 않는다. 각 어댑터를 읽어
비교해야 하며, 이 카드를 닫기 전에 해야 할 일로 남긴다. 지금 단정할 수 있는 것은 "여러 곳에서
쓴다" 는 사실뿐이고, 그것이 위반이라고 주장하지 않는다.

---

# 요약

| 항목 | 상태 |
| --- | --- |
| F-1 admin-mcp 전략 노출 전수 | **해소** — 전략 스키마에 닿는 경로 없음 |
| F-2 가드 이름 정합성 (Terraform ↔ Java) | 확인 |
| F-2 조건부 빈 구조 | 확인 — 권한 없으면 가드가 생성되지 않음 |
| F-2 배포 환경 전수 | **남음** — `enable_operator_auth` 적용 후 |
| Outbox·감사 계약의 의미 일치 | **남음** — 어댑터별 해시·키 형식 비교 |

## 경철님이 해야 하는 것

배포가 끝나면 [operations/login](https://ideatostrategy.com/operations/login) 에서 **TOTP 등록**을
완료해야 한다. 2026-08-08 21:51 기준 Cognito 의 `UserMFASettingList` 가 비어 있어 아직 등록되지
않았다(비밀번호 설정은 완료 — `UserStatus: CONFIRMED`). 등록 없이는 F-2 의 3·4 항목과 INT05 를
수행할 토큰을 얻을 수 없다.
