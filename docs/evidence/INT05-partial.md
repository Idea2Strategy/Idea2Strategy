# INT05 (부분) — 미인증 접근 전수 거부는 확인했다. 인증된 경로는 남았다

INT05 완료 증거가 **아니다**. 원장이 완료로 세는 파일은 `docs/evidence/INT05.md` 다.

## 언제 · 어디서

- 2026-08-08. AWS Development (`https://ideatostrategy.com`).
- 운영자 인증이 켜진 뒤(릴리스 31259186323), 그리고 MFA 등록·복구가 끝난 뒤(A92).

## 1. 엔드포인트 전수 목록 — 13개

소스에서 뽑았다. 표본이 아니다.

```
GET  /api/v1/operations/cases
GET  /api/v1/operations/cases/{caseId}
GET  /api/v1/operations/competition/rooms/{roomId}
GET  /api/v1/operations/me
GET  /api/v1/operations/rbac/catalog
GET  /api/v1/operations/rbac/operators/{operatorId}/assignments
POST /api/v1/operations/accounts/{accountId}/sanctions
POST /api/v1/operations/accounts/{accountId}/sanctions/{sanctionId}:lift
POST /api/v1/operations/cases/{caseId}/commands/{action}
POST /api/v1/operations/competition/rooms/{roomId}/cancellation
POST /api/v1/operations/competition/rooms/{roomId}/invalidation
POST /api/v1/operations/rbac/assignments/grants
POST /api/v1/operations/rbac/assignments/revocations
```

## 2. 토큰 없이 / 잘못된 토큰으로 — 13개 모두 데이터를 주지 않는다

두 경우(헤더 없음, `Bearer not.a.real.token`)의 응답이 **모든 엔드포인트에서 동일**했다. 즉
잘못된 토큰이 아무것도 더 열지 않는다.

| 응답 | 개수 | 엔드포인트 |
| --- | --- | --- |
| 401 | 6 | `cases/{caseId}`, `me`, `rbac/catalog`, `rbac/operators/{id}/assignments`, `rbac/assignments/grants`, `rbac/assignments/revocations` |
| 400 | 4 | `cases`, `sanctions`, `sanctions/{id}:lift`, `cases/{id}/commands/{action}` |
| 404 | 3 | `competition/rooms/{roomId}` GET·`cancellation`·`invalidation` |

**데이터는 하나도 반환되지 않았다.** 400 응답 본문은 `{"timestamp":…,"status":400,"error":"Bad Request","path":…}`
뿐이고 상세가 없다.

## 3. 존재 확인 oracle 은 없다

`/operations/competition/rooms/{roomId}` 가 404 를 주므로, **실제로 존재하는 방과 없는 방을
구분해 주는지** 확인했다. 이 세션에서 만든 실제 방(`287c762e-…`)과 가짜 UUID 를 같은 방식으로
호출했다.

```
실제방  GET  → 404      POST cancellation → 404
가짜방  GET  → 404      POST cancellation → 404
```

**동일하다.** 미인증 호출자가 방의 존재를 알아낼 수 없다.

## 4. 400·404 가 401 이 아닌 이유 — 인증이 필터가 아니라 핸들러에 있다

이 저장소는 운영자 인증을 Spring Security 필터가 아니라 **서비스 계층에서** 강제한다. 401 은
`OperatorCaseAuthenticationRejectedException`·`OperatorRbacAuthenticationRejectedException`·
`OperatorAuthorizationException` 이 예외 핸들러를 통해 나오는 것이다.

그래서 요청이 핸들러 메서드에 **도달하기 전에** Spring MVC 가 실패하면 인증 검사에 닿지 않는다.

- `GET /operations/cases` 는 `@RequestParam Set<UserCaseType> type` 을 필수로 요구한다
  (기본값 없음). 파라미터가 없으면 바인딩 단계에서 400 이다.
- `POST` 들은 본문 바인딩 실패로 400 이다.
- `/operations/competition/rooms/{roomId}` 는 클래스 수준 매핑이라 하위 경로 매칭에서 404 가 된다.

**정보 노출은 없다**(§2·§3). 그러나 순서가 뒤집혀 있다는 사실 자체는 기록해 둔다 — 미인증
호출자가 엔드포인트의 검증 형태를 탐색할 수 있고, 더 중요한 것은 아래다.

## 5. 그래서 A90 F-2 의 질문이 실질적이다 — 그리고 답은 통과다

필터 백스톱이 없으므로, **어느 운영자 핸들러가 주체 확인을 빠뜨리면 그 엔드포인트는 아무 보호가
없다.** 표본으로는 알 수 없고 전수로 봐야 한다.

운영자 컨트롤러 5개가 모두 서비스 경유이고, 그 서비스 7개 전부가 인증을 강제한다.

| 서비스 | 강제 방식 |
| --- | --- |
| `OperatorCaseCommandService` | `OperatorCaseAuthenticationRejectedException` |
| `OperatorCaseQueryService` | 같음 |
| `OperatorRbacCommandService` | `OperatorRbacAuthenticationRejectedException` |
| `OperatorRbacReadService` | 인증 참조 있음 |
| `OperatorRoomManagementService` | `OperatorAuthorizationException` |
| `PlatformRoomInvalidationService` | 같음 |
| `OfficialCompetitionRoomCreationService` | 인증 참조 있음 |

### 여기서도 내 grep 이 한 번 틀렸다

처음에 `CurrentOperatorPrincipal|operatorPrincipal` 로 찾아 네 서비스가 **0건**으로 나왔고, 잠깐
"인증하지 않는다" 고 판단했다. **틀렸다.** 그 서비스들은 `OperatorCaseAuthorizationPort` 와
전용 예외를 쓴다. 프로브에서 그 엔드포인트들이 401 을 준 사실이 그 판단과 모순되었고, 모순을
따라가 심볼을 찾았다.

오늘 같은 실수를 세 번 했다(`IDEA2STRATEGY_` 접두, workspace 이름, 이 심볼). **grep 이 0 을
돌려주는 것은 "없다" 가 아니라 "내가 찾은 이름으로는 없다" 다.** 관찰(401)과 검색 결과가
어긋나면 관찰을 믿어야 한다.

## 6. 남은 것 — 인증된 경로

| 항목 | 필요한 것 |
| --- | --- |
| 유효한 운영자 토큰으로 각 엔드포인트가 200/정상 응답 | 운영자 로그인(완료됨) 후 토큰 |
| 권한 없는 토큰으로 403 전수 | 두 번째 역할의 운영자 또는 권한 회수 |
| 감사 기록 — 성공·거부가 `operations.audit_events` 에 남는지 | 위 두 항목 수행 후 조회 |
| 케이스 9개 명령의 실제 수행 | 케이스 데이터가 있어야 한다 |

토큰은 사용자 브라우저 세션에 있고 에이전트가 그것으로 API 를 호출하지 않는다(자격증명이다).
그러므로 이 구간은 사용자가 토큰을 사용해 수행하거나, `ui` 화면에서 조작하며 그 결과를 감사
테이블에서 확인하는 방식이 된다.

케이스 데이터는 사용자 신고·제재 흐름에서 생기므로 INT03 과도 얽힌다.

## 요약

| 항목 | 상태 |
| --- | --- |
| 엔드포인트 전수 목록화 | 통과 — 13개 |
| 미인증 접근이 데이터를 주지 않음 | **통과 — 13/13** |
| 잘못된 토큰이 아무것도 더 열지 않음 | 통과 — 응답 동일 |
| 존재 확인 oracle 없음 | 통과 — 실제방·가짜방 동일 |
| 모든 운영자 서비스가 인증 강제 | 통과 — 7/7 |
| 인증이 필터가 아니라 핸들러에 있음 | **기록** — 정보 노출은 없으나 순서가 뒤집힘 |
| 인증된 경로·권한 거부·감사 기록 | **남음** |
