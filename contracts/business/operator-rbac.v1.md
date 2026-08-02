---
schema_version: 1
id: contract.operations.operator-rbac.v1
kind: business
status: approved
revision: 1
refs:
  - role.operator
  - journey.operator.administer
  - capability.audit.evidence
  - scenario.account.sanction
---

# contract.operations.operator-rbac.v1

상태: [COM-A13 #130](https://github.com/Idea2Strategy/Idea2Strategy/issues/130) 확정 계약.
제안 PR [#147](https://github.com/Idea2Strategy/Idea2Strategy/pull/147)을 제품 권한자
`user:kcrmin`이 병합해 승인한 의미를 canonical DBML과 함께 고정한다.

연결 구현: [backend #146](https://github.com/Idea2Strategy/Idea2Strategy-backend/issues/146)

## 목적과 비목표

이 계약은 일반 사용자 계정과 분리된 운영자 계정에 최소 권한 RBAC를 적용한다. 활성 운영자가 현재 요청에서
MFA 보증을 제시한 경우에만 서버가 역할 조회·부여·회수를 수행한다. 부여자는 자신이 현재 보유한 권한 중
현재 카탈로그에서 위임 가능하다고 선언된 부분집합만 더 낮은 역할에 위임할 수 있다.

실제 role code, permission code, hierarchy rank 값, delegable 값은 이 계약이 정하지 않는다. 이 값들은 별도
검토된 versioned seed/config artifact가 소유한다. DBML Records, migration, 테스트 fixture는
`REVIEW_EXAMPLE` 이외의 제품 카탈로그 항목을 만들지 않는다.

A14 제재, A16 관리자 MCP, A20 사건 처리, A23 UI와 A90 타 서비스 소비 통합은 비범위다.

## 계정과 인증 경계

- 일반 사용자 인증 주체는 `identity.accounts`, 운영자 주체는 `operations.operator_accounts`로 분리한다.
- 운영자 API는 인증된 외부 주체의 HMAC lookup이 정확히 하나의 운영자 행을 찾고, 그 행의 status가
  `ACTIVE`이며 `mfa_enrolled_at`이 있고 현재 요청의 신뢰된 인증 context가 MFA 완료를 증명할 때만 계속한다.
- `last_mfa_verified_at`만으로 현재 요청 MFA를 추정하지 않는다. MFA freshness 시간은 승인된 인증 정책이
  없으므로 이 계약에서 임의로 정하지 않는다.
- 일반 사용자, 미등록·비활성 운영자, MFA 미충족 요청은 fail closed한다. 인증된 UUID 주체가 있으면 거절도
  아래 감사 규칙으로 남기며, 신뢰 가능한 actor UUID가 없는 요청은 보안 접근 로그 경계에서 차단한다.

## 카탈로그 경계

`operations.rbac_catalog_versions`는 배포된 seed/config의 version과 SHA-256 content hash만 저장한다.
`rbac_catalog_roles`, `rbac_catalog_permissions`, `rbac_catalog_role_permissions`는 그 version에 속한 immutable
snapshot이다.

- 동시에 `ACTIVE`인 카탈로그 version은 최대 하나다. partial unique index가 이를 강제한다. version이 없으면
  operator API 전체가 fail closed하며, 정상 운영에는 정확히 하나가 필요하다.
- ACTIVE가 된 snapshot 행과 content hash는 수정하거나 삭제할 수 없다. migration trigger가 fail closed한다.
- RETIRED version은 재활성화하지 않는다.
- role/permission code가 현재 ACTIVE snapshot에 없거나 snapshot status가 ACTIVE가 아니면 권한은 없다.
- `operator_role_assignments.catalog_version`이 NULL, unknown, DRAFT 또는 RETIRED이면 현재 권한 계산에서 제외한다.
- 새 assignment insert는 ACTIVE catalog version을 반드시 고정한다. upgrade 전 nullable 행은 backfill을
  추정하지 않고 무권한으로 취급한다.
- API·application의 permission guard 설정이 ACTIVE snapshot에 없으면 애플리케이션 시작과 요청을 모두
  fail closed한다. UI 노출 여부는 인가 근거가 아니다.

## 현재 권한 계산

요청 시각 `now`에 다음을 모두 만족하는 assignment만 유효하다.

1. target operator와 role이 ACTIVE다.
2. assignment가 회수되지 않았다.
3. `granted_at <= now`이고 `expires_at IS NULL OR now < expires_at`이다.
4. assignment가 고정한 catalog version이 현재 ACTIVE version과 같다.
5. role, permission, role-permission snapshot 행이 모두 같은 ACTIVE version에 존재하고 ACTIVE다.

회수 commit 직후와 만료 시각부터 다음 요청은 권한을 다시 계산한다. 서버 인가 결정에 장기 권한 cache를
사용하지 않는다. 짧은 cache를 도입하는 경우에도 grant/revoke/catalog 전환 commit이 원자적으로 해당 version을
증가시켜 다음 요청이 이전 결과를 사용할 수 없게 해야 하며, 이 제안에는 cache를 도입하지 않는다.

조회 endpoint와 명령 endpoint는 각각 versioned seed/config가 매핑한 permission을 서버에서 검사한다.
실제 permission 이름은 이 계약에 포함하지 않는다.

## 위임 규칙

역할 부여 트랜잭션은 부여자·대상 운영자, ACTIVE catalog version, 요청 role과 관련 snapshot 행을 잠그고 다음을
한 번에 검증한다.

1. 부여자와 대상 모두 ACTIVE이며 부여자의 현재 요청이 MFA를 충족한다.
2. 숫자가 클수록 상위 권한이라는 공통 ordering에서, 부여자의 현재 role 중 적어도 하나가 요청 role보다
   엄격히 높은 hierarchy rank를 가져야 한다. 동급 또는 상위 role 요청은 거절한다.
3. 요청 role의 전체 ACTIVE permission 집합이 부여자의 현재 effective permission 집합의 부분집합이다.
4. 그 전체 집합이 부여자의 현재 delegable permission 합집합의 부분집합이다.
5. 요청 role, permission 또는 mapping이 unknown/stale/inactive이면 거절한다.
6. 대상이 이미 같은 role의 유효 assignment를 보유하면 새 assignment를 만들지 않는 성공 no-op만 허용하며,
   동일 idempotency 요청에 대해서만 같은 응답을 재생한다.

한 permission이라도 위 조건을 통과하지 못하면 assignment를 전혀 만들지 않고 `REJECTED` 감사 한 건만
commit한다. 검사 후 assignment와 성공 감사 삽입 전까지 같은 잠금을 유지한다.

회수는 대상 assignment를 `SELECT ... FOR UPDATE`로 잠그고 아직 회수되지 않은 경우에만 `revoked_at`,
`revoked_by_operator_id`, `revocation_reason_code`를 원자적으로 기록한다. 이미 같은 요청으로 회수된 경우 저장된
응답을 재생한다. 다른 payload 또는 다른 actor의 재사용은 idempotency conflict다. 만료는 assignment의 불변
`expires_at`로 계산하며 권한을 되살리는 갱신은 허용하지 않는다. 재부여는 새 assignment와 새 idempotency key를
사용한다.

## 멱등성과 동시성

- 클라이언트 idempotency key는 `operations.audit_events.idempotency_key`의 전역 unique 경계를 사용한다.
- `request_document`는 action, actor, target operator, role 또는 assignment, expiry, reason, catalog version을
  포함하는 JSON object다. 비밀·토큰·원문 외부 subject는 포함하지 않는다.
- `request_hash`는 PostgreSQL `jsonb`로 정규화된 `request_document::text` UTF-8의 SHA-256 lowercase hex다.
- key가 없으면 명령을 실행하지 않는다. 같은 key와 같은 hash는 저장된 response status/code/document를
  재생하고 assignment/audit을 추가하지 않는다. 같은 key와 다른 hash는 `409`로 거절하고 기존 행을 바꾸지
  않는다.
- 동시에 같은 payload를 제출한 요청은 unique 경계와 row lock 뒤 정확히 한 assignment와 한 audit만 만든다.
- 동시에 권한을 부여·회수하거나 catalog를 전환한 경우 lock을 획득한 뒤 현재 상태를 다시 계산한다. 이전
  snapshot으로 검증한 결과를 새 ACTIVE version에 commit하지 않는다.

## 불변 감사 증적

모든 역할 조회 권한 거절과 grant/revoke 성공·no-op·거절은 `operations.audit_events`에 기록한다. 단, 신뢰 가능한
actor UUID가 없는 pre-auth 요청은 보안 접근 로그가 소유한다. 기존 필드에 catalog version이나 증적 JSON을 겹쳐 싣지 않는다.
조회 거절처럼 client idempotency key가 없는 요청은 서버가 correlation UUID에서 유도한 충돌 없는 감사 key를
사용하며 business command의 client key와 같은 namespace를 사용하지 않는다.

`target_domain = 'OPERATOR_RBAC'`인 행은 다음을 모두 가진다.

- 기존 열: actor type/id, action type, target operator UUID, reason code, correlation UUID, idempotency key,
  occurred/recorded time
- `rbac_catalog_version`, `decision_status`, response status/code
- `resolved_rbac_catalog_version`: DB snapshot을 찾은 경우의 FK. config version이 unknown인 거절은 NULL이며,
  성공은 반드시 `rbac_catalog_version`과 같다.
- `request_document`와 `request_hash`
- `before_document`와 `before_hash`, `after_document`와 `after_hash`
- `evidence_document`와 `evidence_hash`
- 재생 가능한 최소 `response_document`

before/after document는 target operator, 평가 시각과 정렬된 assignment snapshot을 포함한다. evidence document는
요청 role/assignment, 부여자 effective role·permission UUID 집합, delegable permission UUID 집합, target role의
permission UUID 집합, hierarchy 비교 결과, operator/MFA/catalog 검증 결과를 포함한다. 실제 외부 identity,
credential, 사용자 프로필, 비공개 전략 데이터는 포함하지 않는다.

문서 hash는 각 PostgreSQL `jsonb`의 정규화된 `::text` UTF-8 SHA-256 lowercase hex다. 거절은
`before_hash = after_hash`여야 한다. 성공은 저장된 변경과 after document가 같은 트랜잭션에 있다.
`audit_events` UPDATE·DELETE를 금지하는 trigger는 DB owner가 아닌 runtime role에도 적용한다.
`rbac_catalog_version` 자체는 평가를 시도한 version을 보존하므로 FK가 아니다. unknown config version 거절도
그 값을 잃지 않는다. `resolved_rbac_catalog_version`만 catalog table FK이며 성공에는 필수다.

거절 감사를 저장하기 위해 business denial을 예외 rollback으로 처리하지 않는다. 트랜잭션은 REJECTED 감사와
응답을 commit한 뒤 application이 저장된 거절 결과를 반환한다. DB 장애로 감사가 commit되지 않으면 명령도
성공하지 않는다.

## API 의미

구체적인 endpoint permission code는 seed/config에 둔다. 최소 API 의미는 다음과 같다.

- role/catalog 조회: ACTIVE version과 호출자가 조회 가능한 role/permission/delegability projection만 반환한다.
- operator assignment 조회: 만료·회수 상태와 평가 시각을 반환하며 서버 query guard를 통과해야 한다.
- grant: target operator, role, optional expiry, reason, correlation, idempotency를 받는다.
- revoke: assignment, reason, correlation, idempotency를 받는다.
- audit query: actor/target/correlation/action/decision/time 조건으로 성공·거절과 before-after evidence를 조회한다.

권한 부족은 `403`, 일반 사용자/운영자 인증 경계 실패는 인증 정책에 따른 `401` 또는 `403`, unknown target은
정보 노출을 피하는 일관된 `404`, idempotency payload conflict는 `409`다. response body는 안정 code와
correlation id를 포함하고 내부 permission 집합을 불필요하게 노출하지 않는다.

## migration, rollback, test 의무

canonical 승인 뒤 중앙 Flyway migration은 다음 순서의 additive upgrade여야 한다.

1. catalog version/snapshot tables와 FK·check·index 추가
2. assignment catalog version nullable column 추가
3. audit evidence nullable columns과 OPERATOR_RBAC 조건부 complete check 추가
4. ACTIVE catalog 단일 partial unique index 추가
5. catalog/audit 불변 trigger와 새 assignment catalog-required trigger 추가
6. 실제 제품 catalog 값이 없는 환경에서는 빈 DRAFT/ACTIVE seed를 만들지 않고 operator API를 fail closed

down migration으로 감사나 assignment를 삭제하지 않는다. 배포 취소는 새 API writer를 중지하고 이전 reader가
새 nullable 열을 무시하는 forward rollback만 허용한다. schema 제거는 보존 의무가 끝난 별도 승인 작업이다.

검증은 empty migration과 pre-A13 upgrade, FK/check/trigger, 일반 사용자·비활성 운영자·MFA 미충족, unknown/stale
catalog, query/command guard, permission 부분집합과 strict hierarchy, 성공·거절 감사, 같은 key 재생·다른 payload
409, 동시 이중 grant, grant-vs-revoke, grant-vs-catalog 전환, expiry boundary를 포함한다. backend 전체 테스트와
PostgreSQL Testcontainers 동시성 테스트가 같은 commit에서 통과해야 한다.

## 승인 및 적용 근거

제안 PR [#147](https://github.com/Idea2Strategy/Idea2Strategy/pull/147)의 확정 의미와
`db/schema.dbml`의 A13 additive delta가 이 계약의 기준이다. 실제 permission catalog 항목은 별도
versioned seed/config 검토 없이 추가하지 않는다.
