# Idea2Strategy Docker 개발 환경 사용 가이드

> 로컬 실행 명령은 이 문서에서 확인한다. Backend 모듈과 서버 배치의 최신 기준은 [백엔드·AWS 아키텍처 기준](backend-and-aws-architecture.md)이며, 이 문서에 남아 있는 `backend-app`·`batch-app`·`backtest-app` 예시는 신규 리포가 만들어질 때 Core·Trading·Compute App 구성으로 교체해야 한다.

이 문서는 팀원이 Idea2Strategy의 로컬 개발 환경을 처음 실행하고 개발을 시작할 수 있도록 설명한다.

## 한눈에 보는 사용 방법

```text
1. Docker Desktop 설치
2. 프로젝트 루트의 dev.cmd 더블클릭
3. 담당 작업에 맞는 메뉴 선택
4. IntelliJ 또는 VS Code에서 로컬 소스 수정
5. 브라우저나 API 클라이언트로 결과 확인
6. 작업 종료 시 컨테이너만 종료하고 데이터는 유지
```

## 중앙 Flyway 번들

로컬 Compose와 CI는 각 애플리케이션 저장소의 migration 디렉터리를 직접 실행하지 않는다. 다음 명령이 backend의 중앙 assembler와 현재 checkout된 정확한 trading-engine contribution 계약을 검증한 뒤 로컬 전용 번들을 만든다.

```powershell
./scripts/prepare-flyway-bundle.ps1
```

생성 위치는 `.harness/local/tmp/flyway-bundle` 하나로 고정된다. 스크립트는 이 정확한 경로 밖의 디렉터리를 삭제하거나 다시 만들지 않으며 symlink·reparse point 출력도 거부한다. `compose.back.yml`의 `flyway` 서비스는 생성된 번들만 `/flyway/sql`에 읽기 전용으로 mount한다. backend와 trading runtime은 Flyway를 실행하지 않는다.

PostgreSQL 16에서 최초 migrate, validate, 두 번째 migrate의 pending 0과 현재 application table 수를 확인하려면 다음을 실행한다.

```powershell
./scripts/test-flyway-migration.ps1
```

Docker 컨테이너 안에서 코드를 수정하지 않는다. 평소처럼 로컬 프로젝트 파일을 IDE에서 수정하면 된다.

## 1. 최초 준비

### 필수 프로그램

- Git
- Docker Desktop
- Frontend 개발자: VS Code 등 JavaScript IDE
- Backend 개발자: IntelliJ IDEA와 Java 21

Docker Desktop은 설치만 되어 있으면 된다. `dev.cmd` 실행 시 Docker가 꺼져 있으면 자동으로 시작을 시도한다.

### 프로젝트 위치 확인

다음 파일이 보이는 폴더가 프로젝트 루트이다.

```text
Idea2Strategy/
├── dev.cmd
├── compose.front.yml
├── compose.back.yml
├── ui/
├── scripts/
└── infra/
```

처음 저장소를 받은 뒤 `ui` 폴더가 비어 있다면 프로젝트 루트에서 다음 명령을 한 번 실행한다.

```powershell
git submodule update --init --recursive
```

## 2. 개발 환경 실행

프로젝트 루트의 `dev.cmd`를 더블클릭한다.

```text
1. Frontend만 실행
2. Backend 개발 인프라만 실행
3. Frontend + Backend 개발 인프라 실행 (권장)
4. Spring 포함 전체 실행
5. 기타 관리
0. 종료
```

담당 업무에 따라 다음과 같이 선택한다.

| 담당 업무 | 선택할 메뉴 | 실행되는 항목 |
|---|---:|---|
| 화면 개발만 수행 | 1 | Frontend |
| Spring API·배치·백테스트 개발 | 2 | PostgreSQL, Redis, MinIO |
| Frontend와 Backend 연동 개발 | 3 | Frontend, PostgreSQL, Redis, MinIO |
| 전체 통합 동작 확인 | 4 | 위 항목과 Spring 애플리케이션 |

현재 Backend 소스가 아직 추가되지 않았다면 4번은 사용할 수 없다. Backend 멀티 모듈과 Flyway 파일이 추가된 뒤 전체 통합 테스트에 사용한다.

최초 실행 시 다음 작업은 자동으로 처리된다.

- 로컬 비밀번호가 들어 있는 `.env.docker` 생성
- 필요한 Docker 이미지 다운로드 및 빌드
- PostgreSQL, Redis, MinIO 등 선택한 서비스 실행
- Market Data와 Result 버킷 생성
- 두 버킷의 버전 관리 활성화
- 서비스가 정상 상태가 될 때까지 대기
- Frontend와 MinIO 화면 열기

첫 실행은 이미지를 내려받기 때문에 시간이 조금 걸릴 수 있다.

## 3. Frontend 개발 방법

1. `dev.cmd`에서 1번 또는 3번을 선택한다.
2. IDE에서 `ui` 폴더를 연다.
3. 소스 파일을 수정하고 저장한다.
4. 브라우저에서 `http://localhost:15173`을 확인한다.

`ui` 폴더는 Frontend 컨테이너에 연결되어 있다. 일반적인 소스 수정은 Vite가 감지하므로 컨테이너를 다시 만들 필요가 없다.

다음 파일을 변경한 경우에는 `dev.cmd`의 기타 관리 메뉴에서 **전체 환경 다시 빌드·시작**을 선택한다.

- `package.json`
- `pnpm-lock.yaml`
- Frontend Dockerfile
- Compose 설정

## 4. Backend 개발 방법

Backend 개발 중에는 Spring을 IntelliJ에서 실행하고, 필요한 개발 인프라만 Docker로 실행하는 방식을 권장한다.

1. `dev.cmd`에서 2번 또는 3번을 선택한다.
2. IntelliJ에서 개발할 Spring 모듈을 연다.
3. 로컬 프로필로 Spring 애플리케이션을 실행한다.
4. API 테스트 도구 또는 Frontend를 통해 결과를 확인한다.

예정된 Backend 모듈 구조는 다음과 같다.

```text
backend/
├── backend-app/       # 일반 API와 모의투자 서비스
├── batch-app/         # 정기 배치 처리
├── backtest-app/      # 백테스트 실행
├── db-migration/      # Flyway 마이그레이션
└── gradlew
```

각 모듈은 같은 PostgreSQL을 사용하지만 별도로 빌드하고 실행한다.

### 로컬 Spring 연결 정보

IntelliJ에서 실행하는 Spring은 다음 주소로 Docker 서비스에 연결한다.

| 서비스 | 로컬 연결 정보 |
|---|---|
| PostgreSQL | `localhost:15432` |
| Redis | `localhost:16379` |
| MinIO S3 API | `http://localhost:19000` |
| MinIO 관리 화면 | `http://localhost:19001` |

PostgreSQL의 DB 이름, 사용자 이름과 비밀번호는 프로젝트 루트의 `.env.docker`에서 확인한다.

Spring 설정 예시는 다음과 같다.

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:15432/idea2strategy
    username: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
  data:
    redis:
      host: localhost
      port: 16379
```

MinIO를 사용하는 로컬 프로필에는 다음 값이 필요하다.

```text
Endpoint: http://localhost:19000
Region: ap-northeast-2
Market Data Bucket: idea2strategy-local-market-data
Result Bucket: idea2strategy-local-results
Access Key / Secret Key: .env.docker의 MinIO 계정 정보
```

`.env.docker`에는 개인 로컬 비밀번호가 있으므로 Git에 올리거나 메신저로 공유하지 않는다.

## 5. 주요 접속 주소

| 용도 | 주소 |
|---|---|
| Frontend | `http://localhost:15173` |
| Backend API 예정 주소 | `http://localhost:18080` |
| Batch 예정 주소 | `http://localhost:18081` |
| Backtest 예정 주소 | `http://localhost:18082` |
| PostgreSQL | `localhost:15432` |
| Redis | `localhost:16379` |
| MinIO S3 API | `http://localhost:19000` |
| MinIO 관리 화면 | `http://localhost:19001` |

이 포트들은 자신의 PC에서만 접근할 수 있도록 `127.0.0.1`에 연결되어 있다.

## 6. 작업 종료와 데이터 보존

CMD 창을 닫아도 실행 중인 Docker 컨테이너는 자동으로 종료되지 않는다.

안전하게 종료하려면 다음 순서로 진행한다.

```text
dev.cmd 실행
→ 5. 기타 관리
→ 5. 전체 환경 종료 (데이터 유지)
```

일반적인 종료, 재시작 또는 컨테이너 재생성으로는 PostgreSQL과 MinIO 데이터가 사라지지 않는다. 데이터는 Docker Volume에 보관된다.

다음 작업은 데이터를 삭제하므로 주의한다.

```text
5. 기타 관리
→ 6. 전체 환경 초기화
→ RESET 입력
```

초기화하면 다음 데이터가 삭제된다.

- 로컬 PostgreSQL 데이터
- MinIO의 Market Data 및 Result 객체와 버전 이력
- Frontend 의존성 Volume

팀 공용 AWS RDS나 S3 데이터에는 영향을 주지 않는다.

## 7. 자주 사용하는 관리 기능

`dev.cmd`에서 5번 **기타 관리**를 선택하면 다음 기능을 사용할 수 있다.

| 메뉴 | 사용 시점 |
|---|---|
| 전체 상태 확인 | 어떤 서비스가 실행 중인지 확인할 때 |
| 전체 로그 보기 | 화면이나 API가 동작하지 않을 때 |
| 브라우저 열기 | Frontend 또는 MinIO 화면을 다시 열 때 |
| 전체 환경 다시 빌드·시작 | 의존성이나 Docker 설정이 바뀌었을 때 |
| 전체 환경 종료 | 작업을 마치되 데이터를 보존할 때 |
| 전체 환경 초기화 | 로컬 데이터를 완전히 새로 만들 때만 사용 |

## 8. 문제가 생겼을 때

### `dev.ps1`이 메모장으로 열리는 경우

`dev.ps1`을 직접 더블클릭하지 말고 프로젝트 루트의 `dev.cmd`를 실행한다.

### Docker를 찾을 수 없다는 오류

Docker Desktop이 설치되어 있는지 확인한 뒤 Docker Desktop을 한 번 직접 실행한다.

### 포트가 이미 사용 중이라는 오류

기존에 실행 중인 PostgreSQL, Redis 또는 다른 개발 서버가 같은 포트를 사용하고 있을 수 있다. `dev.cmd`의 기타 관리 메뉴에서 상태를 확인하고, 충돌하는 프로그램을 종료한다.

### 변경한 Frontend 코드가 반영되지 않는 경우

1. 브라우저를 새로고침한다.
2. 기타 관리 메뉴에서 로그를 확인한다.
3. `package.json`이나 lock 파일을 수정했다면 전체 환경을 다시 빌드한다.

### DB 또는 MinIO 비밀번호가 맞지 않는 경우

기존 Docker Volume을 유지한 상태에서 `.env.docker`를 삭제하거나 변경하면 저장된 계정 정보와 파일의 비밀번호가 달라질 수 있다.

- 기존 데이터가 필요하면 `.env.docker`를 임의로 삭제하지 않는다.
- 기존 데이터가 필요 없다면 기타 관리의 **전체 환경 초기화** 후 다시 실행한다.

### Spring 포함 전체 실행이 실패하는 경우

4번 메뉴는 다음 항목이 모두 존재한 뒤 사용할 수 있다.

- `backend/gradlew`
- `backend/backend-app`
- `backend/batch-app`
- `backend/backtest-app`
- `backend/db-migration/src/main/resources/db/migration`

Backend 소스가 준비되기 전에는 2번 또는 3번 메뉴를 사용한다.

### GitHub Actions의 private 서브모듈 권한

루트 Flyway 통합 job은 backend와 trading 서브모듈만 루트 gitlink의 정확한
커밋으로 checkout한다. 루트 저장소의 Actions secret
`SUBMODULE_READ_TOKEN`에는 `Idea2Strategy-backend`와
`Idea2Strategy-trading-engine`에만 `Contents: read` 권한이 있는 fine-grained
token을 등록한다. 루트의 기본 `GITHUB_TOKEN`은 sibling private 저장소를 읽을
수 없으며, 이 checkout에 write 권한 토큰을 사용하지 않는다.

## 9. 팀 공통 규칙

- Docker 컨테이너 안에서 소스 코드를 직접 수정하지 않는다.
- `.env.docker`는 Git에 커밋하거나 다른 사람에게 공유하지 않는다.
- DB 스키마 변경은 임의 SQL이 아니라 Flyway 마이그레이션으로 관리한다.
- Market Data와 Result 버킷의 객체를 수동으로 삭제하기 전에는 재생성이 가능한 로컬 테스트 데이터인지 확인한다.
- 문제가 발생하면 초기화부터 하지 말고 상태와 로그를 먼저 확인한다.
- 전체 통합 확인이 필요할 때만 Spring 애플리케이션까지 Docker로 실행한다.

## 작업 흐름 요약

```text
dev.cmd 실행
→ 담당 업무에 맞는 환경 선택
→ IDE에서 로컬 소스 수정
→ 브라우저 또는 API로 확인
→ 오류 발생 시 상태와 로그 확인
→ 작업 후 데이터 유지 상태로 종료
```
