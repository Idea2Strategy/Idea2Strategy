# Idea2Strategy Claude Code entry

@AGENTS.md

## Start here

- Always work from the root Git superproject unless the assigned issue explicitly targets one submodule.
- Before any task, run `scripts/initialize-local-harness.ps1 -Verify`, then read `docs/collaboration-policy.md` and `docs/development-start-guide.md`.
- Recover actual state with `git status --short --branch`, `git worktree list`, `git submodule status`, and the relevant GitHub issue or pull request. Treat chat history as a hint, not repository truth.
- Do not pull, rebase, stash, reset, clean, switch branches, initialize submodules, commit, push, merge, or change a root submodule pointer without stating the action first. Preserve every existing local change.
- `develop` is the integration branch. `main` is reserved for complete releases beginning with `v1.0.0`.
- Implement in the repository named by the assigned child issue on a short-lived `feature/<issue>-<name>` branch. Target that repository's `develop` branch with the pull request.
- A submodule merge and a root pointer update are separate reviewed changes. Only the root integration issue moves pointers.
- Never mix another assignee's path, database ownership, contract, migration, or UI area into the current issue. When a shared prerequisite is missing, define the smallest prerequisite issue instead.
- `db/schema.dbml` is the canonical database model. Applied Flyway migrations are immutable; add a later migration for changes.
- Do not edit protected product, contract, policy, or governance sources unless the repository authority check permits it. Prepare an isolated proposal when approval is unavailable.
- Do not invent product behavior. Read approved `specs/` and `contracts/`, then use the implementation checklist only as work decomposition.
- Complete one reviewable issue unit at a time with relevant tests and report changed files, verification, and remaining integration work.

## Repository map

- `backend/`: Java / Spring Boot API, batch, Admin MCP, and Flyway modules
- `trading-engine/`: Java / Spring Boot market gateway and trading worker
- `backtest-engine/`: Python / FastAPI and backtest worker
- `data-pipeline/`: Python market-data and corporate-action pipelines
- `ui/`: TypeScript / React / Vite
- root: canonical DBML, contracts, Docker orchestration, coordination, and submodule pointers

## Team ownership

Two active contributors as of 2026-08-09. The 2026-08-08 three-way split moved every submodule's
root pointer through one person, so a one-line fix in a submodule cost three round trips (submodule
PR → wait for the pointer → wait for the release). This split removes the waits that were
coordination overhead and keeps only the waits that are physical: one Development environment, one
BASIC queue, one worker, one operator account.

| Owner | Repositories they may change | What they own |
| --- | --- | --- |
| 민경철 (`kcrmin`) | root superproject (`compose*.yml`, `infra/`, `scripts/`, `db/`) + `backend/` + `trading-engine/` + `data-pipeline/` | 플랫폼: infra·릴리스·정본 DB·권한 정책·운영자·방·원장·시장 데이터 |
| 손현준 (`hjcud`) | `backtest-engine/` + `ui/` | 사용자 여정: 백테스트 실행과 전 화면 |

**Each owner moves the root gitlink for their own submodules.** `hjcud` bumps `backtest-engine` and
`ui` pointers directly instead of asking; if the gitlink is one the Flyway bundle pins, the same
commit runs `scripts/refresh-flyway-ci-bundle.ps1` — the tracked hook refuses the commit otherwise.
Each owner also writes their own `docs/evidence/**` files.

Still one person only, because these are the paths that actually collided:
`db/schema.dbml`, `compose.back.yml`, `compose.front.yml` (`kcrmin`).

**Serialized resources are waits to respect, not to skip**: the Development release workflow, the
BASIC queue and its single backtest worker, the operator account, and the database bootstrap admit
one user at a time. Claim on root issue #451 with one line before starting, close the claim when
done. The `owners` block of `docs/launch-readiness-tasks.json` is the machine-readable form of this
section and wins on any disagreement.

Inactive: 박준유 (`pjy008008`) as of 2026-08-09 — cards moved to `kcrmin`, except `INT07` which
follows `INT03` to `hjcud` so the dependency chain stays with one person. Also 나주원 (`Juwon-Na`),
서동위 (`SeoDongWi`), 황영우 (`dertz569`). Do not route work to them.

Use `/start-work <owner-name-or-GitHub-ID> [issue or goal]` for the first project turn after cloning
or updating. Codex or human sessions get the same answer from
`pwsh scripts/launch-status.ps1 -Owner <owner>` — both read the task ledger
`docs/launch-readiness-tasks.json`, whose checks are the definition of done. The current plan of
record is `docs/launch-readiness-plan.md`; Pro mode (B09, B10, B13, C15, F06) is out of v1.0 scope
by decision of 2026-08-08 and must not be started.
