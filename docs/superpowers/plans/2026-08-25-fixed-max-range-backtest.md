# Fixed Maximum-Range Backtest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run any of the 725 local instruments over the fixed maximum interval, seed useful complex BUY/SELL examples into the test account, repair real 1/3-month previews, and keep incomplete Basic drafts editable.

**Architecture:** A one-time approved local reset adopts all 725 backup instruments and immutable market objects into V1, while a new policy and pinned XNYS calendar cover the complete interval. Plan-aware reading avoids replaying unrelated instruments and a bounded history projection supplies real 1/3-month previews. Idempotent sample seeding and an independent oracle prove complex BUY/SELL behavior and exact result evidence.

**Tech Stack:** PowerShell, Python 3.12, PyArrow, pytest, FastAPI, PostgreSQL 16, MinIO, LocalStack/SQS, Java 21/Spring Boot, React/TypeScript, Playwright, Docker Compose.

**Spec:** `docs/superpowers/specs/2026-08-25-fixed-max-range-backtest-design.md`

## Global Constraints

- Fixed policy start is `2016-01-01T05:00:00Z`; fixed policy end is `2026-07-30T04:00:00Z` and is exclusive.
- The visible inclusive date range is `2016-01-01 ~ 2026-07-29`.
- The real-data reference universe contains all 725 backup instruments using one consistent UUID per instrument.
- Local operation must not require a mounted `D:` drive after normalization.
- Real-data bootstrap must never substitute synthetic prices while presenting the result as real.
- Seeded strategies require BUY and SELL fills, closing trades, and trades in at least two months.
- Seeded BUY and SELL flows each contain multiple meaningful conditions and are owned by `developer@idea2strategy.local`.
- Preview anchors to the latest available completed bar and offers 1-month and 3-month windows, defaulting to 3 months.
- Owned non-archived incomplete Basic drafts remain editable regardless of validation status.
- User-created zero-trade strategies remain valid completed results.
- Oracle code must not import production indicator or execution helpers.
- Existing applied Flyway migrations remain immutable.
- Every behavior change follows red-green-refactor.

---

### Task 1: Publish the fixed policy and extended pinned calendar

**Files:**
- Modify: `proposals/development-runtime-policy/artifacts/execution-policy.json`
- Modify: `proposals/development-runtime-policy/artifacts/policy-seed.sql`
- Modify: `proposals/development-runtime-policy/artifacts/artifact-manifest.json`
- Modify: `backtest-engine/src/backtest_engine/execution_policy.py`
- Create: `backtest-engine/src/backtest_engine/calendar/xnys_2016_2026.py`
- Modify: `backtest-engine/src/backtest_engine/calendar/__init__.py`
- Modify: `backtest-engine/src/backtest_engine/production.py`
- Test: `backtest-engine/tests/test_execution_policy.py`
- Test: `backtest-engine/tests/test_calendar.py`
- Test: `scripts/test-development-database-bootstrap.ps1`

**Interfaces:**
- Produces `official-backtest-policy-max-range-v1` with UTC boundaries `2016-01-01T05:00:00Z` and `2026-07-30T04:00:00Z`.
- Produces `XNYS_CALENDAR_2016_2026` and its immutable version string.

- [ ] **Step 1: Write failing policy-boundary tests**

Assert the loaded development artifact and Python catalog expose the exact version and boundaries, and that ET conversion renders the inclusive last date as `2026-07-29`.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
cd backtest-engine
uv run pytest tests/test_execution_policy.py tests/test_calendar.py -q
cd ..
./scripts/test-development-database-bootstrap.ps1
```

Expected: the old one-month policy and 2024-only calendar assertions fail.

- [ ] **Step 3: Add the immutable calendar and policy**

Pin regular closures, early closes, and known one-off closures from 2016 through 2026. Register the new calendar in production without editing the historical calendar object.

- [ ] **Step 4: Verify GREEN and commit submodule policy runtime**

Run the focused tests again, then commit Backtest changes with `feat: add maximum-range backtest policy calendar`.

---

### Task 2: Adopt the complete real-data universe

**Files:**
- Create: `scripts/local/normalize-backtest-reference-pack.py`
- Create: `scripts/local/reference_pack.py`
- Create: `scripts/local/tests/test_reference_pack.py`
- Modify: `.gitignore`
- Modify: `scripts/dev.ps1`
- Modify: `scripts/restore-local-baseline.ps1`

**Interfaces:**
- Produces ignored `local/backtest-reference-pack/v1/` containing the 725-instrument catalog, deterministic object index, `manifest.json`, and `receipt.json`.
- `build_reference_pack(source_root: Path, output_root: Path) -> ReferencePackReceipt` preserves the approved canonical instrument identities.
- `verify_reference_pack(output_root: Path) -> ReferencePackReceipt` verifies hashes, schemas, row counts, ordering, and boundaries without `D:`.

- [ ] **Step 1: Write failing importer tests**

Use tiny fixtures to prove complete catalog mapping, OHLCV preservation, deterministic hashes, duplicate-symbol rejection, missing-year rejection, exclusive-end enforcement, plan-instrument filtering, and verification after the source is unavailable.

- [ ] **Step 2: Run tests and verify RED**

Run: `backtest-engine/.venv/Scripts/python.exe -m pytest scripts/local/tests/test_reference_pack.py -q`

Expected: imports fail because the focused modules do not exist.

- [ ] **Step 3: Implement bounded streaming normalization**

Preserve source identities and immutable bytes where possible, create full-range registrations and an instrument-to-object index, and atomically promote a fully verified local catalog/receipt.

- [ ] **Step 4: Integrate idempotent bootstrap**

`scripts/dev.ps1` first verifies the normalized pack. It builds once from the approved backup if missing, and otherwise reports a precise path requirement. No path is hard-coded to `D:`.

- [ ] **Step 5: Run twice and commit root importer**

Run importer tests and two consecutive `scripts/dev.ps1 -BackOnly` initializations. Commit with `feat: normalize local backtest reference data`.

---

### Task 3: Register a full-range manifest and real RSI materializations

**Files:**
- Modify: `scripts/local/seed-basic-strategy-e2e.py`
- Modify: `scripts/local/materialize-local-strategy-features.py`
- Create: `scripts/local/tests/test_reference_pack_registration.py`
- Modify: `scripts/dev.ps1`

**Interfaces:**
- Produces one AVAILABLE 30m dataset manifest matching the fixed policy.
- Produces pinned RSI(14) materializations for instruments selected by seeded or user strategies, cached by immutable input hash.
- Re-running registration returns the same logical dataset and feature hashes.

- [ ] **Step 1: Write failing registration tests**

Assert manifest/policy boundary equality, object hash and row-count agreement, exact feature identity, real RSI values, unrelated-instrument exclusion, and idempotent second registration.

- [ ] **Step 2: Observe RED against the one-month artificial seed**

Run: `backtest-engine/.venv/Scripts/python.exe -m pytest scripts/local/tests/test_reference_pack_registration.py -q`

- [ ] **Step 3: Register immutable objects and compute published RSI**

Upload normalized parts to MinIO, insert current V1 catalog rows, and calculate RSI from real closes using the published definition. Do not use the former `20 + index % 30` artificial series.

- [ ] **Step 4: Verify registration and commit**

Run focused tests plus `./scripts/test-development-database-bootstrap.ps1`. Commit with `feat: register full-range local market inputs`.

---

### Task 4: Seed complex strategies and require positive trades

**Files:**
- Create: `scripts/local/sample_backtest_strategies.py`
- Modify: `scripts/local/seed-basic-strategy-e2e.py`
- Create: `scripts/local/tests/test_sample_backtest_strategies.py`
- Modify: `scripts/test-basic-strategy-real-e2e.ps1`

**Interfaces:**
- Produces stable sample keys `AAPL_MACD_SMA_TREND`, `MSFT_RSI_BOLLINGER_REVERSION`, and `LIQUID_MULTI_ASSET_PARTITION_CYCLE` owned by the test account.
- Each sample declares `minimum_fill_count`, `minimum_closing_trade_count`, and `minimum_trade_month_count` and includes separate BUY/SELL flows.

- [ ] **Step 1: Write failing semantic-shape tests**

Assert every sample has multiple meaningful conditions in both BUY and SELL flows, catalog-backed UUIDs, bounded allocation/caps, valid compiler arguments, and no single-block strategy.

- [ ] **Step 2: Write failing real-result contracts**

After actual execution, assert each completed run has positive BUY/SELL fills, positive closing trades, and at least two trade months. Print only run IDs and counts on failure.

- [ ] **Step 3: Run and observe the current zero-fill failure**

Run: `./scripts/test-basic-strategy-real-e2e.ps1`

Expected: the current over-constrained sample reports `fillCount=0`.

- [ ] **Step 4: Implement idempotent sample creation and empirical parameter selection**

Use fixed literal parameters selected from offline real-series analysis. Store them in source, not in a runtime tuner. Bootstrap creates/releases/runs samples once per semantic hash and waits on condition-based completion.

- [ ] **Step 5: Verify all positive-trade contracts and commit**

Run sample unit tests and real E2E twice. Commit with `feat: seed trade-producing complex strategies`.

---

### Task 5: Add an independent semantic and accounting oracle

**Files:**
- Create: `scripts/integration/backtest_semantic_oracle.py`
- Create: `scripts/integration/test_backtest_semantic_oracle.py`
- Create: `scripts/integration/fixtures/reference_trade_expectations.v1.json`
- Modify: `scripts/test-basic-strategy-real-e2e.ps1`

**Interfaces:**
- `calculate_rsi(closes: Sequence[Decimal], period: int) -> list[Decimal | None]`
- `calculate_macd(closes: Sequence[Decimal], fast: int, slow: int, signal: int) -> list[MacdPoint | None]`
- `expected_signals(strategy: Mapping, bars: Sequence[Bar]) -> tuple[ExpectedSignal, ...]`
- `reconcile_run(run_id: UUID, raw_pack: Path, api: BacktestApi) -> ReconciliationReport`

- [ ] **Step 1: Write oracle unit tests from hand-calculated series**

Cover flat, monotonic, alternating, threshold equality, crossing direction, warm-up boundary, and completed-bar-only cases without importing `backtest_engine` indicator code.

- [ ] **Step 2: Run oracle tests and verify RED**

Run: `backtest-engine/.venv/Scripts/python.exe -m pytest scripts/integration/test_backtest_semantic_oracle.py -q`

- [ ] **Step 3: Implement independent calculations and event reconciliation**

Recompute indicator points and exact signal transitions. Apply the published next-eligible-bar, slippage, fee, precision, and position rules independently, then compare API and immutable detail records.

- [ ] **Step 4: Add mutation-sensitive assertions**

Tests must fail if RSI is replaced with SMA, MACD fast/slow periods are swapped, a variable edit is ignored, a signal moves one bar early, BUY slippage uses the SELL direction, a fee is omitted, or one trade-history row disappears.

- [ ] **Step 5: Verify real runs and commit**

Run the oracle unit suite and real reconciliation for all three samples. Commit with `test: reconcile backtests with independent oracle`.

---

### Task 6: Repair preview, incomplete-draft entry, and trade history UI

**Files:**
- Modify: `ui/src/views/BacktestViews.tsx`
- Modify: `ui/src/views/StrategyViews.tsx`
- Modify: `ui/src/api/marketData.ts`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/marketdata/MarketBarService.java`
- Modify: `backend/modules/backend-messaging/src/main/java/com/idea2strategy/backend/messaging/marketdata/RedisMarketBarAdapter.java`
- Modify: `ui/src/lib/backtestApi.ts`
- Modify: `ui/src/BacktestViews.test.tsx`
- Modify: `ui/e2e/basic-strategy-real.e2e.ts`

**Interfaces:**
- Displays `2016-01-01 ~ 2026-07-29` as read-only official period.
- Preview defaults to the latest available 3 months and switches to 1 month without consulting the browser clock.
- Every owned non-archived Basic draft is reachable from the whole row, action, keyboard, direct URL, and refresh.
- Monthly trade rows show side, instrument, signal/evaluation time, fill time, quantity, price, fee, and realized PnL when present.

- [ ] **Step 1: Write failing UI tests**

Assert fixed-period copy, populated/empty trade history, exact 1/3-month preview ranges, variable-sensitive markers, and incomplete-draft navigation through every supported entry path.

- [ ] **Step 2: Run UI RED tests**

Run: `cd ui; pnpm test --run src/BacktestViews.test.tsx`

- [ ] **Step 3: Implement minimal presentation changes**

Consume authoritative run and market-data ranges, render them read-only, map real trades, add the 1/3-month preview control, and separate draft editability from validation completeness.

- [ ] **Step 4: Run unit, type, build, and Playwright verification**

Run `pnpm test --run`, `pnpm typecheck`, `pnpm build`, and the real Basic Playwright flow. Commit UI changes with `feat: show fixed backtest period and trades`.

---

### Task 7: Full-stack idempotency and negative-state verification

**Files:**
- Modify: `scripts/test-basic-strategy-real-e2e.ps1`
- Modify: `scripts/integration/test_basic_strategy_matrix_e2e.py`
- Create: `docs/evidence/fixed-max-range-backtest.md`

**Interfaces:**
- Produces an ignored receipt containing sample strategy IDs, run IDs, counts, hashes, and reconciliation status but no tokens or credentials.

- [ ] **Step 1: Add fixed-period and data-gap assertions**

Prove all three samples pin the same period, missing pack returns typed unavailable, insufficient warm-up is not false, restrictive user strategy warns, and a legitimate zero-trade user run completes with an empty history.

- [ ] **Step 2: Run the complete workflow twice**

Run `./scripts/test-basic-strategy-real-e2e.ps1` twice without D: and without deleting PostgreSQL or MinIO state. Expected: stable logical hashes and new/reused IDs according to idempotency contracts.

- [ ] **Step 3: Record evidence**

Document actual fixed boundaries, normalized row counts/hashes, sample fill and closing counts, trade months, selected oracle timestamps/values, test counts, and exact commands.

- [ ] **Step 4: Commit root integration evidence**

Commit with `test: prove fixed maximum-range backtests`.

---

### Task 8: Verification, review, push, and local handoff

**Files:**
- No predetermined production files; any defect fix begins with a reproducing regression test.

**Interfaces:**
- Produces reachable submodule commits, a root branch with exact gitlinks, green required checks, and running local services.

- [ ] **Step 1: Run repository verification**

Run affected Backend tests, the full Backtest test/lint/type suite, UI test/type/build suite, Flyway bundle tests, policy artifact verification, matrix E2E, semantic oracle, and real Playwright E2E.

- [ ] **Step 2: Run secret-safety checks before push**

Scan staged and tracked changes with repository hooks without printing credential values. Confirm local receipts, normalized data, tokens, and backup metadata remain ignored.

- [ ] **Step 3: Request code review and fix confirmed findings**

Use `superpowers:requesting-code-review`, reproduce each accepted finding, fix through TDD, and rerun the complete affected matrix.

- [ ] **Step 4: Push submodules then root**

Announce each push, push only task branches, verify root gitlinks are reachable, and create the root PR with the approved `user:kcrmin` decision and exact evidence.

- [ ] **Step 5: Merge only after required checks**

Wait for GitGuardian and all required checks. After merge, fetch and verify remote `develop` heads and clean worktrees.

- [ ] **Step 6: Restart and report local access**

Start the deploy-like local stack and report URL `http://localhost:15173/login`, account `developer@idea2strategy.local`, password `TestUser!2026`, seeded strategy names, and verified run IDs/counts.
