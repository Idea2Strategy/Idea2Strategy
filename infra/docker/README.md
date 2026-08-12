# Idea2Strategy 로컬 Docker 개발 환경

After the first complete startup, rebuild only the changed application with `./scripts/dev.ps1 restart -Service <name> -NoBrowser`. Supported names are `frontend`, `backend-api`, `backend-batch`, `backend-worker`, `admin-mcp`, `market-gateway`, `trading-worker`, `backtest-api`, and `backtest-worker`. Durable market-data backup and restore are documented in [`docs/infrastructure/market-data-baseline-runbook.md`](../../docs/infrastructure/market-data-baseline-runbook.md); dumps and Parquet payloads never belong in Git.

Frontend와 Backend/공통 인프라를 별도 Compose 파일로 관리한다.

- `compose.front.yml`: 현재 `ui` 서브모듈의 Vite Frontend
- `compose.back.yml`: PostgreSQL 16, Redis 7.4, MinIO, LocalStack SQS와 선택 실행 서비스
- `.env.docker`: 최초 실행 시 자동 생성되는 로컬 비밀값. Git에 포함하지 않는다.

## 빠른 시작

Windows 탐색기에서 프로젝트 루트의 `dev.cmd`를 실행한다. 하나의 CMD 창에 다음 선택 메뉴가
표시된다.

```text
1. Frontend만 실행
2. Backend 개발 인프라만 실행
3. Frontend + Backend 개발 인프라 실행
4. Spring 포함 전체 실행
5. 기타 관리
0. 종료
```

`Backend 개발 인프라`는 PostgreSQL, Redis, MinIO와 LocalStack SQS를 뜻한다. 도메인
기능 없이 인프라만 필요하면 2번 또는 3번을 사용한다.

PowerShell 명령으로 직접 실행할 수도 있다.

```powershell
.\scripts\dev.ps1
```

스크립트는 다음 작업을 자동으로 수행한다.

1. `.env.docker`가 없으면 안전한 임의 비밀번호와 함께 생성한다.
2. Docker Desktop 엔진이 꺼져 있으면 시작하고 준비될 때까지 기다린다.
3. Frontend 이미지를 빌드한다.
4. Frontend, PostgreSQL, Redis, MinIO와 LocalStack SQS를 실행한다.
5. Market Data와 Result 버킷을 만들고 버전 관리를 활성화한다.
6. 서비스 상태를 확인한 뒤 Frontend와 MinIO Console을 브라우저로 연다.

## 접속 정보

| 대상 | 주소 |
|---|---|
| Frontend | `http://localhost:15173` |
| MinIO Console | `http://localhost:19001` |
| MinIO S3 API | `http://localhost:19000` |
| PostgreSQL | `localhost:15432` |
| Redis | `localhost:16379` |
| LocalStack SQS | `http://localhost:14566` |

PostgreSQL DB와 사용자는 기본적으로 모두 `idea2strategy`다. 비밀번호와 MinIO
비밀번호는 Git에서 제외된 `.env.docker`에서 확인한다.

모든 포트는 `127.0.0.1`에만 바인딩되므로 같은 네트워크의 다른 장치에 공개되지 않는다.

## 관리 명령

```powershell
# 실행하고 브라우저 열기
.\scripts\dev.ps1 up

# 브라우저를 열지 않고 실행
.\scripts\dev.ps1 up -NoBrowser

# Frontend만 실행
.\scripts\dev.ps1 up -Scope front

# PostgreSQL, Redis, MinIO, LocalStack SQS만 실행
.\scripts\dev.ps1 up -Scope back

# Frontend와 Backend 개발 인프라를 함께 실행
.\scripts\dev.ps1 up -Scope all

# 상태 확인
.\scripts\dev.ps1 status

# 로그 확인
.\scripts\dev.ps1 logs

# 재시작
.\scripts\dev.ps1 restart

# 컨테이너 종료, 데이터 볼륨 유지
.\scripts\dev.ps1 down

# 로컬 DB와 객체 데이터를 포함한 볼륨 삭제
.\scripts\dev.ps1 reset -Force
```

## Frontend 개발

호스트의 `ui` 디렉터리를 컨테이너에 마운트한다. 로컬 파일을 수정하면 Vite가 변경을
감지하며, 의존성은 `idea2strategy-frontend-node-modules` Docker Volume에 보관한다.
UI 서브모듈 내부에 Docker 전용 파일을 추가하지 않는다.

## 서비스 App 함께 실행

기본 실행은 공통 인프라만 시작한다. API와 Worker 골격까지 확인할 때 선택 프로필을 사용한다.

```text
backend/
├── apps/backend-api/
├── apps/backend-batch/
├── apps/backend-worker/
├── apps/admin-mcp/
└── db-migration/

trading-engine/apps/
├── market-gateway/
└── trading-worker/

backtest-engine/
├── src/backtest_engine/api.py
└── src/backtest_engine/worker.py
```

```powershell
.\scripts\dev.ps1 up -WithBackend
```

`apps` 프로필은 다음 순서로 실행된다.

```text
PostgreSQL 정상
→ LocalStack SQS와 MinIO 준비
→ Flyway Migration 성공
→ Backend / Trading / Backtest API와 Worker 개별 빌드 및 실행
```

Spring 애플리케이션은 하나의 이미지로 합치지 않는다. 동일한
`infra/docker/backend/Dockerfile.spring`에서 Gradle 모듈만 다르게 지정해 별도 JAR와
별도 컨테이너를 만든다.

## AWS와의 차이

이 구성은 로컬 개발 전용이다.

- 로컬 PostgreSQL은 Development RDS의 대체재다.
- 로컬 MinIO는 Amazon S3의 대체재다.
- 로컬 LocalStack SQS는 AWS SQS의 대체재다.
- AWS에서는 MinIO와 PostgreSQL 컨테이너를 실행하지 않는다.
- Redis는 실시간 시장 사건과 최신 상태에만 사용하고 durable 작업 Queue로 사용하지 않는다.
- S3 Version ID, IAM, RDS TLS와 실제 AWS 권한은 Development AWS에서 별도로 검증한다.
- 로컬 Redis는 재구축 가능한 임시 데이터만 저장한다.

## 정적 검증

Docker 엔진이 실행 중일 때 다음 명령으로 Compose 구성과 보안 바인딩을 검증한다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-docker-development.ps1
```
