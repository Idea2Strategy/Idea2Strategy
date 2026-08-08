# INT01 — 계약 호환성 전체 검증

카드 문구: "provider·consumer 버전·fixture 전수".

## 언제 · 어디서

- 2026-08-08
- 루트 `a3ae38f`. 서브모듈 `backend 72300cb`, `backtest-engine e950bee`,
  `data-pipeline f30f9c4`, `trading-engine f806f0c`, `ui 3d121dd`

---

# 1. 레지스트리 전수 — 통과

`contracts/registry.yaml` 의 모든 항목을 검사한다. 목록을 손으로 유지하지 않는다.

```
node --test scripts/validate-contract-registry.test.mjs
→ tests 7  pass 7  fail 0
```

무엇을 보는가:

| 검사 | 내용 |
| --- | --- |
| 항목 누락 없음 | 항목 수를 서로 다른 방법으로 두 번 세어 쪼개기가 무언가 삼키지 않았는지 |
| 지문 | 모든 계약의 `fingerprint` vs 원본 파일의 sha256 |
| provider·consumer | 모두 `.gitmodules` 에서 유도한 workspace 집합 안에 있는지 |
| 메타데이터 | `kind`·`status`·`compatibility`·`revision` 이 허용값인지 |
| 버전 | id 의 `.vN` 접미사가 원본 파일 이름의 버전과 같은지 |
| **등록 누락** | `contracts/` 에 있으나 레지스트리에 없는 파일 |
| 경로 | `source` 가 `contracts/` 밖을 가리키지 않는지 |

마지막에서 두 번째가 기존 검증기들이 하지 못하는 방향이다. 그쪽은 레지스트리→파일로 가므로,
아무도 등록하지 않은 계약 파일은 provider 도 consumer 도 없고 그것을 보는 검사도 없다.

**안 보고 통과하는 것이 아님을 확인했다.** 지문 하나를 깨니 지문 검사가 실패하고,
`contracts/business/` 에 프로브 파일을 넣으니 등록 검사가 실패했다.

이 검사는 `pnpm contract:validate:registry` 로 등록되어 CI 의 `schema-and-coordination` 잡에서
돈다.

## 만들면서 잡은 내 오류 두 개

**workspace 목록을 손으로 적은 것.** `workspace.trading`, `workspace.backtest` 라고 적었는데
레지스트리와 `.harness` 가 쓰는 이름은 `workspace.trading-engine`,
`workspace.backtest-engine` 이다. **올바른 레지스트리를 결함으로 신고했다.** 지금은
`.gitmodules` 의 서브모듈 경로에서 유도하므로 어긋날 수 없다.

**provider∩consumer 를 실패로 본 것.** "경계를 정하지 않는다" 며 막았는데 그런 규칙은 어느
승인된 문서에도 없고, 실제로 backend 가 양쪽인 계약이 둘 있다 — outbox 에 쓰는 쪽과 결과를
되받는 쪽이 같은 workspace 인 것은 정상이다. 근거 없는 규칙을 지웠다.

---

# 2. fixture 전수 (소유자 ↔ 소비자) — 통과

```
python scripts/validate_d_contract_parity.py
```

```
ok  strategy-bot.v1 fixtures (B -> backtest-engine): 6 file(s) identical to
    backend/modules/backend-messaging/src/main/resources/contracts/strategy-bot/v1
ok  data-pipeline vendored bundle: 42 vendored file(s) recorded and present
ok  backtest-engine vendored bundle: 42 vendored file(s) recorded and present

3 parity check(s) passed.
```

## 여기서 실제 결함이 나왔고, 그것이 이 카드를 이틀치 늦췄다

처음 돌렸을 때:

```
FAIL  strategy-bot.v1 fixtures (B -> backtest-engine):
      official-backtest-request.valid.json differs from its owner
```

소비자 사본이 backend 가 보내는 **아홉 필드를 빠뜨리고 있었다** — `runId`, `lane`,
`aggregateSequence`, `expectedDatasetHash`, `periodStart`, `periodEnd`,
`executionPolicyVersion`, `featureMaterializations`, `requestHash`.

그중 넷(`expectedDatasetHash`, `featureMaterializations`, `executionPolicyVersion`,
`requestHash`)은 백테스트를 재현 가능한 입력에 고정하는 값이다. 그것을 보지 않는 소비자는
**다른 데이터로 계산한 결과를 같은 요청의 결과로 받아들일 수 있다.**

**이 크기의 드리프트가 살아남은 이유는 단순하다 — 그 검증기를 아무도 돌리지 않았다.**
`.github/workflows/` 와 `package.json` 어디에도 호출하는 곳이 없었다.

원장 3.4 로 등록해 소유자(`hjcud`)에게 넘겼고, backtest-engine #71 이 고쳤다(루트 포인터
`e950bee`). 그 뒤 검증기가 `6 file(s) identical` 을 보고한다.

## 검증기를 CI 에 붙였다

`three-lane-feature-e2e` 잡의 **의존성 설치 앞에** 넣었다. 이미 `submodules: recursive` 로
체크아웃하고 Python 을 세팅하는 잡이고, 앞에 두면 전체 환경을 빌드한 뒤가 아니라 몇 초 안에
실패한다. 표준 라이브러리만 쓴다.

실행 로그에서 그 단계가 실제로 도는 것을 확인했다 —
`Verify contract fixture parity between owners and consumers`
(run 31257842485, job 93103886439).

**붙이는 것을 수정 뒤로 미룬 것은 의도적이었다.** 드리프트가 열려 있는 동안 붙이면 develop 이
전원에게 빨개지기만 하고 새로 알려 주는 것은 없다.

---

# 3. 기존 계약 검증기 — 통과

새 검사가 기존 것을 대체하지 않는다. 각각 다른 것을 본다.

```
node --test scripts/validate-release-protected-contracts.test.mjs   → tests 3  pass 3  fail 0
node --test scripts/validate-com-a-canonical.test.mjs               → tests 3  pass 3  fail 0
```

---

# 4. 통과하지 못한 것

**계약이 선언한 provider·consumer 가 실제로 그 계약을 구현하는지는 검증하지 않았다.**
이 카드가 확인한 것은 등록의 정합성(지문·버전·범위)과 fixture 의 바이트 일치다. "선언된
consumer 가 그 메시지를 실제로 처리하는가" 는 코드 경로를 타야 알 수 있고, 그것은 INT03·INT04·
INT06 이 실행으로 확인하는 것이다.

한 가지 구체적인 예를 남긴다. `RoomAccessType` 이 두 곳에 있고 값이 다르다 —
`backend-domain` 은 `PUBLIC, SECRET`, `backend-messaging` 계약은 `PUBLIC, PRIVATE` 다.
데이터베이스 enum 은 `PUBLIC, SECRET` 이고, `valueOf` 로 변환하는 유일한 지점
(`CompetitionRoomJooqQueryAdapter:120`)은 도메인 쪽을 쓴다. 그래서 지금 깨지는 곳은 찾지 못했고,
메시징 쪽 `PRIVATE` 가 어떤 소비자에게 전달되어 도메인 값으로 되돌려지는 경로가 있는지는
확인하지 못했다. 값 집합만 세는 검색으로는 판별되지 않았다(다른 문맥의 `SECRET`·`PRIVATE` 가
섞인다). **결함이라고 단정하지 않고 여기에 남긴다** — A90(인증·감사 통합)이나 INT06 에서 그
경로를 타는 시험이 답을 준다.

---

# 요약

| 항목 | 상태 | 근거 |
| --- | --- | --- |
| 레지스트리 지문·버전 전수 | 통과 | §1 — 7/7, 반증 2건 |
| provider·consumer 선언 | 통과 | §1 — `.gitmodules` 에서 유도 |
| 등록 누락 | 통과 | §1 — 기존 검증기가 못 보던 방향 |
| fixture 소유자↔소비자 | 통과 | §2 — 3/3, 실제 결함 1건 발견·해소 |
| CI 강제 | 통과 | §1·§2 — 두 검증기 모두 CI 에서 돈다 |
| 선언과 구현의 일치 | 미검증 | §4 — 실행으로만 확인 가능. INT03·INT04·INT06 |

이 카드의 가장 큰 산출물은 통과 도장이 아니라 **CI 에 붙은 두 검증기**다. 아홉 필드 드리프트가
살아남은 것은 검사가 없어서가 아니라 **아무도 돌리지 않아서**였고, 그것이 이제는 반복될 수 없다.
