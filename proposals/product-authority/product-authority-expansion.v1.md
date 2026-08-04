---
schema_version: 1
id: decision.governance.product-authority-expansion
kind: decision
status: applied-by-authority-instruction
revision: 3
refs:
  - docs/superpowers/specs/2026-07-22-product-authority-governance-design.md
  - docs/collaboration-policy.md
  - .harness/governance.yaml
---

# decision.governance.product-authority-expansion

`user:pjy008008`, `user:Juwon-Na`, `user:Pearone99`를 `user:kcrmin`과 함께 제품
권한자(product authority)로 추가하는 제안이다.

2026-08-02 권한자 `user:kcrmin`의 명시적 지시로 2절 변경 집합을 작업 트리에 반영했다.
`stackcord governance check --json`은 여전히 `unknown`이며 fresh provider 승인 관찰은
존재하지 않는다. 따라서 이 변경은 아직 승인·통합·릴리스된 변경이 아니고,
GitHub PR에서 정확한 head 커밋과 보호 fingerprint에 대한 권한자 승인을 받아야 한다.

- 상태: 권한자 지시로 작업 트리 반영 — provider 승인 관찰은 미확보
- 작성일: 2026-08-02
- 기준 저장소: `Idea2Strategy/Idea2Strategy`
- 기준 브랜치: `develop`
- 기준 커밋: `f803fe907dbd7a393c15977e23ffe45bf89ce53b` (`f803fe9`)
- 기준 Stackcord 보호 fingerprint: `sha256:65b40c52947bc8530e1fe224bea9e5b0c9914fb6d33c366c2fcccc7f685b4736`
- 요청 시점 `stackcord governance check --json` 결과: `status: unknown`, exit 6,
  blocker `governance.approval-unknown` — fresh provider 관찰 없음

## 1. 요청과 차단 사유

요청은 "프로젝트 결정권자에 `pjy008008`과 `Juwon-Na`를 추가 등록"이다. 두 계정은
`CLAUDE.md`의 팀 소유권 목록에 이미 있는 구성원 C 박준유 (`pjy008008`)와
구성원 A 나주원 (`Juwon-Na`)이다.

두 번째 요청에 함께 제시된 `Pearwon99`는 GitHub API에서 404를 반환했다. 권한자가
이후 오타를 정정해 실제 식별자가 `Pearone99`임을 확인했고, 이 계정은 GitHub에
존재하며 계정 이름이 "Juwon Na"로 `Juwon-Na`와 동일인의 다른 계정이다.

따라서 등록 항목은 넷이지만 실질 권한자는 셋이다. `minimum: 1`에서는 한 사람이 두
계정을 갖는 것이 승인 정족수를 실질적으로 늘리지 않는다.

`Pearone99`의 저장소 접근 권한은 `none`이다. governance 등록은 승인을 인정하는
조건일 뿐이므로, 협력자로 초대되기 전에는 이 계정으로 PR을 승인할 수 없고
fresh provider 관찰도 생기지 않는다.

`.harness/governance.yaml`은 보호 정본이며, `AGENTS.md`와
`docs/collaboration-policy.md` 7절의 canonical-write gate는 fresh provider 관찰이
`user:kcrmin`을 승인자로 확인할 때만 수정을 허용한다. 현재 관찰은 `unknown`이므로
must not edit 원칙에 따라 정본을 수정하지 않고 이 제안만 작성한다.

권한 목록 확장 자체가 신뢰 모델 변경이므로, 현재 권한자의 명시적 승인 없이
자기 승인 경로를 늘리는 편집은 gate가 열려 있어도 별도 승인 대상이다.

## 2. 승인 시 적용할 정확한 변경 집합

### 2.1 GitHub 정본 governance

`.harness/governance.yaml`

```yaml
product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:Pearone99]
```

### 2.2 GitLab monolithic 미러 governance

`docs/collaboration-policy.md`는 GitLab 미러가 동일한 GitHub 권한을 따르도록 요구한다.
따라서 `Idea2Strategy-gitlab/.harness/governance.yaml`도 같은 값으로 함께 변경한다.
두 구성이 갈라지면 검증이 실패하고 후보를 게시하지 않는다.

### 2.3 검증 스크립트의 기대 리터럴

두 검증기는 `product_authorities: [user:kcrmin]`을 부분 문자열로 단정한다.
값이 바뀌면 그대로 실패하므로 함께 갱신해야 한다.

- `scripts/verify-collaboration-policy.ps1:68`
- `scripts/verify-foundation-evidence.mjs:132`

두 곳 모두 기대값을 `product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:Pearone99]`로 바꾼다.
정렬 순서 변화에 취약한 완전 문자열 비교 대신 두 권한자를 각각 확인하는 검사로
바꾸는 편이 안전하다.

### 2.4 로컬 권한 메타데이터

`scripts/verify-foundation-evidence.mjs:137`은 Git에서 제외된
`.harness/local/project/policy/owner.yaml`에 `provider_authority: user:kcrmin`이
있어야 한다고 단정한다. 단일 값 스키마이므로 다음 중 하나를 정해야 한다.

1. `provider_authority`를 단일 값으로 유지하고 목록 필드를 추가한다.
2. 필드를 복수형 목록으로 바꾸고 검증기와 `scripts/initialize-local-harness.ps1`의
   생성 로직을 함께 갱신한다.

이 파일은 Git에서 제외되므로 각 개발자 머신에서 재초기화가 필요하다.

### 2.5 단일 권한자를 단정하는 문서

다음 문장들은 "유일한 권한자" 전제를 담고 있어 복수 권한자와 모순된다.

- `docs/collaboration-policy.md:99` — "유일한 권한자는 `user:kcrmin`이다"
- `docs/collaboration-policy.md:101`, `:114`
- `docs/superpowers/specs/2026-07-22-product-authority-governance-design.md:5`, `:15`, `:18`
- `AGENTS.md` — "approved authority of `user:kcrmin`"
- `.agents/skills/use-project-harness/SKILL.md:16`
- `.agents/skills/use-project-harness/references/fallback.md:11`

`verify-collaboration-policy.ps1:85-91`은 위 네 개 규칙 파일에 리터럴
`user:kcrmin`이 남아 있기를 요구한다. 따라서 `user:kcrmin`을 지우지 않고
"승인된 권한자 중 하나(`user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`, `user:Pearone99`)"로
확장 서술한다. 검증기에도 두 신규 권한자 리터럴 요구를 추가하면 문서와 구성이
함께 유지된다.

`docs/collaboration-policy.md`는 7절 자체 규칙에 따라 정책 문서 소유자가 승인한
전용 작업에서만 수정하고, 변경 이력에 이유·영향·승인 근거를 남기며 제품 코드
변경과 분리한다. 이 문서는 `verify-foundation-evidence.mjs`의 sha256 무결성
기준과 묶여 있으므로 수정 후 로컬 기준을 재생성해야 한다.

## 3. 승인 정족수 영향

권한자 지시에 따라 `approval.minimum: 1`과 `authority_self_approval: true`를 유지한다.
따라서 두 권한자는 각자 단독 자기 승인으로 보호 제품 의미를 확정할 수 있다.
이중 확인(`minimum: 2`)은 채택하지 않았다.

권한 범위도 축소하지 않는다. `user:pjy008008`·`user:Juwon-Na`·`user:Pearone99`는 `user:kcrmin`과 동등하며
`protected_kinds` 전체(`product`, `policy`, `business`, `contract`)를 승인할 수 있다.
현재 Stackcord 구성은 kind별 권한 분리를 표현하지 않으므로 이 결정은
구성과도 일치한다.

## 4. 적용 절차

1. `user:kcrmin`이 이 제안을 검토하고 3절 정족수 항목을 결정한다.
2. `feature/<issue>-product-authority-expansion` 브랜치에서 2절 변경만 수행하고
   제품 코드 변경을 섞지 않는다.
3. `scripts/verify-collaboration-policy.ps1`,
   `scripts/verify-foundation-evidence.mjs`, `scripts/test-local-harness.ps1`를
   실행해 통과를 확인한다.
4. GitHub PR에서 정확한 head 커밋과 보호 fingerprint에 대해 `user:kcrmin`의
   승인을 받고 `stackcord governance check --json`이 `approved`를 보고하는지
   확인한다.
5. `develop` 병합 후 GitLab 미러 구성을 동일하게 반영한다.
6. 각 개발자 머신에서 `scripts/initialize-local-harness.ps1 -Verify`로 로컬
   권한 메타데이터를 재생성한다.

## 5. 미해결 확인 사항

- 협력자 권한 확인 완료: `pjy008008`은 `admin`, `Juwon-Na`는 `write`, `Pearone99`는
  `none`이다. 앞의 둘은 PR 승인이 가능하다. `write`는 branch protection 등 저장소 설정
  변경 권한을 포함하지 않는다.
- `user:Pearone99`을 협력자로 초대할지, 초대한다면 어느 권한 수준을 부여할지 결정이
  필요하다. 초대 전에는 등록만 되어 있고 승인에 사용할 수 없다.
- 나주원이 `user:Juwon-Na`와 `user:Pearone99` 중 어느 계정을 상시 사용할지 정하면
  나머지 한 항목은 등록에서 제거하는 편이 권한 표면을 줄인다.
- `scripts/verify-foundation-evidence.mjs`는 이 머신에 Node.js가 없어 로컬에서
  실행하지 못했다. CI에서 처음 검증된다.
- `worktrees/com07-root`는 별도 브랜치 워크트리이므로 이 변경을 반영하지 않았다.
  해당 브랜치가 `develop`을 병합할 때 함께 반영된다.

## 6. Revision 2 — `user:hjcud` 추가 (2026-08-04)

권한자 `user:kcrmin`이 "나주원, 박준유, 손현준을 나와 완전히 동일한 권한(서비스
방향성 변경 가능)으로 승격"을 지시했다. `user:Juwon-Na`(나주원)와
`user:pjy008008`(박준유)은 revision 1에서 이미 등록되어 정본에 반영되어 있으므로,
실제 변경 집합은 **`user:hjcud`(구성원 B 손현준, 전략·봇) 한 명 추가**다.

- 기준 브랜치: `chore/product-authority-hjcud` (기점 `develop` = `fdb8802`)
- 이 시점 `stackcord governance check --json`: `status: unknown`, exit 6,
  blocker `governance.approval-unknown` — `.harness/local/governance` 관찰 부재.
  `scripts/initialize-local-harness.ps1 -Verify`는 통과했으나 이 디렉터리는
  실제 provider 승인 관찰로만 생성되므로 gate는 여전히 닫혀 있다.
- 따라서 이 변경은 승인·통합·릴리스된 변경이 **아니다**. GitHub PR에서 정확한 head
  커밋과 보호 fingerprint에 대해 권한자 승인을 받아야 정본이 된다.

### 6.1 확인된 협력자 권한 (2026-08-04)

revision 1 §5의 값이 이후 변경되었으므로 함께 정정했다.

| 계정 | revision 1 | 2026-08-04 확인 | PR 승인 가능 |
| --- | --- | --- | --- |
| `user:kcrmin` | `admin` | `admin` | 가능 |
| `user:pjy008008` | `admin` | `admin` | 가능 |
| `user:Juwon-Na` | `write` | `admin` | 가능 |
| `user:Pearone99` | `none` | `read` | **불가** |
| `user:hjcud` | 미등록 | `admin` | 가능 |

`user:hjcud`는 GitHub에서 이미 `admin`이므로 등록 즉시 승인에 사용할 수 있다.
`user:Pearone99`는 `read`로 승격되었으나 `read`는 PR 승인 권한을 포함하지 않아
여전히 승인에 사용할 수 없다.

### 6.2 정족수 영향

`approval.minimum: 1`과 `authority_self_approval: true`를 권한자 지시대로 유지한다.
등록 항목은 다섯이지만 `user:Juwon-Na`·`user:Pearone99`가 동일인이므로 실질 권한자는
넷(민경철·박준유·나주원·손현준)이며, 각자 단독 자기 승인으로 `protected_kinds`
전체를 확정할 수 있다. 이중 확인(`minimum: 2`)은 채택하지 않았다.

### 6.3 변경 파일

`.harness/governance.yaml`, `AGENTS.md`,
`.agents/skills/use-project-harness/SKILL.md`,
`.agents/skills/use-project-harness/references/fallback.md`,
`scripts/initialize-local-harness.ps1`, `scripts/test-local-harness.ps1`,
`scripts/verify-collaboration-policy.ps1`, `scripts/verify-foundation-evidence.mjs`,
`docs/collaboration-policy.md`,
`docs/superpowers/specs/2026-07-22-product-authority-governance-design.md`,
이 문서.

`docs/prompts/stackcord-pre-mutation-governance.md:32-33`의 `user:kcrmin` 언급은
프롬프트 내 acceptance example이고 검증기 요구 목록에 없어 revision 1과 동일하게
갱신하지 않았다.

GitLab 미러(`Idea2Strategy-gitlab/.harness/governance.yaml`)는 §4 절차 5단계에
따라 `develop` 병합 후 반영한다.

### 6.4 검증 공백 — §5의 서술 정정

revision 1 §5는 `scripts/verify-foundation-evidence.mjs`가 "CI에서 처음 검증된다"고
기록했으나 이는 사실이 아니다. 그런 CI 단계는 존재하지 않는다.

`.github/workflows/ci.yml`의 `schema-and-coordination` 잡은 Node 24를 설치하지만
`pnpm dbml:validate*`, `pnpm dbml:export:test`, `git diff --check HEAD^`,
submodule 포인터 검사만 실행한다. `verify-foundation-evidence.mjs`,
`verify-collaboration-policy.ps1`, `test-local-harness.ps1` 중 어느 것도 CI에서
호출되지 않는다. 이 머신에는 Node.js·pnpm·npm·bun·deno가 모두 없어 로컬 실행도
불가능하다.

따라서 `verify-foundation-evidence.mjs`의 기대 리터럴 변경(132·137·146행)은
자동 검증 없이 육안 검토에만 의존한다. governance 검증기를 CI에 연결하는 작업은
이 권한 변경과 분리된 별도 이슈로 다룬다.

## 7. Revision 3 — `user:Pearone99` 제거와 검증기 CI 연결 (2026-08-04)

`revision: 3`. 권한자 `user:kcrmin`의 지시로 두 가지를 함께 수행했다.

### 7.1 `user:Pearone99` 제거

```yaml
product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:hjcud]
```

이 계정은 나주원의 보조 계정이므로 `minimum: 1`에서 실질 권한자 수를 늘리지
않았고, 협력자 권한이 `read`여서 PR 승인에도 사용할 수 없었다. 즉 승인 능력은
없이 권한 표면만 넓히는 항목이었다. 제거 후 등록 항목 4개가 실제 인원 4명과
1:1로 대응한다.

- 민경철 `user:kcrmin` (admin)
- 박준유 `user:pjy008008` (admin)
- 나주원 `user:Juwon-Na` (admin)
- 손현준 `user:hjcud` (admin)

네 계정 모두 `admin`이라 전원 PR 승인이 가능하다. revision 1 §5와 revision 2
§6.1의 "나주원이 어느 계정을 상시 사용할지 정해야 한다"는 미결정 항목은 이
제거로 해소되었고 `docs/collaboration-policy.md` 13절에서 삭제했다.

### 7.2 §6.4 검증 공백 해소

§6.4가 기록한 공백을 새 스크립트 없이 기존 검증기를 CI에 연결해 닫았다.
`.github/workflows/ci.yml`의 `schema-and-coordination` 잡에 네 단계를 추가했다.

```yaml
- name: Initialize local harness
  shell: pwsh
  run: ./scripts/initialize-local-harness.ps1 -Verify
- name: Verify collaboration policy and product authorities
  shell: pwsh
  run: ./scripts/verify-collaboration-policy.ps1
- name: Verify governance foundation evidence
  run: node scripts/verify-foundation-evidence.mjs policy
- name: Test local harness
  shell: pwsh
  run: ./scripts/test-local-harness.ps1
```

성립 근거:

- `initialize-local-harness.ps1`의 `Initialize-TrackedPolicyIntegrity`(59-82행)가
  Git 제외 대상인 `owner.yaml`과 `integrity.json`을 체크아웃된 트리에서 생성한다.
  fresh runner에는 두 파일이 없으므로 생성 조건이 성립하고, 해시는 CI가 체크아웃한
  정책 파일에서 계산되어 자기 일관적으로 일치한다. 줄바꿈 정규화 차이에 영향받지 않는다.
- `verify-foundation-evidence.mjs`는 mode 인자를 받으며 권한자 단정은 `policy`
  모드(`verifyPolicy`)에 있다.
- `test-local-harness.ps1`은 `git init`과 `check-ignore`만 사용하고 커밋하지
  않으므로 runner의 git identity 설정이 필요 없다.
- `ubuntu-latest` runner에는 `pwsh`가 사전 설치되어 있고, 잡은 이미 Node 24를
  설치한다.

이제 `.harness/governance.yaml`의 권한자 목록이 4개 스크립트의 기대 리터럴이나
4개 규칙 문서(`AGENTS.md`, SKILL, fallback, `docs/collaboration-policy.md`)와
갈라지면 CI가 실패한다. revision 1·2에서 발생한 종류의 drift가 자동 검출된다.

### 7.3 변경 파일

`.harness/governance.yaml`, `.github/workflows/ci.yml`, `AGENTS.md`,
`.agents/skills/use-project-harness/SKILL.md`,
`.agents/skills/use-project-harness/references/fallback.md`,
`scripts/initialize-local-harness.ps1`, `scripts/test-local-harness.ps1`,
`scripts/verify-collaboration-policy.ps1`, `scripts/verify-foundation-evidence.mjs`,
`docs/collaboration-policy.md`,
`docs/superpowers/specs/2026-07-22-product-authority-governance-design.md`(34·51행
포함), 이 문서.

`docs/collaboration-policy.md` 14절의 2026-08-02 이력 행에 남은 `user:Pearone99`
언급은 당시 사실 기록이므로 수정하지 않았다. revision 1·2 본문도 같은 이유로
보존했다.
