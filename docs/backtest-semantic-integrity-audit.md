# Backtest semantic-integrity audit

Status: VERIFIED; COMPONENT PRS MERGED; ROOT INTEGRATION PENDING

Audit branch: `codex/backtest-semantic-integrity`

Evidence cutoff: 2026-08-31

This is the defect ledger and decision record for the end-to-end audit of Basic strategy
semantics. A green syntax test is not completion: every supported meaning must survive plan loading,
evaluation, candidate gating, order sizing, risk checks, matching, accounting, persistence, and result
readback, with live/backtest parity where both runtimes implement it.

## Supported capability boundary

| Boundary | Supported meaning | Compatibility rule |
|---|---|---|
| Plan schema | `basic-compiled-plan.v1`, `basic-compiled-plan.v2` | Released payloads remain readable; new behavior may not silently reinterpret an old payload. |
| Compiler | `basic-compiler:1.0.0` | Plan checksum and strategy snapshot hash pin the executable input. |
| Instrument universe | `us-supported-universe:2026-07-31` | Only catalogued instruments may execute. |
| Resolutions | `30m`, `1h`, `4h`, `1d` | Each partition keeps its own resolution; a run may require multiple manifests. |
| Sessions | pinned `XNYS` regular sessions | Holidays and early closes are data, not weekday guesses. |
| Catalog `2026-07-31` | legacy reader | No execution-gate arguments; do not invent them. |
| Catalogs `2026-08-07`, `2026-08-08`, `2026-08-25` | execution gate enabled | `executionMode`, wait rule, interval and maximum executions are enforced. |
| Position model | long-only | No short sale or regular-hours-external fill. |
| Fill timing | next eligible bar/session | A close-derived signal never fills retroactively from its own bar. |

The active production catalog is `basic-elements:2026-08-25`. Its supported condition/action
surface is the catalog itself plus the shared conformance fixture; this audit treats any UI-only or
compiler-only block as unsupported until all stages above prove it.

## Canonical execution meanings

- A **position cycle** begins at the first opening fill (`position.openedAt`) and ends only when
  quantity reaches zero. Scale-in and partial-exit fills may change average entry price but do not
  begin a new cycle. A later re-entry has a new opening instant.
- `1회만` admits at most one candidate for a flow and instrument in one position cycle. Full close
  releases the gate for a later cycle.
- `주기마다` admits eligible candidates until `maxExecutions` is reached.
- `조건 재충족` rearms only after the condition evaluates false.
- `N봉 이후` counts eligible evaluations after the previous admitted candidate.
- `N거래일 이후` counts pinned XNYS sessions, excluding weekends, holidays, and extraordinary
  closures. It must not be implemented as elapsed weekdays.
- An execution count means a **condition-qualified order attempt**, not a fill. The gate is consumed
  when a candidate is durably admitted, before downstream composition, risk, and matching. A later
  rejection, partial fill, expiry, or cancellation does not refund that attempt. This matches the
  live recovery source, which reconstructs counts from immutable order intents, prevents retry from
  creating duplicate attempts, and keeps actual risk rejections as evidence rather than retrying a
  signal forever.

## Immutable reproduction evidence

Run `0b792370-ff88-3e7d-83d6-853db368c990` is the frozen comparison target.

| Field | Evidence |
|---|---|
| Strategy/bot | `장기 성장 · 대형 낙폭 방어` / `79e0dec4-d866-39b2-a764-9b3e47ec1a15` |
| Evaluation range | 2016-01-01 through 2026-07-29 |
| Initial cash | 100,000.00000000 |
| Result hash | `3c1c391ac8772c195e70d420610c80f2a1bc6676050ca38b9cf48c726a4d3253` |
| Input bundle fingerprint | `sha256:797676d5a352b8bdac3c9cdafb1341ef6ce4c1f202203d6880cc6f5039b5c260` |
| Plan checksum | `sha256:0d82b25076cb690e80949e3c2e438cf8ce75be15709321b596a734f08c80d7ae` |
| Strategy snapshot hash | `sha256:5930d32c2dc97f03f7589296ec798935de168cd2752734145c1d2c1cfc30b202` |
| Inputs | 55 MARKET_BARS manifests, no feature materialization |
| Plan surface | META, AMZN, NVDA, AAPL, MSFT; one buy and one sell flow per instrument |
| Existing result | 82 fills; 1,291.23247521 fees; 322.85482290 slippage; ending equity 1,379,243.25090189; return 1,279.2432509%; max drawdown -39.79807121% |
| Detail evidence | 5,707 trade-detail rows: 5,472 `MAX_INSTRUMENT_POSITION_PERCENT` rejections, 94 orders, 82 fills, 59 cancellations |

The old result is evidence, not an oracle. A corrected rerun may legitimately differ, but every
difference must be attributable to a ledgered semantic correction and independently recomputed.

The independent `scripts/integration/backtest_actual_run_oracle.py` audit of corrected run
`d953380f-2c1d-44ce-abc7-355b1aa03220` passed without importing production calculation helpers. It
verified all 55 object SHA-256 values and 13,395 source rows, matched every one of 24 fill base prices
to the pinned Parquet session open, recomputed price/slippage/fee at eight-place `HALF_EVEN`,
reconstructed the cash chain and FIFO lots, balanced all 24 ledger transactions, and independently
reproduced ending cash `282780.21568874`, ending equity `1029579.03568874`, realized PnL
`277360.67076605`, fees `1162.57948231`, and slippage `290.69092895`.

After a clean Docker image rebuild (no copied-in module), run
`6c54268a-3625-46b3-852a-df53c2cfa610` repeated the same frozen pins and independently reproduced
the same fill count and every monetary result above. Its 55 source manifests and all 24 ledger
transactions also passed the oracle. The distinct result hash is expected because durable result
object identities are run-scoped; semantic and accounting values are identical.

## Defect ledger

| ID | Severity | Reproduction | Root cause | State | Required proof |
|---|---:|---|---|---|---|
| BTE-001 | Critical | Active `2026-08-25` plan admits a second `1회만` candidate | Backtest enabled gates only for a hard-coded `2026-08-08` version string | FIXED and merged | Active/legacy catalog capability tests and replay-boundary test pass |
| BTE-002 | Critical | Scale-in changes average price and reopens `1회만` in backtest/live | Position-cycle identity included average entry price | FIXED and merged in backtest and trading | Same `openedAt` with changed average retains gate; new `openedAt` releases it; both runtime suites pass |
| BTE-003 | High | Christmas and other weekday closures count toward `N거래일` and holding duration | Three paths counted weekdays or a hand-written holiday approximation instead of pinned sessions | FIXED and merged | Christmas red tests pass against the backtest's pinned schedule and a real PostgreSQL calendar query; backtest and trading suites pass |
| BTE-004 | Contract ambiguity | Gate is consumed before downstream risk rejection or fill completion | Product text said "execution" while durable live recovery has always counted condition-qualified immutable intents | JUSTIFIED-NONDEFECT | Canonical meaning recorded above; gate state tests prove an admitted attempt is not refunded, while close/re-entry alone resets its cycle |
| BTE-005 | High | A repeating-decimal position average produces different sell-condition inputs in live and backtest | Live used 8-place `HALF_UP`; backtest published an unquantized quotient | FIXED and merged | Exact ninth-decimal tie tests prove both publish 8-place `HALF_EVEN`; backtest and trading suites pass |
| BTE-006 | Critical | After scale-in, live keeps publishing the pre-scale-in average and return while backtest uses the new average | Preventing BTE-002's tracker reset exposed that the tracker stored average price as immutable cycle identity | FIXED and merged | Scale-in test retains peak/counters/gate but updates average, current return and peak return |
| BTE-007 | Critical | The frozen 2016-2026 run failed at its final 2026 input even though every pinned annual Parquet object was available and valid | Manifest compatibility and row validation incorrectly required an immutable calendar-year partition to be wholly contained by the run window; the event layer then received valid rows after the run end | FIXED and merged | Four preserved diagnostic runs isolate each boundary; reader/legacy/wiring tests prove overlap admission, full-manifest validation and policy-window filtering; corrected frozen-input rerun completed |

### BTE-007 actual-data failure chain

The source bundle stores one immutable manifest per instrument and calendar year. The requested run
ends on 2026-07-29, while each valid 2026 boundary manifest ends on 2027-01-01. Treating that shape
as corruption made the exact frozen input impossible to replay. The following local runs were kept as
diagnostic evidence rather than silently retried or rewritten:

| Run | Terminal evidence | Isolated layer |
|---|---|---|
| `a383e642-7025-4f5c-9a91-332ce0b57d86` | `FAILED / REQUIRED_INPUT_UNAVAILABLE` | V2 manifest compatibility required containment |
| `d715e997-0f4f-4b6f-9852-3839d1d57237` | `FAILED / REQUIRED_INPUT_UNAVAILABLE` | Legacy manifest helper retained the same containment rule |
| `2edf53d6-523a-46ea-aad2-9a0a000e2749` | `FAILED / INPUT_DATASET_UNREADABLE` | Reader validated every immutable row against the shorter run window |
| `b2f54077-3a76-4bb0-aada-bbc2b70e8b96` | `FAILED / INPUT_DATASET_UNREADABLE` | Valid post-window rows reached event conversion instead of being clipped |
| `d953380f-2c1d-44ce-abc7-355b1aa03220` | `COMPLETED` in 8.16 seconds | Correct overlap, validation and filtering behavior |

The completed rerun has the same bundle fingerprint, plan checksum, strategy snapshot hash,
execution-policy version and exact set of 55 `(manifest id, purpose, locked hash)` tuples as the
frozen source run. It produced 24 fills, 1,162.57948231 fees, 290.69092895 slippage, ending equity
1,029,579.03568874 and return 929.57903569%. The old and corrected results intentionally differ:
the old active-catalog replay bypassed execution gates (BTE-001), producing 82 fills and thousands
of repeated risk rejections. The independent per-fill ledger and raw-market reconciliation above
promotes the corrected figures to oracle-backed results.

## Test oracle and adversarial evidence

- `tests/test_execution_properties.py` uses Hypothesis against calculation-independent cash,
  position, ledger and gate oracles. It covers 100 randomized round trips, 75 rejection-purity
  cases and 50 gate-counter sequences per test run.
- The catalog pairwise matrix executes every supported Basic condition and action at least once,
  both sides, every supported resolution, mixed partitions and multi-instrument plans. Reader tests
  vary batch size, object order, row-group boundaries and manifest segmentation; reproducibility
  tests repeat delivery and restart boundaries. These are the chunk/manifest/retry metamorphic
  checks: changing transport shape does not change ordered events, fills or result hashes.
- Failure-injection suites cover lease loss and heartbeat, stale queued/running recovery, resource
  limits, timeout, cancellation, retry exhaustion, malformed input, duplicate delivery, S3 lost
  response/precondition failure, publisher failure, DLQ terminalization and fenced persistence.
- Mutation testing is deliberately scoped to the required execution-gate, sizing, order-fill and
  FIFO-accounting paths. Gate retirement killed 17/17 mutants and gate application killed 30/30
  after adding the `false before first candidate` case. Fill sizing killed 93/109; the remaining
  16 are calculation-equivalent mutations that only remove or change diagnostic labels passed to
  the same quantizer. Fill/FIFO produced 220 mutants: 173 behavioral mutants were killed and 47
  were justified equivalents (diagnostic-label changes, plus the FIFO missing-key default which
  is unreachable after the preceding held-position invariant). Two broad-run timeouts that set a
  fill's instrument or timestamp to `None` were rerun directly against the focused oracle and both
  failed it. No behavioral survivor remains. This pass exposed and closed two real test gaps:
  competing-order reservations in fill sizing and a condition that is false before its first
  candidate.

## Local integration and browser evidence

- Clean rebuilt backtest API/worker images completed run
  `6c54268a-3625-46b3-852a-df53c2cfa610` from the immutable 55-manifest input. Both corrected runs
  passed the independent raw-Parquet/ledger oracle with 13,395 source rows, 24 fills and 24 balanced
  ledger transactions.
- Docker-marked backtest integration tests and the root three-lane/basic-strategy E2E suites pass.
  The trading worker check passes including its real PostgreSQL calendar test.
- The final backtest non-Docker suite passed with 1,402 tests and two expected skips; Ruff and mypy
  passed. The trading engine's forced full Gradle `check --rerun-tasks` completed successfully in
  8 minutes 31 seconds. Backtest PR `#97` passed all nine CI gates and merged as `d70b848`; trading
  PR `#158` passed both CI gates and merged as `eb97bc3`.
- At `http://localhost:15173/backtests`, the authenticated browser showed the clean run's comparison
  line chart, 2016-01-01 through 2026-07-29 range, +929.58% strategy result, +262.78% S&P 500 and
  +506.41% NASDAQ-100. The 2016-01 ET trade view loaded actual order, partial-fill, fill and expiry
  rows with quantity, price, fee and running cash. Monthly analysis showed explicit unavailable
  future months rather than zeroes, and execution info showed attempt 1 `SUCCEEDED`. No application
  console error occurred; the only error-level record was a transient Vite HMR reconnect followed
  immediately by `connected`.

## Root integration step

- Refresh the root Flyway contribution bundle and gitlinks at the merged component revisions, pass
  the staged secret scan, then merge the root PR to `develop`.
