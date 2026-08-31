# Basic 전략·백테스트 완성 검증 증거

- 실행 일시: 2026-08-25 (KST)
- 환경: Windows 로컬 Docker Desktop, 실제 PostgreSQL·Redis·LocalStack·MinIO와 브라우저
- 루트 통합 `develop`: `bfe8d37a48395ae036eade365b033742c69f4c3c`
- Backend `develop`: `933f3e3f48a83fb68e3107ac903c699d2e9e7383`
- Backtest `develop`: `2ce1020f8429ae7bc35cb3022bcb086dfe033407`
- Data Pipeline `develop`: `3e7a33a382b003ab9d9e9c4be95d7114470734b7`
- UI `develop`: `17067d7b17b894064b29c5747a7799062005cd80`
- 판정: **PASS**

## 실행 범위와 판정 기준

Basic만 실행 가능하다. Pro 편집 UI는 레이아웃 작업을 위해 보이지만 저장·검증·릴리스는
`프로 전략은 준비 중입니다`로 차단한다. Basic의 단일 클록은 `30m`, `1h`, `4h`, `1d`이고,
최대 4개 파티션, 컨테이너당 5개 조건, 파티션당 5개 종목을 Backend에서도 다시 검증한다.

아래의 `통과`는 단순 렌더링이 아니라 같은 버전의 literal conformance fixture를 UI 문서화,
Backend 검증·컴파일, Python runtime true/false 평가와 3-lane Docker 실행에서 각각 소비했다는
뜻이다. 브라우저 열은 전체 카탈로그의 실제 계정 저장·재조회와 대표 복합 전략의 실제
릴리스→공식 BASIC 결과 조회를 함께 뜻한다.

## 14개 Basic 요소 지원 행렬

| 요소 | UI 입력·저장 | Backend 검증 | 컴파일 | Runtime | BASIC/CUSTOM/COMPETITION | 실제 브라우저 |
| --- | --- | --- | --- | --- | --- | --- |
| `BASIC_PRICE_COMPARE` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_PRICE_CHANGE_PERCENT` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_VOLUME_COMPARE` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_STREAK` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 릴리스·실행 통과 |
| `BASIC_SMA_CROSS` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_RSI_CROSS` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_MACD_CROSS` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 릴리스·실행 통과 |
| `BASIC_BOLLINGER_REVERSAL` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 릴리스·실행 통과 |
| `BASIC_POSITION_RETURN` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_HOLDING_PERIOD` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_PEAK_RETURN` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_DRAWDOWN_FROM_PEAK` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 저장·재조회 통과 |
| `BASIC_SCHEDULE` | 통과 | 통과 | 통과 | true/false 통과 | 통과 | 릴리스·실행 통과 |
| `BASIC_EQUAL_ALLOCATION_ORDER` | 통과 | 통과 | 통과 | cap·주문 통과 | 통과 | 릴리스·실행 통과 |

## 실제 브라우저→Backend→Backtest 영수증

`scripts/test-basic-strategy-real-e2e.ps1 -KeepStack`을 D: 드라이브 연결이나 초기화 없이
연속 두 번 실행했다. 두 실행 모두 Playwright 1개 시나리오가 통과했고 로컬 seed는 같은
AAPL·MSFT·SPY, feature materialization 2개, market hash
`2a99c23c386ed3b9eaadeddb0ec527549c607b7d9fd0215284c6a23ab6fac9d1`로 수렴했다.

두 번째 실행의 secret-free 영수증은 다음과 같다.

| 필드 | 값 |
| --- | --- |
| strategy ID | `384ebd91-59a0-46d2-885e-d906179c43aa` |
| release / bot ID | `aad7b4b9-6ed3-3b19-9553-2b8971891b01` |
| BASIC run ID | `e3352754-f175-3963-8f6c-af1e8451e487` |
| terminal state | `COMPLETED` |
| result checksum | `93e58c1d47c71768cf197e59d8ba19a187943a62e32b21b06f5692114f89f6c1` |

이 브라우저 시나리오는 실제 로그인, 전략 생성, 종목 선택, 블록 추가와 값 변경, 저장,
validation, release, 공식 run 완료 대기, 결과 UI와 checksum 표시까지 통과한다. mock API를
Backtest 실행 증거로 사용하지 않았다.

## 경계값·경고·실패 상태

| 범주 | 검증한 내용 | 증거 계층 |
| --- | --- | --- |
| 구조 한도 | 파티션 5번째, 조건 6번째, 종목 6번째, terminal 누락·중복 차단 | UI + Backend 단위/통합 |
| 숫자 경계 | 빈 값, malformed, 0·음수·100 초과 cap, RSI/기간/해상도 경계 | literal corpus + UI + Backend |
| 복합 경고 | 중복·모순·항상 참/거짓·과도한 반복 주문·제한적 조합 | Backend warning analyzer + UI 표시 |
| 데이터 부족 | 과거 bar·feature·position·dataset 부족을 typed unavailable로 처리 | Backtest runtime/API + 3-lane Docker |
| 동시성·권한 | edit lease 충돌, stale validation/release, 401·403 | Backend + UI behavior tests |
| 실행 실패 상태 | queued/running/failed/cancelled/unavailable를 완료로 오표시하지 않음 | Backtest API + UI behavior tests |
| Pro | 보이지만 모든 실행 동작과 API 호출 차단 | UI behavior tests |

부정 상태는 상태 전이를 정밀하게 통제할 수 있는 Backend/Backtest/UI 계층 테스트의
증거다. 실제 브라우저 full-stack 성공 경로를 통과했다는 사실만으로 실패·취소·권한 거부
브라우저 경로까지 실행했다고 과장하지 않는다.

## 재현 명령과 결과

```powershell
# root contracts
node --test scripts/validate-basic-strategy-conformance.test.mjs
pnpm contract:validate:basic-strategy
pnpm contract:validate:registry

# Backend
cd backend
.\gradlew.bat test --no-daemon

# UI
cd ..\ui
pnpm test --run
pnpm typecheck
pnpm build

# Backtest
cd ..\backtest-engine
uv run pytest -q
uv run ruff check .
uv run mypy src

# data pipeline feature path
cd ..\data-pipeline
uv run --extra dev pytest tests/test_central_migration_copy_runner.py `
  tests/test_feature_backfill.py tests/test_feature_catalog.py `
  tests/test_feature_output_publication.py tests/test_features.py `
  tests/test_pipeline_feature_output_command.py `
  tests/test_pipeline_feature_output_trust_boundary.py -q

# Flyway and cross-repository execution
cd ..
.\scripts\refresh-flyway-ci-bundle.ps1
.\scripts\test-flyway-ci-bundle.ps1
.\backtest-engine\.venv\Scripts\python.exe -m pytest -c backtest-engine/pyproject.toml `
  scripts/integration/test_three_lane_feature_e2e.py `
  scripts/integration/test_basic_strategy_matrix_e2e.py -m docker -vv
.\scripts\test-basic-strategy-real-e2e.ps1 -KeepStack
```

| 검증 | 결과 |
| --- | --- |
| Root Basic conformance | 6/6 통과, 14 cases, fixture parity 일치 |
| Root contract registry | 7/7 통과 |
| 협업 정책 | `status=passed` |
| Backend 전체 Gradle | 992 통과, 실패·오류·skip 0, `BUILD SUCCESSFUL` |
| UI Vitest | 52 files, 602/602 통과 |
| UI typecheck/build | `tsc --noEmit` 및 Vite production build 통과 |
| Backtest pytest | 1,217 수집, 1,215 통과, Docker 제외 2 skip |
| Backtest lint/type | Ruff 오류 0, mypy 57 source files 오류 0 |
| Data Pipeline feature/DB | 로컬 feature/DB 272/272 및 PR CI 10/10 통과 |
| 3-lane 생성 matrix | 5/5 통과 |
| Flyway | 4 migrations 적용·validate 통과, 두 번째 migrate 0건 |
| Flyway bundle checksum | `d1fce94a6113e7eb33ba7f4f9868a2cbe1bfa7948c5cc6327e437324e389bb87` |
| 실제 릴리스 브라우저 | fresh stack 1/1 + 무초기화 재실행 1/1 통과 |
| 실제 회원가입·복합 저장 브라우저 | 1/1 통과 |

관찰된 경고는 Starlette/Testcontainers의 upstream deprecation 안내와 jsdom canvas 미구현
안내뿐이며 실패·skip으로 숨긴 제품 시나리오는 없다. Backtest의 2 skip은 기본 pytest 설정이
Docker marker를 별도 통합 명령으로 분리하기 때문이고, 해당 Docker matrix 5개는 별도로 모두
실행했다.

## 범위 밖

Pro 실행 구현, 실운영 AWS 배포, 실거래 주문, 성능·부하·장기 soak 시험은 이번 증빙의
통과 범위가 아니다. 결제·출금 기능은 제품 범위에 없으며 이번 전략 실행 경로에도 없다.
