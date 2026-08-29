# Canonical Local Market History and Ultimate Strategy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make preview, mixed-resolution official backtests, and SPX/NDX comparison run reproducibly from retained real local data, then retain one verified editable `THE ULTIMATE STRATEGY` demonstration and push all verified changes.

**Architecture:** Extend the existing immutable Parquet/MinIO/PostgreSQL publication boundary instead of creating another source of truth. A provider-neutral local history publisher records physical Parquet evidence and emits a checksum-bound Redis preview projection; backend validates that provenance, backtest pins requirement-specific manifests, and UI consumes canonical equity and cash-index series.

**Tech Stack:** Python 3.12, PyArrow, boto3/MinIO, psycopg/PostgreSQL 16, Java 21/Spring/jOOQ, Python FastAPI backtest worker, React/TypeScript/Vite, Docker Compose, Playwright.

**Spec:** `docs/superpowers/specs/2026-08-29-canonical-local-market-history-and-ultimate-strategy-design.md`

## Global Constraints

- Use external provider APIs only during explicit ingest; preview, validation, backtest, bot, and result reads are offline.
- Never generate/interpolate OHLCV, substitute SPY/QQQ, disclose credentials, or mutate an immutable published revision.
- Retain fixed official evaluation dates 2016-01-01 through 2026-07-29 while storing target history from 2015-01-01 through the latest completed provider session.
- Preserve all pre-existing dirty work and incorporate the current backend benchmark, UI comparison/schema, and root restore-script changes.
- Pro mode and Stackcord are out of scope.

---

### Task 1: Persist physical object and manifest ranges

**Files:**
- Modify: `db/schema.dbml`
- Create: `backend/db-migration/src/main/resources/db/migration/V20260829090000__pipeline_market_data_physical_ranges.sql`
- Create: `backend/db-migration/src/test/java/com/idea2strategy/backend/migration/MarketDataPhysicalRangeMigrationIntegrationTest.java`
- Modify: `data-pipeline/market_pipeline_lib/db/tables.py`
- Modify: `data-pipeline/tests/test_database_schema.py`

**Interfaces:**
- Produces nullable-backfilled/non-null-for-new-publication `actual_start_at`, `actual_end_at`, and verified row-count evidence without changing half-open `period_start`/`period_end` coverage semantics.

- [ ] Write the migration integration test proving the new columns exist, reject reversed physical ranges, and permit an old row whose physical range is not yet backfilled.
- [ ] Run the focused backend migration test and confirm it fails because the fields do not exist.
- [ ] Add DBML and Flyway columns/check constraints; extend pipeline table metadata.
- [ ] Run migration and schema tests, refresh the Flyway CI bundle if the backend gitlink later moves, and record the authority instruction in the change.

### Task 2: Build resumable provider-neutral local history ingestion

**Files:**
- Create: `data-pipeline/market_pipeline_lib/local_history/model.py`
- Create: `data-pipeline/market_pipeline_lib/local_history/sources.py`
- Create: `data-pipeline/market_pipeline_lib/local_history/normalize.py`
- Create: `data-pipeline/market_pipeline_lib/local_history/publish.py`
- Create: `data-pipeline/apps/pipeline_worker/load_local_history.py`
- Create: `data-pipeline/tests/test_local_history_sources.py`
- Create: `data-pipeline/tests/test_local_history_publication.py`
- Modify: `data-pipeline/pyproject.toml`
- Modify: `data-pipeline/README.md`

**Interfaces:**
- Produces `HistoryRequirement(provider, symbol, instrument_id, resolution, start, end)` and `PublishedHistory(manifest_id, revision, object_ids, actual_start_at, actual_end_at, row_count, dataset_hash)`.
- Consumes existing Alpaca credentials from the ignored environment and explicit cash-index provider endpoints with no credential values in logs.

- [ ] Write source tests for Alpaca pagination, `Retry-After`, bounded retry, repeated page token, duplicate equality/conflict, and provider errors.
- [ ] Write normalization tests for UTC/ET DST boundaries, regular/early-close sessions, 30m ordering, deterministic 4h/1d aggregation, OHLC invariants, non-negative volume, and no interpolation.
- [ ] Write publication tests for interruption/resume, idempotent re-run, immutable revision, temporary-object failure, checksum mismatch, Parquet min/max/rows, and atomic `AVAILABLE` visibility.
- [ ] Run the tests and confirm each new behavior fails before implementation.
- [ ] Implement small focused model, source, normalization, and publisher modules by reusing existing calendar, Alpaca client, hashing, object storage, and repository primitives.
- [ ] Add a non-interactive CLI that defaults to AAPL/MSFT/META/AMZN/NVDA plus SPX/NDX, requires explicit `--execute`, and reports only non-secret ranges/counts/hashes.
- [ ] Run unit/property/integration suites and a dry-run plan; confirm no provider call occurs during plan.

### Task 3: Bind preview projections to canonical publications

**Files:**
- Modify: `scripts/local/project-local-market-history.py`
- Replace: `scripts/local/load-local-index-benchmarks.ps1`
- Create: `scripts/local/load-local-market-history.ps1`
- Modify: `scripts/restore-local-baseline.ps1`
- Modify: `backend/modules/backend-messaging/src/main/java/com/idea2strategy/backend/messaging/marketdata/MarketBarJsonCodec.java`
- Modify: `backend/modules/backend-messaging/src/main/java/com/idea2strategy/backend/messaging/marketdata/RedisMarketBarAdapter.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/marketdata/MarketBarService.java`
- Modify: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/marketdata/MarketBarController.java`
- Modify: `backend/modules/backend-messaging/src/test/java/com/idea2strategy/backend/messaging/marketdata/MarketBarJsonCodecTest.java`
- Modify: `backend/modules/backend-messaging/src/test/java/com/idea2strategy/backend/messaging/marketdata/RedisMarketBarAdapterTest.java`
- Modify: `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/marketdata/MarketBarServiceTest.java`
- Modify: `backend/apps/backend-api/src/test/java/com/idea2strategy/backend/api/marketdata/MarketBarControllerTest.java`

**Interfaces:**
- Preview projection schema v2 includes `manifestId`, `revision`, `datasetHash`, `objectHashes`, `actualFrom`, `actualTo`, `rowCount`, and `projectionHash`.
- API returns bars plus requested/actual window, coverage state, reason, and canonical provenance.

- [ ] Add codec/adapter/service/controller tests that reject missing, stale, corrupt, wrong-instrument, and wrong-timeframe provenance while retaining authenticated COMPLETE/PARTIAL/EMPTY responses.
- [ ] Run focused backend tests and observe the missing schema-v2/provenance failures.
- [ ] Implement projection-v2 generation strictly from verified Parquet and backend provenance validation.
- [ ] Replace the direct-to-Redis index script with the canonical ingestion wrapper; keep restore idempotent and offline after a successful publication.
- [ ] Run backend tests and compare first/middle/last AAPL/MSFT/META/NVDA API rows to independently read Parquet rows.

### Task 4: Prove requirement-specific manifest selection and streaming replay

**Files:**
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/OfficialBacktestInputSelector.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/StrategyReleaseInputCatalog.java`
- Modify: `backend/modules/backend-persistence/src/main/java/com/idea2strategy/backend/persistence/strategy/StrategyReleaseInputCatalogJooqQueryAdapter.java`
- Modify: `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/strategy/OfficialBacktestInputSelectorTest.java`
- Modify: `backend/modules/backend-persistence/src/test/java/com/idea2strategy/backend/persistence/strategy/StrategyReleaseInputCatalogPersistenceIntegrationTest.java`
- Modify: `backtest-engine/src/backtest_engine/basic_runtime.py`
- Modify: `backtest-engine/src/backtest_engine/data_availability.py`
- Modify: `backtest-engine/src/backtest_engine/persistence/market_data.py`
- Modify: `backtest-engine/tests/test_market_data_reader.py`
- Create: `backtest-engine/tests/test_partition_input_selection.py`

**Interfaces:**
- Produces a stable requirement-to-manifest binding keyed by `(instrument_id, data_kind, resolution)` with physical range, warm-up, rows, and checksum.
- Worker consumes only bound instruments/columns/row groups and merges adjacent revisions without gaps or conflicting duplicates.

- [ ] Add selector tests for one symbol, multiple symbols, 30m+4h+1d, warm-up, minimum cover, newer revision tie-break, instrument-scope mismatch, universe membership evidence, and reproducible repeat selection.
- [ ] Add worker tests for multiple manifests at one resolution, multiple resolutions, plan-filtered reads, gaps, duplicate equality/conflict, and post-publication replay stability.
- [ ] Run focused suites and capture the precise failing cases.
- [ ] Add physical evidence/membership fields to catalog queries and selection records, then bind each requirement explicitly.
- [ ] Make worker reads batch/row-group filtered and preserve deterministic event order without runtime resampling.
- [ ] Run selector, persistence, contract, and worker suites.

### Task 5: Complete actual cash-index API and result comparison UI

**Files:**
- Preserve and complete current backend changes under `apps/backend-api/.../MarketBenchmarkController.java`, `modules/backend-application/.../MarketBenchmarkCatalogPort.java`, and `modules/backend-persistence/.../marketdata/`
- Preserve and complete current UI changes in `src/api/marketData.ts`, `src/views/BacktestLiveView.tsx`, `src/styles/balanced.css`, and their tests/E2E fixtures

**Interfaces:**
- `GET /api/v1/market-data/benchmarks` returns exactly SPX/S&P 500 and NDX/NASDAQ-100 to authenticated customers.
- Result chart compares canonical strategy equity with actual SPX and NDX daily closes on the common interval.

- [ ] Finish backend authentication/catalog tests and prove benchmarks are not selectable trade instruments.
- [ ] Finish UI contract tests for exactly two cash indices, three line series, common-range clipping, no ETF labels, no interpolation, and precise partial/corrupt errors.
- [ ] Run the focused tests and correct current in-progress implementation failures.
- [ ] Remove all residual SPY/QQQ comparison paths and the internal implementation copy specified by the user.
- [ ] Verify responsive chart/monthly/result states at 1440, 768, and 390 widths.

### Task 6: Reconcile canonical performance and UTC lifecycle

**Files:**
- Modify: `backtest-engine/src/backtest_engine/orchestrator.py`
- Modify: `backtest-engine/src/backtest_engine/persistence/publish.py`
- Modify: `backtest-engine/src/backtest_engine/performance/metrics.py`
- Modify: `backtest-engine/src/backtest_engine/performance/monthly.py`
- Modify: focused lifecycle/performance/monthly tests
- Create: `scripts/local/repair-local-backtest-timestamps.py`
- Create: `scripts/local/tests/test_repair_local_backtest_timestamps.py`

**Interfaces:**
- All terminal timestamps are aware UTC and never precede starts/attempt completion.
- One canonical equity series defines summary and month-end returns.

- [ ] Add regression test reproducing the observed completed-run timestamp preceding its successful attempt.
- [ ] Add independent reconciliation tests for total/annualized return, MDD, Sharpe, realized/unrealized PnL, fees, fills, closing trades, win rate, and every monthly return.
- [ ] Run tests and verify the timestamp/reconciliation failures before changes.
- [ ] Fix clock boundaries and any calculation divergence without changing valid strategy semantics.
- [ ] Implement an idempotent local repair that updates only impossible terminal timestamps supported by immutable attempt/result evidence.
- [ ] Re-run terminal lifecycle tests including max retry, DLQ, stale recovery, protected heartbeat lease, cancellation, duplicate delivery, restart, invalid input, timeout, and resource failure.

### Task 7: Make Ultimate Strategy editable, defensible, and reproducible

**Files:**
- Modify: `scripts/local/sample_backtest_strategies.py`
- Modify: `scripts/local/tests/test_sample_backtest_strategies.py`
- Preserve and complete current UI schema compatibility changes in `src/lib/basicStrategyDocument.ts` and its tests
- Modify: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/strategy/StrategyDocumentController.java`
- Modify: `backend/apps/backend-api/src/test/java/com/idea2strategy/backend/api/strategy/StrategyDocumentControllerTest.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/BasicStrategyDraftCommandService.java`
- Modify: `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/strategy/BasicStrategyDraftCommandServiceTest.java`
- Create: `scripts/local/verify-ultimate-strategy.py`
- Create: `scripts/local/tests/test_verify_ultimate_strategy.py`

**Interfaces:**
- Seed/upsert one stable strategy named `THE ULTIMATE STRATEGY` using current Basic semantic and presentation schemas.
- Verification reports frozen configuration, in-sample, holdout, walk-forward, fills, metrics, cash-budget reconciliation, and no-lookahead evidence.

- [ ] Add round-trip tests for CLI-created current schema, older presentation migration, semantic equality after UI save, missing layout reconstruction, optimistic edit sequence, and no unnecessary JWT lease.
- [ ] Define multiple BUY and SELL conditions per partition across 30m/4h/1d using only supported Basic blocks; validate allocation/order/cash budgets.
- [ ] Run semantic compile and editor round-trip tests before executing any performance experiment.
- [ ] Freeze parameters using the in-sample interval, then run holdout and walk-forward checks without retuning from full-period results.
- [ ] Accept only real BUY/SELL fills across multiple years/months with reconciled finite metrics; otherwise adjust strategy logic using in-sample evidence and repeat the untouched holdout.

### Task 8: Load real data and independently verify it

**Files:**
- Create ignored local receipts below `.harness/local/market-history/`
- Create tracked non-sensitive evidence: `docs/evidence/canonical-local-market-history-and-ultimate-strategy.md`

**Interfaces:**
- Local MinIO/PostgreSQL/Redis retain all target data and evidence; tracked evidence contains no raw licensed bars or credentials.

- [ ] Run provider permission/coverage probes with redacted output.
- [ ] Execute target ingest from 2015-01-01 to the latest completed provider session and repeat it to prove idempotency.
- [ ] Query PostgreSQL for every target/resolution revision, physical range, rows, and checksum; ensure no BUILDING/QUARANTINED partial publication is selectable.
- [ ] Independently read every published Parquet footer and first/middle/last target rows, recompute SHA-256/row count/min/max, and compare API JSON.
- [ ] Run the mixed-resolution Ultimate backtest and independently reconcile all result/month/index values.
- [ ] Block provider egress for backend/worker, repeat preview/backtest/result reads, and compare online/offline hashes and logs.

### Task 9: Browser E2E, cleanup, security, and delivery

**Files:**
- Modify: `ui/e2e/backtest.e2e.ts`
- Modify/add focused preview and strategy E2E specs under `ui/e2e/`
- Modify: `scripts/restore-local-baseline.ps1`
- Update: `docs/evidence/canonical-local-market-history-and-ultimate-strategy.md`

**Interfaces:**
- Final local URL is `http://localhost:15173`; account remains `developer@idea2strategy.local` with the user-provided local password.

- [ ] Soft-delete experimental strategies/bots/runs while retaining immutable referenced evidence, Ultimate completed result, and optional failed/cancelled UI fixtures.
- [ ] Rotate the local database credential exposed by the diagnostic exception, update only ignored local configuration, restart all dependent containers, and prove the old credential fails.
- [ ] Run Docker E2E for login, strategy list/open/edit/save, AAPL/MSFT/META/NVDA 1m/3m preview, mixed-resolution request/date input, complete/fail/cancel, chart, monthly table, input evidence, and new-user empty state.
- [ ] Run all affected backend, backtest, data-pipeline, UI, root harness/Flyway tests, `git diff --check`, and secret scanners.
- [ ] Inspect every diff and status, commit per owning submodule, push each current feature branch, update root gitlinks/Flyway bundle, commit root evidence, and push `origin/fix/integrate-submodule-heads`.
- [ ] Re-read pushed commit hashes and produce the requested final evidence report before marking the Goal complete.
