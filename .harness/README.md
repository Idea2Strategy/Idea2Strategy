# Idea2Strategy project harness

This directory holds only the product-authority registry. The former
Stackcord entry, manifest, command, workspace, and work-ledger files were
removed together with the Stackcord workflow; do not recreate them.

## Tracked layout

- `product-authorities.yaml`: protected-path authority registry

## Where things live now

1. `specs/` — approved product meaning
2. `contracts/` — cross-service obligations
3. `db/schema.dbml` — canonical database model
4. `docs/development-start-guide.md` — how to run and change the repository

Runtime artifacts and machine-specific state belong in the ignored `.local/`
directory at the repository root, not under `.harness/`.
