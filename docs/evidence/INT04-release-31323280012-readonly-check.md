# INT04 선행 확인 (읽기 전용) — 릴리스 31323280012 이후 `backend-batch` 실태

INT04 완료 증거가 **아니다.** 원장이 완료로 세는 파일은 `docs/evidence/INT04.md` 이고 이 문서는
그것이 아니다. 이 문서는 **새 방을 만들기 전에** `backend-batch` 가 실제로 방 전이를 수행할 수 있는
상태인지만 읽기 전용으로 확인한 기록이다. 앞선 문서는 `INT04-batch-blocker.md` 이고, 그 문서가 남긴
두 벽 중 **벽 2(권한)는 이 확인으로 해소가 확인되었고, 벽 1(기동)은 그대로 남아 있다.**

## 언제 · 어디서

2026-08-10 02:45~02:55 KST. AWS Development, core `i-08cde9672dea60ae6`
(2026-08-09T17:13:06Z 기동 — 이전 core `i-0e94310bdc4e8f5f8` 를 릴리스 31323280012 가 교체했다).

확인을 수행한 로컬 체크아웃: 루트 `develop` `3e000be`, `origin/develop` 대비 **33 커밋 뒤**이고
`backend`·`backtest-engine`·`ui` gitlink 가 더럽다. 그래서 **이 체크아웃의
`db/flyway-ci-bundle/R__database_runtime_grants.sql` 은 배포된 것보다 낡았다** — 아래 §4 의 불일치는
그 결과이고, 결함이 아니다. 판단은 전부 라이브 DB 실측을 기준으로 했다.

**변경은 하나도 하지 않았다.** 재시작·수동 기동·ASG·DB 변경·새 배포 없음. SQS 는 attribute 조회만
했고 receive/delete/redrive 를 하지 않았다.

## 1. `backend-batch` 는 기동되어 있지 않다 (restart=0 판정 불가)

```
aws ssm send-command --instance-ids i-08cde9672dea60ae6 \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["docker ps -a --format \"{{.Names}} | {{.Status}} | {{.Image}}\"", "docker ps -aq --filter name=batch"]'
```

```
idea2strategy-backend-api-1     | Up 27 minutes (healthy) | e8e626305146
idea2strategy-backtest-api-1    | Up 27 minutes (healthy) | 2961d787c9f7
idea2strategy-backend-worker-1  | Up 27 minutes           | 447f00ba98d1
batch container → NO_BATCH_CONTAINER
docker images | grep -i batch → NO_BATCH_IMAGE
```

컨테이너가 없을 뿐 아니라 **이미지도 pull 되어 있지 않다.** `profiles: [manual]` 이라
`docker compose up` 대상이 아니고, `INT04-batch-blocker.md` §"배치는 정지시켜 두었다" 에서 정지·제거한
상태가 릴리스를 건너 그대로 이어졌다. 릴리스 성공 검사가 이것을 보지 않는 이유도 같다.

restart 횟수는 대상 컨테이너가 없어 **판정 불가**다. `restart=0` 을 통과로 적으면 안 된다.

## 2. digest — 설정은 SSM 과 일치한다. 실행 중인 이미지가 없어 실물 대조는 못 한다

```
aws ssm get-parameters --names /idea2strategy/dev/deployment/images/backend-batch
```

```
Value   = …/idea2strategy-dev/backend-batch@sha256:e8c480175c50d8dc0a23a5f85fe6796a41183f4e83d19da748d99d60992eb70a
Version = 36
LastModifiedDate = 2026-08-10T02:13:03+09:00
```

호스트 `/opt/idea2strategy/compose.yaml` 의 `backend-batch.image` 가 **같은 digest 로 고정**되어 있다.
즉 릴리스는 이 서비스에 대해서도 정상적으로 반영되었고, 아무도 기동하지 않았을 뿐이다. 다음에 수동
기동하면 릴리스 31323280012 의 이미지로 뜬다.

## 3. CloudWatch — 두 메시지는 나오고 `permission denied` 는 사라졌으나, 반복 예외가 하나 있다

로그 그룹 `/idea2strategy/dev/core`, 스트림 `backend-batch`.

```
aws logs describe-log-streams --log-group-name /idea2strategy/dev/core \
  --log-stream-name-prefix backend-batch
aws logs filter-log-events --log-group-name /idea2strategy/dev/core \
  --log-stream-names backend-batch --start-time <t> --filter-pattern '"permission denied"'
```

- 스트림의 **마지막 이벤트가 2026-08-09 20:57:58 KST** 다. 이번 릴리스 이후의 배치 로그는 **존재하지
  않는다** — §1 의 직접적 결과다. 아래는 직전 실행(2026-08-09 20:29:48 ~ 20:57:58 KST, 이전 core)이다.
- `Room schedule transition batch completed: roomsAdvanced=0, transitionsApplied=0` — 10초마다 정상 출력.
- `Room evaluation start batch completed: participantsStarted=0` — 10초마다 정상 출력.
- 종료는 크래시가 아니라 정상 종료(`HikariPool-1 - Shutdown completed`).
- `permission denied` — 스트림 전체에서 **마지막 발생이 2026-08-09 03:01 KST**, 그 이후 0건.
  `INT04-batch-blocker.md` 의 `permission denied for table rooms` 는 재현되지 않는다.
- **반복 예외 1종 있음.** 그 28분 동안 동일 ERROR 29건(분당 1건):

```
ERROR c.i.b.batch.BatchEvidenceJdbcAdapter : Batch item failed: category=SANCTION
  itemId=91687695-21be-4fd7-8855-6f0552395cc0|52b9effa-69eb-4281-8bd8-0c842fdc8858|1|2026-08-09T05:00:00Z
  attempt=1 disposition=RETRY code=UNCLASSIFIED_EXECUTION_FAILURE
  cause=org.springframework.jdbc.BadSqlGrammarException: PreparedStatementCallback; bad SQL grammar
        [insert into identity.account_sanction_heads(account_id, aggregate_version) values (?, 0)
         on conflict (account_id) do nothing ]
```

같은 SANCTION 항목이 계속 RETRY 되어 `DeadlineBatchRunner` 가 매번 `failures=2` 로 끝났다.

**ON CONFLICT 불일치는 아니다** — 실측으로 `account_sanction_heads_pkey PRIMARY KEY (account_id)` 가
존재한다(§4). 당시 `idea2strategy_batch` 에 그 테이블 INSERT 가 없어 42501 이 class-42 로 번역된 것으로
읽는 것이 가장 정합적이고(핀된 번들이 그 시점 SELECT 만 부여), **현재는 INSERT 가 부여되어 있다.**
그러므로 이 예외는 해소되었을 수 있으나 **다음 기동 전까지 확정할 수 없다.** 통과로 적지 않는다.

## 4. 권한 — `has_table_privilege` 실측. 요청한 항목은 전부 있다

`information_schema.role_table_grants` 는 호출자가 grantee 역할의 멤버가 아니면 행을 숨긴다
(`INT04-batch-blocker.md` 가 여기서 한 번 속았다). 그래서 `has_table_privilege` 로만 확정했다.
호스트에 `psql` 이 없어 이미 떠 있는 `backtest-api` 컨테이너의 psycopg 로 조회했다 — **SELECT 전용,
트랜잭션은 rollback.** 스키마 이름 해석이 호출자 USAGE 를 요구하므로 `pg_class`/`pg_namespace` 에서
OID 를 얻어 `has_table_privilege(role, oid, priv)` 형태로 물었다.

```
connected_as=idea2strategy_backtest_runtime db=idea2strategy_runtime
batch_role_exists=True

competition.rooms                              UPDATE yes
competition.rooms                              SELECT yes
competition.participations                     UPDATE yes
competition.participations                     SELECT yes
competition.room_events                        INSERT yes
competition.participation_events               INSERT yes
competition.backtest_period_runs               INSERT yes
competition.live_evaluation_segments           INSERT yes
bot.bots                                       UPDATE yes
bot.continuation_deadlines                     INSERT yes
backtest.runs                                  INSERT yes
operations.outbox_messages                     INSERT yes
operations.outbox_messages                     UPDATE yes
identity.account_sanction_heads                SELECT/INSERT/UPDATE yes

schema competition / bot / backtest / operations / identity   USAGE yes
```

`INT04-batch-blocker.md` 의 표 전체가 충족된다 → **trading-engine #153 은 라이브에 반영되어 있다.**
(이 체크아웃의 `db/flyway-ci-bundle/…grants.sql:508` 은 `account_sanction_heads` 를 SELECT 로만 적고
있으나, 그 사본은 33 커밋 뒤처진 것이므로 라이브가 정본이다. §"언제·어디서" 참조.)

### 통과하지 못한 것 — `identity.account_sanctions` 에 INSERT 가 없다

```
identity.account_sanctions                  batch has: SELECT,UPDATE     ← INSERT 없음
identity.account_sanction_events            batch has: SELECT,INSERT
identity.account_sanction_command_receipts  batch has: SELECT,INSERT
```

같은 SANCTION 계열에서 `heads`·`events`·`receipts` 는 INSERT 가 있는데 `account_sanctions` 만 없다.
§3 의 반복 실패가 `heads` 단계에서 멈춰 있었으므로 이 누락은 **아직 발화하지 않은 다음 벽**이다.
권한 부여·bootstrap 실측 검사·회귀 시험까지 묶어 준비 중인 INT04 PR 에서 고친다(2026-08-10 사용자 결정).

## 5. SQS — attribute 만 조회했다

```
aws sqs get-queue-attributes --queue-url <url> --attribute-names \
  ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  ApproximateNumberOfMessagesDelayed RedrivePolicy VisibilityTimeout
```

| 큐 | 가시 | 처리중 | 지연 | redrive |
| --- | --- | --- | --- | --- |
| `room-ledger-opened` | 0 | 0 | 0 | maxReceiveCount=5 |
| `room-ledger-open-rejected` | 0 | 0 | 0 | maxReceiveCount=5 |
| `backtest-competition` | 0 | 0 | 0 | maxReceiveCount=5 |
| `backtest-competition-dlq` | 0 | 0 | 0 | — |
| `backtest-competition-request` | 0 | 0 | 0 | maxReceiveCount=5 |
| `backtest-competition-request-dlq` | 0 | 0 | 0 | — |

적체 없음, DLQ 비어 있음. receive/delete/redrive 는 하지 않았다.

## 결론

| 확인 항목 | 결과 |
| --- | --- |
| `backend-batch` running, restart=0 | **불충족** — 컨테이너·이미지 모두 없음. restart 판정 불가 |
| 실행 이미지 digest = SSM 값 | **부분** — compose 고정값은 일치, 실행 중인 이미지가 없어 실물 대조 불가 |
| 두 배치 완료 로그 존재 | 직전 실행에서 확인. 이번 릴리스 이후 로그는 없음 |
| `permission denied` / 반복 예외 없음 | `permission denied` 없음. **SANCTION 반복 예외 있음**(해소 여부 미확정) |
| `idea2strategy_batch` 권한 | 요청 항목 **전부 충족**. `identity.account_sanctions` INSERT 누락 별건 발견 |
| SQS attribute | 전부 0, 정상 |

**따라서 이 시점에 INT04 신규 방을 만들면 안 된다.** 배치가 떠 있지 않아 `DRAFT → RECRUITING` 전이가
일어나지 않고, `INT04-batch-blocker.md` 와 같은 관찰을 반복하게 된다. 순서는 INT04 PR(권한·bootstrap
검사·회귀) → CI 통과 → 포인터 갱신과 DB bootstrap 포함 재배포 → 루트 #451 에 기존 release 사용 종료와
INT04 선점 → 그 다음에 방 생성이다. 이 문서 시점에는 #451 에 아무것도 남기지 않았다.

## 부수적으로 확인된 것

- 이 확인에 쓴 SSM 명령 출력 한 건에 **Development 백테스트 런타임 롤의 DB 자격증명이 평문으로
  남았다**(psycopg 가 DSN 을 예외 메시지에 포함시켰다). 이후 실행은 예외를 삼키도록 고쳤다.
  자격증명 회전과 노출 이력 점검은 보안 사고로 `kcrmin` 에게 별도 보고했다. **명령 ID 와 값은 공개
  문서에 적지 않는다.**
- `backtest-api` 런타임 롤은 `competition` 스키마에 USAGE 가 없다(조회 중 `permission denied for
  schema competition` 로 확인). 최소권한 관점에서 정상으로 보이며 결함으로 보고하지 않는다.
