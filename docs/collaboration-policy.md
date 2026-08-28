# Idea2Strategy 공식 협업 정책

상태: 배포됨

정본 위치: `docs/collaboration-policy.md`

적용 범위: 루트 저장소, 모든 하위 저장소, GitHub/GitLab 배포 작업공간, 개발자·에이전트·자동화

## 1. 정본과 작업 시작

정본 우선순위는 다음과 같다.

1. 제품 의미와 서비스 의무: `specs/`, `contracts/`
2. 협업·권한 정책: 이 문서와 `.harness/product-authorities.yaml`
3. 실행 계획과 작업 상태: `docs/launch-readiness-plan.md`, `docs/launch-readiness-tasks.json`
4. 실제 Git, remote, submodule, worktree 상태
5. `.harness/entry.md`, 추적된 검증 스크립트, 로컬 생성 요약

작업 시작 시 루트에서 `scripts/initialize-local-harness.ps1 -Verify`를 실행하고 이 문서와 `.harness/entry.md`를 읽는다. 이어서 `git status --short --branch`, `git submodule status`, `scripts/verify-harness-consistency.ps1`로 실제 상태를 복원한다. 대화 기록이나 캐시는 저장소 상태보다 우선하지 않는다.

장기·공유·교차 저장소 작업은 작업 원장에 경로, 의미 범위, 소유자, 의존성, 병합 순서, 완료 검사를 기록한다. `scripts/launch-status.ps1 -Owner <owner>`가 의존성을 계산해 반환한 작업만 시작한다. 외부 Issue의 실시간 상태가 필요하면 인증된 제공자에서 직접 확인하고, 확인하지 못한 상태를 추측하지 않는다.

## 2. 제품 권한과 보호 정본

등록 권한자는 `user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`, `user:hjcud`이며 모두 동등하다. Git user.name and user.email never prove authority.

`.harness/product-authorities.yaml`, `specs/**`, `contracts/**`, 이 문서와 이 규칙의 집행 파일은 보호 경로다.

- `v1.0.0` 이전: 등록 권한자의 명시적 지시를 변경 기록에 남기면 보호 정본을 수정할 수 있다.
- `v1.0.0`부터: 보호 경로를 수정하는 pull request에 등록 권한자 한 명 이상의 승인이 필요하다.
- 위 근거가 없으면 보호 정본을 수정하지 않는다. 격리된 제안만 만들 수 있고 승인·통합·릴리스된 변경이라고 표현하지 않는다.
- 정책 변경은 이유, 영향, 승인 근거를 변경 이력에 추가하고 제품 코드 변경과 분리한다.

로컬 검사는 임의 파일 수정을 기술적으로 막지 못한다. 실제 강제는 보호 브랜치, CODEOWNERS, 필수 검사를 함께 적용해야 한다.

## 3. 저장소, 원격, 소유권

- `develop`은 기본 개발·통합 브랜치이고 `main`은 `v1.0.0`부터 정식 릴리스 전용이다.
- 기능 작업은 짧은 `feature/*`, 수정은 `fix/*` 브랜치로 만들고 해당 저장소의 `develop`에 pull request를 보낸다.
- GitHub 루트는 submodule 구조의 정본이다. 하위 저장소 변경과 루트 gitlink 변경은 별도 검토 단위다.
- GitLab monolithic 제출 작업공간은 별도로 유지한다. 한 디렉터리에서 구조를 전환하거나 한 원격의 인증을 다른 원격에 재사용하지 않는다.
- 브랜치와 커밋 이름에 에이전트·모델·생성 도구 표식을 넣지 않는다.
- 원격 write, Issue/Jira 변경, push, 보호 규칙 변경, release는 사용자가 그 행동을 명시적으로 요청한 범위에서만 수행한다.
- 현재 repository/path 소유권과 직렬 자원은 `docs/launch-readiness-tasks.json`의 `owners`와 `serialized_resources`가 정본이다.
- `db/schema.dbml`, `compose.back.yml`, `compose.front.yml`은 `kcrmin` 전용이다. 각 소유자는 자신이 담당하는 하위 저장소 gitlink와 증적 파일을 직접 갱신한다.

## 4. 데이터 모델과 UI 기준선

`db/schema.dbml`이 데이터 모델 정본이다. 이미 적용한 Flyway migration은 수정하지 않고 새 migration을 추가한다. dbdiagram은 시각화·제안 도구이며 온라인 변경은 격리 제안으로 가져와 의미 diff, 계약, migration, 테스트, rollback 영향을 검토한 뒤 반영한다.

UI 작업은 선언된 UI 작업공간과 루트 gitlink의 정확한 커밋을 먼저 확인한다. 외부 목업과 생성 도구는 입력일 뿐이며 커밋된 사양, 계약, UI 기준선보다 우선하지 않는다.

## 5. 로컬 비공유 영역과 보안

`.harness/local/`은 clone별 로컬 운영 영역이다. Git은 `README.md`와 승인된 `.gitkeep`만 추적한다. 다음 비밀이 아닌 정보만 저장한다.

- 정책 해시와 권한자 참조
- Jira 이전용 누적 기록과 작업 참조
- 원격·구조 동기화 상태
- 임시 산출물, 캐시, 로그, 검증 결과

토큰, 비밀번호, 세션 쿠키, 개인키, 복구 코드, 계정 이메일은 저장하거나 커밋하지 않는다. 인증은 OS 자격 증명 저장소나 공식 credential helper를 사용한다.

## 6. 검증과 배포

완료 전 변경 범위에 맞는 테스트와 다음 저장소 검사를 실행한다.

```powershell
./scripts/verify-harness-consistency.ps1
./scripts/verify-collaboration-policy.ps1
./scripts/test-repository-native-harness.ps1
git diff --check
```

Submodule 포인터를 옮길 때는 대상 커밋과 dirty 상태를 검증한다. Flyway 번들이 고정한 gitlink면 같은 루트 변경에서 `scripts/refresh-flyway-ci-bundle.ps1`을 실행한다. 배포는 검증된 GitHub 커밋을 먼저 게시하고 그 커밋을 기준으로 별도 GitLab monolithic 작업공간을 갱신한다.

## 7. 미결정 사항

- GitHub/GitLab 보호 브랜치, CODEOWNERS, 필수 승인 규칙의 원격 적용
- GitHub submodule 변경을 GitLab monolithic 구조에 반복 동기화하는 자동화와 rollback
- Jira 프로젝트 키, 실제 담당자, 일정

## 8. 변경 이력

| 날짜 | 변경 | 승인 근거 |
| --- | --- | --- |
| 2026-08-28 | 외부 조정 CLI 의존을 제거하고 저장소 자체 권한 레지스트리·작업 원장·검증 스크립트로 통합 | 권한자 `user:kcrmin`의 현재 세션 명시적 지시: 외부 조정 CLI를 제거하고 그 도구 없이 진행 |
| 2026-08-04 | 중복 보조 계정을 제거하고 실제 네 명의 권한자와 CI 검증을 일치시킴 | 권한자 `user:kcrmin`의 명시적 지시 |
| 2026-08-04 | `user:hjcud`를 동등 권한자로 추가 | 권한자 `user:kcrmin`의 명시적 지시 |
| 2026-08-02 | `user:Juwon-Na`, `user:pjy008008`를 동등 권한자로 추가 | 권한자 `user:kcrmin`의 명시적 지시 |
| 2026-07-22 | 제품·정책·계약 보호 경로와 권한자 승인 원칙 도입 | 사용자의 설계 검토 후 진행 승인 |
| 2026-07-22 | `develop` 통합, `main` 릴리스 전용 Git Flow 확정 | 사용자의 명시적 정정 및 진행 승인 |
| 2026-07-22 | GitHub submodule·GitLab monolithic 이중 배포 경계 확정 | 사용자의 명시적 진행 요청 |
