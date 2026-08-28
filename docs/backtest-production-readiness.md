# Backtest production readiness

This document records the executable production boundary. It does not authorize an environment rollout, migration, or traffic switch.

## Supported strategy boundary

- Newly published Basic strategies use the active Basic element catalog.
- Each partition independently selects `30m`, `1h`, `4h`, or `1d`. A strategy may mix resolutions and instruments across partitions.
- Compilation derives the minimum manifest set from every partition's instrument, resolution, indicator, and warm-up requirements. It must neither collapse the request to one resolution nor load unrelated manifests.
- The executable catalog contains price comparison, price-change percentage, volume comparison, streak, SMA cross, RSI cross, MACD cross, Bollinger reversal, position return, holding period, peak return, drawdown from peak, schedule, and equal-allocation order blocks.
- Multiple buy and sell conditions are valid per partition. The compiled condition tree preserves their grouping and order.
- Every selected dataset manifest, feature definition, object hash, instrument, resolution, and covered time range is pinned in the run input for reproducibility.
- Missing, gapped, cross-resolution, unhashed, or insufficient input fails closed with a user-readable reason. Runtime code never substitutes generated market data.
- `1m`, `5m`, and `15m` are unavailable in the active catalog. Older immutable catalog versions remain readable only for already released entities.

## Runtime behavior

1. Backend validates the saved assembly and resolves each block by its partition-specific instrument and resolution.
2. The planner selects the smallest complete set of manifests and publishes an immutable compiled plan.
3. Backtest API pins the plan, manifests, execution policy, owner, and idempotency key.
4. Worker verifies every immutable input, derives warm-up, and evaluates closed bars without same-bar fills or future data.
5. Position return, holding period, peak, and drawdown state are recomputed after fills and before the next decision.
6. `orderPercent`, `executionMode`, `waitMode`, `waitInterval`, and `maxExecutions` are enforced in backtest and virtual trading.
7. Summary, benchmark curves, monthly analysis, trades, diagnostics, attempt count, terminal status, and failure or cancellation reason are persisted and exposed through owner-scoped APIs.

## Lifecycle and cancellation

- `POST /api/v1/backtests/{runId}/cancellation` is owner scoped and idempotent for an already cancelled run.
- A queued run becomes `CANCELLED` immediately and cannot later be dispatched.
- A running run records a cancellation request; the worker observes it at a safe point, publishes `CANCELLED`, and acknowledges without DLQ delivery.
- Completed and failed runs reject a new cancellation with conflict.
- Retry exhaustion and DLQ handling must persist `FAILED`, the final reason, and attempt count.
- Stale recovery uses lease and heartbeat evidence. It must recover abandoned queued/running work without terminating a healthy long-running execution.
- Duplicate delivery and worker restart must preserve one consistent terminal result.

## Release gates

All gates run on the exact root and submodule commits:

- backend and trading full Gradle suites;
- backtest unit, contract, persistence, lint, and type checks;
- data-pipeline feature and manifest tests;
- UI Vitest, production build, and browser E2E;
- real-data OHLCV comparison against source Parquet;
- multi-instrument and mixed-resolution compile-to-result journey;
- success, retry exhaustion, DLQ failure, stale recovery, healthy heartbeat, cancellation, and duplicate-delivery lifecycle tests;
- fresh PostgreSQL Flyway application and repeat-run idempotency;
- root policy, harness, secret, and submodule-pointer checks.

Production startup remains fail-closed when the database schema, dataset coverage, object hashes, queue configuration, authentication, or service health is unavailable. The service performs virtual execution only and never connects these backtests to a brokerage account.

## Evidence rule

Counts and outcomes belong in dated `docs/evidence/**` records generated from actual commands. This document intentionally does not copy volatile test counts or deployment claims. Passing local integration proves the checked local inputs and commits only; it does not prove that a remote environment has the same migrations, credentials, rights, or dataset coverage.
