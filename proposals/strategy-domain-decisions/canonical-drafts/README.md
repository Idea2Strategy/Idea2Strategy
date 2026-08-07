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

## How to apply §3

Copy both files to their `specs/` paths, in one commit, on a branch:

```bash
cp -r proposals/strategy-domain-decisions/canonical-drafts/specs/. specs/
```

That yields exactly two changes:

- **new** `specs/product/decisions/decision.data.providers-alpaca-sip.md` — records the provider and
  rights decision closed in root issue #143, which `specs/` never captured.
- **modified** `specs/product/open-questions/question.data.providers-rights.md` — revision 2. Keeps
  `status: unknown`, because quote-level and borrow data genuinely are undecided, but narrows the
  question to only those two and points at the decision for the rest.

Then open the pull request, and have a product authority leave a **review approval** on it. Once that
approval exists for that head commit, `stackcord governance check --json` reports the approved
authority and the write is authorized. Do not merge with `--admin`; an admin merge bypasses review and
produces no observation, which is how the gate came to be closed in the first place.

Note `scripts/validate-proposal-boundary.mjs` will fail on that branch by design — it refuses any
change touching `specs/`, `contracts/`, `.harness/governance.yaml`, `docs/collaboration-policy.md`, or
`db/schema.dbml`. It validates that a *proposal* stays isolated, so it is the wrong check for the
branch that performs the canonical write. It is not wired into CI.

## Why §3 first

It is the cheapest and least contested of the recommendations: the decision was already made and
closed on an issue, so this records history rather than settling anything new. Proving the approval
mechanism once on a change nobody disputes is worth more than proving it on the catalog limits.
