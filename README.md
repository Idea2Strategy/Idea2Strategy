# Idea2Strategy

Idea2Strategy is an early-stage virtual trading bot SaaS project. Product discovery is still in progress, so repository contents should not be treated as a finalized specification.

## Repository structure

- `backend/`: Spring Boot API, batch, worker, Admin MCP, and Flyway migration modules
- `trading-engine/`: Spring Boot market gateway and trading worker modules
- `backtest-engine/`: Python FastAPI and backtest worker
- `data-pipeline/`: Python market-data pipeline and corporate-action research jobs
- `ui/`: React/Vite frontend
- Root repository: canonical DBML, product context, contracts, Docker orchestration, and cross-repository coordination

The current UI is exploratory. Its UX, copy, visual design, and implementation architecture may be substantially revised or replaced.

## Prerequisites

- Git
- PowerShell 5.1 or later on Windows
- Claude Code when using the shared AI-assisted workflow
- Access to the selected GitHub or GitLab repository

Both remotes use `develop` as their default collaboration branch. `main` is reserved for complete releases beginning with `v1.0.0`.

Team members should follow [`docs/development-start-guide.md`](docs/development-start-guide.md) after the shared foundation is merged into `develop`. It covers clone/update, Claude Code onboarding, local startup, assigned-repository branching, tests, pull requests, and root submodule-pointer integration.

The executable backtest catalog, cancellation behavior, supported resolutions, and release gates
are recorded in [`docs/backtest-production-readiness.md`](docs/backtest-production-readiness.md).

Claude Code automatically reads [`CLAUDE.md`](CLAUDE.md). After cloning or pulling, start Claude from the repository root and run `/start-work <A-F> <name> <GitHub-ID>`.

## Clone from GitHub with all submodules

```bash
git clone --recurse-submodules https://github.com/Idea2Strategy/Idea2Strategy.git
cd Idea2Strategy
```

For an existing clone:

```bash
git submodule update --init --recursive
```

## Clone from the monolithic GitLab mirror

```bash
git clone https://lab.ssafy.com/s15-webmobile2-sub1/S15P11B205.git
cd S15P11B205
```

The GitLab checkout contains `ui/` as ordinary tracked files and must not contain a nested `ui/.git` directory.

## Initialize collaboration

Run these commands from the cloned repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-local-harness.ps1 -Verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-harness-consistency.ps1
git status --short --branch
git submodule status
```

The initializer creates the ignored local workspace, policy-integrity baseline, and a non-secret reference to the configured product authority. It does not authenticate the current user and never overwrites an existing local owner record.

The shared skeleton lives under `.harness/local/`; generated artifacts, temporary files, caches, logs, dbdiagram proposals, and user-specific project records stored there are never committed. A fresh clone must remain clean after initialization.

## Project harness

Ask your AI assistant what to do next. It will read `.harness/entry.md`, inspect actual Git state, and continue from canonical specs and contracts.

If the project uses an independent editable UI baseline, it lives in a declared `ui/` directory or submodule. External mockups can be inspected, brought into that workspace, edited normally, and committed before frontend implementation is bound to the exact baseline.
## Collaboration policy

Before contributing, read [`docs/collaboration-policy.md`](docs/collaboration-policy.md). It defines the Idea2Strategy-specific GitHub/GitLab boundaries, policy ownership, local Jira record, dbdiagram operation, and remote distribution rules. The tracked harness, scripts, Git state, and launch-readiness ledger are the source of truth for recovery, coordination, planning, and verification.
