# Backtest production readiness

This document records the executable service boundary for the production backtest path. It does
not authorize a production deployment; environment rollout, migration approval, and traffic
switching remain separate release actions.

## Supported strategy boundary

- Newly published Basic strategies use catalog `basic-elements:2026-08-08`.
- A strategy selects exactly one of `30m`, `1h`, `4h`, or `1d` across its resolution-bearing
  blocks. Mixed-resolution plans fail validation rather than selecting an arbitrary dataset.
- `1m`, `5m`, and `15m` are not available in the active catalog. Older immutable catalog versions
  remain readable only so already released bots can be reproduced.
- The executable catalog contains price comparison, price-change percentage, volume comparison,
  streak, SMA cross, RSI cross, MACD cross, Bollinger reversal, position return, holding period,
  peak return, drawdown from peak, schedule, and equal-allocation order blocks.
- Position-only exit plans bind their evaluation clock to the selected immutable dataset manifest.
  The worker rejects a manifest whose production resolution cannot be proven.
- The strategy authoring page is owned by the UI strategy workstream and is intentionally not
  changed by this work. The current semantic document and latest catalog are consumed as-is.

## Runtime behavior

1. Backend validates the saved assembly, resolves each dynamic feed from the block's actual
   `resolution`, and publishes an immutable compiled plan.
2. Backtest API pins the plan, dataset manifest, execution policy, and owner-scoped request.
3. Worker verifies every immutable input, derives raw-bar warm-up, and evaluates one closed bar at
   a time without same-bar fills.
4. Position return, holding, peak, and drawdown inputs are recomputed after fills and before the
   next decision.
5. `orderPercent`, `executionMode`, `waitMode`, `waitInterval`, and `maxExecutions` are enforced in
   both backtest and live virtual-trading runtimes. Partial buys reduce the equal cash allocation;
   partial sells reduce the held position selected by the composer. A virtual-trading worker restart
   restores the current position cycle's execution count and last execution time from canonical
   order intents, and starts a fresh gate only after the prior position cycle has closed.
6. Result summaries, monthly judgments, detail objects, and terminal run status are persisted and
   exposed through owner-scoped APIs.

## Cancellation

- `POST /api/v1/backtests/{runId}/cancellation` is owner scoped and idempotent for an already
  cancelled run.
- A queued run becomes `CANCELLED` immediately and is never dispatched for computation.
- A running run records `cancellationRequestedAt`; the worker observes it at a cooperative safe
  point, publishes `CANCELLED`, acknowledges the queue message, and does not send it to the DLQ.
- Completed, failed, and unavailable runs reject a new cancellation request with a conflict.
- The Backtest UI exposes cancellation only for queued or running runs and shows requested and
  completed cancellation evidence.

## Release gates

Before deployment, all of the following must pass on the exact root/submodule commits:

- backend full Gradle tests, including Flyway migration policy and PostgreSQL catalog integration;
- backtest Python unit, contract, persistence, lint, and type checks;
- trading full Gradle tests, including candidate contract and partial-position sizing;
- UI Vitest suite and production Vite build;
- a real cross-service journey: publish a Basic strategy, request each supported resolution,
  execute the worker, read the result, and cancel both queued and running runs;
- root collaboration-policy verification and Stackcord release/status audit.

Production startup remains fail-closed when the Flyway catalog migration, PostgreSQL schema,
dataset feed resolution, object hashes, queue configuration, authentication, or service health
checks are unavailable. This feature does not connect to a real brokerage account; trading remains
the platform's virtual execution service.
