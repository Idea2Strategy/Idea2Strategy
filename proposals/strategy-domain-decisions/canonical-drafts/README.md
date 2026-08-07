# Canonical drafts

Status: **PROPOSED / NOT GOVERNANCE-APPROVED**

These files are byte-for-byte what `../README.md` recommends writing into `specs/`. They live here, under
their eventual `specs/` path, because the canonical-write gate is closed and an agent following
`AGENTS.md` may not edit a protected source while it is.

## Why approving the proposal did not open the gate

`proposals/strategy-domain-decisions/README.md` was approved by a configured product authority and
merged. That records agreement with the recommendations, and it is why these drafts exist. It did not
open the gate, and the mechanism is worth stating precisely so the next attempt is not a surprise:

- The observation the gate needs is a **fresh provider review approval for the exact repository, head
  commit, and protected fingerprint**.
- That proposal PR touched only `proposals/`, which is not a protected path. The protected fingerprint
  therefore never moved — it is still `sha256:656e5b9a…` before and after the merge — and no
  observation was produced. `stackcord governance check --json` still reports `status: unknown`.
- `scripts/initialize-local-harness.ps1 -Verify` does not create the observation either. It generates
  the ignored `owner.yaml` and policy integrity baseline, nothing more.

So the gate opens only when an authority leaves a real GitHub review approval on a pull request that
**does** touch a protected path. That is a bootstrap the agent cannot perform: authoring the first
protected-path edit is exactly what `AGENTS.md` forbids while the check is unknown, and hand-writing
`.harness/local/governance` would fabricate the provider approval the gate exists to require.

## What is drafted

| Proposal § | Files | Effect |
|---|---|---|
| §3 providers and rights | `decision.data.providers-alpaca-sip` (new), `question.data.providers-rights` (rev 2) | Records the decision closed on root #143; narrows the question to quote and borrow data. |
| §5 UI visual baseline | `decision.ui.partial-baseline` (rev 3) | Adds one clause: implementation is gated on the required-states contract alone. `question.ui.visual-baseline` stays untouched and unknown. |
| §8 released-version conflict | `policy.strategy.immutable-release` (rev 2), `scenario.strategy.release` (rev 2), `capability.backtest.automatic` (rev 3) | Adopts the implemented model: release copies into a provenance-free bot, the strategy stays editable, and the automatic backtest is per bot rather than per released strategy version. |
| §1 catalog | `decision.strategy.basic-catalog-v1` (new), `question.strategy.catalog` (rev 2) | Records the four bar periods, the published block set, and the composition limits; narrows the question to the risk element, the per-symbol cap's home, and the required-data expression. |
| §2 precision | `decision.accounting.precision-v1` (new), `question.accounting.formulas` (rev 2) | Records precision, rounding, slippage, FIFO profit and loss, and the metric set; narrows the question to short-only formulas, which Basic excludes. |

**Not drafted: §7.** Its outcome is a decision, not a transcription — where the backtest supportability check runs, and how an element should express its data requirement now that the current expression is known to name nothing. Drafting canonical text before that is chosen would invent the answer.

**§6 is not drafted either**, because it did not need to be: it is recorded as `DMD-032` in `db/data-model-decisions.md`, which is not a protected path and is the established home for a data-model decision pending canonical alignment.

Two entries touched by §8 are deliberately absent: `role.room-participant` and `ui.bot.operations` need the same correction, but they belong to the room and bot-operations owners rather than the strategy domain, and mixing another assignee's canonical area into this change is exactly what the collaboration policy forbids.

## How to apply

Copying the whole tree applies every section at once:

```bash
cp -r proposals/strategy-domain-decisions/canonical-drafts/specs/. specs/
```

To apply one section at a time — recommended, so a single contested recommendation cannot hold up the
rest — copy only that section's files from the table above.

Then open the pull request and have a product authority leave a **review approval** on it. Once that
approval exists for that head commit, `stackcord governance check --json` reports the approved
authority and the write is authorized. Do not merge with `--admin`; an admin merge bypasses review and
produces no observation, which is how the gate came to be closed in the first place.

Note `scripts/validate-proposal-boundary.mjs` will fail on that branch by design — it refuses any
change touching `specs/`, `contracts/`, `.harness/governance.yaml`, `docs/collaboration-policy.md`, or
`db/schema.dbml`. It validates that a *proposal* stays isolated, so it is the wrong check for the
branch that performs the canonical write. It is not wired into CI.

## Suggested order

§3 first. It is the cheapest and least contested: the decision was already made and closed on an
issue, so it records history rather than settling anything new. Proving the approval mechanism once on
a change nobody disputes is worth more than proving it on the catalog limits.

Then §5, which unblocks screen work without deciding any visual; then §8, which adopts what the code
already does; then §1 and §2, which are the two that carry real recommendations and deserve the most
scrutiny — particularly §1's numeric limits, which are judgement calls rather than transcriptions.

§7 stays open until its design question is answered. Its one decision-free part, implementing the
`backtest-unavailable` state that `ui.strategy.authoring` already requires, needs no canonical write
and can proceed as ordinary work.
