# Canonical local market history and Ultimate Strategy evidence

Verified on 2026-08-29 in the `product-integrity-hardening` worktree. This document records reproducible local evidence; it intentionally contains no credentials, session tokens, or licensed raw bars.

## Delivered behavior

- Market preview reads authenticated Redis projections rebuilt from immutable MinIO Parquet objects. It never synthesizes bars and anchors one- and three-month windows to each instrument/resolution's latest stored bar.
- PostgreSQL manifests and objects now retain logical and independently measured physical ranges. Selection rejects incomplete publications and can choose only the manifests needed by each strategy partition.
- A benchmark API exposes locally retained S&P 500 (`SPX`) and NASDAQ-100 (`NDX`) cash-index series. Backtest UI compares cumulative performance as lines and derives the monthly matrix from the canonical equity series.
- Terminal backtest timestamps are constrained and normalized to aware UTC. Completion cannot precede the successful attempt. Existing retry, DLQ, stale lease/heartbeat, cancellation, idempotency, and restart paths remain covered by the full engine suite.
- `THE ULTIMATE STRATEGY` opens in the current Basic editor without destructive fallback. It contains three mixed-resolution partitions, multiple buy/sell conditions, and eight supported cards: drawdown-from-peak, equal-allocation order, position return, price compare, RSI cross, schedule, and SMA cross.

## Actual retained market data

Equity source is the canonical adjusted Alpaca SIP ALL feed already retained locally. Index source is Yahoo Finance chart-v8 cash-index history, validated before immutable publication. The physical verifier hashes complete Parquet objects, checks row counts and footer/time ranges, and compares projected/API OHLCV rows.

| Instrument | Resolution | Physical UTC range | Rows |
|---|---:|---:|---:|
| AAPL, MSFT, AMZN, NVDA | 30m | 2016-01-05 through 2026-07-29 | 34,376 each |
| AAPL, MSFT, AMZN, NVDA | 1h | 2016-01-06 through 2026-07-29 | 18,510 each |
| AAPL, MSFT, AMZN, NVDA | 4h | 2016-01-13 through 2026-07-29 | 5,277 each |
| AAPL, MSFT, AMZN, NVDA | 1d | 2016-01-25 through 2026-07-29 | 2,643 each |
| META | 30m | 2021-07-01 through 2026-07-29 | 15,330 |
| META | 1h | 2021-07-02 through 2026-07-29 | 8,251 |
| META | 4h | 2021-06-30 through 2026-07-29 | 2,360 full-source rows |
| META | 1d | 2021-07-21 through 2026-07-29 | 1,171 |
| SPX, NDX | 1d | 2015-01-02 through 2026-08-28 | 2,931 each |

The requested 2015 start is present for both benchmarks. The available local Alpaca equity archive begins in 2016 for four symbols and in 2021 for META. The D drive was not mounted and no Alpaca credential was present during verification, so earlier META/equity bars were not invented or misreported. Load scripts are idempotent and can extend these ranges when an authorized source becomes available.

## Local data and API proof

- Physical-range backfill: 49 manifests and 404 objects verified and updated; 28 genuinely empty objects retained as empty.
- Redis projection after rebuild: `30m=620,691`, `1h=623,549`, `4h=509,741`, `1d=387,738`; 2,560 projected keys.
- Independent spot checks matched Parquet and API first/last values for AAPL 30m/4h/1d, MSFT 4h, META 4h, NVDA 30m, SPX 1d, and NDX 1d. Example preview ends were 2026-07-29 for equities and 2026-08-28 for indexes.
- Offline runtime check placed every API and worker on an internal-only Docker network, proved provider egress was blocked, and still read 43 one-month bars, 125 three-month bars, both benchmarks, and the retained completed backtest.
- The same offline check created a fresh 2024-01-01 through 2024-12-31 Ultimate Strategy backtest. It reached `COMPLETED` in about 13 seconds, pinned five immutable inputs, and returned 25.76496159%; the proof run was then soft-deleted. Backend, batch, backtest, and trading container logs contained zero external market-provider domain references during the run.

## Demo resources and reconciled result

- Strategy: `9ec38a5c-efce-4146-b9e1-2ac880b35574` (`THE ULTIMATE STRATEGY`)
- Bot: `9333718c-0d10-314d-bda9-9536eff2d705`
- Completed backtest: `bc9a35d1-bec2-399a-88c5-b343ba57c854`, 2016-01-01 through 2026-07-29
- Retained lifecycle examples: one cancelled and one failed execution; experimental records were soft-deleted.

The completed result reconciled to a 209.17969718% total return, 11.2742% annualized return, -14.90967731% maximum drawdown, 0.56073482 Sharpe ratio, 22.4213666% volatility, 384 fills, 166 closing trades, 80 wins, 86 losses, 4,048.90080680 fees, 1,012.26921090 slippage, and 309,179.69718230 ending equity. The canonical performance series produced 127 monthly cells (37 positive, 24 negative, 66 flat). Over the common 2016-01-04 through 2026-07-29 range, retained benchmark returns were 262.78% for SPX and 506.41% for NDX.

## Verification matrix

- Backend full Gradle suite: passed, 64 tasks.
- Trading Engine full Gradle suite: passed, 44 tasks.
- Backtest Engine full pytest suite and Ruff: passed.
- Data Pipeline: 1,235 passed, 26 LocalStack-gated skipped, 69 subtests; Ruff passed.
- UI: 58 files and 689 tests passed; TypeScript check and production build passed.
- Real-stack Playwright: `opens THE ULTIMATE STRATEGY across its three real-data resolutions` passed. It opened the editor and switched actual AAPL/MSFT/META/NVDA previews across 30m/4h/1d and one-/three-month windows; visible chart last rows matched API `availableTo`.
- Flyway pinned bundle: eight migrations applied successfully and the second migrate was idempotent.
- Formatting/compilation: root `git diff --check`, Python script compilation, and UI typecheck passed.
- Secret scan: Gitleaks 8.28.0 scanned every staged root/submodule diff with redaction enabled and found no leaks. The local database credential was rotated; the previous credential was rejected; customer sessions were revoked after diagnostics.

## Reproduction entry points

- UI: `http://localhost:15173`
- API: `http://localhost:18080`
- Offline proof: `pwsh scripts/local/verify-offline-runtime.ps1 -TestEmail <local-test-email> -TestPassword <local-test-password>`
- Parquet/API proof: `pwsh scripts/local/verify-local-market-history.ps1`
- Physical range repair: `pwsh scripts/local/backfill-local-physical-ranges.ps1`
- Index load: `pwsh scripts/local/load-local-index-benchmarks.ps1`
- Target equity load: `pwsh scripts/local/load-local-target-equities.ps1`
