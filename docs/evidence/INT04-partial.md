# INT04 (부분) — 방 생성 경로가 열렸다. 점수 구간은 봇을 기다린다

INT04 완료 증거가 **아니다**. 원장이 완료로 세는 파일은 `docs/evidence/INT04.md` 다.

카드 문구: "전체 방 E2E — 백테스트 결과가 방 점수에 섞이지 않는지 포함".

## 언제 · 어디서

- 2026-08-08. **AWS Development** (`https://ideatostrategy.com`).
- 릴리스 [31259186323](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31259186323)
  적용 직후. core 인스턴스가 `i-03bb3f4a492227874` 로 교체된 상태(13:36:50Z 기동).
- 로컬이 아니라 AWS 에서 한 이유: 로컬에는 채점 템플릿·수수료·버퍼 정책 시드가 없다.
  그 시드 SQL 은 저장소에 없고 "separately approved" 산출물로 경로를 받아 주입된다
  (`scripts/invoke-development-database-bootstrap.ps1:255-263`). 만들어 넣으면 제품 값을
  발명하는 셈이므로 시드가 있는 환경에서 수행했다.

---

# 1. 여기서 막혀 있었다 — 배포 환경에서 방을 만들 수 없었다

```
POST /api/v1/competition/rooms
→ 400  Unknown entity type 'CompetitionRoomJpaEntity'
       ('CompetitionRoomJpaEntity' does not belong to this persistence unit)
```

`CompetitionRoomConfiguration` 에 `@EntityScan` 이 없어 방 엔티티 네 개가 persistence unit 에
들어가지 않았다. backend #240 으로 고쳤고(루트 포인터 `72300cb`), 이 릴리스로 배포되었다.

**진단을 늦춘 것이 하나 있다.** 그 실패가 HTTP 400 "Invalid competition room" 으로 보고된다 —
서버 설정 문제를 클라이언트 오류로 알려 주므로 요청을 먼저 의심하게 된다. 실제로 그 앞에
요청 형식 문제도 둘 있었고(아래 §3), 세 번째가 되어서야 서버 쪽임을 알았다.

---

# 2. 지금 통과하는 것

## 가입 → 검증 → 로그인

```
POST /api/v1/auth/signup        → 202  {"accountId":"0e3cab40-…","verificationRequired":true}
POST /api/v1/auth/verify-email  → 204
POST /api/v1/auth/login         → 200  accessToken 발급(428자)
```

검증 메일은 SES 가 sandbox 라 배달되지 않는다. 그래서 토큰을 **VPC 안 호스트에서** 만들어
`identity.email_verification_requests.token_digest` 에 심고 **실제 검증 엔드포인트를 태웠다**.
평문 토큰과 HMAC 키는 호스트 밖으로 나오지 않았다. 우회한 것은 배달뿐이고 검증 경로 자체는
그대로 통과했다.

## 방 생성 → 조회

```
POST /api/v1/competition/rooms  → 201  {"id":"287c762e-…","accessType":"PUBLIC","status":"DRAFT"}
GET  /api/v1/competition/rooms/mine → 방이 조회되고 저장 값이 요청과 일치
     (initialCashAmount 100000.00000000, botParticipationLimit 10, perAccountBotLimit 2,
      stoppedBotSlotPolicy RELEASE, minimumOperationSeconds 3600, minimumFillCount 1)
```

## 미공개 방이 새지 않는다

```
GET /api/v1/competition/rooms/public → 방금 만든 DRAFT 방의 id 가 0건
```

`PUBLIC` accessType 이지만 상태가 `DRAFT` 이므로 공개 목록에 나오지 않는다. 접근 유형과 공개
여부가 분리되어 있음을 확인한 것이다.

## 404 두 개는 정상이다

`GET /api/v1/competition/rooms/{roomId}` 가 404 인데 **그 경로에 GET 이 없다** —
`RoomTerminationController` 가 `{roomId}` 아래 POST 세 개(withdrawal, cancellation, expulsion)만
매핑한다. 방 상세는 `rooms/mine` 이 제공한다. 리더보드도 404 인데 `DRAFT` 방에는 스냅샷이 없다.
둘 다 결함이 아니다.

---

# 3. 가는 길에 확인한 계약 두 가지

**일정 순서.** `participationClosesAt` 이 `evaluationStartsAt` **앞**이어야 한다.

```
400  "LIVE_PAPER participation must close before evaluation starts"
```

**금액은 JSON 숫자로.** `"initialCashAmount":"100000.00"`(문자열)은 400 이고 본문에 `detail` 이
없다. 숫자 `100000.00` 은 통과한다. 문자열은 Jackson 파싱 단계에서 막히므로 ProblemDetail 이
붙지 않고, 도메인 검증 실패(위 일정 오류)는 붙는다 — **오류 본문의 유무로 어느 계층에서
막혔는지 구분할 수 있다.**

또 하나: **액세스 토큰 수명이 5분**이다(`identity.jwt.access-lifetime:PT5M`). 시험 도중 401 이
나면 만료를 먼저 의심한다.

---

# 4. 카드의 핵심 불변식 — DB 가 강제하고 있다

"백테스트 결과가 방 점수에 섞이지 않는지" 는 애플리케이션 규칙이 아니라
**제약 트리거**로 걸려 있다.

```
competition_leaderboard_result_source_guard | deferrable=true | initdeferred=false
  | table=leaderboard_entries
```

`V20260802231000__backend_leaderboard_result_source_guard.sql` 의 분기가 대칭이다.

| 방 유형 | 요구 | 금지 |
| --- | --- | --- |
| `LIVE_PAPER` | `performance_snapshot_id` 있어야 함 | **`backtest_aggregate_result_id` 가 null 이어야 함** |
| `BACKTEST` | `backtest_aggregate_result_id` 있어야 함 | **`performance_snapshot_id` 가 null 이어야 함** |
| 그 외 | — | `unsupported competition type` 으로 거부 |

거기에 소유 관계까지 확인한다 — participation 이 스냅샷의 방에 속하는지, live 성과 스냅샷의
봇이 participation 의 봇과 같은지, backtest aggregate 가 그 participation 과 그 방에 속하는지.

`ELSE` 분기가 있어 **새 방 유형이 추가되면 조용히 통과하지 않고 거부된다.** 이것이 이 가드의
가장 좋은 점이다.

## 다만 트리거가 실제로 발화하는 것은 보이지 못했다

위반 insert 를 시도해 예외를 받아 보는 것이 진짜 증명이고, 그러려면 방·participation·봇·
스냅샷의 FK 를 모두 채워야 한다. 그 데이터는 봇이 돌아야 생긴다. 그래서 **설치 확인과 로직
검토까지만** 했고, 발화는 아래 남은 구간에서 확인한다. 지금 말할 수 있는 것은 "가드가 존재하고
그 논리가 대칭이다" 이며, "섞이지 않음을 실증했다" 고 쓰지 않는다.

---

# 5. 남은 것과 그 이유

| 항목 | 막는 것 |
| --- | --- |
| 방 공개 → 참가 → 봇 배정 | 봇이 필요하고, 봇은 지표(feature)가 필요하다 |
| 평가 → 리더보드 스냅샷 | 같음 |
| 가드 발화 실증 | 위반 insert 에 필요한 FK 행이 없다 |
| 원장 대사(방 계좌) | 거래가 없다 |

전부 **원장 2.5(지표 백필, 담당 `pjy008008`)** 에 걸려 있다. `feature_materializations` 가 0 인
동안에는 봇이 평가되지 않으므로 방 점수 구간을 정직하게 통과시킬 수 없다.

오늘 `data-pipeline` 이 그 경로를 여덟 번 고쳤다(#48~#55). 백필이 돌면 이 문서를 이어
`docs/evidence/INT04.md` 로 닫는다.

## 정리

이 시험이 만든 방(`287c762e-5dfb-4895-8897-f8a9e825f8a5`)과 계정은 Development 에 남겨 둔다 —
`DRAFT` 이고 공개 목록에 나오지 않으므로 다른 시험을 방해하지 않으며, 이어지는 구간에서 그대로
쓴다.
