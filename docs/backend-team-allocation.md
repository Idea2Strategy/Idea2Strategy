# Idea2Strategy 개발 배정 및 병렬 진행 방식

> 상태: **2026-08-09 2인으로 재배정.** 정본은 `docs/launch-readiness-tasks.json` 의 `owners` 블록이다. 아래 §0은 그 요약이고, §1의 A~F 표는 영역 정의로만 유지한다.
> 범위: Basic 전략, 외부 AI 연동 CLI, 실시간 가상 거래, 자동 백테스트, 방과 성과 기능
> 원칙: 공통 선행 Issue와 사용자 흐름별 상위·하위 Issue를 확정하기 전에는 작업 브랜치를 생성하지 않는다.

이 문서는 세부 구현 체크리스트가 아니다. 담당자와 진행 방식을 공유하고, 실제 구현 항목은 `backend-implementation-master-checklist.md`에서 GitHub Issue 단위로 옮길 때 사용한다. **현재 진행 중인 작업의 정본은 `launch-readiness-plan.md`다.**

## 0. 현재 배정 (2026-08-09, 2인)

3인 배정은 모든 서브모듈 포인터가 한 사람을 거치게 해 왕복 대기를 만들었다. 2인으로 재편하면서
**각 소유자가 자기 서브모듈의 루트 gitlink 를 직접 올린다.** 번들에 포함된 gitlink 를 옮기면 같은
커밋에서 `scripts/refresh-flyway-ci-bundle.ps1` 을 돌린다 — 추적된 훅이 강제하므로 잊을 수 없다.
자기 `docs/evidence/**` 도 직접 쓴다.

| 담당 | 수정 가능한 리포지터리 | 소유 영역 |
|---|---|---|
| 민경철 (`kcrmin`) | root 슈퍼프로젝트(`compose*.yml`, `infra/`, `scripts/`, `db/`) + `backend` + `trading-engine` + `data-pipeline` | 플랫폼: infra·릴리스·정본 DB·권한·운영자·방·원장·시장 데이터 (A·B·C·E·F, D 의 수집) |
| 손현준 (`hjcud`) | `backtest-engine`, `ui` | 사용자 여정: 백테스트 실행과 전 화면 (D 의 백테스트, 전 영역 UI) |

여전히 한 사람만 수정하는 경로: `db/schema.dbml`, `compose.back.yml`, `compose.front.yml` (`kcrmin`).
실제로 충돌했던 지점이 이 셋이다.

**직렬 자원 — 건너뛰지 않는 대기.** Development 릴리스 워크플로, BASIC 큐와 단일 backtest worker,
운영자 계정, DB 부트스트랩은 환경에 하나뿐이다. 쓰기 전에 루트 이슈 #451 에 선점 한 줄을 남기고
끝나면 종료를 남긴다.

비활동: 박준유 (`pjy008008`, 2026-08-09 부터 — 카드는 `kcrmin` 으로, `INT07` 만 `INT03` 의존을 따라
`hjcud` 로), 나주원 (`Juwon-Na`), 서동위 (`SeoDongWi`), 황영우 (`dertz569`). 이들에게 작업을 배정하지
않는다.

**v1.0 범위 제외 (2026-08-08 결정):** Pro 모드 — B09, B10, B13, C15, F06. 시작하지 않는다. UI의 `ProEditorUnavailableView`가 이미 진입을 막고 있다.

## 1. 영역 정의 (문자 라벨의 의미 — 배정표는 §0)

| 영역 | 담당자 | 담당 범위 | 주 저장소 | 서버 기술·런타임 | 함께 연결할 UI |
|---|---|---|---|---|---|
| A — 계정·운영 | 나주원 (`Juwon-Na`) | 가입, 로그인, 세션, 권한, 제재, 알림, 운영자 기능, Admin MCP | `backend` | Java·Spring Boot | 로그인, 계정 설정, 알림, 운영자 화면 |
| B — 전략·봇 | 손현준 (`hjcud`) | Basic 전략 저장·검증·출시, 봇 생성·실행·중단, 외부 AI용 CLI | `backend` | Java·Spring Boot | 전략 편집기, 출시, 봇 생성·제어 화면 |
| C — 시장·평가 | 박준유 (`pjy008008`) | Alpaca 실시간 시세, 지표 계산, Basic 전략 평가, 주문 후보 생성 | `trading-engine` | Java·Spring Boot | 실행 상태, 데이터 상태, 판단 로그 화면 |
| D — 데이터·백테스트 | 서동위 (`SeoDongWi`) | 과거 데이터, Parquet·Manifest, 기업행사, 백테스트 실행·결과 | `data-pipeline`, `backtest-engine` | Python·FastAPI·worker/Lambda | 백테스트 상태, 결과, 월별 거래 상세 화면 |
| E — 방·성과 | 황영우 (`dertz569`) | 방 생성·참여·일정, 평가, 점수 템플릿, 리더보드 | `backend` | Java·Spring Boot | 방 생성·참여·관리, 평가·리더보드 화면 |
| F — 거래·원장 | 민경철 (`kcrmin`) | 예산·위험 검사, 주문, 가상 체결, 포지션, 원장, 정산 | `trading-engine` | Java·Spring Boot | 주문·체결, 포지션·예산, 원장 화면 |

각 영역은 서버만 담당하지 않는다. 사용자가 이용하는 기능은 해당 서버 처리와 `ui` 연결을 같은 작업 범위로 본다.

`ui` 하위 Issue는 모든 영역에서 TypeScript·React·Vite를 사용한다. 루트 저장소의 문서·DBML·계약·submodule pointer 작업은 별도 애플리케이션 런타임이 없는 통합 작업으로 표시한다.

## 2. 여섯 명이 먼저 같이 끝낼 공통 작업

### 확정된 공통 기준

- Runtime: Java 21 LTS, Spring Boot 4.1.0, Gradle 8.14.3, Python 3.12.13, FastAPI 0.139.2, Uvicorn 0.52.0, Node.js 24 LTS, pnpm 11
- Data·migration: PostgreSQL 16, Redis 7.4, Flyway 11, Docker Compose v2
- Durable Queue: 운영 AWS SQS, 로컬 LocalStack SQS. Standard가 기본이며 실제 순서 보장 계약이 있는 경로만 FIFO를 사용한다.
- Redis 책임: 실시간 시장 사건 전달과 최신 상태 저장. 봇 명령·백테스트·배치 같은 durable 작업 전달에는 사용하지 않는다.
- Migration 책임: 각 도메인 소유자가 자신의 migration을 작성하고 나주원(`Juwon-Na`)이 중앙 Flyway 모듈에서 순서·충돌·DBML 일치를 통합 검토한다.
- 외부 공개 포트: `ui:15173`, `backend-api:18080`, `backtest-api:18082`
- 내부·관리 포트: `admin-mcp:18083`, PostgreSQL `15432`, Redis `16379`, MinIO `19000/19001`
- Worker 경계: `backend-batch`, `backend-worker`, `market-gateway`, `trading-worker`, `backtest-worker`, `pipeline-worker`는 호스트 포트를 열지 않고 Docker 내부 네트워크로 통신한다.

아래 항목만 모두 함께 끝낸 뒤 A~F 작업을 시작한다.

- [ ] 루트와 모든 서브모듈의 기준 브랜치를 `develop`으로 맞추고 기준 commit을 확인한다.
- [ ] 위에서 확정한 Runtime·Data 버전을 각 저장소의 build·lock 파일과 로컬 실행 환경에 적용한다.
- [ ] `backend`, `trading-engine`, `ui`, 두 Python 저장소가 빈 상태에서도 빌드·테스트·실행되게 한다.
- [ ] DB 스키마와 테이블별 변경 담당자를 확정하고 중앙 Flyway 모듈의 migration 작성·통합 규칙을 적용한다.
- [ ] API 오류 형식, 시간 저장 방식, pagination, 인증 주체, correlation ID와 idempotency 규칙을 정한다.
- [ ] 영역 사이에서 주고받을 메시지·파일 형식과 예제 fixture를 만든다.
- [ ] 외부 서비스가 없어도 개발 가능한 fake auth, fake clock, fake queue, 시장 데이터, Parquet와 S3 대역을 준비한다.
- [ ] 각 저장소의 build, test, migration, contract test와 smoke test를 CI에서 확인한다.
- [ ] `ui`의 router, API client, 인증 상태, loading·empty·error·permission 공통 처리를 준비한다.
- [ ] 공통 작업을 각 저장소의 `develop`에 먼저 병합하고 여섯 명이 최신 상태를 다시 받는다.

공통 작업은 한 브랜치에서 여섯 명이 동시에 수정하지 않는다. 항목마다 한 명이 변경하고 필요한 사람이 검토한 뒤 바로 `develop`에 병합한다.

## 3. 공통 작업 후 병렬 개발하는 방법

각 담당자는 다른 영역의 실제 구현을 기다리지 않고 다음 순서로 진행한다.

1. 자신이 소비할 API·이벤트·Parquet 형식의 예제 fixture를 먼저 받는다.
2. 실제 상대 서비스 대신 fixture와 fake adapter로 서버와 UI를 함께 개발한다.
3. 자신의 저장소와 DB 소유 범위만 수정한다.
4. 상대 영역이 실제 구현을 끝내면 fixture와 동일한 계약인지 contract test로 확인한다.
5. 실제 서비스 간 연결은 각자의 독립 기능이 끝난 뒤 별도 통합 작업으로 처리한다.

주요 연결 경계는 다음과 같다.

```text
A 인증·권한 ───────────────→ B, C, D, E, F
B 잠긴 Basic 전략 ─────────→ C 평가, D 백테스트
C 주문 후보 ───────────────→ F 주문·체결
D Dataset Manifest ────────→ C 준비 데이터, D 백테스트
F 주문·체결·원장 사건 ─────→ B 봇 조회, E 성과, A 알림
E 방 평가 일정·참가 상태 ──→ B, C, F
```

이 경계의 형식이 먼저 정해져 있으면 구현 순서가 달라도 병렬 작업할 수 있다.

## 4. 각 담당자가 처음 시작할 작업

| 영역 | 첫 번째 확인 가능한 결과 |
|---|---|
| A | 가입·로그인 후 인증된 사용자 정보가 UI에 표시되고 권한 없는 요청이 거절된다. |
| B | Basic 전략 문서를 저장하고 다시 열었을 때 블록과 입력값이 그대로 복원된다. |
| C | 녹화된 Alpaca 시세가 내부 시장 이벤트로 변환되고 실행 상태가 UI에 표시된다. |
| D | Alpaca 예제 응답이 Parquet와 Manifest로 저장되고 동일한 입력을 백테스트가 읽는다. |
| E | 공개·비밀방을 생성하고 참여 상태를 저장하며 UI에서 확인한다. |
| F | 주문 후보가 예산·위험 검사를 거쳐 주문 의도로 변환되고 결과가 UI에 표시된다. |

첫 결과가 끝나면 같은 브랜치를 계속 사용하지 않는다. 다음 작업은 최신 `develop`에서 새 브랜치를 만든다.

## 5. GitHub Issue 계층

확정된 담당자를 기준으로 마스터 체크리스트를 다음 2단계 Issue로 옮긴다. 실제 Issue는 상위·하위 분해와 선행 관계를 최종 확인한 뒤 생성한다.

### 5.1 루트 저장소: 사용자 흐름 카드

루트 저장소에는 사용자가 처음부터 끝까지 경험하는 큰 기능 흐름마다 상위 Issue를 하나 만든다.

예: `[FLOW-B01] Basic 전략 작성·검증·출시`

상위 Issue에는 다음을 기록한다.

- 흐름 담당자
- 사용자에게 제공될 최종 결과
- 시작 전에 반드시 끝나야 하는 공통 선행 Issue
- 영향을 받는 서브모듈과 하위 Issue
- 통합 순서와 전체 E2E 완료 조건
- 최종적으로 갱신할 루트 submodule pointer

상위 Issue 자체에서 여러 저장소의 코드를 함께 구현하지 않는다. GitHub의 sub-issue 관계를 사용하거나, 사용할 수 없는 경우 본문의 체크리스트로 각 저장소 하위 Issue를 연결한다.

| 하위 Issue | 저장소 | 기술·런타임 | 담당자 | 선행 Issue | 단독 소유 범위 | 산출물 |
|---|---|---|---|---|---|---|
| `backend#…` | `backend` | Java·Spring Boot | 손현준 (`hjcud`) | 공통 계약 Issue | API·Command·Query·DB 변경 | backend PR |
| `ui#…` | `ui` | TypeScript·React | 손현준 (`hjcud`) | API 계약 fixture | 해당 기능 화면 경로 | UI PR |
| `backtest-engine#…` | `backtest-engine` | Python·FastAPI/worker | 서동위 (`SeoDongWi`) | compiled plan fixture | 백테스트 소비 경로 | engine PR |
| `root#…` 통합 | 루트 | 문서·계약·E2E | 흐름 담당자 | 위 하위 Issue 전체 | E2E·pointer만 | 루트 PR |

### 5.2 각 서브모듈: 실제 구현 Issue

상위 흐름에 참여하는 저장소마다 별도의 하위 Issue를 만든다. 하위 Issue 하나는 한 저장소와 한 담당자의 변경만 소유한다.

각 하위 Issue에는 반드시 다음을 적는다.

- 연결된 루트 상위 Issue
- 저장소와 기술·런타임
- 담당자 1명과 검토자
- `Blocked by` 선행 Issue
- 수정할 경로·DB 스키마/테이블·migration·계약의 단독 소유 범위
- 다른 하위 Issue에 제공할 fixture 또는 계약
- 테스트, PR 대상 브랜치와 완료 조건

`해줘`라고 요청할 때 실행하는 단위도 이 하위 Issue 하나다. 상위 Issue 전체를 한 번에 한 브랜치나 한 PR로 처리하지 않는다.

### 5.3 선행 관계

선행 관계는 다음처럼 구분한다.

- **Hard prerequisite**: DB baseline, 공통 골격처럼 끝나기 전에는 작업을 시작할 수 없다.
- **Contract prerequisite**: producer의 실제 구현을 기다리지 않고 승인된 계약·fixture로 병렬 개발할 수 있다.
- **Integration prerequisite**: 개별 구현은 끝낼 수 있지만 관련 PR이 모두 병합되기 전에는 상위 흐름을 완료할 수 없다.

코드를 아직 push하지 않았더라도 GitHub에서 진행 상태를 확인한다.

```text
상위: Todo → Ready → In Progress → Integration → Done
하위: Todo → Ready → In Progress → Review → Done
```

담당자와 모든 Hard prerequisite가 확정된 하위 Issue만 `Ready`가 된다. 담당자가 작업 시작을 표시하면 `In Progress`, PR이 열리면 `Review`로 바꾼다. 상위 Issue는 모든 하위 Issue, 실제 연동 E2E와 루트 pointer PR이 끝난 뒤에만 `Done`으로 닫는다.

## 6. 브랜치와 develop 병합 규칙

구현 작업 하나당 Issue 하나, 저장소별 브랜치 하나를 사용한다.

```text
최신 develop 받기
→ feature/{issue-number}-{short-name} 생성
→ 구현·테스트
→ 해당 저장소 develop 대상 PR
→ 리뷰·검증
→ develop 병합
→ 다음 Issue를 최신 develop에서 새 브랜치로 시작
```

서버와 UI가 함께 바뀌어도 저장소마다 별도의 하위 Issue와 브랜치를 만든다. Issue 번호는 저장소별 번호이므로 같을 필요가 없으며, 두 Issue를 같은 루트 상위 Issue에 연결한다.

```text
backend:  feature/341-strategy-release-api
ui:      feature/87-strategy-release-ui
```

완료 순서는 다음과 같다.

1. 공통 Hard prerequisite Issue와 PR을 먼저 완료한다.
2. `Ready`인 각 서브모듈 하위 Issue를 병렬로 진행한다.
3. 각 PR을 해당 저장소의 `develop`에 병합한다.
4. 실제 서비스 조합으로 계약 테스트와 E2E를 확인한다.
5. 루트 통합 Issue에서 검증된 submodule commit을 가리키는 pointer PR을 `develop`에 병합한다.
6. 하위 Issue를 모두 닫고 마지막으로 루트 상위 Issue를 `Done`으로 닫는다.

`main`에는 개발 중 변경을 병합하지 않는다. 완성된 정식 릴리스만 `main`으로 보낸다.

## 7. 충돌을 줄이는 소유 경계

| 저장소 | 우선 소유 영역 |
|---|---|
| `backend` | A: identity·operations / B: strategy·bot-control / E: competition·performance |
| `trading-engine` | C: market·evaluation / F: order·execution·settlement |
| `data-pipeline`, `backtest-engine` | D |
| `ui` | 각 담당자의 기능 경로, 공통 shell은 공통 작업 담당자 |

하나의 경로, DB 테이블, migration 또는 계약에는 동시에 한 하위 Issue만 write owner가 된다. 다른 담당자의 소유 범위나 공통 build 파일·UI shell을 바꿔야 하면 현재 Issue에 섞지 않는다. 별도의 선행 Issue와 작은 PR을 먼저 `develop`에 병합하고, 영향받는 작업은 최신 `develop`에서 새 브랜치를 만든다.

계약 producer 구현이 늦더라도 승인된 fixture가 있으면 consumer는 병렬 개발한다. 다만 실제 producer와의 계약 테스트가 끝나기 전에는 상위 흐름을 완료하지 않는다.

## 8. 회의에서 지금 결정할 것

회의에서는 다음만 정하면 된다.

1. 공통 작업 항목별 작성자와 검토자
2. 공통 작업을 병합할 순서와 Hard prerequisite
3. 각 사용자 흐름의 루트 카드와 필요한 서브모듈 하위 Issue
4. GitHub Issue를 생성할 시점

공통 선행 Issue → 루트 사용자 흐름 카드 → 서브모듈 하위 Issue 순서로 생성하고, 위 담당자와 선행 관계를 입력한 뒤 실제 개발을 시작한다.
