# Backtest Benchmark Comparison and UI Foundation Design

## Product outcome

The backtest result must answer whether the strategy outperformed passive market exposure. The primary visualization is therefore cumulative return, not evaluation activity. Every product screen must also share one readable type, spacing, alignment, color, and remote-state hierarchy.

## Performance comparison

- The strategy curve comes only from the official run's persisted `CALCULATION_SERIES` Parquet rows where `metric_id=equity`.
- Default benchmarks are `S&P 500 (SPY)` and `NASDAQ-100 (QQQ)`. `Russell 2000 (IWM)` is an optional third comparison when local data exists.
- Benchmark values use actual locally stored adjusted daily closes. No generated, interpolated, or fallback prices are allowed.
- Each selected series is rebased to 0% at the first date in the common comparison interval. The common interval begins at the latest first observation and ends at the earliest last observation across the strategy and selected benchmarks.
- The UI shows the official run interval and common comparison interval separately. Partial or absent benchmark coverage is named with the symbol and actual available dates.
- The chart is a responsive line chart with a time x-axis and percentage y-axis, zero line, direct legend values, hover/focus inspection, and accessible summary. Activity counts remain available only in monthly analysis.
- If the strategy equity series is absent or invalid, the completed result is not represented with a fabricated flat line; the user sees a result-data error.

## API contracts

- `GET /api/v1/backtests/{runId}/performance-series` requires the same user authentication and non-enumerating ownership rule as other result routes.
- A non-completed run returns the existing `409 BACKTEST_RESULT_NOT_READY` contract.
- A completed run returns ordered unique points `{ occurredAt, equity }` plus immutable result hashes. Corrupt, duplicate, non-equity, or non-finite rows fail closed.
- The market-bar endpoint accepts a larger bounded daily-bar limit sufficient for the locally retained history; the existing authentication and actual Redis history source remain unchanged.

## UI foundation

- `--fs-micro: 11px` is the absolute minimum for meaningful text. Body copy is at least 14px, controls 13px, section headings 17px, and page headings 28–40px.
- Monospace is reserved for hashes, identifiers, code, and numeric tabular values. Korean status/error prose always uses the sans family.
- Page content uses a centered 1200–1280px container, 24–32px desktop gutters, 16–20px mobile gutters, and no unexplained left anchoring.
- Buttons use one height scale, visible primary/secondary/destructive hierarchy, minimum 44px touch targets on narrow screens, and no unlabeled duplicate actions.
- Loading, empty, stale, error, forbidden, and authentication states use shared components. Raw server codes appear as secondary diagnostic detail, never as the headline or loose unstyled text.
- Error copy states what failed, whether existing data is still usable, and the next valid action.

## Verification

- Contract tests compare returned equity points to original Parquet calculation-series rows.
- Benchmark tests compare normalized return points to actual SPY/QQQ adjusted closes and prove common-range clipping.
- UI tests prove that the primary chart contains strategy and selected benchmark line series and contains no activity-count series.
- A browser audit covers signed-in primary routes and signed-out/auth/operator routes at 1440px, 768px, and 390px, checking horizontal overflow, meaningful text below 11px, inconsistent font families, and state/action layout.
- Production build, component suites, Docker services, and actual browser comparison must pass before delivery.
