# Idea2Strategy development guide

Work from this repository root and preserve unrelated local changes.

## Sources of truth

- Product behavior and decisions: `specs/`
- Service and data obligations: `contracts/`
- Database model: `db/schema.dbml` and `db/data-model-decisions.md`
- Local execution: `compose.back.yml`, `compose.front.yml`, and `scripts/dev.ps1`

There is no contributor ownership table, administrator approval gate, Stackcord workflow, task ledger, or mandatory harness initialization. Change the repository directly, keep product meaning consistent across affected services, and run tests appropriate to the files changed.

Applied Flyway migrations remain immutable; add a later migration for schema changes. Never discard another developer's uncommitted work.
