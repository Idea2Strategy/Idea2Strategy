# Idea2Strategy Claude Code entry

@AGENTS.md

## Start here

- Always work from the root Git superproject unless the assigned issue explicitly targets one submodule.
- Before any task, run `scripts/initialize-local-harness.ps1 -Verify`, then read `.harness/entry.md`, `docs/collaboration-policy.md`, and `docs/development-start-guide.md`.
- Recover actual state with `stackcord status --json`, `git status --short --branch`, and `git submodule status`. Treat chat history as a hint, not repository truth.
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

Three active contributors as of 2026-08-08. **Ownership is by repository**, because that is what
keeps two people out of one file. The A–F area letters still label issues and epics, so each owner
inherits whole areas rather than parts of them.

| Owner | Repositories they may change | Areas inherited |
| --- | --- | --- |
| 민경철 (`kcrmin`) | root superproject (`compose*.yml`, `infra/`, `scripts/`, `db/`, submodule pointers) + `backend/` | A 계정·운영, B 전략·봇(backend), E 방·성과 |
| 박준유 (`pjy008008`) | `data-pipeline/` + `trading-engine/` | C 시장·평가, D 데이터(수집·기업행사), F 거래·원장 |
| 손현준 (`hjcud`) | `backtest-engine/` + `ui/` | D 백테스트, 전 영역의 UI |

Area D is split by repository on purpose: `data-pipeline` and `backtest-engine` are separate
repositories, so the split creates no file contention. Name the repository, not the letter, when the
two disagree.

`db/schema.dbml`, `compose.back.yml` and root submodule pointers are changed by `kcrmin` only.
Anyone else who needs one asks. These are the three places where concurrent work actually collided.

Inactive: 나주원 (`Juwon-Na`), 서동위 (`SeoDongWi`), 황영우 (`dertz569`). Their areas are
redistributed above. Do not route work to them.

Use `/start-work <owner-name-or-GitHub-ID> [issue or goal]` for the first project turn after cloning
or updating. Codex or human sessions get the same answer from
`pwsh scripts/launch-status.ps1 -Owner <owner>` — both read the task ledger
`docs/launch-readiness-tasks.json`, whose checks are the definition of done. The current plan of
record is `docs/launch-readiness-plan.md`; Pro mode (B09, B10, B13, C15, F06) is out of v1.0 scope
by decision of 2026-08-08 and must not be started.
