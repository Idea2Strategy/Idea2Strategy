# Idea2Strategy Claude Code entry

@AGENTS.md

## Repository map

- `backend/`: Java / Spring Boot API, batch, Admin MCP, and Flyway modules
- `trading-engine/`: Java / Spring Boot market gateway and trading worker
- `backtest-engine/`: Python / FastAPI backtest API and worker
- `data-pipeline/`: Python market-data and corporate-action pipelines
- `ui/`: TypeScript / React / Vite
- root: product specifications, contracts, canonical DBML, infrastructure, Docker orchestration, and submodule pointers

Start by checking `git status --short --branch` and reading the relevant source of truth from `specs/`, `contracts/`, or `db/`. There is no role assignment, owner lookup, launch checklist, or approval command to run.
