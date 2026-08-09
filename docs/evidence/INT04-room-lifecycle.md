# INT04 (부분) — 방 수명주기는 돈다. 점수 구간이 백테스트 경로에 걸려 있다

INT04 완료 증거가 **아니다.** 원장이 세는 파일은 `docs/evidence/INT04.md` 다. 앞선 문서는
`INT04-partial.md` → `INT04-batch-blocker.md` 이고, 이 문서는 그 둘이 남긴 차단이 어떻게 해소되었고
그 자리에서 무엇을 새로 만났는지 적는다.

## 언제 · 어디서

2026-08-09, AWS Development. 릴리스 31293508303 · 31296333509 · 31302328826 적용 후.

---

## 1. `INT04-batch-blocker.md` 의 벽 둘은 해소되었다

### 벽 1 — `backend-batch` 가 기동하지 못했다

루트 PR #441 이 `IDENTITY_CRYPTO_EMAIL_ENCRYPTION_KEY` 를 `batch-secret.env` 에 넣도록 고쳤고,
그것이 배포되어 배치가 정상 기동한다. `profiles: [manual]` 이므로 릴리스가 자동으로 띄우지 않는다는
점은 그대로다 — **인스턴스가 교체될 때마다 사라진다.** 오늘 세 번 다시 띄웠다.

### 벽 2 — 배치 역할에 competition·bot 쓰기 권한이 없었다

backend #251(`bot.continuation_deadlines` UPDATE 포함)까지 배포된 뒤, 방 전이가 실제로 일어났다.

```
2026-08-09T04:21:35Z  RoomScheduleTransitionBatchRunner :
  Room schedule transition batch completed: roomsAdvanced=2, transitionsApplied=4
permission denied 0건
```

방 두 개(`2463390f-…`, `287c762e-…`)가 `DRAFT → RECRUITING → EVALUATING → ENDED` 까지 전이되었다.
일정이 전부 과거였기 때문에 한 주기에 통과했다. **시연이나 관측용 방은 반드시 미래 시각으로 만들어야
한다** — 과거 일정 방은 10초 안에 ENDED 까지 지나간다.

`has_table_privilege` 로 확인한 배치 권한(2026-08-09):

```
competition.rooms                  SELECT UPDATE
competition.participations         SELECT UPDATE
competition.room_events            SELECT INSERT
competition.participation_events   SELECT INSERT
competition.backtest_period_runs   SELECT INSERT
competition.live_evaluation_segments SELECT INSERT
bot.bots                           SELECT UPDATE
bot.continuation_deadlines         SELECT INSERT UPDATE   ← #251
backtest.runs                      SELECT INSERT
```

---

## 2. 전이 경로에서 동시성 결함을 하나 찾아 고쳤다

`#258` 의 CI 가 `CompetitionRoomCqrsPersistenceIntegrationTest` 의 10회 반복 중 하나를 실패시켰다.
**처음에는 flaky 로 분류하고 재실행했다. 그것은 오판이었다** — backend #260 이 지적한 대로 실제
결함이다.

`advanceDue()` 가 여는 SELECT 의 후보 수를 `roomsAdvanced` 로 보고했다. 방 잠금은
`competition.rooms` 만 덮고 `competition.room_schedules` 는 덮지 않으므로, 동시 설정 변경이
`recruitment_opens_at` 을 범위 밖으로 옮기고 커밋할 수 있다. 재검증은 옳게 0건을 적용하는데 보고서는
`(roomsAdvanced=1, transitionsApplied=0)` 이 되어 불변식이 이를 거부한다.

**예외는 그 방 하나가 아니라 배치 사이클 전체를 실패시킨다** — 같은 tick 에 만기가 온 모든 방이
멈춘다. backend #260 / PR #261 로 고쳤고 `roomsAdvanced` 는 실제로 전이한 방만 센다. 아직 미배포다.

---

## 3. 참가 구간을 위한 입력은 확보했다

리허설 계정으로 API 전 과정을 밟아 봇까지 만들었다(계정 `f61cc348`, 전략 `b1f67aac`).

```
가입 → 인증 → 로그인             200
전략 생성                        201  b1f67aac-682f-4976-934c-8f7bce89e8f0
편집 리스 → 문서 저장             200  editSequence=1
검증                             201  VALID  (findings: BACKTEST_FEATURE_REQUIRED feature:RSI_14)
「봇 출시하기」(릴리스)            201  botId=c03d326e-919d-3408-b586-3f707683b4d8
```

**전략 이름에 한글을 쓰면 `curl` 경유로 400 이 났고 ASCII 로는 201 이었다.** UI 경로에서도 그런지는
확인하지 못했다 — UI 는 인코딩을 다르게 다룰 수 있으므로 여기서 단정하지 않는다. 화면에서 한 번
확인할 항목으로 남긴다.

---

## 4. 남은 차단 — 점수 구간이 백테스트 경로에 걸려 있다

`RoomEvaluationStartJooqAdapter` 는 `backtest.runs` 와 `competition.backtest_period_runs` 를 넣는다.
즉 **방 평가는 백테스트 레인을 지나간다.** 그 레인이 지금 막혀 있다.

리허설 봇의 공식 백테스트 `2b6ef43f-0606-346b-acdb-b9b59c3c088b` 가 이렇게 실패했다.

```
CalendarCoverageError: 2016-07-01 is outside the pinned XNYS coverage
  2024-01-01..2026-12-31 (xnys-2024-2026:1.0.0)
```

run 평가 구간은 2024-01-01 ~ 2025-01-01 로 달력 안이다. 2016-07-01 은 실행 정책
`development-official-backtest-2026-q3-v1` 의 `periodStart` 에서 온다 — 오케스트레이터가 run 창을
읽기 전에 정책 경계로 세션 스케줄을 만든다. backtest-engine #82 / #83 / PR #84 와 루트 #471 이
이것을 다루고 있고, 그 뒤에 정책·manifest·스키마 이름의 불일치가 더 남아 있다(루트 #471 참조).

따라서 **참가 → 봇 배정 → 평가 → 리더보드와 "백테스트 결과가 방 점수에 섞이지 않음" 실증은 그 경로가
열린 뒤에만 가능하다.** 가드 발화 실증도 그 구간이 만드는 FK 행을 필요로 한다.

## 5. 이 문서로 확정된 것

| 구간 | 상태 |
| --- | --- |
| 가입 → 로그인 | 통과 |
| 방 생성 · 조회 · 미공개 방 비노출 | 통과 (`INT04-partial.md`) |
| 전략 → 검증 → 출시(봇 생성) | 통과 — 오늘 API 전 과정 실증 |
| **방 `DRAFT → RECRUITING → EVALUATING → ENDED` 전이** | **통과 — `roomsAdvanced=2, transitionsApplied=4`** |
| 전이 집계 동시성 결함 | 수정됨 (#260), 미배포 |
| 참가 → 평가 → 리더보드 | **차단 — backtest-engine #82 / 루트 #471** |
| 백테스트 결과 ⊥ 방 점수 실증 | 위에 걸림 |

## 남겨 둔 것

계정 `f61cc348`, 전략 `b1f67aac`, 봇 `c03d326e`, run `2b6ef43f` 는 Development 에 남겨 둔다 —
이어지는 구간에서 그대로 쓴다. `backend-batch` 는 backend #264(예외를 삼켜 무한 재시도하던 결함)가
배포되기 전에는 다시 띄우지 않는다. 지금 띄우면 만료된 제재에 대한 60초 주기 실패 루프가 재개된다.
