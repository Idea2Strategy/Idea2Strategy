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

- A: 나주원 (`Juwon-Na`) — 계정·운영
- B: 손현준 (`hjcud`) — 전략·봇
- C: 박준유 (`pjy008008`) — 시장·평가
- D: 서동위 (`SeoDongWi`) — 데이터·백테스트
- E: 황영우 (`dertz569`) — 방·성과
- F: 민경철 (`kcrmin`) — 거래·원장

Use `/start-work <A-F> <name> <GitHub-ID> [issue or goal]` for the first project turn after cloning or updating.
