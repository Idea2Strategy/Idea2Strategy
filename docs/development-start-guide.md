# Idea2Strategy 팀 개발 시작 가이드

이 문서는 공통 개발 기반이 각 저장소의 `develop` 브랜치에 병합되고, 루트 `develop`이 그 서브모듈 커밋들을 가리킨 뒤 팀원들이 따라야 하는 순서를 정리한다.

## 1. 시작 전 확인

필수 도구:

- Git
- Docker Desktop
- PowerShell 5.1 이상
- Stackcord CLI 1.0.0
- GitHub 조직과 담당 저장소 접근 권한

개발 기준 브랜치는 `develop`이다. `main`은 `v1.0.0`부터 완성된 릴리스에만 사용한다.

## 2. 처음 clone하는 경우

```powershell
git clone --recurse-submodules --branch develop https://github.com/Idea2Strategy/Idea2Strategy.git
Set-Location Idea2Strategy
```

루트가 기록한 정확한 서브모듈 커밋을 받아오므로 처음부터 각 서브모듈의 `develop`을 임의로 pull하지 않는다.

## 3. 기존 clone을 갱신하는 경우

먼저 자신이 수정 중인 파일이 없는지 확인한다. 작업이 남아 있다면 임의로 stash, reset 또는 checkout하지 말고 기존 작업부터 정리한다.

```powershell
git status --short --branch
git switch develop
git pull --ff-only origin develop
git submodule sync --recursive
git submodule update --init --recursive
```

`git submodule foreach git pull`은 사용하지 않는다. 루트가 검증한 포인터보다 각 서브모듈을 임의로 앞당길 수 있기 때문이다.

## 4. 로컬 협업 환경 초기화

프로젝트 루트에서 실행한다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-local-harness.ps1 -Verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-docker-development.ps1
```

`stackcord status --json`에서 제품 권한이 `unknown`으로 표시될 수 있다. 일반 구현은 진행할 수 있지만 `specs/`, `contracts/`, 협업 정책과 제품 거버넌스 파일은 승인 확인 없이 수정하지 않는다.

## 5. 전체 로컬 환경 실행

Docker Desktop을 실행한 뒤 프로젝트 루트에서 다음 명령을 사용한다.

```powershell
.\scripts\dev.ps1 up -Scope all -WithBackend -NoBrowser
```

최초 실행은 이미지와 의존성을 내려받으므로 시간이 걸릴 수 있다. 정상 실행 후 주요 주소는 다음과 같다.

| 서비스 | 주소 |
| --- | --- |
| UI | `http://localhost:15173` |
| Backend API | `http://localhost:18080` |
| Backtest API | `http://localhost:18082` |
| Admin MCP | `http://localhost:18083` |
| MinIO Console | `http://localhost:19001` |

상태 확인과 종료:

```powershell
.\scripts\dev.ps1 status
.\scripts\dev.ps1 down
```

`down`은 컨테이너만 종료하고 로컬 데이터 볼륨은 유지한다. 데이터를 지우는 `reset -Force`는 필요한 사람이 정확한 영향을 확인한 뒤에만 사용한다.

## 6. 담당 작업 시작

먼저 자신에게 배정된 GitHub Issue와 대상 저장소를 확인한다. 담당 배정은 [`backend-team-allocation.md`](backend-team-allocation.md)를 기준으로 하며, 실제 작업 상태는 GitHub Issue를 따른다.

루트 저장소가 아니라 실제 코드를 수정할 서브모듈에서 브랜치를 만든다. 예를 들어 Backend Issue `341`을 맡았다면:

```powershell
git -C backend switch develop
git -C backend pull --ff-only origin develop
git -C backend switch -c feature/341-short-name
```

Trading, Backtest, Data Pipeline과 UI도 같은 방식으로 해당 디렉터리에서 브랜치를 만든다.

```text
backend/          Java / Spring Boot
trading-engine/   Java / Spring Boot
backtest-engine/  Python / FastAPI worker
data-pipeline/    Python pipeline / batch
ui/               TypeScript / React / Vite
```

한 기능이 서버와 UI를 모두 변경하면 저장소마다 별도 Issue, 브랜치와 PR을 사용한다. 루트 저장소에서는 DBML·계약·Docker·문서·최종 서브모듈 포인터 통합만 처리한다.

## 7. 충돌 없이 병렬 개발하는 규칙

- 자신에게 배정된 Issue의 경로와 도메인만 수정한다.
- 다른 담당자의 코드가 아직 없어도 합의된 계약과 fixture/fake adapter를 사용해 먼저 개발한다.
- 공통 interface나 메시지 형식 변경이 필요하면 소비자 구현보다 계약 PR을 먼저 만든다.
- `db/schema.dbml`이 논리 모델 정본이다. dbdiagram 화면을 직접 정본으로 취급하지 않는다.
- 이미 적용된 `V1__initial_schema.sql`은 수정하지 않는다. DB 변경은 DBML 영향 확인과 새로운 `V2__...sql` 이상의 migration PR로 처리한다.
- 하나의 migration 번호, 공통 설정 파일 또는 UI 공통 shell을 두 명이 동시에 수정하지 않는다.
- 서브모듈 PR은 해당 저장소의 `develop`로 보낸다. 기능 브랜치를 `main`으로 보내지 않는다.

## 8. 작업 완료와 병합

1. 담당 저장소의 build와 test를 통과시킨다.
2. 자신의 기능 브랜치를 push한다.
3. 해당 서브모듈의 `develop`을 대상으로 PR을 만든다.
4. 리뷰와 CI가 끝나면 서브모듈 `develop`에 병합한다.
5. 여러 저장소가 필요한 기능은 계약 테스트와 E2E를 확인한다.
6. 마지막으로 별도 루트 통합 브랜치에서 검증된 서브모듈 커밋을 가리키도록 포인터를 갱신하고 루트 `develop` PR을 만든다.

개별 담당자는 서브모듈 PR이 끝났다는 이유만으로 루트 포인터를 직접 섞어 올리지 않는다. 루트 통합 Issue의 담당자가 완료된 커밋들을 정해진 순서로 모은다.

### GitHub Actions 확인

루트와 모든 서브모듈은 `develop` 대상 PR과 `develop` push에서 저장소별 CI를 실행한다.

- 루트: canonical DBML, dbdiagram export 도구와 submodule pointer 형식
- `backend`, `trading-engine`: Java 21·Gradle 전체 테스트
- `backtest-engine`: Python 3.12·pytest
- `data-pipeline`: Python 3.12 Linux·unittest 전체
- `ui`: Node.js 24·pnpm 11의 typecheck, test와 build

현재 GitHub 비공개 무료 플랜에서는 branch protection의 required status check를 강제할 수 없다. 따라서 PR 작성자와 리뷰어는 Actions가 성공하기 전에 병합하지 않는 것을 필수 협업 규칙으로 적용한다. 플랜이 변경되면 `develop`에 위 검사를 required status check로 연결한다.

`data-pipeline`의 전체 Parquet 테스트 기준 환경은 CI와 동일한 Python 3.12 Linux다. Windows의 깊은 임시 경로에서는 파일 경로 제한 때문에 일부 Parquet E2E가 실패할 수 있으므로, 해당 실패를 확인할 때는 다음 Linux 컨테이너 명령으로 재현한다.

```powershell
docker run --rm -v "${PWD}:/workspace" -w /workspace python:3.12-slim `
  sh -lc "python -m pip install -q -r requirements.txt && python -m unittest discover -s tests -v"
```

## 9. 현재 DB 기준선

- 정본: `db/schema.dbml`
- PostgreSQL: 10개 논리 스키마
- 테이블: 137개
- 초기 Flyway migration: `backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql`
- DBML의 `Records`는 dbdiagram 검토용 샘플이며 migration seed가 아니다.

새 clone에서 전체 환경을 처음 실행하면 Flyway가 V1을 자동 적용한다. 이후 실행에서는 같은 migration을 다시 적용하지 않고 checksum과 적용 상태를 검증한다.

## 10. Claude Code로 작업 시작

저장소 루트의 `CLAUDE.md`는 Claude Code가 세션 시작 시 자동으로 읽는 팀 공용 지침이다. `.claude/skills/start-work/SKILL.md`는 담당자와 실제 Git·서브모듈·Issue 상태를 확인하고 지금 시작할 작업 하나를 찾는 `/start-work` 명령을 제공한다.

Claude Code가 없다면 [공식 설치 안내](https://code.claude.com/docs/en/quickstart)에 따라 설치하고 로그인한다. 설치된 경우 저장소 루트에서 다음과 같이 시작한다.

```powershell
claude
```

처음 열 때 저장소 신뢰 여부를 확인한 뒤, 자신의 정보로 아래 명령을 한 번 실행한다.

```text
/start-work A 나주원 Juwon-Na
/start-work B 손현준 hjcud
/start-work C 박준유 pjy008008
/start-work D 서동위 SeoDongWi
/start-work E 황영우 dertz569
/start-work F 민경철 kcrmin
```

이미 배정된 GitHub Issue가 있으면 마지막에 번호나 URL을 붙인다.

```text
/start-work B 손현준 hjcud backend#123
```

Claude는 이 명령에서 구현을 시작하지 않고 현재 상태, 담당 범위와 선행조건을 확인한 뒤 지금 처리할 하위 Issue 하나를 제안한다. 제안이 맞으면 `해줘`라고 입력한다. 이후에는 해당 하위 Issue 하나를 구현·테스트하고 대상 서브모듈의 `develop` PR까지 준비한다.

슬래시 명령을 사용하지 않는 환경에서는 다음 문장을 그대로 입력해도 된다.

```text
나는 [이름]([GitHub ID])이고 [A-F] 담당이야. CLAUDE.md와 AGENTS.md를 읽고 Stackcord로 실제 Git·서브모듈·Issue 상태를 복원해줘. 내 담당 범위에서 선행조건이 완료되어 지금 시작 가능한 하위 Issue 하나만 알려줘. 이미 확정된 제품 결정을 다시 묻지 말고, 내가 "해줘"라고 하면 그 Issue 체크리스트 단위로 해당 서브모듈 feature 브랜치에서 구현하고 테스트해줘.
```
