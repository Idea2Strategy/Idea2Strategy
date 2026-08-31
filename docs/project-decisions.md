# Project decisions and sources of truth

This document is a map, not a task list. Detailed behavior belongs in the linked canonical files.

## Canonical order

1. `specs/` defines user-visible product behavior and quality requirements.
2. `contracts/` defines obligations between services and data producers/consumers.
3. `db/schema.dbml` defines the logical database model; `db/data-model-decisions.md` explains its choices.
4. Runtime code and tests implement and verify those decisions.

Historical plans, ownership records, evidence ledgers, and approval metadata are not product sources of truth.

## Strategy scope

- PRO strategy mode is outside the current product scope.
- Strategy execution must honor the configured budget allocation and maximum holding ratio; showing either setting without sending and enforcing it is invalid behavior.
- A sell action is the supported position-reduction mechanism. A separate crisis-management feature is not part of the current scope; order validation, partial fills, retries, and failure handling remain required execution behavior.
- UI strategy blocks, partitions, candle resolutions, and data-dependent cards must represent combinations the backend can validate and execute. Multiple partitions must remain distinct through execution rather than being silently merged.
- Features that require unavailable data must be disabled or clearly marked unavailable instead of appearing operational.

The detailed strategy semantics remain in `specs/product/`, `specs/scenarios/`, `specs/ui/`, and the registered contracts.
