# Backtest production readiness

This document records the executable service boundary for the production backtest path. It does
not authorize a production deployment; environment rollout, migration approval, and traffic
switching remain separate release actions.

The selected-resolution RSI change is currently an implementation proposal. The exact canonical
contract replacement and deployment remain gated until a configured product authority approves
the exact change through the repository's GitHub review process.
See [`proposals/backtest-rsi-resolution-alignment/README.md`](../proposals/backtest-rsi-resolution-alignment/README.md).

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
- `BASIC_RSI_CROSS` binds the selected resolution to a distinct `RSI_14` definition, deterministic
  feature feed, and pinned materialization. The worker consumes the pinned prior/current values;
  it does not recompute RSI from closes. Missing, gapped, or cross-resolution output fails closed.
- The strategy authoring page is owned by the UI strategy workstream and is intentionally not
  changed by this work. The current semantic document and latest catalog are consumed as-is.

## Runtime behavior

1. Backend validates the saved assembly, resolves each feature by `(feature code, resolution)`,
   and publishes an immutable compiled plan. Raw adjusted bars are a platform input, not a
   per-element availability claim.
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
- root collaboration-policy verification and exact GitHub release/commit status audit.

Production startup remains fail-closed when the Flyway catalog migration, PostgreSQL schema,
dataset feed resolution, object hashes, queue configuration, authentication, or service health
checks are unavailable. This feature does not connect to a real brokerage account; trading remains
the platform's virtual execution service.

## Verification snapshot (2026-08-08)

- The root repository and every service submodule were fetched with pruning, and every working
  branch contains its latest fetched `origin/develop` commit.
- Backend full Gradle and trading full Gradle suites pass. Backtest unit, contract, persistence,
  lint, and type checks pass. The root PostgreSQL 16 + LocalStack shared-runtime journey also
  passes with an active-catalog `RSI_CROSS@30m` plan through BASIC, CUSTOM, and COMPETITION,
  including retry, duplicate suppression, immutable feature-object binding, result persistence,
  and fail-closed rejection of a changed object version. Deployment of that journey remains part
  of the release gate.
- UI passes 547 Vitest cases and the production Vite build.
- Data Pipeline's changed feature/migration path passes 75 tests plus 8 subtests, including a fresh
  PostgreSQL 16 migration and materialization run; full-suite execution exceeded the local
  five-minute harness limit without reporting a failure. Ruff passes, and the changed modules pass
  mypy. Full-project mypy remains blocked by pre-existing errors exposed by the unpinned latest
  pandas stubs.
- The refreshed central Flyway bundle validates and applies all 53 migrations on a fresh
  PostgreSQL 16 database; the second application reports no pending migration. The exact
  source-revision receipt is verified by `scripts/test-flyway-ci-bundle.ps1`.

These results verify the production backtest path in local integration environments; they do not
prove that a production environment already has the commits, migration, credentials, provider
rights, or historical dataset coverage. One unused legacy D90 Redis ingestion adapter still mirrors
the previous trading stream shape and is excluded from the data-pipeline production-path suite. It
is not instantiated by the historical-data or backtest runtime, but should be retired or realigned
before claiming that every legacy repository test is green.

Issue #248 must remain open while its authoritative comment still pins RSI to one `1m` identity.
That clause is superseded only after a configured product authority approves the proposed
four-resolution identity model and the same three-lane end-to-end gate passes in the deployed
environment. The local `30m` execution proof now passes; it is not evidence that the draft commits
or migrations are deployed.
