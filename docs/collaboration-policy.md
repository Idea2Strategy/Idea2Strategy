# Idea2Strategy 공식 협업 정책

상태: 배포됨
정본 위치: `docs/collaboration-policy.md`
적용 범위: Idea2Strategy 루트 저장소, `ui` 작업공간, 향후 GitLab 제출 작업공간, 모든 개발자·에이전트·자동화 작업

## 1. 목적과 정본 관계

이 문서는 Idea2Strategy 전용 Git·협업 운영 정책의 단일 공유 정본이다. 제품 요구사항은 `specs/`와 `contracts/`가 소유하며 이 문서는 제품 동작을 정의하지 않는다.

작업자는 모든 작업 시작 전에 `AGENTS.md`, `.harness/entry.md`와 이 문서를 읽는다. 정본 우선순위는 다음과 같다.

1. 제품 의미와 서비스 의무: `specs/`, `contracts/`
2. Idea2Strategy 전용 협업 정책: 이 문서
3. 프로젝트 복원·조정·계획·검증의 공통 절차: Stackcord 지침과 `.harness/entry.md`
4. 실제 Git·remote·submodule·worktree·인증 가능 범위
5. 로컬 작업 상태와 생성된 요약

Stackcord 공통 절차와 이 문서가 충돌하면 공통 절차 자체는 Stackcord가 정본이고, Idea2Strategy의 저장소 역할·문서 소유·이중 구조·로컬 기록은 이 문서가 정본이다. 충돌을 발견한 작업자는 어느 쪽도 임의로 고치지 않고 차이와 영향을 보고한다.

## 2. 규칙 분류

| 범주 | 정본 | 적용 내용 |
| --- | --- | --- |
| Stackcord 공통 규칙 | 설치된 Stackcord 지침, `.harness/entry.md` | 프로젝트 복원, 상태 감사, 경계 간 조정, 실행 계획, 작업 선점, 계약·DBML·UI·통합 검증 |
| Idea2Strategy 추가 규칙 | 이 문서 | GitHub/GitLab 역할 분리, submodule/monolithic 경계, 정책 문서 통제, Jira 로컬 기록, dbdiagram 운영 |
| 로컬 전용 규칙 | `.harness/local/` | 논리적 소유자 대응, 문서 무결성 기준, Jira 누적 기록, 구조 동기화 상태와 하네스별 비공유 상태 |

공통 규칙을 이 문서에 복제하지 않는다. 작업 유형에 맞는 Stackcord 재개·조정·계획 지침을 먼저 적용하고 이 문서의 프로젝트 전용 경계를 추가한다.

## 3. 작업 시작과 계획

1. 루트 저장소를 확인하고 Stackcord 상태·컨텍스트 감사와 실제 Git·submodule 상태를 읽는다.
2. 이 문서의 무결성과 무단 변경 여부를 검사한다.
3. 관련 `specs/`, `contracts/`, 작업 정의와 실제 provider 상태를 읽는다.
4. 공유·장기·교차 저장소 작업은 Stackcord 계획으로 경로와 의미 범위, 소유자, 의존성, 병합 순서와 검증 근거를 정의한다.
5. 선택된 task provider만 실시간 작업 상태를 소유한다. 캐시나 로컬 추정으로 외부 상태를 대신하지 않는다.
6. 원격 write, Issue/Jira 등록, push, 보호 규칙 변경, release는 사용자가 해당 행동을 명시적으로 승인한 경우에만 수행한다.

## 4. 저장소와 원격 역할

### GitHub

- 루트 저장소와 `ui` Git submodule 구조의 정본이다.
- `ui`의 커밋과 루트 submodule 포인터 변경은 별도 검토 대상으로 취급한다.
- GitHub Issues는 TODO·할당·진행 추적용 후보 provider다. 실제 생성·수정·할당은 명시적 요청이 있을 때만 수행한다.
- 현재 로컬 task provider는 Git-local이며, GitHub Issues 전환은 실제 connector 또는 인증 CLI와 사용자 승인이 준비된 뒤 수행한다.

### GitLab

- SSAFY 제출·팀 협업용 monolithic 원격이다.
- 별도 sibling 작업공간과 Git Credential Manager 인증이 구성되어 있다. 구체적인 계정 식별자와 자격 증명은 공유 기록에 남기지 않는다.
- GitLab 구조는 `ui` 콘텐츠를 포함하지만 GitHub 정본 작업공간에서 submodule을 제거하거나 직접 전환하지 않는다.
- 별도 하네스 또는 안전한 작업공간에서 변환하며, 정확한 동기화 방식이 승인되기 전 자동화하지 않는다.
- 자격 증명은 OS 자격 증명 저장소 또는 공식 credential helper만 사용한다.

### 원격별 인증 경계

- GitHub와 GitLab은 서로 다른 사용자일 수 있으며 하나의 논리적 `정책 문서 소유자` 역할로만 연결한다.
- 계정명·이메일·토큰은 이 문서, Jira 기록, 커밋, 로그에 기록하지 않는다.
- 전역 Git 설정을 바꾸지 않는다. 필요한 설정은 저장소·worktree·하네스 작업공간 범위로 제한한다.
- 한 원격의 자격 증명·사용자 설정을 다른 원격에 재사용하지 않는다.

## 5. Git 구조와 추적 관계

- GitHub 작업공간은 현재 submodule 구조를 유지한다.
- GitLab monolithic 작업공간은 별도로 만들며 두 구조를 한 작업 디렉터리에서 전환하지 않는다.
- 두 원격의 커밋 SHA나 브랜치 이력이 동일하다고 가정하지 않는다.
- 논리적으로 같은 변경은 향후 승인될 동기화 기록에서 원본 변경, 대상 변경, 관련 Issue/Jira 키와 검증 결과로 연결한다.
- GitHub 구조를 GitLab에, GitLab monolithic 구조를 GitHub 정본에 잘못 게시하지 않도록 원격·작업공간·submodule 형태 검사를 배포 전 필수로 둔다.
- 최초 monolithic 변환은 검증된 GitHub 루트 커밋과 정확히 일치하는 UI tree를 사용한다. 이후 반복 동기화·충돌·되돌리기 자동화는 별도 설계 전까지 수행하지 않는다.

## 6. Git convention과 Git Flow

- Stackcord가 정한 일반 브랜치·커밋 규칙을 공통 기준으로 참조한다.
- 브랜치는 업무 목적을 나타내고, 커밋은 실제 변경 의미를 나타낸다.
- 브랜치명과 커밋 메시지에 에이전트·모델·자동 생성 표식이나 도구 이름을 넣지 않는다.
- 작업 식별자가 생기면 GitHub Issue 또는 향후 Jira 기록과 연결한다.
- 제품 코드와 이 정책 문서의 변경은 같은 커밋에 섞지 않는다.
- `develop`은 GitHub와 GitLab의 기본 개발·통합 브랜치다. 일반 `feature/*`, `fix/*`, `docs/*`, `chore/*` pull/merge request는 `develop`을 대상으로 한다.
- `main`은 정식 릴리스 전용이다. 첫 제품 변경은 완성된 서비스가 승인된 `v1.0.0` 시점에만 검증된 `develop`에서 `main`으로 반영하고 같은 semantic version 태그를 붙인다.
- `v1.0.0` 이후 긴급 수정은 `hotfix/*`를 `main`에서 분기해 검증 후 `main`과 `develop` 양쪽에 반영한다.
- 호스팅 서비스가 제안하는 기본 대상 브랜치를 그대로 사용하지 않고 작업 성격과 이 규칙을 먼저 확인한다.

## 7. 공식 협업 정책 변경 통제

- 일반 참여자와 일반 자동화 작업은 이 문서를 읽을 수 있지만 직접 수정하지 않는다.
- 변경이 필요하면 로컬 Jira 형식 또는 선택된 task provider에 별도 변경 요청을 기록한다.
- 최초 생성자에 연결된 권한 있는 `정책 문서 소유자`가 승인한 전용 작업에서만 수정한다.
- 논리적 소유자 대응과 승인 상태는 Git에서 제외된 로컬 메타데이터에만 둔다. 비밀번호·토큰·세션·개인키·복구 코드는 어느 로컬 메타데이터에도 저장하지 않는다.
- 변경 작업은 이유·영향·승인 근거를 이 문서의 변경 이력에 추가하고 제품 코드 변경과 분리한다.
- 무단 변경이나 무결성 차이를 발견하면 관련 작업을 중단하고 정본과의 차이를 보고한다.
- 자동 포맷터가 이 문서를 일괄 재작성하지 않게 한다.

이 규칙은 로컬 검증만으로 절대적인 수정 방지를 보장하지 않는다. 실제 강제에는 아래 원격 보호와 CI가 필요하다.

### 제품 권한과 확정 원본 수정 차단

- Stackcord 제품 권한 검사를 활성화하며 선택 provider는 GitHub, 기준 저장소는 `Idea2Strategy/Idea2Strategy`, 권한자는 `user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`이다.
- `.harness/governance.yaml`, `specs/**`, `contracts/**`, 이 문서와 차단 규칙을 집행하는 파일을 수정하기 전에 `stackcord governance check --json`을 실행한다.
- 정확한 저장소·HEAD 커밋·보호 의미 fingerprint에 대해 구성된 권한자(`user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`)를 승인자로 확인한 fresh provider 관찰만 확정 원본 수정을 허용한다.
- 세 권한자는 동등하다. 권한 범위는 `protected_kinds` 전체(`product`, `policy`, `business`, `contract`)이며 kind별·영역별 제한을 두지 않는다. `approval.minimum: 1`과 `authority_self_approval: true`이므로 각 권한자는 단독 자기 승인으로 확정 원본 변경을 승인할 수 있다.
- 저장소 협력자 권한과 제품 권한은 별개다. `user:Juwon-Na`는 GitHub `write` 권한만 보유하므로 PR 승인은 가능하지만 branch protection 등 저장소 설정은 변경할 수 없다.
- 관찰이 없거나 stale·unknown·unavailable이거나 다른 subject이면 작업자는 must not edit 원칙에 따라 확정 원본을 수정하지 않는다. 별도 격리 제안은 만들 수 있지만 승인·통합·릴리스된 변경으로 표현하지 않는다.
- Git user.name and user.email never prove authority. 알려진 이메일은 로컬 연락 메타데이터일 뿐 권한 판정에 사용하지 않는다.
- GitLab monolithic 저장소도 별도의 GitLab 사용자에게 제품 권한을 부여하지 않고 위 GitHub 권한을 동일하게 따른다.

## 8. 보호 계층과 현재 적용 상태

| 계층 | 필요한 통제 | 현재 상태 |
| --- | --- | --- |
| 로컬 | 필수 읽기 진입점, ignore 검증, 정책 해시·변경 감지, 민감정보 패턴 검사 | 이번 검토본에 구성 |
| GitHub | 보호 브랜치, 정책 경로 CODEOWNERS 승인, 필수 상태 검사, 직접 push 제한 | 미적용·사용자 승인 필요 |
| GitLab | protected branch, CODEOWNERS/approval rule, 필수 pipeline, 직접 push 제한 | 원격 구성·보호 규칙 미적용 |
| CI/검토 | 정책 변경 전용 검사, 승인 소유자 검증, 제품 변경과 정책 변경 혼합 차단 | 미구현 |
| 조직 권한 | GitHub/GitLab의 실제 정책 소유자 계정 매핑과 최소 권한 | Stackcord 권한자는 `user:kcrmin`·`user:pjy008008`·`user:Juwon-Na`로 구성, fresh provider 승인 관찰은 아직 없음 |

원격 보호를 적용하기 전에는 누구도 정책 문서가 기술적으로 변경 불가능하다고 주장하지 않는다.

## 9. Jira 로컬 기록

- Jira에는 자동 등록하지 않는다.
- 프로젝트 누적 기록은 Git에서 제외된 `.harness/local/project/jira/project-log.yaml`에 둔다.
- 하네스별 임시 상태와 프로젝트 전체 누적 기록을 분리하며 임시 폴더 삭제가 누적 기록을 지우지 않게 한다.
- 작업·체크리스트·담당 역할·할당/시작/완료 시각·상태·브랜치·커밋·GitHub Issue·근거와 비고를 기록한다.
- 계정 식별자와 인증 정보는 기록하지 않는다.
- Jira 프로젝트 키·실제 담당자·일정은 사용자가 지정하기 전 만들지 않는다.
- 사용자가 요청하면 누적 기록에서 Jira 이전용 문서를 생성하되 실제 등록은 별도 승인 작업으로 수행한다.

## 10. DBML과 dbdiagram 보류 정책

- `db/schema.dbml`이 데이터 모델의 Git 정본이고 dbdiagram은 시각화·협업 제안 도구다.
- 사용자의 현재 결정에 따라 DBML의 의미 변경은 보류한다. 보류 해제 전에는 테이블·열·관계·인덱스·note를 변경하거나 dbdiagram 변경을 정본에 적용하지 않는다.
- dbdiagram은 현재 로컬에서 인증된 정책 문서 소유자 관리 계정으로 운영한다. 구체적인 계정 식별자는 공유 문서에 기록하지 않는다.
- 온라인 변경은 격리된 proposal로 pull하고 의미 diff·계약·migration·test·rollback 영향을 검토한 뒤에만 Git 정본 변경 후보가 된다.

## 11. 로컬 비공유 영역

`.harness/local/`은 프로젝트 전체의 지속적인 로컬 운영 영역이다. 모든 clone은 `README.md`와 정확한 `.gitkeep` 표식으로 같은 골격을 공유하지만, 그 밖의 실제 내용은 Git에서 제외한다. `scripts/initialize-local-harness.ps1`이 골격을 복원하고 경계를 검증한다. 다음만 저장한다.

- 원격별 논리적 소유자 대응과 검증 상태
- 정책 문서 소유자·무결성 메타데이터
- Jira 누적 작업 기록
- 하네스별 로컬 작업 참조
- GitHub submodule과 향후 GitLab monolithic 구조의 동기화 상태
- 비밀이 아닌 검증 해시와 시각

토큰·비밀번호·세션 쿠키·개인키·복구 코드·원격 인증 원문은 저장하지 않는다. 생성물은 `.harness/local/artifacts/`, 임시 파일은 `.harness/local/tmp/`, 캐시는 `.harness/local/cache/`, 로그는 `.harness/local/logs/`에 둔다. 실제 내용은 `.gitignore`로 제외하며 검증 스크립트로 ignore와 추적 allowlist를 확인한다.

## 12. 배포 전후 운영

사용자는 2026-07-22 검토본과 로컬 하네스 구조의 배포를 승인했다. 배포는 검증된 GitHub 후보를 먼저 게시한 뒤 그 정확한 커밋으로 별도 GitLab monolithic 작업공간을 만드는 순서로 진행한다. GitHub Issue/Jira 등록과 원격 보호 규칙 변경은 여전히 별도 승인 없이는 수행하지 않는다.

배포 뒤 모든 작업자는 같은 커밋의 이 문서를 읽어야 한다. 정책 변경 요청과 일반 제품 작업을 분리하고, Stackcord 복원 시 이 문서의 존재·무결성·Git 상태를 함께 확인한다.

## 13. 미결정 사항

- 최초 변환 이후 submodule 변경을 GitLab monolithic 구조에 반복 동기화하는 자동화·충돌·rollback 방식
- GitHub Issues를 Stackcord의 실시간 task provider로 전환하는 시점
- GitHub `user:kcrmin`·`user:pjy008008`·`user:Juwon-Na`의 fresh provider 승인 관찰과 GitHub/GitLab 원격 보호 설정
- `Pearwon99`가 `user:Juwon-Na`의 GitLab 계정인지 확인. GitHub에는 존재하지 않는 식별자이므로 제품 권한에는 사용하지 않는다.
- Jira 프로젝트 키·실제 담당자·일정

## 14. 변경 이력

| 날짜 | 상태 | 변경 이유 | 승인 근거 |
| --- | --- | --- | --- |
| 2026-08-02 | 제품 권한자 추가 | `user:Juwon-Na`(구성원 A, 계정·운영)를 세 번째 동등 권한자로 등록하고 `protected_kinds` 전체 권한을 부여. 사용자가 함께 제시한 `Pearwon99`는 GitHub에 존재하지 않아(404) 사용하지 않았다. 영향: 단독 자기 승인이 가능한 권한자가 셋으로 늘어남 | 권한자 `user:kcrmin`이 현재 세션에서 명시적으로 추가를 지시. `user:Juwon-Na`의 GitHub 협력자 권한은 `write`로 확인되어 PR 승인이 가능하다. 근거 문서: `proposals/product-authority/product-authority-expansion.v1.md` |
| 2026-08-02 | 제품 권한자 추가 | `user:pjy008008`(구성원 C, 시장·평가)을 `user:kcrmin`과 동등한 제품 권한자로 등록하고 `protected_kinds` 전체에 대한 권한을 부여. 영향: 보호 정본 승인 경로가 둘로 늘어나며 `approval.minimum: 1`·`authority_self_approval: true` 하에서 각 권한자가 단독 자기 승인 가능 | 권한자 `user:kcrmin`이 현재 세션에서 명시적으로 추가를 지시하고 정본 반영을 승인. 근거 문서: `proposals/product-authority/product-authority-expansion.v1.md`. 주의: `stackcord governance check --json`은 여전히 `unknown`이며 fresh provider 승인 관찰은 아직 없음 |
| 2026-07-22 | 제품 권한 governance 활성화 | GitHub `user:kcrmin`만 확정 제품·정책·비즈니스·계약 변경을 승인할 수 있게 하고, 다른 사용자는 격리 제안만 만들도록 사전 차단 규칙을 추가 | 사용자가 권한 계정과 로컬 연락 이메일을 명시하고 설계 검토 후 진행 승인 |
| 2026-07-22 | Git Flow 정정 | 양쪽 기본 개발 브랜치를 `develop`으로 통일하고 `main`을 `v1.0.0`부터의 정식 릴리스 전용으로 제한 | 사용자의 명시적 정정 및 진행 승인 |
| 2026-07-22 | GitHub·GitLab 배포 | GitHub submodule 기준선과 별도 GitLab monolithic 기준선을 검증된 커밋으로 게시 | 사용자의 명시적 진행 요청; 로컬·DBML·UI tree 검증 통과 |
| 2026-07-22 | 배포 승인·구현 중 | 로컬 운영 영역을 `.harness/local/`로 통합하고 GitLab 저장소·인증·별도 monolithic 작업공간 경계를 확정 | 사용자의 A 구조 선택과 명시적 진행 요청 |
| 2026-07-22 | 배포 전 검토본 생성 | GitHub submodule·향후 GitLab monolithic 구조와 Stackcord 기반 협업을 하나의 정책으로 통합 | 현재 세션의 명시적 사용자 요청; 원격 소유권·보호 설정은 아직 검증·적용하지 않음 |
