# Release-proof Verification Design

**Date:** 2026-08-31
**Status:** Approved by the active user request to declare a Goal and proceed without stopping
**Scope:** Basic strategy authoring, immutable release, market-data selection, all backtest lanes, customer/operator UI, competition, and deploy-like local runtime

## Goal

Produce repeatable evidence that the current release candidate fails closed, terminates every asynchronous workflow, preserves immutable inputs, and renders the same state across UI, APIs, PostgreSQL, queues, and object storage. Completion means no reproducible release-blocking defect remains in the tested scope; it does not claim that arbitrary future software can be mathematically defect-free.

## Verification architecture

The release gate has four independent layers:

1. **Deterministic conformance:** all published Basic elements, numeric and enum boundaries, maximum document shape, warnings, compiler operations, and runtime true/false/unavailable behavior.
2. **Actual-data semantic proof:** several materially different released strategies over the fixed 2016-01-01..2026-07-29 interval, with exact manifest pins, Parquet hashes, OHLCV, fills, fees, slippage, FIFO PnL, equity, and result hashes independently reconciled.
3. **Durability and chaos:** duplicate requests, conflicting idempotency reuse, lane saturation, cancellation races, worker termination/restart, expired leases, stale recovery, DLQ exhaustion, object unavailability, and resource-limit exits. Every run reaches a finite terminal state and a late worker cannot overwrite it.
4. **Product flow:** signup without email verification, strategy create/edit/save/reload/validate/release, backtest states and result charts, bot lifecycle, competition room creation and lifecycle, and operator authentication/RBAC/case surfaces through the deploy-like Docker stack.

## Repetition model

Repetition is deliberate rather than random. Pure deterministic suites run repeatedly to detect order, clock, and shared-state dependence. Actual-data runs use a named corpus spanning 30m, 1h, 4h, 1d, one and several instruments, one and four partitions, every Basic block, buy/sell activity, no-signal completion, warning-bearing strategies, and unavailable input. Chaos cases repeat with fresh message and claim identities. Browser journeys repeat in clean contexts and preserve sanitized receipts.

The gate records each scenario, seed, immutable input fingerprint, run ID, attempt lineage, terminal state, duration, result hash, trade-kind counts, failure reason, and resource peak. Equivalent deterministic requests must agree on their immutable inputs and result evidence. Expected failures must match their typed reason and must never be counted as successful execution.

## Release thresholds

- Every visible Basic element has UI/catalog/compiler/runtime/conformance coverage.
- Every accepted run reaches COMPLETED, FAILED, CANCELLED, or UNAVAILABLE within its policy bound; no stale QUEUED/RUNNING row remains.
- Full-history one-instrument executions finish inside the approved 10-minute dequeue p95 and 15-minute request ceiling in the local development environment.
- Duplicate delivery creates no duplicate run, attempt success, result manifest, fill, or ledger effect.
- All completed fills reconcile to exact pinned market-data bytes and balanced ledger entries.
- All expected failure paths preserve their reason, attempts, and user-readable presentation.
- Real browser flows have zero unexpected console errors, unhandled requests, inaccessible enabled controls, or frontend/backend route mismatches.
- Full component suites, root contracts, Flyway integration, container builds, GitGuardian, and repository secret gates pass from the isolated checkout.

## Defect handling

Every observed failure is first reduced to the narrowest reproducible test. The owner boundary is identified before code changes. The fix is minimal, preserves immutable historical behavior, and is verified by the new regression test, the affected component suite, the actual scenario, and the full release gate. Applied Flyway migrations are never edited.

## Evidence and delivery

Sanitized receipts are written under `.local/artifacts/release-proof/` and remain ignored. A tracked evidence report records commands, aggregate counts, run IDs, hashes, durations, and discovered/fixed defects without credentials. Component changes merge before the root gitlinks and refreshed Flyway CI bundle. Completion requires green pull requests and the final merge commit on remote `develop`.
