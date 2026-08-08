# INT10 — UI 계약 연결 검증 증적

카드 문구: "UI 계약 연결 — 화면 전수 스위프(성과 카피 포함)".

## 언제 · 어디서

- 검증일: 2026-08-08 (Asia/Seoul)
- 담당: `hjcud`
- 환경: Windows 로컬, Node `v24.14.0`, pnpm `11.16.0`, Playwright Chromium
- 루트 기준 커밋: `2803f21b7591181b4e0570089c7726704d2b5fd7`
- UI gitlink: `3d121dd73849fec04e8fb7db8ccb04e1a3b2c3f4`
- INT10 구현 병합: UI PR #163, merge commit `7cf029ac451055a2fcea4608d73225d72d560b86`
- 루트 포인터 반영: `0f64b94`에서 `7cf029a`로 전환됐고, 현재 UI gitlink `3d121dd`는 `7cf029a`를 조상으로 포함한다.
- 상세 원본 기록: UI 서브모듈의 `docs/evidence/INT10.md`

## 판정

**PASS.** 제품 라우트와 상태를 canonical UI 명세·정책에 대조한 화면 전수 스위프가 UI PR #163으로 병합됐다. 스위프에서 발견한 공개 리더보드 성과 고지 누락을 수정했고, 공개 리더보드와 내 봇 비교의 성과 값에 한국어·영문 모의 성과 및 실제 결과 비보장 고지가 표시된다. 현재 루트가 고정한 더 최신 UI 커밋에서도 전체 회귀 검증이 통과했다.

## 기준과 화면 전수 스위프

다음 canonical UI·정책·계약을 기준으로 확인했다.

- `ui.backtest.results`, `ui.bot.operations`, `ui.room.lifecycle`, `ui.strategy.authoring`, `ui.operator.work`
- `policy.comparison.bots-only`, `policy.legal.block-uncertain`, `policy.privacy.strategy-private`, `policy.ui.reference-only`, `policy.user.no-direct-orders`
- `contract.backtest.execution.v1`, `contract.trading.virtual-execution.v1`
- `docs/PHASE5_COMPETITION_ROOMS.md` §5의 모의 성과·실제 결과 비보장 고지
- INT08 후속 F-3의 성과 표시 카피 화면 단위 전수 확인

| 화면군 | 제품 라우트 | 확인한 계약·상태 | 결과 |
| --- | --- | --- | --- |
| 진입·계정·지원 | `/landing`, `/login`, `/signup`, `/password-reset`, `/account`, `/notifications`, `/help` | 로그인 가드, 로딩·오류·빈 상태, 실제 주문 금지, 샘플 가격·성과 고지 | 통과 |
| 전략 작성 | `/strategies`, `/strategies/new/basic`, `/strategies/:id/basic`, Pro 비활성 경로 | Basic 작성·검증·저장, 소유자 범위, 비보장 카피, v1.0 Pro 거절 | 통과 |
| 봇 운용·홈 | `/`, `/bots` | 대기·실행·중지·실패 상태, 개인 운용과 대회 성과 분리, 임시 성과 미표시 | 통과 |
| 백테스트 | `/backtests` | 인증 가드, 목록·실행·시도·월별 거래·공식 성과·오류·빈 상태, 과거 결과 비보장 카피 | 통과 |
| 모의투자 대회 | `/competition` (`/competition-v2`는 redirect) | 공개·소유 방, 익명 봇만 비교, 로딩·오류·빈·종료 상태, 성과 카피 | 누락 1건 수정 후 통과 |
| 운영자 | `/operations/login`, `/operations/callback`, `/operations/cases`, `/operations/rbac`, `/operations/competition` | 전용 인증, 권한 거절, 검토·확인·처리·성공·실패 상태, 고위험 명령 영수증 | 통과 |

`DesignConceptLab.tsx`와 `data/mockData.ts`는 제품 라우터가 사용하는 실 API 경로가 아니므로 런타임 성과 카피 판정에서 제외했다. 제품 경로는 `App.tsx`의 실제 라우트와 주입된 실 API 클라이언트를 기준으로 판정했다.

## 성과 카피 수정과 회귀 방지

- `CompetitionApiWorkspace.tsx`: 공개 리더보드와 내 봇 비교에 성과 고지를 추가했다.
- `i18n.tsx`: 동일 의미의 영문 고지를 추가했다.
- `CompetitionApiWorkspace.test.tsx`: 한·영문 양쪽에서 두 리더보드 고지가 존재하는지 확인한다.
- `competition-performance-disclosure.e2e.ts`: 실제 Chromium과 실제 라우터·HTTP 클라이언트에서 한국어 데스크톱(1440×900), 영문 모바일(390×844)을 검증한다. API 서버만 계약 fixture로 대체한다.

## 최신 UI gitlink 재검증

`C:\Users\SSAFY\Documents\Idea2Strategy\ui`에서 실행했다.

```powershell
pnpm exec vitest run
```

관찰 결과:

```text
Test Files  47 passed (47)
Tests       555 passed (555)
```

```powershell
pnpm run typecheck
```

관찰 결과: `tsc --noEmit` 종료 코드 0.

```powershell
pnpm run build
```

관찰 결과: Vite가 1,857개 모듈을 변환했고 프로덕션 빌드가 종료 코드 0으로 완료됐다.

```powershell
pnpm run e2e
```

관찰 결과:

```text
Running 9 tests using 9 workers
9 passed (5.4s)
```

E2E에는 다음 INT10 전용 브라우저 검증이 포함됐다.

- 한국어 데스크톱에서 두 리더보드의 모의 성과 고지 확인
- 영문 모바일에서 두 리더보드의 모의 성과 고지 확인

## 통과하지 못한 항목

없음. Vitest의 jsdom 환경에서 `HTMLCanvasElement.getContext()` 미구현 안내가 출력됐지만 테스트 실패는 없었고, 실제 브라우저 검증은 Playwright Chromium 9/9로 별도 통과했다.
