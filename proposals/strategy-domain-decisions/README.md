# Strategy domain decisions

Status: **PROPOSED / NOT GOVERNANCE-APPROVED**

`stackcord governance check --json` reported `status: unknown` at the head commit used to author this
document, so nothing here may be described as approved, integrated, or releasable. This file is an
isolated proposal under `proposals/`. Promotion into `specs/` or `contracts/` requires a fresh
provider observation naming a configured product authority for the exact repository, head commit, and
protected fingerprint — in practice, a product-authority review approval on the pull request that
performs the canonical write.

The five `specs/product/open-questions/question.*.md` files still carry `status: unknown`. Each
section below states a recommended resolution, the evidence it rests on, and — where the answer is
not ours to invent — the narrowest decision that still unblocks v1.

---

## 1. `question.strategy.catalog`

> Which exact verified blocks, indicators, types, formulas, limits, and backtest support rules belong
> in the strategy catalog?

### Recommendation: adopt the implemented catalog as Basic v1 and pin the missing limits

The blocks half is already answered by working code. Element catalog version
`basic-elements:2026-08-07` publishes twelve `CONDITION` elements, one `TRIGGER`, and one terminal
`ACTION`, and `proposals/basic-strategy-full-catalog/README.md` records the decided semantics for
each. Recommend promoting that table into `specs/` as the canonical Basic catalog rather than
re-deriving it.

What that proposal does **not** answer is the "limits" half of the question, which remains genuinely
unpinned. Recommended values, chosen to bound runtime evaluation cost while staying above any shape a
Basic user plausibly needs:

| Limit | Recommended | Rationale |
|---|---|---|
| Conditions per container | 5 | An AND chain longer than this is unreadable in the editor, and it bounds per-event evaluation work. |
| Containers per section | 2 (one buy, one sell) | Already the implemented and approved shape; not a new constraint. |
| Sections (partitions) per strategy | 4 | With a 100% budget cap split across siblings, more than four makes each allocation too small to fill. |
| Instruments per section | 5 | Bounds fan-out per event; the ETF universe is 27 instruments total. |
| Historical lookback | 60 completed bars | The largest period any published element requests (`SMA_60`, `HIGH_60`, `LOW_60`). Deriving the cap from the catalog keeps the two from drifting. |

### Recommendation: retire the risk lane from the data model, not just from the toolbar

No `RISK_POLICY` element exists in `basic-elements:2026-08-07` (the migration publishes twelve
`CONDITION`, one `TRIGGER`, one `ACTION`), and `buildBasicSemanticDocument` drops every card on the
risk lane.

This is **not** a live silent-data-loss path, and an earlier revision of this document overstated it.
Two guards already exist: the editor offers only 매수/매도 when adding a card, so there is no way to
create a risk card, and when a catalog client is present the validator raises a blocking issue
(`위기관리 카드는 현재 공개된 실행 카탈로그에서 지원하지 않습니다`) that prevents save-and-launch.
The silent drop survives only where no catalog client exists, which is the prototype and test path.

What remains is dead surface with a sharp edge: `risk` is still a first-class side throughout the
editor's state, clone, restore, render, duplicate and delete paths, so a document written by an older
UI can still carry risk cards — and such a strategy is then permanently unlaunchable until the user
finds and deletes cards the toolbar can no longer create.

Recommended: **remove `risk` from the Basic editor's side model** and, in the same change, delete any
risk cards encountered while restoring a legacy document, reporting what was removed. Publishing a
`BASIC_RISK_STOP` element instead is the better end state but needs the stop semantics decided
(trigger basis, whether it cancels open orders, how it interacts with the sell container) plus a
trading-engine implementation, so it belongs in its own reviewed unit. No capability is lost in v1:
`BASIC_POSITION_RETURN`, `BASIC_PEAK_RETURN`, `BASIC_DRAWDOWN_FROM_PEAK` and
`BASIC_HOLDING_PERIOD` already express stop-loss, take-profit and time exits inside the sell
container.

### Recommendation: give `symbolLimits` a semantic home

Per-symbol maximum-holding caps (`symbolLimits`) are collected by the editor and written **only** into
`presentationDocument.basicEditor.snapshot`. They never reach the semantic document, so they are
absent from the released bot and from validation, while looking to the user like a configured
execution limit. This is the one genuine dual-source defect in the current editor: an
execution-meaningful value living in the layout document.

Recommended: express the cap as a parameter on the terminal `BASIC_EQUAL_ALLOCATION_ORDER` element
(a new catalog version), because the cap constrains order sizing and belongs with the order step.
Until that lands, the editor should not present the control as though it affects execution. Deciding
this is part of this question because it changes the published catalog.

### Backtest support rules

Every non-terminal element declares required feed `ADJUSTED_BAR @ 1m`, and terminal elements declare
none. Recommend recording exactly that as the rule, so backtest capability is derived from the
catalog rather than maintained separately.

---

## 2. `question.accounting.formulas`

> Which exact versioned accounting, precision, rounding, margin, borrow-cost, and performance
> formulas pass market and legal review?

### Recommendation: split the question — v1 needs only the first half

This single question bundles decisions of very different difficulty, and the hard half is out of
Basic scope entirely. Basic explicitly excludes short selling, so **margin and borrow-cost formulas
are not v1-blocking** and should be split into a separate question that stays `unknown` until Pro
short support is designed. That de-scopes the part needing legal review and leaves a tractable
remainder.

Recommended values for the remainder, chosen to match constraints the database already enforces:

| Item | Recommended | Rationale |
|---|---|---|
| Money storage | `NUMERIC` with 4 decimal places | Survives per-share fee arithmetic without binary-float drift; display rounds to 2. |
| Quantity | Whole shares only in v1 | Removes fractional-share allocation and settlement questions from v1; the ETF universe is all whole-share tradable. |
| Order-size rounding | Truncate toward zero | A budget cap must never be exceeded by rounding. This is a safety direction, not a preference. |
| Display rounding | Half-up, 2 decimals | Conventional and matches broker statements. |
| Slippage | 5 bps, fixed | Already a `CHECK` constraint in the canonical model; recording it changes nothing. |
| Realized P&L | FIFO over canonical long lots | Matches the lot model trading already maintains; no alternative is implemented. |
| Performance metrics | Total return, max drawdown, win rate, trade count | The minimum set the results and room-comparison surfaces already display. |

Room scoring formulas are tracked separately in `proposals/official-room-scoring/` and are not
restated here.

---

## 3. `question.data.providers-rights`

> Which providers and licenses satisfy real-time, historical, quote, borrow, corporate-action,
> storage, and redistribution needs?

### Recommendation: record the decision that was already made, and narrow what is left

This question is largely answered but never written back into `specs/`. Root issue #143 is closed
with the decision to extend Alpaca to corporate actions, and all three data rights were granted —
including retention and regeneration of adjusted datasets after the subscription ends, which removes
any licensing expiry from reproducibility. The release pipeline already fails closed unless
`trading_market_data_feed` is the paid Alpaca SIP feed.

So the recommended resolution is: Alpaca SIP for real-time and historical bars and corporate actions,
with retention/regeneration rights confirmed. What remains genuinely undecided is **quote-level and
borrow data**, and neither is needed by v1 — Basic uses completed-bar data only, and borrow data is a
virtual-broker operational input that is never exposed as a strategy input. Recommend narrowing this
question to those two feeds and marking the bar/corporate-action half resolved.

Redistribution is worth stating explicitly, because the product already depends on it: users see
derived indicator values and their own backtest results, never raw redistributable market data feeds.

---

## 4. `question.operations.slo`

> Which availability, latency, capacity, retention, backup, recovery, audit, and support targets are
> operationally sustainable?

### Recommendation: state targets that match the topology actually deployed

The deployed shape is a single region (`ap-northeast-2`), one Core host and one schedule-controlled
Trading host, one RDS instance. Committing to high-availability numbers on that topology would be
fiction. Recommended targets, deliberately modest and honest:

| Target | Recommended |
|---|---|
| Availability | 99% monthly, excluding announced maintenance |
| Order-path latency | Market event to order intent under 5 s at p95 |
| Capacity | 10 concurrently running bots per account, already enforced |
| RPO | 24 h (daily automated RDS snapshot) |
| RTO | 4 h, restoring to a separate instance |
| Audit retention | 1 year for `operations.audit_events` |
| Market-data retention | Indefinite, permitted by the confirmed data rights |
| User-data deletion | Within 30 days of account closure settlement |
| Support | Best-effort, no response-time commitment in v1 |

Two of these carry an obligation rather than a number: the restore-to-a-separate-instance procedure
must be documented before any integration test runs against live data, and the 30-day deletion window
must be reconcilable with the 1-year audit retention (audit rows must therefore not contain personal
data — which the delegated-scope contract already requires).

---

## 5. `question.ui.visual-baseline`

> Which exact layouts, responsive boundaries, colors, design system, panel density, and detailed
> editor interactions pass review in the new UI workspace without using the retired UI as an input?

### Recommendation: leave it unknown, and stop treating it as a blocker

This is the one question where inventing an answer would be actively harmful — visual design needs
human review, and `policy.ui.reference-only` retired the previous submodule as an input. Recommend
leaving `status: unknown`.

What should change is its blocking effect. `decision.ui.partial-baseline` already froze the required
editor interactions, and `ui.strategy.authoring` already enumerates the required states (`draft`,
`validating`, `invalid`, `ready`, `released`, `locked`, `backtest-unavailable`). That behavioral
contract is sufficient to implement and test against without any visual decision. Recommend recording
explicitly that UI implementation work is gated on the required-states contract only, so that
strategy-page work does not stall waiting for a palette.

---

## 6. Which document is authoritative when the editor reloads?

Not one of the five questions, but it decides whether the answer to §1 is implementable, and the
current code answers it by accident rather than by design.

`DMD-010` and `DMD-030` make the split clear in one direction: presentation carries layout and must
never affect execution meaning. They do not say which document **reconstructs the editor**, and today
the answer is presentation, exclusively. The load path stores the fetched semantic document into a ref
that is never read again, then rebuilds the whole canvas from
`presentationDocument.basicEditor.snapshot`.

That has a consequence worth deciding deliberately rather than inheriting: if the snapshot cannot be
read — a future `version`, a shape change, a document written by any non-UI client — the editor
presents an empty canvas for a strategy that is not empty, and the next save writes `groups: []` over
the real semantic document. The immediate defect is being fixed in code by refusing to open an
unreadable document instead of blanking it, but the structural question stands.

Recommend affirming the current division explicitly rather than trying to eliminate it: **semantic is
authoritative for execution, presentation is authoritative for editor reconstruction, and neither is
derivable from the other.** The reason to affirm rather than unify is that the editor's display
encodings are deliberately lossy — `>` and `↑` both compile to `GT`, and a label like
`최근 20봉 평균 거래량 2배` compiles to `{period: 20, multiplier: 2}` — so semantic cannot regenerate
the editor surface, and forcing it to would mean pushing display strings into execution meaning, which
`DMD-010` forbids.

What that affirmation obliges, and should be recorded with it:

- Presentation must never be the only home of an execution-meaningful value (see the `symbolLimits`
  recommendation in §1).
- An unreadable presentation snapshot is a load failure, never an empty canvas.
- The semantic document must remain sufficient to release and run a bot with no presentation input,
  which is already true.

## 7. Structural conflict: is there a "released strategy version" entity?

Not one of the five questions, but it blocks the strategy pages more directly than any of them, and
it is already resolved in code without being resolved in the specs.

Several canonical specs presume an immutable released **strategy version** with one automatic
backtest per version. The canonical model has no such table: release copies the validated document
into a provenance-free independent bot and deliberately destroys the linkage. The shipped library API
already resolves this in favour of the model — `findReleased` reads `bot.bots` and
`bot.launch_snapshots`, reports the bot lifecycle as the status, and returns no version — so
"released strategy" in the running product **is** the bot.

Recommend adopting the implemented model and updating the affected specs
(`policy.strategy.immutable-release`, `capability.backtest.automatic`, `scenario.strategy.release`,
`role.room-participant`, `ui.bot.operations`), for which
`proposals/dbml-redesign/harness-business-logic-alignment.md` already contains a clause-by-clause
mapping. The alternative — adding a strategy-version entity to match the specs — would invalidate the
release path, the room-participation path, and the library API that are all working today.

Consequence worth stating for the strategy pages: the promised `출시 전략 상세` page cannot show
"연결된 봇", because that link is intentionally unrecoverable. The page should present the bot itself.

---

## Approval mechanics

Because the governance gate reports `unknown`, none of the above may be written into `specs/` or
`contracts/` in this change. The path is:

1. A product authority (`user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`, `user:hjcud`) reviews and
   approves the pull request carrying this proposal.
2. A follow-up change performs the canonical writes — one per question, so a single contested
   recommendation cannot block the rest — each re-running `stackcord governance check --json` against
   its own head commit and protected fingerprint.
3. `question.*` files move from `status: unknown` to `status: decided` only in that follow-up, never
   here.

Recommended order, cheapest and least contested first: §3 (recording a decision already made), §5
(unblocking UI work without deciding visuals), §6 (adopting what the code already does), §1 (the
catalog and its limits), §2 (precision, after splitting margin and borrow cost out).
