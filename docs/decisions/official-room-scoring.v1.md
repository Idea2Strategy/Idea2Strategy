---
schema_version: 1
id: decision.room.official-scoring
kind: decision
status: proposed
revision: 1
refs:
  - capability.room.bot-comparison
  - scenario.room.finish
---

# decision.room.official-scoring

This document defines `official-room-scoring-decision.v1` for the development
scoring catalog.

## Scope and immutable identity

- Decision code: `official-room-scoring-decision.v1`
- Calculation rules version: `official-room-scoring.v1`
- Market clock: United States regular trading session clock
- Free-form formulas, executable code, user-defined metrics, and external scoring
  data are prohibited.
- A room locks one published template version, calculation rules version, and
  rules hash before evaluation starts. Later catalogue changes never alter that
  room's result.

## Metric contract

All monetary equity inputs use the room currency and include realized P&L,
unrealized P&L, fees, and the E24 non-mutating virtual-liquidation evidence at
the official cutoff.

### Total return

`totalReturnPct = ((finalEquity / initialCapital) - 1) * 100`

- Higher is better.
- `initialCapital` must be positive.
- Negative final equity is permitted, so total return may be below `-100%`.

### Maximum drawdown

For every ordered official equity observation `t`:

`drawdownPct(t) = ((peakEquity(t) - equity(t)) / peakEquity(t)) * 100`

`maxDrawdownPct = max(drawdownPct(t))`

- `peakEquity(t)` is the greatest official equity observed from evaluation start
  through `t` and must be positive.
- Maximum drawdown is stored as a positive loss magnitude and lower is better.
- Negative equity is permitted, so maximum drawdown may exceed `100%`.

### Sharpe ratio

Sharpe uses only consecutive equity observations within the same continuous
normal-evaluation segment. A return pair never bridges a platform-outage gap.
This removes synthetic volatility from missing observations while total return,
maximum drawdown, existing-order outcomes, and held-position P&L still reflect
the recovered real market evidence on both sides of the outage.

For each valid pair `i`:

- `l_i = ln(equity_i / equity_(i-1))`
- `dt_i` is the actual elapsed normal-evaluation time expressed in years, using
  `31,557,600` seconds per year.
- `T = sum(dt_i)` and `n` is the number of valid pairs.
- `mu = sum(l_i) / T`
- `variance = sum(((l_i - (mu * dt_i))^2) / dt_i) / (n - 1)`
- `sharpeRatio = mu / sqrt(variance)`

The annual risk-free rate is `0`. At least `30` valid return pairs, positive
equity at both ends of every pair, positive `T`, and positive variance are
required. Otherwise Sharpe is unavailable rather than `NaN`, infinity, zero, or
an invented worst score. Higher is better.

The logarithm and square-root boundary uses IEEE 754 binary64 values and the
reproducible `java.lang.StrictMath.log` and `java.lang.StrictMath.sqrt` semantics.
At minimum, conformance tests pin these raw binary64 outputs:

| Operation | Decimal input | Expected raw bits | Decimal output at scale 16 |
| --- | --- | --- | --- |
| `log` | `2.0000000000000000` | `0x3fe62e42fefa39ef` | `0.6931471805599453` |
| `log` | `0.5000000000000000` | `0xbfe62e42fefa39ef` | `-0.6931471805599453` |
| `sqrt` | `2.0000000000000000` | `0x3ff6a09e667f3bcd` | `1.4142135623730951` |

The exact conversion pipeline is:

1. round the decimal operand with `setScale(16, HALF_EVEN)`;
2. convert with `BigDecimal.doubleValue()` and reject non-finite output;
3. apply the named `StrictMath` operation and reject non-finite output; and
4. convert with `BigDecimal.valueOf(result).setScale(16, HALF_EVEN)`.

All later decimal operations use `MathContext(34, HALF_EVEN)` and the rounding
points in the numeric policy. A different numerical algorithm or conversion
requires a new calculation rules version and rules hash.

## Published v1 templates

SINGLE templates preserve the raw selected metric as their score and apply only
the official sort direction.

| Template code | Kind | Component and coefficient |
| --- | --- | --- |
| `SINGLE_TOTAL_RETURN_V1` | SINGLE | `TOTAL_RETURN`, higher, `1.0` |
| `SINGLE_SHARPE_V1` | SINGLE | `SHARPE_RATIO`, higher, `1.0` |
| `SINGLE_MAX_DRAWDOWN_V1` | SINGLE | `MAX_DRAWDOWN`, lower, `1.0` |
| `COMPOSITE_BALANCED_V1` | COMPOSITE | `TOTAL_RETURN` `0.50`, `SHARPE_RATIO` `0.30`, `MAX_DRAWDOWN` `0.20` |

`COMPOSITE_BALANCED_V1` applies fixed, room-independent normalization:

| Metric | Clamp range | Normalized value |
| --- | --- | --- |
| `TOTAL_RETURN` | `[-100, 100]` percent | `(clamp(x, -100, 100) + 100) / 200` |
| `SHARPE_RATIO` | `[-3, 3]` | `(clamp(x, -3, 3) + 3) / 6` |
| `MAX_DRAWDOWN` | `[0, 100]` percent | `(100 - clamp(x, 0, 100)) / 100` |

`compositeScore = 100 * sum(normalizedMetric * coefficient)`

COMPOSITE final score is higher-is-better. The v1 adjustment schema is the empty
object `{}`: every room-level scoring adjustment code is rejected. A room may
select a published template but cannot change its components, coefficients,
clamps, directions, weights, numeric rules, or final score direction.

## Numeric policy

- Decimal inputs and persisted metrics use scale `8`.
- Decimal intermediate operations use precision `34`, scale `16`, and
  `HALF_EVEN` rounding after each division, logarithm, square root, and weighted
  multiplication.
- SINGLE and COMPOSITE final scores use scale `8` and `HALF_EVEN` rounding.
- Tie equality compares the final persisted score exactly; it does not use an
  epsilon or an unrounded hidden value.

## Platform outage and coverage

- The scheduled official evaluation start and end remain unchanged.
- `coverage = normalEvaluationSeconds / scheduledEvaluationSeconds`.
- Scheduled seconds contain only the room's originally planned, in-session
  evaluation clock; exchange-closed time outside that clock is in neither the
  numerator nor denominator.
- The denominator is the entire originally scheduled official evaluation
  duration. The numerator contains only intervals in which the platform could
  perform normal strategy evaluation.
- A platform-outage interval is established by common platform evidence and is
  applied identically to every bot in the room. An individual bot or user failure
  is not an outage exclusion and never improves that bot's coverage.
- Official ranking requires coverage greater than or equal to `0.70`.
- Integer minimum-operation and minimum-fill requirements are adjusted to
  `max(1, ceil(baseRequirement * coverage))` when the base requirement is
  positive. A zero base requirement remains zero.
- An outage is never replayed. The platform does not return to the gap to run
  strategy decisions or submit new orders.
- Orders accepted before the outage continue through their actual fill,
  partial-fill, expiration, and cancellation lifecycle when recoverable venue or
  broker evidence is ingested. The platform does not synthesize a fill.
- Existing positions retain their real price change and P&L evidence. Temporary
  platform downtime leaves finalization pending and retryable instead of
  immediately making the participant or room unscorable.

## Missing evidence and eligibility

A participant receives no official rank and no official score when any of the
following holds:

- coverage is below `70%`;
- the selected template requires a metric that is unavailable;
- the participant's normal-evaluation evidence cannot be recovered; or
- the participant fails the proportionally adjusted E20 operation or fill
  threshold.

The result preserves owner-visible reason and evidence. It must not substitute
zero, a worst score, `NaN`, or infinity. Storage for this state must represent an
absent rank and score or an equivalent explicit unranked record; the E28 schema
proposal owns that physical choice.

If common platform evidence and at least one valid normal interval remain, the
room is partially evaluated under the same coverage rule. A room-wide invalidated
result is reserved for the case where common official evidence cannot be
recovered sufficiently to evaluate the room at all. Individual bot evidence loss
does not invalidate otherwise recoverable competitors.

## Rank and tie policy

Eligible participants are ordered by:

1. final persisted score, applying the selected template's direction;
2. total return, higher first;
3. Sharpe ratio, higher first, with unavailable values last;
4. maximum drawdown, lower first, with unavailable values last.

When all four comparisons are equal, participants share a rank. Competition rank
is used (`1, 1, 3`), not dense rank. Shared-rank display order uses the immutable
`participationId` ascending only as a deterministic presentation key; joining
earlier is never a scoring advantage.

## Evidence and hashing

Every calculation persists or references:

- room, participation, template version, calculation rules version, and rules
  hash;
- scheduled interval, normal segments, outage intervals, and coverage;
- source observation bounds and hashes;
- metric inputs, raw metrics, normalized components, coefficients, rounded score,
  eligibility reason, and tie inputs;
- the E24 cutoff snapshot and virtual-liquidation evidence hashes; and
- a final result hash over a canonical serialization of the above fields.

The development scoring manifest records the SHA-256 of this decision file. Any
content change requires the manifest checksum and affected tests to be updated.
