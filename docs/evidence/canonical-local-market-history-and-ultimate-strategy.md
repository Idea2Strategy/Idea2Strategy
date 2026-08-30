# Canonical local market history and Ultimate Strategy evidence

Verified on 2026-08-30 in the `product-integrity-hardening` worktree. This document records reproducible local evidence; it intentionally contains no credentials, session tokens, or licensed raw bars.

## Delivered behavior

- Market preview reads authenticated Redis projections rebuilt from immutable MinIO Parquet objects. It never synthesizes bars and anchors one- and three-month windows to each instrument/resolution's latest stored bar.
- PostgreSQL manifests and objects now retain logical and independently measured physical ranges. Selection rejects incomplete publications and can choose only the manifests needed by each strategy partition.
- A benchmark API exposes locally retained S&P 500 (`SPX`) and NASDAQ-100 (`NDX`) cash-index series. Backtest UI compares cumulative performance as lines and derives the monthly matrix from the canonical equity series.
- Completed-run reads no longer reconstruct all 2,208 weekly detail objects for every screen request. Execution metadata reads only the immutable result object, while the performance chart reads and verifies only `CALCULATION_SERIES` parts in parallel. A rebuilt-container browser run rendered the complete result instead of remaining on the loading state.
- Terminal backtest timestamps are constrained and normalized to aware UTC. Completion cannot precede the successful attempt. Existing retry, DLQ, stale lease/heartbeat, cancellation, idempotency, and restart paths remain covered by the full engine suite.
- Feature backfill now treats a legacy success without one current AVAILABLE output and exact source-object lineage as stale. Same-year feature windows cannot accidentally supersede a different period, local S3 normalization hashes the downloaded bytes instead of trusting metadata, and composite manifests extend only the instrument scopes proven by their object shard keys.
- `THE ULTIMATE STRATEGY` opens in the current Basic editor without destructive fallback. It contains three mixed-resolution partitions, two buy and two sell cards per partition, and meaningful non-zero thresholds. The saved cards exercise price, volume, SMA, RSI, MACD, schedule, holding-period, position-return, peak-return, drawdown, and allocation-order behavior.

## Actual retained market data

Equity source is the canonical adjusted Alpaca SIP ALL feed already retained locally. Index source is Yahoo Finance chart-v8 cash-index history, validated before immutable publication. The physical verifier hashes complete Parquet objects, checks row counts and footer/time ranges, and compares projected/API OHLCV rows.

| Instrument | Resolution | Physical UTC range | Rows |
|---|---:|---:|---:|
| AAPL, AMZN, META, MSFT, NVDA | 30m | 2016-01-04 through 2026-08-28 | 34,676 each |
| AAPL, AMZN, META, MSFT, NVDA | 1h | 2016-01-04 through 2026-08-28 | 18,678 each |
| AAPL, AMZN, META, MSFT, NVDA | 4h | 2016-01-04 through 2026-08-28 | 5,335 each |
| AAPL, AMZN, META, MSFT, NVDA | 1d | 2016-01-04 through 2026-08-28 | 2,679 each |
| SPX, NDX | 1d | 2015-01-02 through 2026-08-27 | 2,930 each |

The requested 2015 start is present for both benchmarks. The refreshed Alpaca SIP archive now gives all five target equities the same 2016 start and 2026-08-28 end. A second complete loader run returned `publishedManifests=0`, proving the 220 active yearly manifests are idempotent. Provider credentials remain only in the ignored local environment file and are never written to this evidence or Git.

## Local data and API proof

- Redis projection after rebuild: `30m=493,798`, `1h=622,261`, `4h=487,927`, `1d=375,851`; 2,556 projected keys.
- All 20 equity symbol/resolution combinations independently matched the hash-verified Parquet sources, Redis row order, timestamps, and OHLCV. Browser previews ended at the stored equity date 2026-08-28 rather than today's date.
- Browser checks covered AAPL and META one- and three-month windows and AAPL/MSFT/META/NVDA changes across the strategy's actual 30m/4h/1d clocks. The visible chart range and last OHLCV row matched the API and Parquet source.
- Offline runtime check placed every API and worker on an internal-only Docker network, proved provider egress was blocked, and still read 47 one-month bars, 129 three-month bars, both benchmarks, and the retained completed backtest.
- The same offline check created a fresh 2024-01-01 through 2024-12-31 Ultimate Strategy backtest. It reached `COMPLETED`, pinned 10 immutable instrument/year inputs across the strategy's three resolutions, and returned -3.5119874%; the proof run was then soft-deleted. Backend, batch, backtest, and trading container logs contained zero external market-provider domain references during the run.

## Demo resources and current reconciled result

- Strategy: `9ec38a5c-efce-4146-b9e1-2ac880b35574` (`THE ULTIMATE STRATEGY`)
- Bot: `78bbaa0b-72bb-3ce6-ad94-bfe01bfa4372`
- Completed backtest: `cd7b154f-5618-3bcd-a15c-175ce39d054c`, 2016-01-01 through 2026-07-29
- The owner-visible library has one strategy, one released bot, and one completed backtest. Experimental, failed, and cancelled proof records were soft-deleted after their lifecycle assertions passed.

The current result replaces an earlier optimistic result that was contaminated by an over-broad shared manifest and by valuation/accounting inconsistencies. The corrected result hash is `e4a461d9a56377de71969f08bb90876f8a230afc4de7bbc4e09bb719163f4785`. It reconciles to -46.20175565% total return, -5.6983% annualized return, -47.4670059% maximum drawdown, -0.41743868 Sharpe ratio, 12.2788% volatility, 9,953 fills, 2,689 closing trades, 52.1383% win rate, 115,676.45 fees, 28,919.13 slippage, 69,142.59 realized PnL, 53,798.24434831 ending equity, and 16,527.56434831 ending cash. The series has 2,658 daily valuations and 127 monthly returns: 59 positive, 68 negative, and zero exactly-flat months. Best month was 2023-03 at +6.26559151%; worst was 2022-09 at -9.21344357%.

The run pins exactly 55 instrument-scoped yearly manifests: AAPL and MSFT 4-hour bars, META and AMZN 30-minute bars, and NVDA daily bars. No shared composite manifest is used. Across those immutable objects the independent audit read 82,701 market rows. It also read all 2,208 result-detail objects and 21,548 trade records. Every object hash and row count matched PostgreSQL, all OHLC invariants held, no duplicate market key existed, all 9,953 fill identifiers were unique, every fill base price matched the authoritative execution-bar open, the 0.2% fee and 0.05% slippage rules matched exactly, and cash plus marked positions reconciled to equity with zero error. Over the common 2016-01-04 through 2026-07-29 range, retained benchmark returns remain 262.78% for S&P 500 and 506.41% for NASDAQ-100.

### Exact saved strategy composition

- AAPL/MSFT, 4-hour, 40% partition: SMA 5/20 plus 20-bar average-volume entry; price-above-previous-close plus volume entry; 3% loss plus price-below-previous-close exit; five-bar holding plus price-below-previous-close exit.
- META/AMZN, 30-minute, 35% partition: RSI upward cross at 45 plus price confirmation; daily scheduled price-confirmed entry; RSI downward cross at 60 plus price confirmation exit; 26-bar holding plus price confirmation exit.
- NVDA, daily, 25% partition: MACD 12/26/9 upward cross plus price confirmation; daily scheduled price-confirmed entry; 12% peak return plus 8% drawdown exit; 20-trading-day holding plus price confirmation exit.
- Every buy order uses at most 10% of its strategy-card budget; sell cards close 100% of the held position. Per-symbol caps are 20% for AAPL/MSFT, 17% for META/AMZN, and 25% for NVDA.
- The comparison chart's single 0% point is the common starting baseline used to normalize strategy, S&P 500, and NASDAQ-100. It is labeled as such in the UI; it is not a zero-return strategy interval. The monthly series contains no exactly-flat month.

## Verification matrix

- Backend full Gradle suite: passed, 64 tasks.
- Trading Engine full Gradle suite: passed, 44 tasks.
- Backtest Engine: Ruff passed; 1,390 default tests passed (2 skipped), and 165 Docker integration tests passed (10 environment-gated skips).
- Data Pipeline: 1,249 passed, 26 explicitly LocalStack-gated skipped, 69 subtests; Ruff passed.
- Root local-data scripts: 20 passed; changed-file Ruff checks passed.
- UI: 59 files and 696 tests passed; TypeScript check and production build passed.
- Playwright contract E2E: 11 passed. Real-stack Playwright opened THE ULTIMATE STRATEGY across its three real-data resolutions, verified its multiple immutable dataset inputs and feature pin, then independently created and validated a composite Basic strategy, released its bot, waited for an official backtest to complete, checked its immutable input hashes, and rendered the result. Temporary strategies, bots, and runs were soft-deleted afterwards.
- CLI deletion route was exercised against the rebuilt Docker API. Strategy controller registration no longer depends on Spring bean-discovery order, and the final library contains only THE ULTIMATE STRATEGY plus its released bot.
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
