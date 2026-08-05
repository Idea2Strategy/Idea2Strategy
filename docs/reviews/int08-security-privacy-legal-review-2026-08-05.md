# INT08 보안·개인정보·법적 표현 검토 — 2026-08-05

상태: **검토 기록 (INT08 카드는 아직 닫지 않음 — §7 완료 판정 참고)**

검토 기준 리비전 (루트 `develop` `3ac032e` 이후 병합분 포함, 전부 루트에 고정된 gitlink):

| 저장소 | 리비전 |
|---|---|
| backend | `e0ae0ff` |
| trading-engine | `c8ed07e` |
| data-pipeline | `ac3cecf` |
| ui | `83e16bc` |

방법: 카드가 명시한 다섯 축(권한 우회 · 비공개 전략 노출 · 직접 주문 · 투자 추천·위험 등급 표현 · 데이터 권리)마다 승인된 `specs/policies/`를 기준으로 삼고, 병합 코드의 실제 강제 지점을 직접 확인했다. 각 판정은 코드 증거를 인용하며, 확인하지 못한 것은 확인하지 못했다고 적었다.

## 1. 직접 주문 부재 — **충족**

기준: `policy.user.no-direct-orders` ("Users cannot submit individual orders or order intentions outside their locked strategy.")

- backend-api의 POST 표면 전수 확인: 인증·계정 lifecycle, 전략 문서·draft·edit-lease, 봇 run/stop/continuation, 방 생성·참여·초대·종료, 사건, 제재, custom backtest, 운영자 command — **주문·체결 제출 엔드포인트가 존재하지 않는다.**
- trading-engine의 두 앱(market-gateway, trading-worker)에는 `@RestController`가 하나도 없다. 주문은 오직 C의 후보 batch → F 소비 경로로만 생성된다.
- F17의 API·UI는 읽기 6개 표면뿐이고 카드 자체가 "사용자 직접 주문 입력은 제공하지 않는다"를 완료 조건으로 기록했다.
- UI 랜딩 카피가 제품 약속으로 고정: "직접 주문을 내는 일은 없습니다." (`LandingView.tsx`, i18n 대역 포함)

## 2. 비공개 전략 노출 — **충족, 후속 1건**

기준: `policy.privacy.strategy-private` ("Other users and human operators cannot read a user's detailed strategy, holdings, trades, or risk settings.")

- 전략 문서 읽기는 `StrategyDocumentQueryService.getOwned`가 bearer 세션의 `CurrentPrincipal`에 바인딩 — 소유자 외 조회 경로 없음. 봇도 동일 (`BotQueryService.getOwned`).
- 방 리더보드는 익명 별칭 + 성과 지표만 노출하고, 상세 evidence는 `viewerEvidence`가 소유자에게만 채워진다(E92, backend PR #162 — owner-only evidence, LIVE source 거절).
- 운영자 방 관리(`OperatorRoomManagementController`)는 전략·semantic 참조가 전무하다. ui `docs/PHASE5_COMPETITION_ROOMS.md`는 "전략 공개 여부" 설정 자체를 제공하지 않는 것을 설계로 고정했고, 운영자도 전략 내부를 열람할 수 없음을 명시한다.
- 백테스트 결과는 타인 run에 403이 아니라 **404**로 fail-closed — run의 존재 자체를 확인해 주지 않는다(`e2e/mockApi.ts`가 `backtest_engine/api.py`의 실제 규칙을 복제해 고정).
- E33: 제재·철회 봇은 타인의 순위·비교에서 즉시 제거되되 소유자의 원장·판단·성과 원본과 감사 근거는 보존(backend PR #160·#161 E2E).

**후속(F-1, 낮음)**: admin-mcp는 초기 릴리스에서 read-only + 기업행사 승인 relay로 한정된다고 배포 계약이 기록하나, admin-mcp의 read 도구 카탈로그에 전략 상세를 노출하는 도구가 없는지의 전수 확인은 A90 인증·감사 통합 검증에서 수행해야 한다.

## 3. 권한 우회 — **표본 충족, 전수 검증은 A90 소관**

- 고객 표면: `CustomerAccessPrincipal`이 bearer 세션에서 계정을 복원하고 `activeSanction()` 게이트를 요구한다 — 제재 계정의 fail-closed 차단은 backend #196("fail closed for sanctioned customer access")으로 병합, 루트 #188 종료.
- 운영자 표면: `contract.operations.operator-trust.v1` — HMAC lookup이 정확히 하나의 `ACTIVE` 운영자 행을 찾고 현재 요청의 MFA 증명이 있을 때만 진행하며, "raw operator, ALB, servlet identity headers are not permission evidence". UI는 dormant 운영자 fail-closed(ui #118), 모든 command에 idempotency key + `expectedVersion`(ui #122), 운영자 OIDC는 고객 세션을 재사용하지 않는 전용 PKCE(ui #127).
- 세션: 토큰은 브라우저 메모리 전용, 재적재 시 재인증 필수(`sessionAccessToken.ts`). 로그아웃 상태 `/account`·백테스트 401 fail-closed는 real-API browser E2E가 매 PR CI에서 구동.
- DB 계층: `R__database_runtime_grants.sql` least-privilege GRANT를 trading #127~#131이 baseline 테스트로 고정, backend #201 "Enforce database runtime write ownership", backend #206 "harden runtime roles on RDS".

**후속(F-2, 중간)**: 위는 표본 검증이다. "B~F API·worker가 동일 인증 주체·RBAC를 실제로 사용"하는지의 **전수** 검증은 정의상 A90 카드이며, INT08이 대신 닫을 수 없다.

## 4. 투자 추천·위험 등급 표현 — **충족, 카피 전수 확인 1건 후속**

기준: `policy.ui.reference-only`, `policy.legal.block-uncertain`, `policy.comparison.bots-only`

- '위험 등급'/'리스크 등급' 표현: ui 전체에 **0건**.
- 순위 추천 금지: PHASE5 설계 — "서비스가 하나의 지표를 최종 순위로 추천하지 않는다"; 사용자가 정렬 지표·방향을 직접 선택. 대회 워크스페이스 카피도 "익명 봇 성과만 비교합니다".
- 성과 고지 실재 확인: "과거 구간 결과는 수익성이나 안전성을 보장하지 않습니다." · "구조 검사를 통과해도 수익성, 안전성, 전략 적합성을 보장하지 않습니다." · "과거 구간 결과는 앞으로의 성과를 보장하지 않습니다." (i18n 대역 포함 — 영문 화면에서도 동일 고지)
- ui #126("make runtime UI states honest")이 시드 데이터가 실계정 화면에 유입되는 경로를 제거하고 미완성 Dashboard를 비활성화 — 표시 정직성의 구조적 보강.

**후속(F-3, 중간)**: PHASE5가 요구하는 "모든 성과 값에 모의 성과 표시"의 화면 단위 전수 확인은 INT10(UI 계약 연결) 검증 절차에 카피 체크리스트로 포함해야 한다. 백테스트·검증·랜딩 고지는 확인했으나 리더보드 셀 단위 고지는 표본 확인에 그쳤다.

## 5. 데이터 권리 — **결정 완료, 외부 확인 1건 미결**

- 데이터 소스·권리 결정은 루트 #143으로 종료: Alpaca 확장, 세 권리 전부 허용 — 구독 종료 후에도 adjusted dataset 보존·재생성 가능(재현성에 라이선스 만료 없음).
- 원시 데이터 외부 미제공: UI는 집계·성과만 표시하고, 외부 AI CLI는 Basic 공식 블록·값 조작으로 한정(B18B 안전 계약), 외부 데이터 접근 불가.
- 기업행사 증거는 가져온 바이트에서 해시 파생(루트 #205) — 출처 위조 불가.

**해소(F-4 — 2026-08-05 제품 권한자 결정으로 면제)**: 체크리스트 §0이 요구하던 "Alpaca의 서면 확인"은 수행하지 않기로 결정됐다. 데이터 권리 자체는 루트 #143의 2026-08-04 결정(3권리 전부 허용, 구독 종료 후 adjusted dataset 보존·재생성 포함)으로 확정된 것으로 간주하며, `policy.legal.block-uncertain`의 '데이터 권리 확인' 요건은 그 기록으로 충족한 것으로 본다. 구독 약관 해석에 대한 잔여 리스크는 제품 소유자가 인수했다. 결정 기록: 루트 #143 코멘트(2026-08-05, `kcrmin`). 정책 문서 자체는 변경하지 않았다. 실시간 구간(INT03·04·06)에 필요한 SIP 자격증명 공급은 별개의 배포 설정 사안이다.

## 6. 미결 항목 요약

| # | 심각도 | 항목 | 귀속 |
|---|---|---|---|
| ~~F-4~~ | ~~높음~~ | ~~Alpaca 사용 범위 서면 확인~~ — **2026-08-05 제품 권한자 결정으로 면제** (리스크 인수, 루트 #143 코멘트) | 종결 |
| F-2 | 중간 | 인증 주체·RBAC 전수 검증 | A90 (정의상) |
| F-3 | 중간 | 성과 표시 카피 전수 확인 | INT10 절차에 포함 |
| F-1 | 낮음 | admin-mcp read 도구의 전략 노출 전수 확인 | A90 |

## 7. 완료 판정

다섯 축 모두 검토를 수행했고 표본 수준의 위반은 발견하지 못했다. F-4는 2026-08-05 제품 권한자 결정으로 면제돼 **출시 차단급 미결은 없다**. 그럼에도 INT08 카드는 아직 **닫지 않는다**: INT 구간의 완료 의미(§7 "실제 서비스 조합에서 통과")는 배포된 조합에서의 재검증을 포함하며, F-1~F-3이 그 재검증(A90·INT10)에 귀속되기 때문이다.

닫는 조건: A90·INT10 검증이 F-1~F-3을 흡수하면 이 문서를 갱신하고 카드를 닫는다.
