# INT04 (차단 기록) — 방이 `DRAFT` 에서 나오지 못한다. 배치가 그 전이를 못 쓴다

INT04 완료 증거가 **아니다.** 원장이 완료로 세는 파일은 `docs/evidence/INT04.md` 이고, 이 문서는
그것이 아니다. 이어지는 문서는 `INT04-partial.md` 다 — 그 문서의 §5 "남은 것" 이 가리키던 선행
(지표 백필)은 해소되었고, 그 자리에서 **새 벽 두 개**를 만났다. 이 문서가 그 둘을 적는다.

## 언제 · 어디서

2026-08-08. AWS Development (`https://ideatostrategy.com`, core `i-03bb3f4a492227874`).
루트 `develop` `6ec540e` → `f4faed4`.

## 어떻게 여기까지 왔나

`INT04-partial.md` 는 방 점수 구간이 **지표 백필(원장 2.5)** 에 걸려 있다고 적었다. 그것은
`pjy008008` 이 완료했다(725종목 × 4해상도 = 2,900건, `docs/evidence/2.5-aws-feature-backfill.md`).
그리고 backend #241 이 해소되어 공식 릴리스가 201 을 반환하므로 봇도 만들 수 있게 되었다
(`botId=0a125e62-1f02-36f8-b3b8-a15a4ef2c774`).

그래서 방 수명주기를 이어 밟았다. `recruitmentOpensAt` 을 **2분 전**으로 둔 방을 만들었다.

```
POST /api/v1/competition/rooms → 201
  {"id":"2463390f-6cc5-4f9e-851e-afefef334743","accessType":"PUBLIC","status":"DRAFT"}
  recruitmentOpensAt=2026-08-08T17:38:54Z  (생성 시각보다 앞)
```

전이 러너는 `@Scheduled(fixedDelayString = "…:PT10S")` 다. 10초 안에 `RECRUITING` 이 되어야 한다.
되지 않았다. `GET /api/v1/competition/rooms/mine` 은 계속 `"status":"DRAFT"` 였다.

---

# 벽 1 — `backend-batch` 가 기동 자체를 못 했다 (고쳤음, 루트 PR #441)

호스트를 보니 컨테이너가 **없었다.**

```
docker ps → backend-api, backend-worker, backtest-api   ← 셋뿐
docker ps -a | grep batch → NO BATCH CONTAINER
```

`compose.yaml` 의 `backend-batch` 에는 `profiles: [manual]` 이 붙어 있어 `docker compose up` 이
띄우지 않는다. 그 용도대로 수동 기동했더니 즉시 죽었다.

```
Could not resolve placeholder 'identity.crypto.email-encryption-key'
Error creating bean with name 'notificationRecipientResolver'
→ Exited (1)
```

`SesNotificationEmailConfiguration` 이 그 속성을 기본값 없이 읽는데 `/etc/idea2strategy/batch-secret.env`
가 주지 않았다. 배치가 알림 수신자를 정하려고 `identity.accounts` 를 복호화하기 때문에 필요한 키다.

**영향은 컨테이너 하나가 아니다.** 컨텍스트 refresh 가 취소되므로 그 앱의 예약 작업이 전부 돌지
않는다 — 계정 해지·휴면·보존, 마감, 만료 봇 정지, 평가 후 전이, 사설 연장 전이, 방 평가 시작,
그리고 방 전이까지.

**아무것도 이것을 보고하지 않았다.** `profiles: [manual]` 이라 `expected_services` 목록에 없고
health check 도 보지 않는다. 조용히 exit 1 한다. 이것이 이 결함이 살아 있던 이유다.

루트 PR [#441](https://github.com/Idea2Strategy/Idea2Strategy/pull/441) 에서 고쳤다(병합
`f4faed4`). 검사를 둘로 나눈 이유는 그 PR 본문에 적었다 — 요약하면 문자열 검사는 **새로 추가된**
필수 속성을 알 수 없어서, 배치 소스에서 요구사항을 파생하는 검사를
`scripts/test-batch-runtime-properties.ps1` 로 따로 두었다.

## 이 문서를 쓰는 시점의 호스트 상태

PR #441 은 병합되었지만 **아직 배포되지 않았다.** 관찰을 이어가려고 호스트에서 직접 그 줄을 넣었다 —
같은 호스트의 `/etc/idea2strategy/runtime-secret.env`(backend-api 가 쓰는 파일)에서 해당 줄을 그대로
복사했다. **값은 호스트 밖으로 나오지 않았고 내 쪽에서 본 적도 없다.** 다음 릴리스가 템플릿에서 같은
값을 쓰므로 이 손질은 그때 정본으로 대체된다.

그 뒤 배치는 실제로 떴다.

```
idea2strategy-backend-batch-1 | Up 2 minutes
Expired bot stop batch completed: scanned=0, stopsStarted=0, skipped=0
Deadline batch completed: runId=8e8a9e39-…, claimed=0, completed=0, alreadyCompleted=0, failures=1
```

작업이 도는 것까지 확인되었다. 그리고 방 전이만 계속 실패했다 — 벽 2 다.

---

# 벽 2 — 배치 역할이 자기 작업이 쓰는 테이블에 SELECT 만 갖고 있다 (넘겼음)

10초마다 같은 실패가 반복됐다.

```
ERROR … o.s.s.s.TaskUtils$LoggingErrorHandler : Unexpected error occurred in scheduled task
Caused by: org.postgresql.util.PSQLException: ERROR: permission denied for table rooms
Caused by: org.postgresql.util.PSQLException: ERROR: permission denied for table participations
```

## 확정한 방법 — 처음 조회는 나를 속였다

`information_schema.role_table_grants` 로 `idea2strategy_batch` 의 competition 권한을 물었더니
**0건**이 나왔다. "권한이 아예 없다" 로 읽힌다. 그렇게 결론 내리지 않은 것이 맞았다 — 그 뷰는
**호출자가 grantee 역할의 멤버가 아니면 행을 숨긴다.** 나는 `idea2strategy_backend_runtime` 으로
접속했으므로 `idea2strategy_batch` 의 권한을 볼 자격이 없었다. 0건은 부재의 증거가 아니라 가시성의
결과였다.

`has_table_privilege` 는 그 제약을 받지 않는다. 이것으로 확정했다.

| 테이블 | 필요한 것 | 실제 |
| --- | --- | --- |
| `competition.rooms` | `UPDATE` | SELECT |
| `competition.participations` | `UPDATE` | SELECT |
| `competition.room_events` | `INSERT` | SELECT |
| `competition.participation_events` | `INSERT` | SELECT |
| `competition.backtest_period_runs` | `INSERT` | SELECT |
| `competition.live_evaluation_segments` | `INSERT` | SELECT |
| `bot.bots` | `UPDATE` | SELECT |
| `bot.continuation_deadlines` | `INSERT` | SELECT |
| `backtest.runs` | `INSERT` | SELECT |
| `operations.outbox_messages` | INSERT·UPDATE | **이미 맞음** |

스키마 `USAGE` 는 다섯 스키마 모두 있다. 즉 접근 자체가 막힌 것이 아니라 **읽기만 열려 있다.**

## 필요한 권한을 추측하지 않았다

`backend-batch` 가 `@Import` 하는 어댑터 여섯 개의 쓰기 문장을 전수 추출해 표를 만들었다.
`DELETE` 는 어느 어댑터도 하지 않으므로 표에 없다 — 넓게 주면 안 된다는 뜻이다.

`RoomScheduleTransitionJooqAdapter` 하나가 `update competition.rooms`, `update
competition.participations`, `update bot.bots`, `insert competition.room_events`, `insert
competition.participation_events`, `insert bot.continuation_deadlines`, `insert
operations.outbox_messages` 를 모두 한다. 방 전이가 여기서 막히는 이유다.

## backend #241 과 같은 함정이 여기에도 있다

이 어댑터들은 `... for update` 를 쓴다(예: `select … from bot.bots where id = ? for update`).
PostgreSQL 은 `FOR UPDATE` 로 **지목한 모든 테이블**에 `UPDATE` 권한을 요구한다.

#241 은 정확히 이 함정이었고, 거기서는 잠금이 불필요했으므로 **잠금을 제거**했다. 여기 잠금들은
실제로 필요해 보이므로 **권한을 맞추는 쪽**이 맞다. 같은 증상에 반대 처방이라는 것을 적어 둔다 —
다음에 같은 오류를 보면 먼저 "이 잠금이 필요한가" 를 물어야 한다.

## 왜 루트에서 고치지 않았나

정본 파일이 `trading-engine/db/canonical-baseline/R__database_runtime_grants.sql` 이고 그 저장소는
`pjy008008` 소유다. `db/flyway-ci-bundle/` 사본은 핀된 리비전에서 생성되는 산출물이므로 거기를
고치면 다음 refresh 에 덮여 사라진다.

그래서 최소 선행 이슈로 넘겼다 —
[trading-engine #153](https://github.com/Idea2Strategy/Idea2Strategy-trading-engine/issues/153).
위 표와 산출 근거, 확인 방법을 그대로 담았다.

**임시로 GRANT 를 넓히지 않았다.** #241 에서와 같은 이유다 — 배포 환경에 손으로 권한을 주면 원인이
가려지고, 다음 환경에서 같은 실패가 다시 난다.

## 배치는 정지시켜 두었다

권한이 오기 전에는 유용한 일을 못 하면서 10초마다 ERROR 를 남긴다. 그래서 컨테이너를 정지·제거했다.
`profiles: [manual]` 이므로 다음 릴리스가 자동으로 되살리지 않는다.

---

# 지금 INT04 가 통과하는 것과 남은 것

| 구간 | 상태 |
| --- | --- |
| 가입 → 이메일 검증 → 로그인 | 통과 (`INT04-partial.md` §2) |
| 방 생성 → 조회 → 미공개 방 비노출 | 통과 (`INT04-partial.md` §2) |
| 백테스트 결과 ⊥ 방 점수 가드 설치·논리 | 확인 (`INT04-partial.md` §4) |
| 전략 → 검증 → 공식 릴리스(봇 생성) | **새로 통과** (backend #241 해소, 201) |
| 방 `DRAFT` → `RECRUITING` 전이 | **차단** — trading-engine #153 |
| 참가 → 봇 배정 → 평가 → 리더보드 | 위에 걸림 |
| 가드 발화 실증 | 위에 걸림 (위반 insert 에 필요한 FK 행이 안 생긴다) |

`trading-engine #153` 이 반영되고 배포되면, 배치를 띄워 위 방(`2463390f-…`)이 `RECRUITING` 으로
넘어가는지부터 이어서 확인한다. 그때 `docs/evidence/INT04.md` 로 닫는다.

## 남겨 둔 것

방 `2463390f-6cc5-4f9e-851e-afefef334743` 과 계정 `86ab2705-0507-4c2b-9b0d-5748bb330387`,
봇 `0a125e62-1f02-36f8-b3b8-a15a4ef2c774` 는 Development 에 남겨 둔다 — 이어지는 구간에서 그대로
쓴다. 방은 `DRAFT` 라 공개 목록에 나오지 않으므로 다른 시험을 방해하지 않는다.
