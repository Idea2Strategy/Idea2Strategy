# Idea2Strategy 로컬 개발 시작 가이드

## 준비물

- Git
- Docker Desktop
- PowerShell 5.1 이상
- GitHub 저장소 접근 권한

## Clone 또는 갱신

새로 받는 경우:

```powershell
git clone --recurse-submodules --branch develop https://github.com/Idea2Strategy/Idea2Strategy.git
Set-Location Idea2Strategy
```

기존 clone은 작업 중인 변경을 먼저 확인한 뒤 실행한다.

```powershell
git status --short --branch
git switch develop
git pull --ff-only origin develop
git submodule sync --recursive
git submodule update --init --recursive
```

`git submodule foreach git pull`은 루트가 고정한 정확한 포인터를 바꾸므로 사용하지
않는다.

## 프로젝트 초기화와 확인

```powershell
.\scripts\initialize-local-harness.ps1 -Verify
.\scripts\verify-collaboration-policy.ps1
git status --short --branch
git submodule status
```

출시 준비 작업은 다음 명령이 알려주는 한 건만 선택한다.

```powershell
.\scripts\launch-status.ps1 -Owner kcrmin
# 또는
.\scripts\launch-status.ps1 -Owner hjcud
```

## 로컬 Docker 실행

최초에는 전체 환경을 한 번 실행한다.

```powershell
.\scripts\dev.ps1 up -Scope all -WithBackend -NoBrowser
```

그다음에는 수정한 서비스만 다시 빌드하고 시작한다.

```powershell
.\scripts\dev.ps1 restart -Scope backend-api -Build
.\scripts\dev.ps1 status
```

`down`은 컨테이너만 종료하고 PostgreSQL·MinIO 볼륨은 보존한다. `reset -Force`는
로컬 데이터를 지우므로 명시적으로 초기화할 때만 사용한다.

## 브랜치와 협업

- 공유 작업은 전용 worktree와 `feature/<issue>-<name>` 또는 목적에 맞는
  `fix/`, `docs/`, `chore/` 브랜치를 사용한다.
- 자신이 소유한 저장소 경로만 수정한다. 현재 소유권은
  `docs/launch-readiness-tasks.json`의 `owners` 블록이 정본이다.
- DB/API 계약/Compose/submodule 변경은 통합 테스트가 필요하다.
- 서비스 내부 변경은 해당 서비스의 lint·unit test·build를 먼저 실행한다.
- submodule PR과 루트 gitlink 갱신은 별도 검토 단위다.
- 보호된 제품·정책·계약 변경은 `docs/product-authorities.yaml`과
  `docs/collaboration-policy.md`의 승인 규칙을 따른다.

Claude에서는 `/start-work <GitHub-ID> [issue-or-goal]`을 사용할 수 있다. 이 명령은
저장소의 `launch-status.ps1`과 같은 ledger를 읽으며 별도 외부 CLI가 필요 없다.
