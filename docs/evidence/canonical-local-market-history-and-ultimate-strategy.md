# Canonical local market history and Ultimate Strategy evidence

Verified on 2026-08-30 in the `product-integrity-hardening` worktree. This document records reproducible local evidence; it intentionally contains no credentials, session tokens, or licensed raw bars.

## Delivered behavior

- Market preview reads authenticated Redis projections rebuilt from immutable MinIO Parquet objects. It never synthesizes bars and anchors one- and three-month windows to each instrument/resolution's latest stored bar.
- PostgreSQL manifests and objects now retain logical and independently measured physical ranges. Selection rejects incomplete publications and can choose only the manifests needed by each strategy partition.
- A benchmark API exposes locally retained S&P 500 (`SPX`) and NASDAQ-100 (`NDX`) cash-index series. Backtest UI compares cumulative performance as lines and derives the monthly matrix from the canonical equity series.
- Terminal backtest timestamps are constrained and normalized to aware UTC. Completion cannot precede the successful attempt. Existing retry, DLQ, stale lease/heartbeat, cancellation, idempotency, and restart paths remain covered by the full engine suite.
- Feature backfill now treats a legacy success without one current AVAILABLE output and exact source-object lineage as stale. Same-year feature windows cannot accidentally supersede a different period, local S3 normalization hashes the downloaded bytes instead of trusting metadata, and composite manifests extend only the instrument scopes proven by their object shard keys.
- `THE ULTIMATE STRATEGY` opens in the current Basic editor without destructive fallback. It contains three mixed-resolution partitions, multiple buy/sell conditions, and eight supported cards: drawdown-from-peak, equal-allocation order, position return, price compare, RSI cross, schedule, and SMA cross.

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
- Offline runtime check placed every API and worker on an internal-only Docker network, proved provider egress was blocked, and still read 43 one-month bars, 125 three-month bars, both benchmarks, and the retained completed backtest.
- The same offline check created a fresh 2024-01-01 through 2024-12-31 Ultimate Strategy backtest. It reached `COMPLETED` in about 13 seconds, pinned five immutable inputs, and returned 25.76496159%; the proof run was then soft-deleted. Backend, batch, backtest, and trading container logs contained zero external market-provider domain references during the run.

## Demo resources and reconciled result

- Strategy: `9ec38a5c-efce-4146-b9e1-2ac880b35574` (`THE ULTIMATE STRATEGY`)
- Bot: `9333718c-0d10-314d-bda9-9536eff2d705`
- Completed backtest: `59d02aff-874c-3097-b685-1667a3b25d25`, 2016-01-01 through 2026-07-29
- Retained lifecycle examples: one cancelled and one failed execution; experimental records were soft-deleted.

The completed result and published summary share result hash `b20e351c3dad2baddc2807893908310edfb1cd29d84f23781fbde5b6a8abc71e`. It reconciled to a 245.4808299% total return, 12.4495% annualized return, -22.37144933% maximum drawdown, 0.96431541 Sharpe ratio, 13.0759569% volatility, 886 fills, 397 closing trades, 192 wins, 205 losses, 8,708.15976729 fees, 2,177.10403335 slippage, 254,188.98966665 realized PnL, and 345,480.82989936 ending equity. The engine published 2,658 valuation points, 6,488 trade-detail rows, 3,055 replay-ledger rows, and 16,380 position snapshots. It selected the exact mixed-resolution inputs: eleven 1d manifests, one composite 30m manifest, forty-one 4h manifests, and one immutable feature pin. Over the common 2016-01-04 through 2026-07-29 range, retained benchmark returns were 262.78% for SPX and 506.41% for NDX.

## Verification matrix

- Backend full Gradle suite: passed, 64 tasks.
- Trading Engine full Gradle suite: passed, 44 tasks.
- Backtest Engine full pytest suite and Ruff: passed.
- Data Pipeline: 1,249 passed, 26 explicitly LocalStack-gated skipped, 69 subtests; Ruff passed.
- Root local-data scripts: 22 passed; changed-file Ruff checks passed.
- UI: 58 files and 689 tests passed; TypeScript check and production build passed.
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
