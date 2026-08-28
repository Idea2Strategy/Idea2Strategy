# Idea2Strategy project harness

This directory contains only durable coordination configuration. It does not
duplicate product requirements, implementation plans, or current task state.

## Sources of truth

1. `specs/` — approved product meaning
2. `contracts/` — cross-service obligations
3. `docs/collaboration-policy.md` — repository and collaboration policy
4. `docs/launch-readiness-plan.md` — launch scope and rationale
5. `docs/launch-readiness-tasks.json` — current work graph and completion checks
6. `.harness/` — discovery, workspace, authority, and command metadata only

Start with `entry.md`. Runtime artifacts and machine-specific state belong in
`local/`, which is ignored except for its shared skeleton.

## Tracked layout

- `manifest.yaml`, `profile.yaml`, `sources.yaml`: project discovery defaults
- `workspaces.yaml`: root and submodule boundaries
- `commands.yaml`: stable repository verification commands
- `product-authorities.yaml`: protected-path authority registry
- `ui/baselines/`: immutable UI design baselines, not moving branch pointers
- `work/items/`: immutable receipts for the three completed harness bootstraps

Executable work definitions, leases, and branch reservations are deliberately
not stored here. Current work is selected from `docs/launch-readiness-tasks.json`
with `scripts/launch-status.ps1`; completed historical state remains recoverable
from Git and `docs/evidence/`.
