# Backtest Benchmark and UI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the activity overview with an official strategy-versus-market cumulative-return comparison and make product typography, spacing, alignment, color, and remote states consistently readable.

**Architecture:** Expose immutable equity points from the backtest detail Parquet through the existing result-query boundary, load actual adjusted daily bars for benchmark ETFs, and normalize only their common observed interval in the UI. Consolidate shared visual rules through tokens and common state components, then enforce them with structural and browser-computed-style audits.

**Tech Stack:** Python 3.13, FastAPI, PyArrow, Java 21, Spring Boot, Redis, React 19, TypeScript, SVG, Vitest, Testing Library, Docker Compose.

**Spec:** `docs/superpowers/specs/2026-08-26-backtest-benchmark-and-ui-foundation-design.md`

## Global Constraints

- Never generate, interpolate, or silently substitute market or performance data.
- Preserve immutable backtest result hashes and non-enumerating ownership behavior.
- Compare series only over their common actual observation interval and label that interval.
- Meaningful text must not render below 11px.
- Strategy semantics and compiled plans remain unchanged.

---

### Task 1: Official equity-series result API

**Files:**
- Modify: `backtest-engine/src/backtest_engine/result_query.py`
- Modify: `backtest-engine/src/backtest_engine/api.py`
- Test: `backtest-engine/tests/test_result_query.py`
- Test: `backtest-engine/tests/test_backtest_api.py`

**Interfaces:**
- Produces: `GET /api/v1/backtests/{runId}/performance-series` returning ordered `{occurredAt,equity}` points and result hashes.

- [x] Add a failing service test that reads `CALCULATION_SERIES/equity` rows and rejects duplicate or invalid points.
- [x] Add failing API tests for authentication, ownership, not-ready, and completed responses.
- [x] Implement fail-closed Parquet reading and the authenticated route.
- [x] Run focused result-query and API tests.

### Task 2: Actual benchmark bar range

**Files:**
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/marketdata/MarketBarService.java`
- Test: `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/marketdata/MarketBarServiceTest.java`
- Modify: `ui/src/api/marketData.ts`
- Test: `ui/src/api/marketData.test.ts`

**Interfaces:**
- Consumes: actual adjusted `1d` Redis history for SPY, QQQ, and IWM.
- Produces: a bounded recent-history request and explicit actual coverage.

- [x] Add failing backend and UI tests for a 5,000-point daily request and actual coverage metadata.
- [x] Increase only the bounded historical-read limit; keep authentication and source unchanged.
- [x] Run focused backend and UI contract tests.

### Task 3: Cumulative-return comparison model and chart

**Files:**
- Create: `ui/src/lib/backtestComparison.ts`
- Test: `ui/src/lib/backtestComparison.test.ts`
- Modify: `ui/src/api/backtests.ts`
- Test: `ui/src/api/backtests.test.ts`
- Modify: `ui/src/views/BacktestLiveView.tsx`
- Test: `ui/src/BacktestLiveView.test.tsx`

**Interfaces:**
- Consumes: official equity points and actual benchmark closes.
- Produces: common-range normalized line series and coverage notices.

- [x] Add failing normalization tests for common range, non-overlap, missing points, and exact percentage arithmetic.
- [x] Add failing client contract tests for performance-series parsing.
- [x] Add failing view tests for strategy/SPY/QQQ lines, benchmark toggles, coverage copy, and absence of activity series in the overview.
- [x] Implement the model, client, loading/error states, and responsive accessible line chart.
- [x] Keep activity diagnostics in monthly analysis only and run focused tests.

### Task 4: Product UI foundation and state coherence

**Files:**
- Modify: `ui/src/styles/tokens.css`
- Modify: `ui/src/styles/base.css`
- Modify: `ui/src/styles/balanced.css`
- Modify: `ui/src/components/common.tsx`
- Modify only where an audit identifies loose alerts: account, notification, strategy, bot, backtest, competition, and operator components.
- Test: existing App and route/view suites plus a new style-policy test.

**Interfaces:**
- Produces: one readable type scale, centered content geometry, consistent control/state layout, and secondary diagnostic-code styling.

- [x] Add failing policy tests for the meaningful-font minimum.
- [x] Replace conflicting undersized core typography with the shared readable minimum.
- [x] Audit signed-in product routes for overflow, alignment, font family, font size, padding, and state hierarchy.
- [x] Fix each reproducible violation with a regression assertion.

### Task 5: Full-stack proof and delivery

**Files:**
- Modify only when verification exposes a failing behavior, with a failing test first.

- [x] Rebuild affected Docker services and wait for health.
- [x] Compare API equity points to original Parquet and benchmark returns to original Redis daily bars.
- [ ] Run backtest-engine, backend, and full UI suites, typecheck, and production build.
- [x] Verify actual completed, cancelled, empty, and recoverable error states in the browser.
- [ ] Run secret gates, inspect diffs, commit submodules and root, and push the current branches.
