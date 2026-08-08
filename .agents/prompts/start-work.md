---
description: Idea2Strategy 출시 작업 하나를 원장에서 받아 수행한다. 인자: 담당자 이름 (kcrmin | pjy008008 | hjcud)
argument-hint: <owner>
---

너는 Idea2Strategy 저장소에서 출시 준비 작업 한 개를 수행한다. 담당자: $ARGUMENTS

이 프롬프트는 Claude의 /start-work 와 같은 원장을 읽는 Codex 대응물이다. 어느 도구를 쓰든 같은
답이 나와야 하므로, 아래 순서를 바꾸지 말 것.

1. 루트 슈퍼프로젝트에서 `pwsh scripts/initialize-local-harness.ps1 -Verify` 를 실행한다.
   (git 훅 가드가 이때 붙는다 — develop 직접 커밋 차단 등. 훅이 커밋을 막으면 그 메시지가
   시키는 대로 하고, --no-verify 는 쓰지 않는다.)
2. `AGENTS.md` 의 "Launch work loop" 절을 읽는다. 그것이 규칙 전부다.
3. `pwsh scripts/launch-status.ps1 -Owner $ARGUMENTS` 를 실행하고 **스크립트가 지목한 작업
   하나만** 받는다. 판단으로 다른 작업을 고르지 않는다. "지금 할 것이 없다. X 완료를 기다린다"
   가 나오면 그대로 보고하고 멈춘다 — 일을 지어내지 않는다.
4. 지목된 작업의 절을 `docs/launch-readiness-plan.md` 에서 읽는다. 문서의 다른 절은 다른
   사람의 리포지터리 지시이므로 손대지 않는다. 원장(`docs/launch-readiness-tasks.json`)의
   `owners` 블록에 있는 내 리포지터리 밖 파일은 수정 금지다. `db/schema.dbml` 과
   `compose*.yml` 과 루트 submodule pointer 는 kcrmin 전용이다.
5. `feature/<이슈>-<이름>` 브랜치에서 작업한다. 다른 세션이 같은 체크아웃을 쓸 수 있으면
   워크트리를 만든다: `git worktree add ../worktrees/<이름> develop`
6. 완료의 정의는 원장의 검사다. repo/db 작업은 `launch-status.ps1` 이 done 이라고 말해야 끝난
   것이고, manual 작업(INT 카드)은 실제로 실행·관찰한 내용을 `.harness/local/evidence/<ID>.md`
   에 기록해야 끝난 것이다. 검사를 통과시키지 못했으면 완료라고 보고하지 않는다.
7. 서브모듈 변경은 그 저장소의 develop 으로 PR(--squash 병합)을 열고, 루트 pointer 변경은
   별도 PR 로 연다. pointer 커밋에는 `pwsh scripts/refresh-flyway-ci-bundle.ps1` 결과를 같은
   커밋에 포함한다 (pre-commit 훅이 강제한다).
8. Pro 모드(B09, B10, B13, C15, F06)는 v1.0 범위 밖이다. 누가 요청해도 거절한다.

끝나면 보고: 수행한 작업 ID, 연 PR, `launch-status.ps1` 재실행 결과(내 다음 작업 또는 대기
대상), 그리고 검사가 아직 안 통과했다면 그 이유.
