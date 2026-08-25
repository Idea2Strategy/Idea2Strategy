# Fixed Maximum-Range Backtest Design

**Date:** 2026-08-25
**Status:** Approved in session by `user:kcrmin`
**Scope:** Local Basic backtests, fixed evaluation policy, real-data reference pack, seeded complex strategies, semantic evidence, and trade-history UI.

## 1. Outcome

Local development uses one immutable official evaluation window instead of a user-selected or rolling month. The repository seeds complex Basic strategies whose real runs contain entries and exits, exposes their trade history, and proves from raw bars that indicator values, condition instants, fills, fees, cash, positions, and result summaries agree.

## 2. Fixed period

The official local policy is:

- inclusive start: `2016-01-01T00:00:00-05:00` (`2016-01-01T05:00:00Z`);
- exclusive end: `2026-07-30T00:00:00-04:00` (`2026-07-30T04:00:00Z`);
- display: `2016-01-01 ~ 2026-07-29`;
- resolution for the reference pack: `30m`; and
- actual observed bar extent: `2016-01-04T14:30:00Z` through `2026-07-29T19:30:00Z`.

The period is derived from the available adjusted SIP backup. It is not derived from the current date, request date, strategy release date, or UI state. Every Basic official run pins the same policy version and the UI renders it read-only.

## 3. Reference universe

The backup contains 725 instruments. The current V1 application catalog and local bootstrap expose three stable official instruments: AAPL, MSFT, and SPY. Their current UUIDs differ from the backup UUIDs, so the local importer remaps these three symbols into the V1 identities and verifies there is exactly one unambiguous source symbol for each.

This is a reference-universe boundary, not a claim that only three instruments exist. Unsupported backup symbols are not presented as locally backtestable. Extending the official catalog and remapping all 725 instruments is a separate catalog/data migration.

The normalized files live below ignored local storage and do not require a mounted `D:` drive after import. Bootstrap fails with an actionable message if neither the normalized pack nor the approved backup is available; it never replaces real data with synthetic prices while claiming a real-data run.

## 4. Immutable data and calendar

The importer reads the ignored baseline backup, selects AAPL, MSFT, and SPY rows from adjusted 30-minute objects, rewrites only the instrument identity to the V1 UUID, preserves OHLCV and timestamps, and emits deterministic Parquet objects ordered by instrument and bar start. Content hashes, row counts, min/max timestamps, source hashes, and the importer version are recorded in a local receipt.

A new pinned XNYS calendar version covers `2016-01-01` through `2026-12-31`. Session dates and early closes within the evaluation window must agree with the observed real bars. Known one-off closures are pinned explicitly. Requests outside calendar coverage fail rather than being treated as market-closed.

The data manifest and execution policy cover the same ET-boundary interval. Warm-up rows remain inside the pinned input and evaluation never reads a future bar.

## 5. Seeded complex strategies

Bootstrap creates and releases at least three idempotent strategies owned by the local developer account:

1. **AAPL MACD/SMA Trend Cycle** — separate complex BUY and SELL flows combining a schedule/regime condition, an SMA relationship or cross, and MACD direction.
2. **MSFT RSI/Bollinger Mean Reversion** — separate BUY and SELL flows combining RSI, Bollinger behavior, and an additional price/volume guard.
3. **Three-Asset Partition Rotation** — independent AAPL, MSFT, and SPY partitions with multiple conditions and both risk-increasing and risk-reducing paths.

Thresholds are selected from the real fixed-period series only to make the examples useful; the UI describes them as demonstration strategies, not recommendations. A sample is accepted only when its real run has:

- `fillCount > 0`;
- `closingTradeCount > 0`;
- at least two distinct trade months;
- at least one BUY and one SELL fill; and
- a non-empty monthly trade-history response whose count matches result evidence.

If a sample no longer meets its declared minimum after code or data changes, bootstrap/test fails. It does not silently loosen conditions at runtime.

## 6. Semantic oracle

The acceptance suite uses an implementation independent from production runtime helpers. From normalized raw bars it recomputes:

- RSI(14) using the published smoothing definition;
- MACD fast EMA, slow EMA, signal EMA, and crossover direction;
- SMA windows and crossover direction;
- Bollinger center, deviation bands, and reversal direction; and
- the additional price, volume, streak, or schedule guards used by each sample.

For selected trades and all boundary transitions, the oracle asserts:

- the condition is false immediately before the declared crossing and true on the exact signal bar;
- only completed bars at or before the evaluation instant are used;
- the candidate side, instrument, partition, and quantity agree;
- market fills use the policy-defined eligible bar and slippage direction;
- fees, cash postings, position quantities, realized PnL, and equity reconcile exactly at published precision; and
- relational summaries, Parquet detail records, result hashes, monthly summaries, and API trade rows describe the same events.

Production RSI/MACD functions are not imported into the oracle. Golden expected timestamps and decimal values are stored only after being derived and independently reviewed from the real pack.

## 7. Warnings and zero-trade behavior

Zero trades remain a valid result for a user-created strategy. Completion must not be converted into failure merely because no condition triggered. However:

- seeded examples must satisfy the positive-trade contract;
- restrictive valid combinations receive the existing stable restrictive-combination warning;
- missing warm-up or data gaps remain typed unavailable/data-gap outcomes, not false conditions; and
- the result page explicitly shows zero trades when appropriate and renders complete trade rows when present.

## 8. UI behavior

The Backtest page displays the fixed period and explains that it is the official local dataset window. There is no editable date input for this official Basic path. Sample strategies are visible in the ordinary strategy list and their completed runs appear in ordinary history.

Trade history displays month, side, instrument, signal/evaluation time, fill time, quantity, fill price, fee, realized PnL when available, and the strategy/flow explanation already carried by evidence. Empty, loading, unavailable, failed, and forbidden states remain distinct.

## 9. Test and delivery gates

Completion requires:

- policy-boundary and calendar tests for the full fixed interval;
- deterministic importer tests including identity mapping, hashes, ordering, and D-drive independence;
- real runs for all seeded samples meeting their positive-trade contracts;
- independent RSI, MACD, SMA, Bollinger, signal-time, fill, fee, cash, position, PnL, and result reconciliation;
- API and Playwright checks for fixed-period display and non-empty trade history;
- a clean second bootstrap proving idempotency;
- all affected Backend, Backtest, UI, Flyway, root, and GitGuardian checks passing; and
- local services restarted with the test URL and credentials reported to the user.

