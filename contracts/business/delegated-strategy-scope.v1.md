---
schema_version: 1
id: contract.identity.delegated-strategy-scope.v1
kind: business
status: approved
revision: 1
refs:
  - role.strategy-author
  - journey.strategy.author
  - capability.strategy.basic
  - policy.strategy.no-ai
  - policy.strategy.immutable-release
  - policy.user.no-direct-orders
---

# contract.identity.delegated-strategy-scope.v1

상태: [COM-A15 #128](https://github.com/Idea2Strategy/Idea2Strategy/issues/128) 확정 계약.
제안 PR [#148](https://github.com/Idea2Strategy/Idea2Strategy/pull/148)을 제품 권한자
`user:kcrmin`이 병합해 승인한 의미를 canonical DBML과 함께 고정한다.

## 목적과 결정

외부 AI/CLI credential은 계정 소유자가 승인한 scope와 명시 Strategy allowlist 밖으로 권한을 넓힐 수 없다.
#128의 권장 결정안을 다음처럼 고정한다.

- 명시 allowlist와 scope set은 authorization version 활성화 순간 불변이다.
- 목록 변경은 기존 row mutation이 아니라 같은 계정의 새 authorization version으로 교체한다.
- 성공한 `STRATEGY_CREATE` 결과는 같은 authorization의 파생 집합에 원자적으로 추가한다.
- `STRATEGY_COPY`는 source가 명시 allowlist에 있고 result가 authorization 계정 소유일 때만 성공하며, result를
  같은 authorization의 파생 집합에 원자적으로 추가한다.
- 파생 result는 명시 allowlist를 바꾸지 않고 다른 authorization으로 전이되지 않는다.
- release, bot lifecycle, room final action, continuation renewal과 order mutation scope는 존재하지 않는다.

외부 도구는 Basic 공식 블록·값을 노출된 API로만 편집·검증할 수 있다. 지원하지 않는 graph 전략, 사용자 코드, 외부 데이터,
private source 원문과 직접 주문은 허용하지 않는다.

## authorization version과 명시 allowlist

`identity.delegated_authorizations.authorization_version`은 1부터 시작한다. version 2 이상은
`replaces_authorization_id`로 직전 version을 가리키며 같은 account, 같은 논리적 client chain, 직전 version+1인지
deferred constraint trigger가 검증한다. 한 version에서 파생되는 다음 version은 하나뿐이다.

`strategy_target_set_hash`는 정렬된 명시 Strategy UUID 배열을 PostgreSQL jsonb로 정규화한 UTF-8 표현의
SHA-256 lowercase hex다. 활성화 transaction은 target rows, hash, scope rows와 `scope_set_hash`를 함께 검증한다.
빈 명시 목록은 CREATE 전용 authorization에서 허용한다.

`identity.delegated_authorization_strategy_targets`는 authorization, Strategy, 승인 시 owner account와
`delegated_access_epoch`를 고정한다. 명시 allowlist 행은 authorization 활성화 뒤 UPDATE·DELETE할 수 없다.
authorization/scopes/targets 변경은 새 version을 생성하고 이전 authorization과 그 credential을 원자적으로
회수한 뒤에만 활성화한다. 이전 파생 provenance는 그대로 보존하며 새 version에 자동 복사하지 않는다.

target insert 시 authorization.account_id, Strategy.owner_account_id, owner snapshot이 같고 Strategy가 BASIC이며
archive/delete되지 않았는지 deferred trigger가 검증한다. 이후 소유권 이전은 행을 수정하지 않으며 현재 owner
불일치로 다음 요청을 거절한다.

## 파생 Strategy provenance

`identity.delegated_strategy_derivations`는 성공한 CREATE/COPY output만 저장하는 append-only relation이다.

- CREATE: source는 NULL이다. result Strategy와 provenance를 같은 transaction에서 삽입한다.
- COPY: `(authorization_id, source_strategy_id)` FK가 명시 target을 가리켜야 한다. 파생 Strategy는 COPY source가
  될 수 없고 source 권한을 확장하지 않는다.
- result owner는 authorization account와 같아야 하며 생성 시 `delegated_access_epoch`를 고정한다.
- `(authorization_id, idempotency_key)`와 request hash가 명령 재시도를 직렬화한다. 같은 key/hash는 같은 result를
  반환하고 다른 hash는 `409`다.
- result Strategy 하나에는 provenance가 정확히 하나다. 실패·rollback에는 Strategy와 provenance가 모두 없다.
- provenance와 명시 target은 UPDATE·DELETE할 수 없다.

같은 authorization에서 파생 result는 ACCOUNT_RESOURCE_READ, STRATEGY_EDIT, STRATEGY_VALIDATE의 resource
집합에 포함된다. STRATEGY_COPY source는 명시 target만 허용한다. CREATE는 기존 target을 요구하지 않는다.

## Strategy delegated access epoch

`strategy.strategies.delegated_access_epoch`은 1부터 시작한다. 사용자 본인의 release가 성공해 독립 Bot snapshot을
만드는 transaction과 Strategy 소유권 변경 transaction은 epoch를 정확히 1 증가시킨다. 실패한 release/transfer는
증가시키지 않는다. 이 필드는 Bot이나 release provenance를 저장하지 않으며 기존 무계보 원칙을 유지한다.

명시 target은 승인 시 epoch, 파생 result는 생성 시 epoch를 고정한다. 현재 epoch가 snapshot과 다르면 기존
authorization의 다음 호출을 거절한다. 따라서 release/ownership 이후 사용자가 새 authorization version을
명시적으로 승인하기 전에는 credential이 다시 접근할 수 없다. archived_at 또는 deleted_at이 있으면 epoch와
무관하게 거절한다.

## fail-closed 평가 순서

opaque digest lookup은 주체 식별만 하며 권한을 부여하지 않는다. 한 DB snapshot/transaction에서 다음 순서를
지킨다: auth epoch → sanction → authorization/credential expiry·revoke → scope → resource.

1. authorization account가 ACTIVE이고 `account_security_states.auth_epoch`이 `auth_epoch_at_grant`와 같은지 본다.
2. 현재 projection에 ACTIVE sanction이 하나라도 있으면 기간 추정으로 우회하지 않고 거절한다.
3. authorization과 credential이 ACTIVE/non-revoked이며 각 expiry와 expiry mode가 현재 요청에 유효한지 본다.
4. endpoint가 요구하는 exact `identity.delegated_scope`가 authorization에 있는지 본다.
5. 요청 Strategy가 명시 target 또는 허용된 파생 result인지, 현재 owner가 authorization account와 같은지,
   BASIC·non-archived·non-deleted인지, 현재 delegated access epoch가 snapshot과 같은지 본다.

어느 단계든 missing, stale, timeout 또는 불일치면 뒤 단계를 성공으로 추정하지 않는다. 같은 계정 allowlist 밖과
다른 계정 Strategy는 동일한 status/code/body로 거절하고 존재·소유자·private source를 응답에 노출하지 않는다.

delegated principal은 release endpoint로 라우팅하지 않는다. enum에 release scope가 없다는 사실과 별개로
application command guard가 release, bot, room, continuation, order mutation을 항상 거절한다.

## 동시성·회수·멱등성

CREATE/COPY는 authorization, credential, source target/Strategy를 잠근 뒤 위 순서를 다시 평가하고 result Strategy,
document와 derivation을 한 transaction에 commit한다. 회수·만료·auth epoch·sanction·release/ownership 경합은 lock
획득 뒤 현재 상태로 재평가한다. 명령이 먼저 commit하면 그 결과는 보존되지만 뒤의 새 호출은 거절된다. 차단
전환이 먼저 commit하면 output은 생성되지 않는다.

authorization 교체는 새 version의 scopes/targets/hash를 완성한 뒤 이전 authorization/credentials 회수와 새
version 활성화를 직렬화한다. 두 replacement가 같은 version에서 갈라지는 것은 unique replaces 경계로 차단한다.

## 감사와 오류

호출 감사는 기존 `operations.audit_events`를 사용한다. actor type/id와
`delegated_authorization_id`는 authorization UUID, action type은 평가한 scope, target domain은 STRATEGY,
target id는 요청 resource 또는 성공한 result다. CREATE/COPY의 source-result 관계는 derivation relation이
보존한다.

감사에는 authorization/credential의 비밀이 아닌 ID, scope, resource ID, reason, correlation, idempotency와
before/after hash만 둔다. token digest·token 원문·private Strategy source·편집 payload·보유자 개인정보는
payload/evidence에 복제하지 않는다. 외부 응답은 범위 밖·다른 소유자·없는 resource를 구분하지 않는다.

인증 실패는 인증 정책의 `401`, 유효 principal의 scope/resource 거절은 동일한 `404 RESOURCE_NOT_AVAILABLE`,
idempotency payload 충돌은 `409 IDEMPOTENCY_KEY_REUSED`를 사용한다. release 등 금지 command는 안정된 `403`으로
거절한다.

## migration·rollback·test 의무

canonical 승인 뒤 Flyway는 authorization version/hash/replacement 열, target/derivation tables,
credential composite key, Strategy delegated access epoch, FK/check/index를 additive하게 추가한다. activation,
append-only, same-account, version-chain, target-set hash, release/ownership epoch 증가를 trigger로 강제한다.

기존 authorization은 target hash/rows를 추정 backfill하지 않고 resource access를 fail closed한다. 새 version을
명시 승인해야 한다. rollback은 새 writer를 중지하는 forward rollback이며 target/provenance/audit를 삭제하지 않는다.

검증은 empty/upgrade migration, immutable target/version replacement, CREATE atomic output, COPY explicit-source,
same/cross-account indistinguishable denial, derived COPY prohibition, auth epoch, sanction, expiry/revoke, scope,
release/ownership epoch, archive/delete, idempotent retry와 grant/revoke/release concurrency를 포함한다.

## 승인 및 적용 근거

제안 PR [#148](https://github.com/Idea2Strategy/Idea2Strategy/pull/148)의 확정 의미와
`db/schema.dbml`의 A15 additive delta가 이 계약의 기준이다.
