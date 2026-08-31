# Idea2Strategy

Idea2Strategy is a virtual trading strategy authoring, backtesting, and execution platform.

## Repository structure

- `backend/`: Spring Boot API, batch, Admin MCP, and Flyway modules
- `trading-engine/`: Spring Boot market gateway and trading worker
- `backtest-engine/`: Python FastAPI backtest API and worker
- `data-pipeline/`: Python market-data and corporate-action pipelines
- `ui/`: React/Vite frontend
- `specs/`, `contracts/`, `db/`: product behavior, integration contracts, and the canonical data model
- `infra/`, `compose.*.yml`, `scripts/`: deployment and local development

## Start locally

Requirements are Git, Docker Desktop, and PowerShell 5.1 or later.

```powershell
git submodule update --init --recursive
.\scripts\dev.ps1 up -Scope all -WithBackend -NoBrowser
```

Useful commands:

```powershell
.\scripts\dev.ps1 status
.\scripts\dev.ps1 down
```

The default local endpoints are UI `http://localhost:15173`, backend API `http://localhost:18080`, backtest API `http://localhost:18082`, Admin MCP `http://localhost:18083`, and MinIO Console `http://localhost:19001`.

See [development start guide](docs/development-start-guide.md) for repository-specific commands and [project decisions](docs/project-decisions.md) for the product sources of truth.
