# COM-A15 delegated Strategy scope proposal

Issue: [Idea2Strategy#128](https://github.com/Idea2Strategy/Idea2Strategy/issues/128)

Baseline: `origin/develop` at `616044d934e9e9874ad1b0e197fc9d116062acad`

This is an isolated canonical-change candidate because fresh product-authority approval is
not available and the collaboration policy keeps DBML semantic changes on hold.
Canonical `db/schema.dbml` and `contracts/**` remain untouched.

## Contents

- `schema.draft.dbml`: full baseline schema plus only the COM-A15 authorization version,
  explicit target, derived provenance, and Strategy delegated-access epoch delta.
- `delegated-strategy-scope-contract.v1.md`: authorization, CREATE/COPY, failure,
  concurrency, audit, migration, rollback, and test obligations.
- `scripts/validate-delegated-strategy-scope-proposal.mjs` and its tests: structural and
  fail-closed proposal validation.

## Review and apply

```powershell
git diff --no-index -- db/schema.dbml proposals/delegated-strategy-scope/schema.draft.dbml
npm.cmd run dbml:validate:a15-proposal
npm.cmd run dbml:validate
npm.cmd run proposal:validate:boundary
```

After a configured product authority approves the exact commit and explicitly lifts the
DBML hold, apply only the displayed DBML delta, register
`contract.identity.delegated-strategy-scope.v1` at the canonical contract path, point the
validator to canonical paths, and run contract impact/check plus root CI before backend A15
implementation. Do not seed target rows or infer an allowlist for existing authorizations.
