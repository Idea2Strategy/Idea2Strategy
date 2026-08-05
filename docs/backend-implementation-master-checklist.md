# Idea2Strategy 서비스 구현 마스터 체크리스트

> 상태: A~F 담당자 확정, GitHub Issue 생성 전 기준안
> 목적: 공통 선행 단계 완료 후 A~F 중 하나를 맡은 6명의 개발자가 자신의 묶음을 독립적으로 진행하고, 모든 카드가 완료되면 전체 서비스가 실제로 동작하도록 한다.

사용자에게 보이는 카드는 서버 구현만으로 완료되지 않는다. 마스터 카드 하나는 루트 저장소의 상위 사용자 흐름 Issue가 되고, 실제 `ui`·서버·엔진 작업은 저장소별 하위 Issue로 나눈다. 상위 Issue는 화면·API 연결·loading·empty·error·permission 상태와 기능 E2E까지 검증된 뒤에만 완료한다.

## 0. 현재 구현 범위

- 현재 개발과 첫 정식 출시는 `Basic` 전략 모드만 대상으로 한다.
- `Pro`는 제품에서 영구 폐기한 것이 아니라 후속 개발 범위로 보류한다.
- 아래에서 `보류(Pro)`로 표시한 카드는 현재 파트 완료와 첫 정식 출시 완료 조건에 포함하지 않는다.
- 공통 DB와 계약은 나중에 Pro를 추가할 수 있는 확장 지점을 막지 않되, 현재 구현에 사용하지 않는 Pro 실행기·노드·수식·UI를 미리 만들지 않는다.
- 외부 AI 연동용 CLI는 현재 출시 범위에 포함하되, Basic 공식 블록과 값만 조작할 수 있다. 사용자 코드, Pro 노드 그래프, 외부 데이터와 직접 주문은 허용하지 않는다.
- 과거 시장 데이터 provider는 Alpaca SIP로 유지한다.
- 실시간 시장 데이터는 Alpaca Algo Trader Plus의 SIP feed를 사용한다. 현재 공식 게시 가격은 월 99달러이며 결제 시점의 요금과 조건을 다시 확인한다.
- 실시간 대상 universe는 플랫폼이 제공하는 미국 주식·ETF 약 550개다. 하나의 `market-gateway`가 SIP WebSocket으로 구독하며 REST polling을 정상 수집 경로로 사용하지 않는다.
- 유료 구독과 외부 표시·재배포 권한은 별개로 취급한다. 원시 데이터는 외부에 제공하지 않으며 운영 전 실제 서비스 사용 범위에 대한 Alpaca의 서면 확인과 권리 gate가 필요하다.

## 1. 사용하는 방법

담당자 배정표:

| 묶음 | 담당자 | 상태 |
|---|---|---|
| A — 계정·운영 | 나주원 (`Juwon-Na`) | 배정 완료 |
| B — 전략·봇 | 손현준 (`hjcud`) | 배정 완료 |
| C — 시장·평가 | 박준유 (`pjy008008`) | 배정 완료 |
| D — 데이터·백테스트 | 서동위 (`SeoDongWi`) | 배정 완료 |
| E — 방·성과 | 황영우 (`dertz569`) | 배정 완료 |
| F — 거래·원장 | 민경철 (`kcrmin`) | 배정 완료 |

사용자가 `나는 B 담당이야. 이제 뭐 해야 해?`라고 하면 다음 순서로 처리한다.

1. B 묶음에서 완료되지 않았고 선행 카드가 끝난 첫 카드를 찾는다.
2. 실제 Git·서브모듈·진행 중 작업과 의미 충돌을 Stackcord로 확인한다.
3. 해당 카드를 루트 상위 Issue로 두고, 지금 담당자가 처리할 저장소 하위 Issue 하나를 실행 가능한 Stackcord 작업으로 정의해 작업 브랜치를 예약한다.
4. 최초 실패 테스트부터 작성하고 구현·검증한다.
5. 필요한 DBML·Flyway·계약·문서 변경을 같은 PR 또는 명시된 선행 PR에 포함한다.
6. 하위 Issue 완료 근거와 PR을 상위 Issue에 기록한 후 다음 `Ready` 하위 Issue를 안내한다.

`해줘`라고 하면 저장소 하위 Issue 하나를 끝까지 처리한다. 서로 다른 저장소나 담당자의 하위 Issue를 한 PR에 섞지 않는다. 단, 해당 하위 Issue가 소유한 API·Command·Query·DB·테스트는 기능 완성을 위해 함께 구현한다.

각 루트 상위 Issue에는 하위 Issue별 저장소, 담당자, `Blocked by`, 단독 소유 경로·DB·계약과 완료 산출물을 표로 기록한다. 저장소마다 Issue 번호가 독립적이므로 같은 번호를 강제하지 않고 모두 같은 상위 Issue에 연결한다.

각 하위 Issue에는 구현 기술도 명시한다. `backend`와 `trading-engine`은 Java·Spring Boot, `data-pipeline`과 `backtest-engine`은 Python, `ui`는 TypeScript·React·Vite다. Python API는 FastAPI, 장시간 실행은 worker, 예약·이벤트성 데이터 작업은 배포 결정에 따라 worker 또는 Lambda로 표시한다.

## 2. 6명 공통 선행 단계

아래 단계는 A~F를 나눈 뒤 각자 구현을 시작하기 전에 한 번만 완료한다. 한 사람이 공통 구현 전체를 떠안지 않고, 각 묶음 담당자가 자신이 생산할 계약과 fixture를 동시에 준비한다.

- [x] **COM01 — 협업 기준 commit 확정**: 루트의 DBML·문서·계약 후보를 검토해 `develop` 기준 commit을 확정하고, 별도 UI 작업의 submodule pointer를 백엔드 기준선 변경과 섞지 않는다.
- [x] **COM02 — 확정 runtime·build 기준 적용**: Java 21 LTS, Spring Boot 4.1.0, Gradle 8.14.3, Python 3.12.13, FastAPI 0.139.2, Uvicorn 0.52.0, Node.js 24 LTS, pnpm 11, PostgreSQL 16, Redis 7.4, Flyway 11과 Docker Compose v2를 각 저장소의 build·lock·실행 기준에 반영하고 재현 가능한 로컬 명령을 검증한다.
- [x] **COM03 — 공통 인프라와 전달 경계 구현**: 운영 durable command/job queue는 AWS SQS, 로컬 대체물은 LocalStack SQS로 구성한다. SQS Standard를 기본으로 사용하고 순서 보장이 실제 계약인 경로만 FIFO를 사용한다. Redis는 실시간 시장 사건과 최신 상태에만 사용하며 durable 작업 Queue로 대체하지 않는다. SQS의 at-least-once 전달을 전제로 consumer 멱등성, 재시도와 DLQ를 검증한다.
- [x] **COM04 — backend 공통 골격 병합**: A가 주도하고 B·E가 검토해 네 Spring App과 domain/application/persistence/messaging/common 모듈, 공통 build logic과 빈 앱 기동 테스트를 먼저 `backend/develop`에 병합한다.
- [x] **COM05 — 공통 요청·오류·시간·사건 envelope**: 오류 응답, pagination, API version, correlation/idempotency key, UTC 저장·미국 동부 시각 해석과 event envelope를 fixture로 고정한다.
- [x] **COM06 — 서비스 경계 계약 fixture**: B는 Basic compiled plan·봇 명령, C는 시장 사건·평가 결과·주문 후보 batch, D는 Dataset Manifest와 백테스트 요청·결과, E는 방 평가 구간·성과 입력, F는 주문·체결·원장 사건 fixture를 각각 제안하고 모든 consumer의 계약 테스트를 통과시킨다.
- [x] **COM07 — DB 소유권·중앙 Flyway baseline**: 스키마·테이블별 단일 write owner가 자신이 소유한 변경의 migration을 작성하고, 나주원(`Juwon-Na`)이 중앙 Flyway 모듈의 통합 담당자로서 순서·충돌·DBML 일치를 검토한다. 전용 Flyway 1회 실행, 서비스별 최소 권한, timestamp 기반 migration 이름, JPA validate·jOOQ code generation과 Python 접근 경계를 검증한다.
- [x] **COM08 — 독립 테스트 kit**: fake auth, fake clock, fake queue, 녹화 시장 사건, 소형 Parquet, fake S3와 Testcontainers를 각 저장소에서 외부 구현 없이 사용할 수 있게 한다.
- [x] **COM09 — 공통 CI gate**: build, lint, test, migration, DBML, 계약 호환성, dependency·secret scan과 앱 smoke test를 `develop` PR 필수 검사로 구성한다.
- [x] **COM10 — 병렬 작업 소유권 확인**: A~F의 경로·스키마·계약 producer를 확정하고 Stackcord로 의미·migration·workspace·root pointer 충돌과 병합 순서를 확인한다.
- [x] **COM11 — UI 공통 골격**: 실제 제품용 `ui` 서브모듈에 app shell, router, 인증 상태, API client, 공통 오류·loading 처리와 테스트 기반을 먼저 병합한다.
- [x] **COM12 — Issue·브랜치·PR 흐름 검증**: 확정된 A~F 담당자를 루트 사용자 흐름 Issue와 저장소별 하위 Issue에 배정한다. 이후 하위 Issue 하나를 선택해 해당 저장소 feature 브랜치→`develop` PR→E2E→Issue 종료→최신 `develop`에서 다음 브랜치 생성 흐름을 검증한다.

보호된 `contracts/`나 제품 의미를 변경할 때는 정확한 GitHub commit에 대한 제품 권한자의 fresh 승인이 확인되어야 한다. 확인 전에는 격리된 proposal과 각 리포의 소비자 fixture까지만 준비하고 확정 계약으로 표현하지 않는다.

## 3. 공통 완료 기준

모든 카드는 다음을 만족해야 완료다.

- 카드에 적힌 사용자 또는 시스템 결과가 실제 실행된다.
- 구현 전 해당 핵심 동작을 검증하는 실패 테스트가 존재한다.
- 정상, 권한 없음, 잘못된 입력, 중복 요청, 재시도와 장애 경로를 검증한다.
- Spring Command는 기본적으로 JPA, Query는 jOOQ를 사용한다. 원장처럼 원자적 SQL이 필요한 Command에는 jOOQ를 제한적으로 사용할 수 있다.
- Python은 SQLAlchemy Core로 허용된 스키마만 접근하고 Alembic을 사용하지 않는다.
- DB 변경이 필요하면 `db/schema.dbml`과 새 Flyway migration을 PR에 포함한다. 적용된 migration은 수정하지 않는다.
- `operations` 테이블을 포함한 미세한 DB 변경은 제품 방향을 바꾸지 않는 범위에서 카드 PR로 처리할 수 있다.
- 계약 변경도 서비스 방향을 바꾸지 않으면 버전 호환성·소비자 테스트와 함께 PR로 처리할 수 있다.
- 서비스 방향, 법적 경계 또는 사용자에게 보이는 핵심 의미가 달라지면 구현을 멈추고 제품 결정 PR을 먼저 검토한다.
- 로그에 인증정보, 토큰, 비공개 전략 원문과 불필요한 개인정보를 남기지 않는다.
- 감사 대상 동작에는 행위자, 권한, 대상, 사유, 전후 상태와 서버 시각을 남긴다.
- 정적 분석, 단위 테스트, DB 통합 테스트, 계약 테스트와 해당 앱 기동 검증을 통과한다.
- 사용자 기능은 실제 UI 화면, API 연결, loading·empty·error·permission 상태와 E2E를 통과한다.
- 임시 stub, 비어 있는 성공 응답, 숨겨진 기본 정책과 해결되지 않은 핵심 TODO를 남기지 않는다.
- 기능 PR은 `develop`을 대상으로 하고 `main`은 v1.0 이상 정식 릴리스만 받는다.

## 4. 병렬 개발 원칙

- A~F는 각자 자신의 저장소와 소유 테이블을 구현한다.
- 서비스 간 인터페이스는 producer가 버전형 계약과 예제 fixture를 먼저 PR로 제시한다.
- consumer는 provider 구현을 기다리지 않고 fixture와 fake adapter로 개발·테스트한다.
- consumer는 알 수 없는 새 필드를 무시하고, producer는 기존 필드 의미를 같은 버전에서 바꾸지 않는다.
- 이벤트는 event ID, schema version, aggregate ID, occurred-at, correlation ID와 idempotency key를 가진다.
- 외부 서비스가 아직 없어도 각 묶음은 Testcontainers, fake queue, fake clock, fixture Parquet으로 자체 검증을 완료할 수 있어야 한다.
- 다른 담당자의 실제 구현이 필요한 카드는 `통합`으로 표시한다. 각 담당자는 통합 카드를 제외한 자신의 묶음을 먼저 끝낼 수 있다.
- 루트 계약과 DBML에서 같은 부분을 동시에 바꿔야 하면 먼저 소유자와 병합 순서를 정한다.

### 파트 완료와 전체 서비스 완료

각 담당자는 다른 구현을 기다리지 않고 다음 범위까지 끝내면 자신의 `파트 완료`로 표시할 수 있다.

- A 담당: A07~A22와 A 묶음 독립 E2E
- B 담당: `보류(Pro)`를 제외한 B01~B27, B18A~B18B와 B 묶음 독립 E2E
- C 담당: `보류(Pro)`를 제외한 C01~C19와 C 묶음 독립 E2E
- D 담당: D01~D30과 D 묶음 독립 E2E
- E 담당: E01~E34와 E 묶음 독립 E2E
- F 담당: `보류(Pro)`를 제외한 F01~F16·F08A와 F 묶음 독립 E2E

`A90` 같은 90번대 카드는 실제 상대 서비스와 연결하는 통합 카드이므로 파트 완료를 막지 않는다. 먼저 끝낸 담당자는 자신의 파트를 완료 상태로 만든 뒤 다른 묶음 지원이나 90번대 통합을 맡을 수 있다. 모든 파트와 통합 카드가 끝나야 전체 서비스 완료다.

### 같은 backend 저장소 안의 파일 소유 경계

| 묶음 | 우선 소유 경로 |
|---|---|
| A | 실행 앱 공통 설정, build logic, common, identity, operations, security, notification |
| B | strategy, bot-control과 해당 API·Query adapter |
| E | competition, performance와 해당 API·Query adapter |

COM04는 B와 E의 내부 구현을 만들지 않는다. B01과 E01은 자신의 모듈 안에서 독립적으로 골격과 테스트를 만들 수 있다. 공통 Gradle 설정을 변경해야 할 때만 작은 호환 PR을 먼저 병합하며, 다른 파트의 비즈니스 구현 완료를 기다리지 않는다.

### 같은 trading-engine 저장소 안의 파일 소유 경계

| 묶음 | 우선 소유 경로 |
|---|---|
| C | `apps/market-gateway`, market-data adapter, strategy-runtime, evaluation과 `bot` 평가·runtime state persistence |
| F | `apps/trading-worker`, order·execution·settlement, trading persistence·messaging과 `trading` 전체 |

COM04와 별도로 trading-engine의 공통 Gradle 골격과 `evaluation-result/order-candidate-batch` 인터페이스를 먼저 병합한다. C는 후보를 만드는 단계까지만 소유하고 F는 후보를 입력받은 뒤 예산·위험 검사, 주문·체결·원장을 소유한다. C와 F는 상대 소유 module의 구현 class를 직접 참조하지 않고 공통 interface·fixture만 사용한다.

## 5. 공통 인터페이스 소유권

| 인터페이스 | Producer | Consumer |
|---|---|---|
| 인증 주체·운영자 권한 | A | B, C, D, E, F |
| Basic 전략 출시 스냅샷·백테스트 요청 | B | D |
| 봇 실행·중단 명령 | B | C |
| 시장 이벤트 | C | C의 평가 runtime, D의 실시간 적재 |
| 평가 결과·주문 후보 batch | C | F |
| 주문·체결·원장 사건 | F | B, E, A의 알림 |
| Dataset Manifest | D | C, D의 백테스트 |
| 백테스트 완료·불가 사건 | D | B, E, A의 알림 |
| 방 평가 구간·참가 자격 | E | B, C, D |
| 성과 projection 입력 | F | E |

Provider 구현을 기다릴 필요는 없다. 표의 Producer가 계약 fixture를 먼저 제공하고 Consumer는 그것으로 독립 구현한다.

---

# A — 계정·운영

담당자: 나주원 (`Juwon-Na`)
주 저장소: `backend`, 루트 저장소
실행 앱: `backend-api`, `backend-batch`, `backend-worker`, `admin-mcp`
기술·런타임: Java·Spring Boot
주요 스키마: `identity`, `operations`
완료 결과: 사용자가 안전하게 가입·로그인하고, 운영자가 RBAC 범위에서 서비스 전체를 감사·처리하며, 나머지 서비스가 공통 실행 기반을 사용한다.

## A1. 독립 시작 — 사용자 계정과 인증

- [x] **A07 — 이메일 가입·검증·로그인**: 이메일 검증, 비밀번호 정책, 로그인과 실패 이벤트를 구현하고 미검증·중복 계정을 차단한다.
- [x] **A08 — 소셜 로그인 연결**: 허용된 provider 로그인, 기존 이메일 계정 연결과 계정 탈취 방지 검증을 구현한다.
- [x] **A09 — 세션·로그아웃·동시 접속 제한**: 서버 세션 발급·회전·폐기와 다른 세션 차단을 구현하고 인증 사건을 기록한다.
- [x] **A10 — 비밀번호·계정 복구**: 재설정 요청, 만료·일회용 토큰, 복구 코드와 보안 알림을 구현한다.
- [x] **A11 — 계정 환경설정·동의·정책 버전**: 언어, 미국 시장 시각 표시, 라이트·다크 선호, 약관·개인정보 동의 버전을 관리한다.
- [x] **A12 — 탈퇴·휴면·수명주기**: 탈퇴 요청과 취소 가능 구간, 보존·비식별 처리 및 계정 수명주기 사건을 구현한다.

## A2. 권한·외부 도구·운영

- [x] **A13 — 운영자 RBAC**: 상위 권한자가 허용된 범위에서 하위 운영자에게 역할을 위임·회수하고 모든 권한 변경을 감사한다.
- [x] **A14 — 계정 제재와 서비스 중단**: 일시·영구 제재 시 모든 서비스 접근과 실행 중 봇을 중단하되 데이터를 삭제하지 않고 이의제기 경로를 유지한다.
- [x] **A15 — 외부 AI CLI 위임 인증**: 사용자가 명시한 scope·만료·대상 전략 범위의 위임 credential을 발급·회수하고 직접 코드·주문 제출은 차단한다.
- [x] **A16 — 관리자 MCP 권한 경계**: 기업행사 후보, 데이터 사건, 방·계정 사건을 RBAC로 조회·승인하되 전략 생성과 사용자 주문은 허용하지 않는다.
- [x] **A17 — Outbox·비동기 작업 기반**: transactional outbox 발행, 소비 멱등성, 재시도, dead-letter와 운영 재처리를 구현한다.
- [x] **A18 — 알림 설정·전달**: 필수 운영 알림과 선택 알림, 앱·이메일 전달, 재시도·실패 기록과 읽음 상태를 구현한다.
- [x] **A19 — 사용자 사건함**: 문의·신고·이의제기 제출, 상태 전환, 첨부 근거 참조와 사용자 조회를 구현한다.
- [x] **A20 — 운영 사건 처리**: 운영자가 사건을 조회·배정·처리하고 근거·결과·전후 상태를 감사 기록으로 남긴다.
- [x] **A21 — 정기 backend-batch 업무**: 제재·세션·토큰·알림·사건의 기한 전환을 재실행 가능하고 멱등적으로 처리한다.
- [x] **A22 — A 묶음 독립 E2E**: fake 전략·봇·방 사건을 사용해 가입부터 알림·운영 처리까지 독립 E2E를 통과시킨다.
- [x] **A23 — 계정·운영 UI 연결**: 로그인·가입·계정 설정·알림·권한별 운영 화면을 실제 API와 연결하고 오류·권한 상태 E2E를 통과시킨다. — 마지막 잔여였던 전용 고객 로그인·가입 화면이 ui #128로 병합됐다(`/login`·`/signup`, login이 `setSessionAccessToken`으로 세션 확립, topbar 알림의 로그인-필요 상태에서 `returnTo`를 실은 진입점). real-API browser E2E가 실제 backend+PostgreSQL 대상으로 신규 화면 경유 저니를 증명한다: 로그아웃 상태 `/account` fail-closed → `/signup` 가입(202)·이메일 인증(204) → `/login`에서 **잘못된 비밀번호 401이 화면 alert로 표시되고 라우트가 머무름** → 로그인(200) → `/account` 세션 확립·서버 설정 저장·user-case 접수. 계정 설정·알림은 ui #116·#117·#124, 권한별 운영 화면은 ui #118·#122·#127(운영자 OIDC PKCE, 제재·사건 command, dormant fail-closed). 실제 Cognito IdP 연결은 배포 게이트로 A90·A91에서 검증한다

## A3. 통합 구간

- [ ] **A90 — 전체 서비스 인증·감사 통합** `통합`: B~F API·worker가 동일 인증 주체, RBAC, Outbox와 감사 계약을 실제로 사용하는지 검증한다.
- [ ] **A91 — 배포·복구·릴리스 파이프라인** `통합`: Core·Trading·Compute 배포, migration 1회 실행, 롤백·백업 복원과 develop→release→main 절차를 검증한다.

---

# B — 전략·봇

담당자: 손현준 (`hjcud`)
주 저장소: `backend`, 루트 계약
실행 앱: `backend-api`, 일부 `backend-batch`·`backend-worker`
기술·런타임: Java·Spring Boot
주요 스키마: `strategy`, `bot`의 제어·구성 테이블
완료 결과: Basic 전략을 저장·검증·출시하고, 불변 출시본으로 개인 또는 방 참여 봇을 만들고 실행·중단할 수 있다. Pro 전략은 후속 범위로 보류한다.

## B0. 독립 시작 구간

- [x] **B01 — strategy/bot 모듈 골격과 테스트 fixture**: backend 안에 두 도메인의 CQRS-lite 구조, fake 인증 주체·clock·event publisher와 DB 통합 테스트를 만든다.
- [x] **B02 — 공식 종목·지표·Basic 블록 카탈로그 조회**: 버전 고정된 지원 종목, feature와 Basic 블록 정의를 조회하고 비공식 요소 사용을 차단한다.
- [x] **B03 — Basic 템플릿·패키지·버전 조회**: 플랫폼 검증 Basic 매수·매도 템플릿과 재사용 가능한 공식 구조를 값이 비어 있는 버전으로 제공한다.
- [x] **B04 — Basic 전략 문서 복원**: 퍼즐 블록의 타입·연결·매개변수·감싸는 그룹과 편집 위치를 lossless JSON 문서로 저장·조회한다.

## B1. 전략 작성과 검증

- [x] **B05 — Basic 전략 생성·임시 저장**: Basic 전략 생성, 자동·명시적 임시 저장과 edit sequence 검사를 구현하며 임시 전략에는 백테스트를 실행하지 않는다.
- [x] **B06 — 단일 세션 편집 lease**: 한 계정의 다른 세션을 포함한 동시 편집을 막고 만료·회수·복구 가능한 편집 lease를 구현한다.
- [x] **B07 — Basic 블록 조립 검증**: 순차 흐름, 매수·매도 컨테이너, 동적 입력 타입, 독립 종목 평가와 균등 배분 제한을 검증한다.
- [x] **B08 — Basic 규칙 기반 자연어 번역**: 완성된 블록 그룹의 각 부분을 값과 의미가 변하지 않는 규칙 기반 문장으로 생성한다.
- [ ] **B09 — 보류(Pro): Pro 타입 그래프 검증**: 좌우 그래프, 타입 포트, 다중 출력·분기, 다종목 목록 연산, 그룹·재사용·수식과 순환 금지를 검증한다.
- [ ] **B10 — 보류(Pro): Pro 예산·배분·리밸런싱 정책 검증**: 필수 선택이 빠지면 활성화를 막고 숨겨진 기본값 없이 명시적 정책만 허용한다.
- [x] **B11 — 데이터·백테스트 가능성 검증**: 필요한 feed·시간 해상도·feature와 백테스트 불가 블록을 식별하고 근사 없이 결과를 반환한다.
- [x] **B12 — 검증 실행·오류 위치 조회**: 검증 snapshot, 오류·경고, 요소 위치와 재검증 상태를 저장·조회한다.
- [ ] **B13 — 보류(Pro): Basic→Pro 복사 변환**: 원본을 변경하지 않고 새 전략 문서를 만든 뒤 의미 보존 가능한 요소만 Pro 그래프로 변환한다.
- [x] **B14 — 전략·패키지 복사**: 출시 여부와 관계없이 별개 객체로 복사하고 실행 상태·원장·성과는 이어받지 않는다.

## B2. 출시와 외부 AI 도구

- [x] **B15 — Basic 실행 계획 compile**: 검증된 Basic 문서를 결정론적 실행 계획으로 compile하고 카탈로그·템플릿·정책 버전을 고정한다.
- [x] **B16 — 불변 전략 출시**: 유효한 snapshot을 한 번 출시하고 이후 수정·리비전을 금지하며 변경은 복사 후 새 출시만 허용한다. — 출시 시점 `strategy-bot.v1` compiled plan 발행 보강: backend PR #193(`946832e`, 루트 #190). launch snapshot과 같은 트랜잭션에서 `bot.launch_contract_plans`에 기록하므로 plan이 고정하는 snapshot_hash와 RUN·STOP 명령이 싣는 해시가 항상 같은 release를 지목한다. Element 카탈로그의 `executionContract.runtime`이 element code를 runtime operation으로, feature 카탈로그가 warm-up 요구로 번역되며, 그룹이 하나의 실행 순서로 compile되지 않는 전략은 거부(계약이 plan 전체에 단일 `steps`·단일 side를 싣고 C·D 양쪽이 그렇게 구현하므로)
- [x] **B17 — 출시·자동 백테스트 계약 발행**: 정확히 한 번의 공식 백테스트 요청 fixture와 Outbox 사건을 제공하고 재시도 중복을 막는다.
- [x] **B18 — 외부 AI용 Basic 전략 편집 API**: 위임 scope 안에서 공식 Basic 블록 추가·삭제·연결, 값 설정, 미리보기와 검증만 허용하고 코드·외부 데이터·주문 제출을 차단한다.
- [x] **B18A — 배포 가능한 Idea2Strategy CLI**: 로그인·위임, 전략 목록·생성·복사, Basic 블록 편집, 검증·출시를 안정된 명령·exit code·JSON 출력으로 제공한다.
- [x] **B18B — 외부 AI Tool 계약·안전 검증**: AI가 CLI를 도구로 호출해 허용된 Basic 변경만 만들고 적용 전 diff를 확인하며 권한 초과·직접 주문·임의 코드를 거절하는 E2E를 제공한다.
- [x] **B19 — 전략 라이브러리 Query**: 임시·출시 전략, 템플릿, 패키지, 검증·백테스트 상태를 권한과 pagination에 맞게 조회한다.

## B3. 봇 구성과 수명주기

- [x] **B20 — 봇 생성·출시 snapshot**: 출시 전략을 사용해 별개 봇 객체, 파티션·흐름·종목·feature 요구사항·예산 구성을 잠근다.
- [x] **B21 — 봇 실행 전 검증**: 제공 종목만 허용하고 최대 동시 실행 10개, 초기자본, 비용·위험 정책과 데이터 준비 상태를 검증한다.
- [x] **B22 — 봇 실행·대기 명령**: 개인 봇은 즉시 실행 명령을, 방 참여 봇은 방 일정에 맞는 대기·평가 시작 명령을 멱등적으로 발행한다.
- [x] **B23 — 봇 상태·구성 Query**: waiting/running/stopping/stopped/data-degraded/settlement-failed와 구성·이벤트·최근 근거를 조회한다.
- [x] **B24 — 봇 중단 orchestration**: 신규 평가 차단→미체결 취소→포지션 정산→재실행 불가 상태의 명령 순서와 실패 복구를 관리한다.
- [x] **B25 — 무소속 봇 30일 명시적 연장**: 로그인과 조회로 연장하지 않고, 기한 7일 전부터 버튼을 허용하며 서버 접수 시각부터 정확히 30일 뒤로 다음 기한을 계산한다.
- [x] **B26 — 확인 기한 강제 중단 batch**: 기한을 넘긴 무소속 봇에 중복 없이 중단 절차를 시작하고 알림 전달 실패와 무관하게 정책을 적용한다.
- [x] **B27 — B 묶음 독립 E2E**: fake 인증·백테스트·trading adapter로 전략 생성→검증→출시→봇 실행·중단을 검증한다.
- [x] **B28 — 전략·봇 UI 연결**: Basic 전략 편집·검증·출시, 봇 생성·실행·중단 화면을 실제 API와 연결하고 E2E를 통과시킨다.

## B4. 통합 구간

- [x] **B90 — 자동 백테스트 실제 연동** `통합`: B17 계약으로 D가 공식 실행 한 건을 생성하고 B Query에 상태가 반영되는지 검증한다.
- [x] **B91 — 봇 제어와 trading 실제 연동** `통합`: 실행·중단 명령과 C의 평가 상태·F의 주문 및 정산 상태가 중복·역순 전달에서도 일관된지 검증한다. — trading-engine PR #121(`980d7e1`), 선행 backend PR #193(`946832e`, 루트 #190). 프로덕션 `StrategyBotControlConsumer` bean이 없어 RT5 poller가 배선되지 않았고 명령이 outbox에 방치되던 결함 해소. 실 PostgreSQL에서 `operations.outbox_messages` 행을 실제 poller가 청구하고 실제 codec이 plan checksum을 재계산해 검증하는 8건 E2E: 발행된 run이 다음 시장 사건을 정본 주문으로, 완료된 receipt 재청구 없음, lease 만료 후 재전달이 새로 쓰지 않음, 처리된 sequence 이전 run 무시, stop이 평가 종료·정본 정산 후 시장 사건 무반응, stop보다 먼저 발행됐지만 나중에 도착한 run이 봇을 되살리지 않음, 두 번째 stop 1회만 정산, 다른 release를 지목한 명령 거부·재시도 보존. 미포함: 재등록이 시장 sequence 인식을 초기화하므로 시장 사건 자체의 중복 제거는 trading-engine #107
- [x] **B92 — 방 참여 봇 실제 연동** `통합`: E의 참가·평가 구간이 별개 봇 초기화, 실행, 종료 후 계속 운영 선택과 일치하는지 검증한다.

---

# C — 시장·평가

담당자: 박준유 (`pjy008008`)
주 저장소: `trading-engine`
실행 앱: `market-gateway`, `trading-worker`의 평가 조립부
기술·런타임: Java·Spring Boot
주요 스키마: `bot`의 평가·runtime state 테이블, 일부 `market_data` 읽기
완료 결과: 실시간 미국 시장 사건을 정규화하고 잠긴 Basic 전략을 봇별로 직렬 평가해 검증된 주문 후보 batch를 F에 전달한다.

## C0. 독립 시작 구간

- [x] **C01 — trading-engine 실행 골격**: Java·Spring `trading-worker`와 provider-neutral Java·Spring `market-gateway`, 공통 계약·runtime·persistence·messaging adapter를 각각 독립 기동한다.
- [x] **C02 — 시장 사건 계약과 fixture**: Alpaca SIP의 quote·trade·OHLCV-1m을 내부 quote/trade/bar/session 사건으로 정규화하고 provider·feed coverage와 계약 버전을 metadata로 보존한다.
- [x] **C03 — 봇 제어 명령과 trading 결과 계약**: 실행·중단·평가 구간 명령 및 판단·주문·체결·정산 사건 fixture를 정의한다.
- [x] **C04 — trading 정책 버전 fixture**: buying power buffer, 수수료 0.2%, 슬리피지 0.05%, short·borrow 정책 버전을 테스트에서 고정한다.

## C1. 실시간 시장 데이터

- [x] **C05 — Alpaca Algo Trader Plus 실시간 adapter와 권리 gate**: SIP WebSocket으로 지원 universe 약 550종목을 구독하고 인증·구독 승인·연결 상태·데이터 신선도, 재연결 backoff, 전체 재구독과 REST 누락 구간 복구를 검증한다. 운영 환경은 실제 서비스 사용 범위에 대한 권리 확인 상태가 없거나 만료되면 기동 또는 권리 대상 기능을 차단한다.
- [x] **C06 — 시세 정규화·중복·순서 검사**: 지원 종목만 내부 사건으로 변환하고 중복·역순·수정 사건을 안전하게 처리한다.
- [x] **C07 — Redis Streams 발행·최신값 cache**: 유실·중복을 고려한 stream과 종목별 최신 관측값을 갱신하고 소비 지연을 측정한다.
- [x] **C08 — 거래 세션·시장 상태**: 미국 동부 시각 정규장, 휴장·조기 종료와 거래 가능 상태를 공식 캘린더로 판정한다.
- [x] **C09 — 데이터 저하와 복구**: gap·지연·provider 장애 시 해당 평가·주문을 차단하고 data-degraded 및 복구 사건을 발행한다.

## C2. 전략 runtime과 평가

- [x] **C10 — 잠긴 실행 계획 loader**: 출시 snapshot, feature 요구사항과 runtime state를 읽고 변조·버전 불일치를 거절한다.
- [x] **C11 — 시작 전 warm-up**: D의 Manifest를 통해 필요한 과거 지표 데이터만 준비하고 부족하면 실행을 차단한다.
- [x] **C12 — trigger·feature 증분 계산**: 시장·타이머·주문·체결 trigger와 기술 지표를 이벤트 순서대로 증분 계산한다.
- [x] **C13 — 봇별 직렬 평가 queue**: 봇 하나는 한 번에 한 평가만 실행하고 새 시세 때문에 진행 중 계산을 계속 취소하지 않는다.
- [x] **C14 — Basic 실행기**: 종목별 독립 조건, 순차 매수·매도 흐름과 균등 후보 배분을 실행한다.
- [ ] **C15 — 보류(Pro): Pro 실행기**: 분기, 다중 입력, 목록 필터·정렬·상위 N·동적 Ratio·사용자 수식·명시적 상태를 실행한다.
- [x] **C16 — 후보 통합·중복·충돌 해결**: 모든 분기의 주문 후보를 단일 최종 처리기로 모으고 설정된 규칙 외 주문을 만들지 않는다.
- [x] **C17 — 주문 직전 유효성 재검사**: 평가 결과의 시세·포지션·예산·상태가 아직 유효한지 검사하고 무효할 때만 버리고 재평가한다.
- [x] **C18 — 판단 로그와 runtime state**: 조건 충족·최초 실패·예산 계산·후보·거절·축소·적용 규칙과 상태 변경을 순서 있게 기록한다.
- [x] **C19 — C 묶음 독립 E2E·재기동 복구**: 녹화된 시장 fixture로 연결·warm-up→지표 계산→Basic 평가→주문 후보 batch를 실행하고 process 재기동 후 같은 평가 결과를 보장한다.
- [x] **C20 — 실행 상태·판단 UI 연결**: 봇 실행 상태, 데이터 저하와 판단 로그 조회를 실제 API와 연결하되 실행 중 노드 애니메이션은 제공하지 않는다.

## C3. 통합 구간

- [x] **C90 — B 봇 제어 실제 연동** `통합`: B가 발행한 잠긴 봇 snapshot과 실행·중단 명령을 실제로 소비한다.
- [x] **C91 — D Manifest 실제 연동** `통합`: warm-up 입력과 feature를 실제 데이터 버전으로 고정한다.
- [x] **C92 — F 주문 후보 handoff 실제 연동** `통합`: 평가 결과와 주문 후보 batch가 중복·역순 전달되어도 F가 정확히 한 번 처리할 수 있게 한다. — 전송 실체 완성: trading-engine PR #123(`15630d4`, RT3 #107). gateway가 Redis Streams에 올린 정규화 사건을 consumer group으로 소비해 평가 루프에 투입한다(그룹명=소비자 신원이라 replica가 한 사건을 나눠 갖고, consumer명=replica 신원이라 죽은 replica가 미확인으로 남긴 사건을 되찾는다). 확인(ack)은 항상 투입 **후**이며, 재전달 안전성은 기대가 아니라 구조다 — batch id가 사건에서 파생되므로 claim ledger가 두 번째 시도를 인지한다. 복호화·평가 실패 항목은 의도적으로 pending 유지(실패를 ack하면 봉이 조용히 사라진다). 잔여: 봇 재기동 후 재전달된 시장 사건은 시장 sequence 인식이 초기화되어 다시 평가된다(사건 자체 신원 기반 중복 제거는 미해결)
- [x] **C93 — E 평가 구간 실제 연동** `통합`: 방 평가 시작·종료 경계를 따르고 종료 이후 평가가 방 성과 입력으로 이어지지 않게 한다. — backend PR #194(`d495d45`) + trading-engine PR #122(`f5cef35`). 이전에는 시작 경계만 지켜졌고 종료는 B가 stop을 제때 전달하는 동안에만 유지됐다. 그 틈에 내려진 판단은 방 성과가 읽는 공유 정본 원장에 방 소속 거래와 구분 없이 남는다. `competition.room_schedules.evaluation_ends_at`을 RUN 명령의 `executionEligibleUntil`로 실어 runtime이 경계에서 fail-closed로 멈추므로, stop이 늦으면 정산이 늦을 뿐 경계는 늦지 않는다. 종료 시점은 배타적(그 순간의 사건이 창 밖 첫 사건)이고, 일정이 없는 개인 봇은 종료를 싣지 않는다(부재는 소유자의 stop으로만 닫히는 열린 창이며 사고로 무제한이 된 것이 아니다). 종료가 operation key의 일부이므로 일정이 바뀐 방은 다른 명령이 되고, 방 종료 후의 개인 RUN은 방 명령에 수렴하지 않는다(수렴하면 소유자가 실행 중이라 믿는 봇이 방 종료 시점에 멈춘다). 실 PostgreSQL 검증: 종료 순간과 이후 사건이 intent·evaluation_run을 쓰지 않고, 한 봉 이른 같은 봇은 매수한다(경계임을 증명)

---

# D — 데이터·백테스트

담당자: 서동위 (`SeoDongWi`)
주 저장소: `data-pipeline`, `backtest-engine`, 루트 계약
실행 앱: `pipeline-worker`, 세 Lambda, `backtest-api`, `backtest-worker`
기술·런타임: Python·FastAPI·worker/Lambda
주요 스키마: `storage`, `market_data`, `backtest`
완료 결과: Alpaca 과거·증분 데이터를 검증된 Parquet·Manifest로 관리하고, 같은 Python 데이터 계약으로 출시된 Basic 전략의 공식 백테스트를 재현 가능하게 실행한다.

## D0. 독립 시작 구간

- [x] **D01 — Python 두 저장소 앱·패키지 골격**: data-pipeline worker·Lambda와 FastAPI·backtest worker의 package, lint/type/test와 독립 실행 구성을 완성한다.
- [x] **D02 — 객체 저장·Manifest 계약 fixture**: storage object, dataset object, Manifest, lineage, checksum과 publication 상태 예제를 고정한다.
- [x] **D03 — 로컬/S3 storage adapter**: 같은 object key·checksum·metadata 계약으로 로컬 파일과 S3를 교체할 수 있게 한다.

## D1. 시장 데이터 카탈로그와 적재

- [x] **D04 — 지원 종목·심볼·세션·provider·feed 카탈로그**: S&P 500과 승인 ETF 등 제공 종목, 심볼 이력, 미국 거래 세션과 데이터 출처를 버전 관리한다.
- [x] **D05 — Alpaca 10년 raw 수집**: rate limit·재시도·checkpoint·중단 재개와 checksum을 갖춘 종목·날짜 범위 수집을 구현한다.
- [x] **D06 — raw·adjusted 정규화**: 원본 보존, adjusted 값, corporate-action 근거와 schema validation을 분리한다.
- [x] **D07 — Parquet partition·파일 크기 정책**: 일별 유입을 작은 파일 폭증 없이 종목군·시간 범위로 partition하고 predicate pushdown이 가능한 schema를 적용한다.
- [x] **D08 — 주·월·연 compaction**: 새 객체를 먼저 생성·검증한 뒤 Manifest를 교체하고 기존 객체를 즉시 덮어쓰지 않는다.
- [x] **D09 — Manifest 발행·supersede·lineage**: 완전한 dataset snapshot, 포함 객체, 생성 근거와 이전 버전 관계를 원자적으로 발행한다.
- [x] **D10 — 데이터 품질 검사·incident**: 누락 bar, 중복, 역순, 비정상 가격·거래량, 세션 불일치와 checksum 실패를 영향 범위와 함께 기록한다.
- [x] **D11 — pipeline run·watermark·재처리**: feed별 수집 진도, 실패 재개, backfill과 동일 입력 멱등성을 관리한다.
- [x] **D12 — 실시간 데이터 일별 적재**: C 시장 사건을 buffer하여 검증된 일별 Parquet으로 만들고 이후 compaction 대상으로 발행한다.
- [x] **D13 — feature 정의·materialization**: 공식 지표 정의와 입력 Manifest를 고정하고 필요한 feature만 재현 가능하게 물질화한다.
- [x] **D14 — 기업행사 AI 조사 후보**: 하루 두 번 공개 근거를 조사해 종목·사건·예정일·근거를 후보로만 저장하고 자동 전략 판단에는 사용하지 않는다. — 실제 조사 어댑터가 병합됐다: `market_pipeline_lib/corporate_action_discovery.py`가 Alpaca `GET /v1/corporate-actions`를 source-partitioned discovery로 호출하고, `lambdas/corporate_action_research/handler.py`가 슬롯 하나를 실행한다. 대상은 `ticker_info/etf_universe.csv`의 27개 ETF, 후보 동일성은 content hash라 재실행이 중복 적재하지 않으며, 부분 실패는 실패한 티커를 지목하고 슬롯을 실패시킨다. **어댑터가 연결되지 않으면 즉시 실패한다** — "후보 0건"과 조용한 슬롯을 구분할 수 없기 때문이다. 증거 hash는 가져온 바이트에서 파생하므로 모델이 출처를 주장할 수는 있어도 `content_sha256`·`retrieved_at`을 단언할 수는 없다(루트 #205). 설계는 루트 #209, 데이터 소스·데이터 권리 결정은 루트 #143
- [x] **D15 — 기업행사 관리자 승인·반영**: A의 admin-mcp 승인 결과만 공식 corporate action과 adjusted dataset 재생성으로 반영한다. — A 측 경계가 실재한다: backend `apps/admin-mcp` `CorporateActionAdminMcpProvider`가 RBAC `permissionId`·`requestSchemaVersion`과 허용 입출력 필드로 승인 relay를 제공한다(이전에는 `origin/develop` 전체에 admin-mcp 참조 0건이었다). D 측은 `corporate_actions/consumer.py`의 `BackendRelayApprovalConsumer`가 relay payload를 `ApprovalResult`로 파싱해 `CorporateActionReviewService.apply_approval_result`로 적용하고 `regeneration.py`가 adjusted dataset을 재생성한다. 승인 상태는 정본 `market_data.corporate_actions.terms_document`의 append-only `review_history`에 남으므로 DDL 추가가 없다. data-pipeline #16 종료. 미승인·위조·중복·취소·superseded의 fail-closed 규칙은 정본 계약으로 고정됐다: `contracts/data/corporate-action-approval.v1.md`(`contract.operations.corporate-action-approval.v1`), 루트 PR #220으로 권한자 2인(pjy008008·Juwon-Na) 승인 후 병합, CI 검증기 `scripts/validate-corporate-action-approval-canonical.test.mjs`가 fingerprint와 fail-closed 의무를 고정한다
## D2. 공식 백테스트

- [x] **D16 — 백테스트 요청·결과 계약 fixture**: B가 발행할 요청과 D가 발행할 queued/running/complete/failed/unavailable 결과를 버전화한다.
- [x] **D17 — 고정 Parquet reader·실행 정책 fixture**: 소형 immutable Manifest와 Parquet, 분기별 기간, 수수료 0.2%, 슬리피지 0.05%, 시간·세션·정밀도와 모델 버전을 고정한다.
- [x] **D18 — backtest API·queue·상태 머신**: 출시 자동 작업 접수, 조회와 queued/running/complete/failed/unavailable 상태를 멱등적으로 관리한다.
- [x] **D19 — 분기별 공식 기간 선택**: 같은 분기에 생성된 출시본이 동일한 고정 백테스트 기간·정책 버전을 사용하게 한다.
- [x] **D20 — 입력 bundle 잠금**: 전략 snapshot, dataset Manifest, feature materialization, 수수료·슬리피지와 모델 버전을 실행 전에 고정한다.
- [x] **D21 — Basic runtime 호환 계층**: B의 Basic compiled plan을 C와 의미가 같은 trigger·순차 조건·균등 배분으로 실행한다.
- [x] **D22 — 시계·세션·사건 순서 시뮬레이터**: 미국 동부 시각 거래 세션과 데이터 사건을 look-ahead 없이 순서대로 공급한다.
- [x] **D23 — 백테스트 주문·체결·회계 모델**: 다음 유효 1분봉부터 주문 유형별 가격 조건을 평가하고 소수점·부분 체결, DAY/GTC/GTD, 수수료 0.2%, 슬리피지 0.05%, 예산·위험과 복식 원장을 재현한다.
- [x] **D24 — 데이터 부족·불가 판정**: 필요한 시간 해상도 구간만 체결 불가로 처리하고, 전략 전체 실행 가능성이 사라질 때만 unavailable로 종료하며 근사하지 않는다.
- [x] **D25 — 거래·성과 결과 저장**: 주문, 개별 체결, 취소, 거절, 비용, 실현손익, 거래 후 현금·포지션과 성과 summary를 실행 snapshot에 연결한다.
- [x] **D26 — 월별 판단 요약**: ET 월별로 거래 상세를 연결하고 비거래 평가는 저장하지 않으며 최초 실패 조건별 횟수만 집계한다.
- [x] **D27 — 상세 결과 object Manifest**: 대용량 거래·성과 series를 Parquet object로 저장하고 RDB detail manifest로 정확한 snapshot을 연결한다.
- [x] **D28 — 실패·재시도·취소·자원 제한**: run attempt, lease, timeout, 메모리·CPU 제한, 재시도와 중복 worker 실행을 안전하게 처리한다.
- [x] **D29 — 백테스트 결과 Query**: 목록, 개요, 성과, 월별 판단, 월별 거래 상세, 입력 데이터·모델과 unavailable 이유를 제공한다.
- [x] **D30 — D 묶음 독립 재현 E2E**: 고정 Alpaca 응답→Parquet→Manifest→공식 백테스트를 반복해 같은 입력과 결과를 보장하고 pipeline과 backtest의 Compute 자원 제한을 각각 검증한다.
- [x] **D31 — 백테스트 UI 연결**: 자동 실행 상태, 결과 개요, 성과, ET 월별 판단과 거래 상세 화면을 실제 API와 연결하고 unavailable·failed 상태를 검증한다.

## D3. 통합 구간

- [x] **D90 — C 실시간 적재·warm-up 실제 연동** `통합`: 정규화된 시장 사건을 일별 객체로 만들고 C가 정확한 Manifest·feature를 읽으며 누락 시 실행을 차단하는지 검증한다.
- [x] **D91 — B 출시 자동 요청 실제 연동** `통합`: 전략 출시마다 공식 실행이 정확히 한 번 생성되고 결과가 B 조회에 반영된다.
- [x] **D92 — C runtime 의미 동등성 검증** `통합`: 동일 Basic 전략·동일 사건 fixture에서 실시간 runtime과 백테스트 runtime의 판단이 일치한다.
- [x] **D93 — E 방 공식 성과와 결과 격리 검증** `통합`: 백테스트 결과가 E의 라이브 방 순위·우승·공식 성과에 입력되거나 합산되지 않는지 검증한다.

---

# E — 방·성과

담당자: 황영우 (`dertz569`)
주 저장소: `backend`, 루트 계약
실행 앱: `backend-api`, `backend-batch`, `backend-worker`
기술·런타임: Java·Spring Boot
주요 스키마: `competition`, `performance`, 일부 `bot` 조회
완료 결과: 공개·비밀 방의 모집부터 평가 종료까지 봇만 공정하게 비교하고, 방별 검증 점수 템플릿으로 결과를 확정한다.

## E0. 독립 시작 구간

- [x] **E01 — competition/performance 모듈 골격**: 두 도메인의 CQRS-lite 구조, fake bot/trading/backtest adapter와 DB 통합 테스트를 만든다.
- [x] **E02 — 현재 DBML 경쟁 스키마 정합성 PR**: 과거 삭제 결정과 충돌하는 `leaderboard_snapshots`·`leaderboard_entries` 등 현재 테이블을 확인하고 필요한 최소 구조만 canonical DBML PR로 정리한다.
- [x] **E03 — 방 일정·평가·성과 계약 fixture**: 모집→제출 시작→제출 마감→평가→종료, bot command와 performance 입력 계약을 버전화한다.
- [x] **E04 — 검증 점수 템플릿 카탈로그**: 단일형·복합형 공식 계산식, 방향, 허용 조정값과 버전을 제공하고 임의 수식·외부 데이터를 차단한다.

## E1. 방 생성·참여·일정

- [x] **E05 — 공개·비밀 방 생성**: 공개 여부, 정원, 일정, 초기자본, 최소 운영·체결 조건과 점수 템플릿을 검증해 생성한다.
- [x] **E06 — 공식 방 생성**: 플랫폼 운영자만 공식 방을 만들고 공식 기준·규칙·템플릿 버전을 잠근다.
- [x] **E07 — 공개방 탐색·비밀방 초대**: 공개방 검색과 비밀방 코드·초대 발급, 만료·회수·재사용 방지를 구현한다.
- [x] **E08 — 참여 자격·정원·10개 상한**: 참여 시점에 정원과 사용자의 실행 봇 10개 상한을 원자적으로 검사한다.
- [x] **E09 — 방 참여용 별개 봇 생성**: 기존 개인 봇 상태를 이어받지 않고 전략·설정만 복사한 별개 객체를 초기 상태로 만든다.
- [x] **E10 — 모집·제출·평가 일정 전환**: 서버 시각과 잠긴 일정으로 각 단계를 멱등 전환하고 제출 시점별 즉시 시작·대기 규칙을 적용한다.
- [x] **E11 — 평가 시작 초기화**: 평가 시작에 방 초기자본, 빈 포지션·주문·원장·전략 상태로 완전히 초기화해 시작 명령을 발행한다.
- [x] **E12 — 참여 철회·방 취소·무효화**: 단계별 허용 범위, 환원 상태, 봇 무소속 전환 또는 중단과 감사 근거를 처리한다.
- [x] **E13 — 공개·비밀방 추방 규칙**: 공개방 생성자는 추방할 수 없고 비밀방 생성자는 허용 범위에서 추방하며 봇은 삭제 없이 무소속이 된다.
- [x] **E14 — 규칙·일정 잠금**: 모집 이후 평가 의미에 영향을 주는 변경을 차단하고 새 방 생성만 허용한다.

## E2. 평가·성과·비교

- [x] **E15 — 평가 구간 segment 관리**: 시작·종료 경계를 고정하고 구간 밖 주문·체결·성과가 방 결과에 포함되지 않게 한다.
- [x] **E16 — live 성과 projection**: F의 원장·포지션·성과 사건으로 봇별 현재 성과를 재구축 가능하게 계산한다.
- [x] **E17 — 라이브 평가 입력 잠금**: 방의 평가 시작·종료, 초기자본, 비용·위험·점수 템플릿 버전을 참가 봇 전체에 동일하게 고정하고 백테스트 결과를 공식 방 점수에 사용하지 않는다.
- [x] **E18 — 단일형 점수 계산**: 수익률, 최대낙폭 등 선택된 하나의 공식 지표와 정렬 방향으로 점수를 계산한다.
- [x] **E19 — 복합형 점수 계산**: 수익률·샤프지수·최대낙폭 등 공식 템플릿과 허용 수치 조정만으로 점수를 계산한다.
- [x] **E20 — 최소 운영·체결 조건**: 방별 설정값과 개별 부분 체결 횟수 기준으로 평가 유효성을 판정한다.
- [x] **E21 — 봇 전용 익명 리더보드 Query**: 사용자 간 비교를 금지하고 익명 봇 순위·공개 허용 성과만 제공하며 자신의 봇은 추가 정보를 조회할 수 있게 한다.
- [x] **E22 — 내 봇 교차 비교**: 특정 방 리더보드에서 종목 일치 여부와 관계없이 사용자가 자신의 봇들을 비교할 수 있게 한다.
- [x] **E23 — 점수 재계산 가능성**: 원본 원장·성과 근거와 템플릿 버전을 보존해 향후 점수 체계 변경 시 별도 계산 결과를 만들 수 있게 한다.
- [x] **E24 — 평가 종료 성과용 가상 청산**: 실제 주문·현금·포지션·원장을 바꾸지 않고 종료 시점 가상 청산 성과를 계산한다.

## E3. 평가 종료와 후속 운영

- [x] **E25 — 종료 후 계속 운영 선택 저장**: 평가 기간 중 `계속 실행` 또는 `종료 시 중단` 선택을 저장·조회하고 미결정 기본값은 만들지 않는다.
- [x] **E26 — 계속 실행 전환**: 종료된 방 성과는 고정하고 동일 봇의 실제 현금·포지션·주문·상태·원장을 무소속 비공개 봇으로 이어간다.
- [x] **E27 — 종료 시 중단**: 성과용 가상 청산과 별도로 B/F의 실제 중단·정산 절차를 호출한다.
- [x] **E28 — 방 종료 결과 확정**: 유효성, 동점, 공식 점수와 최종 상태를 잠그고 이후 개인 운영 사건이 결과를 바꾸지 않게 한다.
- [x] **E29 — 방·리더보드·내 봇 Query**: 공개 가능한 방 정보, 단계, 참가 상태, 익명 순위, 내 봇 세부 결과를 jOOQ로 조회한다.
- [x] **E30 — 운영자 방 관리**: 권한 있는 운영자가 공식 방, 취소·무효화, 참가 사건과 계산 근거를 조회·처리한다.
- [x] **E31 — 참여 부족 자동 종료**: 유효 제출 봇이 2개 미만이면 순위 없이 방을 종료하고 참여 봇을 중단하지 않은 채 무소속 비공개 상태와 30일 기한으로 전환한다.
- [x] **E32 — 최종 리더보드 접근·보존**: 공개방은 전체 공개, 비밀방은 종료 직전 자격 보유자만 조회하게 하고 종료 후 1년이 지나면 방 단위 조회를 종료한다.
- [x] **E33 — 제재·철회·무효화 공개 제거**: 대상 봇을 다른 사용자의 순위·비교에서 즉시 제거하되 소유자의 원장·판단·성과 원본과 감사 근거는 보존한다.
- [x] **E34 — E 묶음 독립 E2E**: fake bot·trading 사건으로 생성→모집→제출→라이브 평가→순위→계속 운영/중단을 모두 검증한다.
- [x] **E35 — 방·성과 UI 연결**: 방 생성·탐색·참여·일정·익명 봇 리더보드·내 봇 비교와 종료 후 선택 화면을 실제 API와 연결한다. — ui `App.tsx`가 `/competition`에 `RoomsView`를 `competitionRoomsClient`로 배선했고, `src/api/competitionRooms.ts`가 요구된 여섯 표면을 전부 실제 엔드포인트에 건다: `createRoom`(POST `/api/v1/competition/rooms`), `searchRooms`(`/rooms/public`), `joinRoom`(`/rooms/{id}/participations`), `leaderboard`(익명 별칭), `myBots`(`/leaderboard/my-bots`), `get`·`setPostEvaluationChoice`(`/participations/{id}/post-evaluation-choice`, `CONTINUE_PRIVATE`/`STOP_AFTER_EVALUATION`). 일정은 `recruitmentOpensAt`·`participationClosesAt`으로 방 조회에 실린다. 401·403·409를 구분하는 `CompetitionApiError`로 오류 상태를 처리하고, 전략 구조·종목·포지션은 표시하지 않는다(ui `docs/PHASE5_COMPETITION_ROOMS.md` 4절)

## E4. 통합 구간

- [x] **E90 — B 방 참여 봇 실제 연동** `통합`: 별개 봇 생성, 초기화, 대기, 계속 운영과 30일 확인 정책을 실제로 연결한다.
- [x] **E91 — F live 성과 실제 연동** `통합`: 실시간 원장·성과와 평가 구간 경계가 리더보드 결과에 정확히 반영되는지 검증한다.
- [x] **E92 — D 백테스트 결과 격리 연동** `통합`: D 결과는 전략 소유자의 백테스트 조회에만 남고 방 공식 성과·순위 계산 입력에서 배제되는지 검증한다.

---

# F — 거래·원장

담당자: 민경철 (`kcrmin`)
주 저장소: `trading-engine`, 루트 계약
실행 앱: `trading-worker`
기술·런타임: Java·Spring Boot
주요 스키마: `trading`, `bot`의 주문·정산 상태
완료 결과: C가 만든 검증된 주문 후보 batch를 실제 가용자금·위험 경계로 제한하고 현실적인 가상 주문·부분 체결·포지션·공식 복식 원장을 유지한다.

## F0. 독립 시작 구간

- [x] **F01 — execution module·계약 fixture**: C 구현 없이도 주문 후보 batch를 소비할 수 있는 order·execution·settlement·persistence 모듈, fake candidate source와 독립 기동 테스트를 만든다.
- [x] **F02 — Basic 전략·공통 자금 예산 계산**: 기존 포지션, 미체결 예약과 예상 비용을 반영하고 비율 상한, 균등 배분과 예외적 비례 축소를 실행한다.
- [x] **F03 — 포트폴리오 위험·주문 유효성**: 실제 가용자금, 전체 위험 한도, 최소 금액·수량과 소수점 정밀도를 강제한다.

## F1. 주문·체결·회계

- [x] **F04 — 주문 Intent batch와 멱등성**: 평가 한 번의 후보·Intent를 원자적으로 묶고 재시도에도 중복 주문을 만들지 않는다.
- [x] **F05 — 주문 유형·유효기간·상태 머신**: 시장가·지정가·스탑·스탑리밋·트레일링 스탑, DAY/GTC/GTD의 허용 조합과 승인·부분 체결·체결·만료·취소·거절 순서를 구현한다.
- [ ] **F06 — 보류(Pro): 주문 그룹과 연계 주문**: OCO·브래킷·다중 leg, 분기 결과와 명시적 사용자 정책에 따른 그룹·구성 요소·충돌 처리를 구현한다.
- [x] **F07 — 자금·lot 예약**: 미체결 주문의 현금·buying power·보유 lot을 예약하고 변경·취소·체결 시 정확히 해제·이전한다.
- [x] **F08 — 현실적 가상 체결 모델**: 실시간 유효 호가·거래량과 주문 가격 제한으로 부분 체결하며 고정 슬리피지 0.05%와 수수료 0.2%를 적용하고 유리한 가격을 임의 생성하지 않는다.
- [x] **F08A — 소수점·정수 주문 규칙**: 소수점 거래 가능 롱 종목의 시장가 DAY만 금액·소수점 주문을 허용하고 지정가·스탑·스탑리밋·트레일링 및 신규 숏은 정수 수량만 허용한다.
- [x] **F09 — 개별 체결 거래 횟수**: 부분 체결 각각을 거래 횟수로 집계하고 fill adjustment·정정과 원본 사건을 보존한다.
- [x] **F10 — 복식 원장**: 현금·증권·수수료·손익 계정의 transaction/entry 균형을 강제하고 공식 원장을 재구축할 수 있게 한다.
- [x] **F11 — lot·포지션·실현손익**: 소수점 lot, movement, 포지션 projection, 매도 원가와 실현손익을 일관되게 계산한다.
- [x] **F12 — short·증거금·borrow fee**: 허용 범위의 short 검사, lot, 증거금·위험 제한과 borrow fee 발생을 정책 버전으로 처리한다.
- [x] **F13 — 기업행사 적용**: D에서 승인·확정된 split 등 기업행사를 포지션·lot·원장에 재현 가능하게 적용하고 임의 AI 결과는 사용하지 않는다.
- [x] **F14 — 봇 중단·강제 정산**: 평가 중지, 미체결 취소, 현실적인 정산 주문, 실패 재시도와 settlement-failed 상태를 구현한다.
- [x] **F15 — 예산·포지션·주문 Query projection**: 봇·파티션·흐름별 예산, 포지션, 주문, 체결과 공식 원장을 jOOQ 조회용 projection으로 제공한다.
- [x] **F16 — F 묶음 독립 E2E·재기동 복구**: fake 주문 후보와 녹화 호가로 예산→부분 체결→원장→중단을 실행하고 process 재기동 후 같은 공식 상태를 보장한다.
- [x] **F17 — 거래·원장 UI 연결**: 주문·개별 체결·포지션·전략 예산·거절/축소 이유·중단 정산 결과를 실제 API와 연결하고 사용자 직접 주문 입력은 제공하지 않는다.

## F2. 통합 구간

- [x] **F90 — C 주문 후보 실제 연동** `통합`: C의 평가 결과·후보 batch를 중복·역순 전달에서도 정확히 한 번 처리한다.
- [x] **F91 — B 봇 제어 실제 연동** `통합`: B의 실행·중단 명령과 잠긴 봇 정책을 실제 주문·정산 상태로 연결한다.
- [x] **F92 — D 기업행사 실제 연동** `통합`: 승인된 기업행사 버전을 포지션·lot·원장에 정확히 반영한다. — **완료 (2026-08-05, trading #135).** 개시 경로 `ApprovedCorporateActionPoller`가 정본 `market_data.corporate_actions.terms_document.review`(계약 `contract.operations.corporate-action-approval.v1`이 고정한 위치)에서 APPROVED·effective 도래·미supersede·AVAILABLE-manifest 행위를 읽어, 종목을 보유한 모든 봇에 F13 적용 경로(`CorporateActionApplication`·`SplitAdjustment`·`PostgresCorporateActionStore.apply`)로 반영한다 — 봇마다 공식 bot_event 하나(`CORPORATE_ACTION_APPLIED`), 한 행위는 전 봇 + 완료 fact가 한 트랜잭션에 커밋. 재전달은 movement id 파생 `(actionId, positionLotId, botEventId)`과 `on conflict do nothing` 완료 fact로 수렴한다. fail-closed: stale content hash·미지원 action type·도메인 거부는 거절 fact + audit event로 남아 조용한 스킵이 없고, **이미 lot을 움직인 행위를 supersede하는 승인은 `SUPERSEDE_AFTER_APPLICATION`으로 거절한다**(정본에 보상 movement가 없어 운영자 결정 사안). E2E가 실제 canonical 스키마에서 봇 2·lot 3 적용, 수량 2배·cost basis 보존, pending/future 불변, 영수증 유실 재전달 수렴, 거절 사유 코드와 audit 증적을 증명. 활성화는 `trading.corporate-action-apply.enabled` property 게이트(기본 PT30S poll)
- [x] **F93 — E live 성과 실제 연동** `통합`: 원장·포지션·체결 사건이 평가 구간 경계에 맞게 E의 성과 projection으로 전달되는지 검증한다.

---

# 6. 전체 서비스 통합·출시 체크

아래 항목은 A~F 일반 카드가 모두 완료된 뒤 진행한다. 특정 한 사람의 기능 묶음 완료를 막지는 않는다.

- [ ] **INT01 — 계약 호환성 전체 검증**: 모든 provider·consumer 계약 버전과 fixture를 실제 서비스 조합으로 검증한다.
- [ ] **INT02 — 최초 DB 구축·migration rehearsal**: 빈 PostgreSQL과 직전 release snapshot 모두에서 migration, 권한과 rollback 절차를 검증한다.
- [ ] **INT03 — 전체 사용자 E2E**: 가입→Basic 전략→검증→출시→자동 백테스트→개인 봇 실행→주문·체결→중단을 검증한다.
- [ ] **INT04 — 전체 방 E2E**: 방 생성→참여→평가 초기화→실시간 평가→익명 순위→계속 운영/중단을 검증하고 백테스트 결과가 방 점수에 섞이지 않는지 확인한다.
- [ ] **INT05 — 운영자 E2E**: RBAC 위임→기업행사 승인→데이터 incident→계정 제재→봇 중단→감사 조회를 검증한다.
- [ ] **INT06 — 장애·재기동·중복 전달 시험**: API, worker, Redis, queue, RDS, S3 장애와 복구에서 주문·원장·백테스트가 중복·유실되지 않는지 검증한다.
- [ ] **INT07 — 성능·용량 시험**: 정규장 실시간 부하, 동시 봇, 백테스트·pipeline 자원 격리와 목표 지연을 측정한다.
- [ ] **INT08 — 보안·개인정보·법적 표현 검토**: 권한 우회, 비공개 전략 노출, 직접 주문, 투자 추천·위험 등급 표현과 데이터 권리를 검토한다. — 1차 검토 기록: `docs/reviews/int08-security-privacy-legal-review-2026-08-05.md` (2026-08-05, 고정 gitlink 기준). 다섯 축 모두 표본 수준 위반 없음: 직접 주문 엔드포인트 부재, 전략 읽기 소유자 스코프 + 타인 백테스트 404 fail-closed, 제재 fail-closed·운영자 MFA/RBAC, '위험 등급' 표현 0건 + 성과 고지 실재, 데이터 권리 3종 허용(루트 #143). **미결 4건이 기록돼 카드는 열어 둔다**: Alpaca 사용 범위 서면 확인(높음, 외부·법적 — INT12 전 필수), 인증 전수 검증(A90 귀속), 성과 카피 전수 확인(INT10 귀속), admin-mcp read 도구 전수 확인(A90 귀속)
- [ ] **INT09 — 백업·복구·원장 대사**: RDS/S3 백업 복구, projection 재생성, 원장 균형과 객체 checksum을 검증한다.
- [ ] **INT10 — UI 계약 연결**: UI가 backend-api와 허용된 관리자 진입점만 사용하고 모든 필수 상태·오류를 처리하는지 검증한다.
- [ ] **INT11 — 정확한 release candidate 검증**: 루트와 모든 서브모듈의 정확한 commit, DB migration, UI baseline, 테스트 증거를 하나의 후보로 고정한다.
- [ ] **INT12 — v1.0 릴리스**: 검증된 release branch만 main에 병합하고 배포·모니터링·rollback 준비 상태를 확인한다.

## 7. 완료의 의미

다음 조건을 모두 만족할 때 “백엔드 구현 완료”로 본다.

- COM01~COM12, A07~A23, `보류(Pro)`를 제외한 B01~B28·B18A~B18B, C01~C20, D01~D31, E01~E35와 F01~F17·F08A가 모두 완료됐다.
- A90~A91, B90~B92, C90~C93, D90~D93, E90~E92, F90~F93과 INT01~INT12가 실제 서비스 조합에서 통과했다.
- 현재 출시 범위로 기록한 Basic 전략, CLI, 실시간 모의투자, 자동 백테스트, 방 비교, 운영자 기능에 비어 있는 성공 응답이나 수동 DB 조작 의존이 없다.
- DBML, Flyway, 실행 코드, 계약, 테스트와 UI가 같은 서비스 의미를 사용한다.
- 법적 검토가 필요한 표현과 데이터 권리가 확인되지 않은 기능은 공개하지 않는다.
- 정확한 release candidate가 develop의 검증된 결과로 고정되고 v1.0부터 main에 반영된다.
