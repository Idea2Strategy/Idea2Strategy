# Canonical local market history and Ultimate Strategy design

Date: 2026-08-29
Status: Approved for implementation
Authority: `user:kcrmin` explicitly requested uninterrupted design review, implementation, real-data loading, verification, cleanup, commit, and push in the current session.

## Outcome

Strategy preview, official backtests, and benchmark comparison use one internally retained body of real market history. External providers are used only by an explicit ingestion command. Once an ingest is published, disconnecting `D:` and blocking provider networks does not change preview, execution, or result reads.

The local developer account retains one editable multi-partition demonstration named `THE ULTIMATE STRATEGY`, one representative completed run, and at most one failed and one cancelled run needed to inspect terminal-state UI. Demonstration performance is evidence, not a promised return and not a target that permits look-ahead, synthetic fills, or result manipulation.

## Confirmed current state and root causes

- The local catalog has 725 tradeable instruments plus `SPX` and `NDX`, and adjusted manifests for 30m, 1h, 4h, and 1d declare 2016-01-01 through 2026-07-30.
- Existing equity Parquet objects sampled from the 2016 daily manifest contain real 2016 rows, but the schema records coverage boundaries rather than separately recording actual first and last bar timestamps. Consequently a manifest can look complete without proving its physical rows.
- Preview is a Redis projection of Parquet, but the projection carries no immutable manifest identity or content checksum. It therefore cannot prove that the chart is still the projection of the selected canonical object.
- The in-progress benchmark loader writes downloaded index JSON directly to Redis. It does not publish Parquet or a manifest. Its NDX request currently retained only 2019-07-11 through 2023-01-17, while SPX retained 2016-01-04 through 2026-07-29. That partial NDX series is unusable as a full-period benchmark.
- Existing `THE ULTIMATE STRATEGY` and completed run are present, but result publication has written a run `completed_at` approximately nine hours before the successful attempt completion. The attempt timestamp is correct, so lifecycle and result publication clocks are not using one UTC boundary.
- The database has no queued or running run at the design checkpoint. Retry exhaustion already reaches `FAILED`, but regression and offline evidence still have to prove every required terminal path.
- Numerous experimental strategies remain visible even though older cleanup only soft-deleted some of them.

## Data authority and providers

### Equities

Alpaca SIP remains the approved equity provider. The explicit target set is AAPL, MSFT, META, AMZN, and NVDA. Ingestion starts at 2015-01-01 and ends at the latest completed regular session the provider actually returns. The collector requests adjusted 30-minute regular-session bars, validates them, and deterministically derives 4-hour and daily bars. It never interpolates missing bars.

### Benchmarks

Benchmarks are the cash indices, not investable proxies:

- `SPX`, displayed as `S&P 500`;
- `NDX`, displayed as `NASDAQ-100`.

The index collector downloads both cash-index histories from a provider endpoint that returns those symbols themselves. It pins the provider name and symbol in object and manifest provenance. If a provider cannot return the requested index or complete range, publication fails; SPY and QQQ are never substituted. Index volume is legitimately absent and is represented as nullable/not-applicable source data, not fabricated market volume.

## Collection and publication boundary

One resumable ingestion command owns these stages:

1. Plan `(provider, instrument, resolution, date chunk)` work with deterministic keys.
2. Fetch paginated provider responses with bounded retry, `Retry-After`, and jitter.
3. Persist chunk checkpoints in ignored local state without credentials.
4. Normalize timestamps to UTC and filter against the pinned XNYS regular-session calendar.
5. Sort and deduplicate by `(instrument_id, bar_start_at)`, rejecting conflicting duplicates.
6. Validate finite positive OHLC, OHLC range invariants, non-negative volume, expected timeframe span, and adjusted/raw policy.
7. Derive 4h and 1d only from validated lower-timeframe rows, using session-aware deterministic groups and recording source-bar count.
8. Write deterministic Parquet to a temporary key, read it independently, and calculate row count, actual minimum/maximum timestamp, schema version, byte size, and SHA-256.
9. Upload immutable bytes to versioned MinIO and verify the returned version and downloaded checksum.
10. In one PostgreSQL transaction publish `storage.objects`, `dataset_manifests`, and `dataset_objects`, then mark the checkpoint successful. A partial failure never exposes an `AVAILABLE` manifest.
11. Project a bounded preview history into Redis only after publication. The projection includes manifest ID, revision, dataset hash, object hashes, actual range, and projection hash.

Re-running the same completed plan verifies and reuses the existing publication. Changed source bytes create a later immutable revision and never overwrite or mutate an earlier revision.

## Coverage and schema

Coverage boundaries and physical evidence are different facts. Existing `period_start`/`period_end` retain half-open coverage semantics used by manifest selection. New actual-range fields on manifest/object metadata record the physical Parquet minimum and maximum `bar_start_at`; row count is the Parquet row count. Publication rejects an actual range outside coverage, an empty object, or disagreement among Parquet metadata, storage metadata, and PostgreSQL.

For each target equity, 30m, 4h, and 1d are retained from 2015-01-01 through the latest available completed session. SPX and NDX retain daily history for the same calendar span where the provider has actual observations. The fixed official backtest policy remains 2016-01-01 through 2026-07-29; additional history supplies warm-up and preview but does not silently extend an immutable execution policy.

## Preview

`GET /api/v1/market-data/instruments/{instrumentId}/bars` remains customer-authenticated. The selected instrument must be either a published Basic instrument or a published benchmark. The service reads only a projection whose manifest and checksum provenance match an available canonical publication; a stale or unverifiable Redis document is treated as corrupt, not as data.

`window=1m|3m` anchors to the requested instrument/timeframe's actual last bar. Responses include requested and actual range, last bar time, coverage state, manifest ID/revision/hash, and bars. `COMPLETE`, `PARTIAL`, `EMPTY`, `CORRUPT`, `UNAUTHORIZED`, and internal failure remain distinguishable. Changing symbol, timeframe, or window aborts the prior request and renders the newly selected real series.

## Manifest selection and replay

The compiled plan is the authority for requirements. Each flow contributes its own instruments, exact resolution, and maximum warm-up. Backend chooses the deterministic minimum available cover for each `(instrument, data kind, resolution)` requirement and pins every selected manifest before enqueueing.

Universe manifests can satisfy a requirement only when object evidence proves the required instrument occurs within the covered objects. Instrument-scoped manifests match only that instrument. The selection result records requirement-to-manifest bindings, revision, safe object identity, physical range, warm-up range, row count, and checksum. Later publications do not change a pinned run.

The worker streams only required columns, instruments, and row groups from each pinned object. It merges adjacent manifests deterministically, rejects gaps/conflicting duplicates, and never resamples or substitutes a resolution at runtime.

## Canonical performance and benchmark comparison

One result calculation produces the persisted equity series, performance summary, and month-end summaries. Total return equals the final equity-series value relative to initial equity. Maximum drawdown and Sharpe are derived from that series under the pinned policy. Fill count, closing-trade count, win rate, realized PnL, unrealized PnL, fees, and slippage remain distinct.

Monthly return uses consecutive month-end equity observations, with the first month measured from initial equity. Raw decimal values are persisted; UI rounding is presentation only. Summary, line chart, and monthly table are rejected if they cannot reconcile with the canonical series.

SPX and NDX use actual daily closes clipped to the intersection of their observations and the strategy equity series. Each series is rebased to 0% at its own first observation in that common interval. Missing dates are not interpolated and no ETF result is exposed. The UI renders three continuous time-series lines and the exact common interval.

## Ultimate Strategy

`THE ULTIMATE STRATEGY` remains an ordinary editable Basic draft/release using the current supported schema. It uses multiple independent equity partitions and a mixture of 30m, 4h, and 1d clocks. Every partition has more than one meaningful BUY condition and more than one meaningful SELL condition; allocation caps, order percentages, and cash reservation cannot collectively exceed the portfolio budget.

Parameters are selected only from an in-sample interval, then frozen and evaluated on a chronological holdout and rolling walk-forward windows. Acceptance requires BUY and SELL fills across multiple years and months, finite reproducible metrics, no future-bar reads, and no cash-reservation inconsistency. It does not require positive performance in every month or beating either index. The exact document and every reported result are retained as evidence.

CLI, backend, and UI use the same current Basic schema vocabulary. Legacy presentation snapshots are migrated losslessly at read time and saved in the current shape. Missing editor-only layout metadata is reconstructed from semantic groups without changing semantics. JWT use does not acquire a long-lived edit lease; optimistic `edit_sequence` detects real concurrent saves.

## Execution lifecycle

All lifecycle timestamps are timezone-aware UTC from one clock. Result publication cannot precede the attempt or run start. Success atomically publishes immutable result evidence and marks `COMPLETED`. Permanent failures, final retry, DLQ handling, invalid inputs, resource limits, timeout, and publish failure persist a stable failure code and mark `FAILED`. Cancellation marks `CANCELLED` after cooperative stop.

Stale recovery uses attempt lease expiry and heartbeat, never wall-clock run age alone. Duplicate messages and restart replay are idempotent. Existing terminal records with an impossible completion timestamp are repaired only when immutable attempt/result evidence determines the correct instant; the repair is recorded and idempotent.

## UI and local data cleanup

The result view prioritizes the strategy/SPX/NDX cumulative-return line chart, then reconciled metrics, monthly returns, trade detail, attempts/failure reason, and pinned input ranges. It does not expose the removed internal implementation sentence. Loading, partial data, no data, corrupt data, failure, cancellation, forbidden, and authentication states use consistent typography and layout.

Cleanup uses existing soft-delete and reference rules. It keeps `THE ULTIMATE STRATEGY`, its representative completed run, and optional one failed/one cancelled UI record. It removes stale experiments from ordinary lists without deleting immutable releases, input manifests, audit evidence, or result objects that are still referenced.

## Verification gates

- Unit/property/integration tests cover pagination, retry, resume, deduplication, session/timezone, aggregation, atomic publication, idempotency, range/hash/row verification, and secret redaction.
- Contract tests cover authenticated preview states, latest-data 1m/3m windows, provenance, multi-instrument/multi-resolution minimum cover, revision pins, and reproducible replay.
- Independent PyArrow checks compare first/middle/last OHLCV rows and physical ranges/hashes against API and PostgreSQL without importing production calculation helpers.
- Backtest tests reconcile equity, summary, drawdown, fees, fills, closed trades, win rate, every monthly return, SPX, and NDX.
- Terminal tests cover completion, final retry, DLQ, stale recovery, protected live lease, cancellation, duplicate delivery, restart, timeout, resource failure, and invalid input.
- Docker and browser E2E cover login, editable migrated strategy, save, multiple instruments/timeframes/windows, request date input, completion/failure/cancellation, line chart, monthly analysis, inputs, and new-user empty state.
- After ingestion, provider access is blocked and the same preview, validation, backtest, benchmark, and result reads are repeated; worker/backend logs must contain no provider-domain request.
- Repository checks, full affected suites, `git diff --check`, and secret scans pass before commit and push.

## Delivery boundary

No Stackcord work and no Pro-mode implementation are included. Raw licensed bars, credentials, local session material, and provider URLs containing credentials are never committed. Code, schema migration, deterministic ingest tooling, tests, and non-sensitive evidence are committed to their owning repositories; local data remains in ignored/versioned Docker storage.
