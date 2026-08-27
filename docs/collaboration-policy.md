# Idea2Strategy 공식 협업 정책

상태: 배포됨
정본 위치: `docs/collaboration-policy.md`

## 1. 정본과 작업 시작

제품 의미는 `specs/`, 서비스 의무는 `contracts/`, DB 모델은
`db/schema.dbml`, 출시 순서와 완료 조건은 `docs/launch-readiness-plan.md`와
`docs/launch-readiness-tasks.json`이 소유한다. 이 문서는 Git·협업 운영만
정의한다.

모든 작업은 다음 순서로 시작한다.

1. `scripts/initialize-local-harness.ps1 -Verify`를 실행한다.
2. `AGENTS.md`, 이 문서, 관련 사양과 계약을 읽는다.
3. `git status --short --branch`, `git worktree list`, `git submodule status`로
   실제 로컬 상태를 확인한다.
4. GitHub Issue·PR·리뷰가 필요한 작업은 인증된 도구로 현재 상태를 읽는다.
   캐시나 대화 기록은 실시간 상태를 대신하지 않는다.
5. 공유·장기·교차 저장소 작업은 전용 worktree, 변경 경로, 소유자, 의존성,
   병합 순서, 첫 실패 테스트와 완료 근거를 먼저 기록한다.

## 2. 저장소와 Git Flow

- GitHub 루트 저장소는 submodule 구조의 정본이다.
- `develop`은 개발·통합 브랜치이고 `main`은 `v1.0.0`부터 정식 릴리스 전용이다.
- 기능 브랜치는 목적을 나타내며 일반 PR은 `develop`을 대상으로 한다.
- submodule 변경과 루트 gitlink 갱신은 별도 검토 단위다. 단,
  `docs/launch-readiness-tasks.json`의 `may_move_gitlinks`에 지정된 소유자는 자기
  submodule 포인터를 직접 갱신한다.
- `db/schema.dbml`, `compose.back.yml`, `compose.front.yml` 등 ledger의
  `exclusive_paths`는 지정 소유자만 변경한다.
- Development 배포, BASIC queue/worker, operator 계정, DB bootstrap 같은
  `serialized_resources`는 루트 Issue에 사용 시작·종료를 남기고 한 번에 한
  사람만 사용한다.
- 기존 변경을 임의로 stash, reset, clean, checkout 하지 않는다.

GitLab monolithic 제출 작업공간은 GitHub submodule 작업공간과 분리한다. 두
원격의 이력과 자격증명을 같은 것으로 가정하지 않으며, 토큰·비밀번호·개인키는
문서·로그·커밋에 기록하지 않는다.

## 3. 제품 권한과 보호 정본

권한 구성의 정본은 `docs/product-authorities.yaml`이다. 네 권한자
`user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`, `user:hjcud`는 product,
policy, business, contract 범위에서 동등하다.

- 보호 경로: `docs/product-authorities.yaml`, `specs/**`, `contracts/**`, 이
  문서와 이 규칙을 집행하는 파일.
- 일반 작업자는 보호 경로를 직접 고치지 않고 격리된 proposal을 만든다.
- `v1.0.0` 전에는 구성된 권한자의 명시적 지시를 PR 본문에 권한자 이름과 함께
  인용하면 해당 PR에서 보호 정본을 수정할 수 있다.
- `v1.0.0`부터는 정확한 커밋에 대한 GitHub의 fresh approval이 필요하다.
- 승인 상태가 없거나 오래됐거나 확인 불가하면 승인·통합·릴리스로 표현하지
  않는다.
- Git user.name and user.email never prove authority.

이 변경은 권한자 `user:kcrmin`의 2026-08-12/13 외부 조정 도구 완전 제거
지시에 따라 독립 PR로 수행한다. 원문은 PR 본문에 기록한다.

## 4. 로컬 비공유 영역

`.harness/local/`은 프로젝트 스크립트가 쓰는 일반 로컬 운영 영역이다. 모든
clone은 `README.md`와 `.gitkeep` 골격만 공유하고 실제 산출물·임시 파일·캐시·
로그·Jira 이전 기록·정책 해시는 Git에서 제외한다. 자격증명, 세션 쿠키, 토큰,
개인키, 복구 코드는 저장하지 않는다.

`scripts/initialize-local-harness.ps1`은 이 골격, ignore 경계, Git hook,
workspace isolation을 검증한다. `.harness/ui/baselines/`는 별도의 추적되는 UI
기준선이며 로컬 운영 데이터가 아니다.

## 5. DBML·계약·검증

- `db/schema.dbml`이 데이터 모델의 Git 정본이다. 이미 적용된 Flyway migration은
  수정하지 않고 새 migration을 추가한다.
- dbdiagram과 외부 UI 도구는 제안 입력일 뿐 정본이 아니다.
- 계약/API/DB/Compose/submodule 경계 변경은 통합 검증을 거친다.
- 완료 주장은 관련 테스트, CI, 정확한 커밋과 PR 상태로 증명한다.
- 원격 쓰기, Issue/Jira 변경, push, merge, release는 사용자가 요청한 범위에서만
  수행한다.

## 6. 변경 이력

| 날짜 | 변경 | 승인 근거 |
| --- | --- | --- |
| 2026-08-13 | 외부 조정 도구 의존성을 제거하고 Git·GitHub·저장소 스크립트 기반 절차로 전환. 권한 구성을 `docs/product-authorities.yaml`로 이동 | `user:kcrmin`의 현재 세션 명시적 제거 지시 |
| 2026-08-04 | 제품 권한자를 실제 네 명과 1:1로 정리하고 CI 검증 연결 | `user:kcrmin`의 명시적 지시 |
| 2026-08-02 | `user:pjy008008`, `user:Juwon-Na`, `user:hjcud`를 동등 권한자로 확장 | `user:kcrmin`의 명시적 지시 |
| 2026-07-22 | `develop` 통합, `main` 릴리스 전용 Git Flow와 GitHub/GitLab 분리 구조 확정 | 사용자의 명시적 승인 |
