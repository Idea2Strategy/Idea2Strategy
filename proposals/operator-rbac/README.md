# COM-A13 operator RBAC contract proposal

Issue: [Idea2Strategy#130](https://github.com/Idea2Strategy/Idea2Strategy/issues/130)

Backend consumer: [Idea2Strategy-backend#146](https://github.com/Idea2Strategy/Idea2Strategy-backend/issues/146)

Baseline: `origin/develop` at `616044d934e9e9874ad1b0e197fc9d116062acad`

This directory is an isolated, complete canonical-change candidate. It exists because
`stackcord governance check --json` could not verify fresh product-authority approval and
`docs/collaboration-policy.md` keeps DBML semantic changes on hold. It does not replace
`db/schema.dbml` or `contracts/**`.

## Contents

- `schema.draft.dbml`: a byte-for-byte copy of the baseline canonical DBML except for the
  A13 additive catalog, assignment-version binding, audit evidence fields, constraints,
  notes, and references.
- `operator-rbac-contract.v1.md`: the human-readable authorization, failure,
  idempotency, concurrency, audit, API, migration, rollback, and test obligations.
- `scripts/validate-operator-rbac-proposal.mjs`: structural and semantic validator.
- `scripts/validate-operator-rbac-proposal.test.mjs`: positive and fail-closed regression
  tests.

No real role code, permission code, hierarchy value, or delegable value is included.

## Review and canonical application

Review the exact DBML delta with:

```powershell
git diff --no-index -- db/schema.dbml proposals/operator-rbac/schema.draft.dbml
npm.cmd run dbml:validate:a13-proposal
npm.cmd run dbml:validate
npm.cmd run proposal:validate:boundary
```

After the exact proposal commit receives fresh approval from a configured product
authority and the DBML hold is explicitly lifted:

1. apply only the displayed DBML delta to `db/schema.dbml`;
2. place the human contract at the canonical contract location selected by the root
   contract registry and register `contract.operations.operator-rbac.v1`;
3. point the A13 validator/package script at those canonical paths;
4. run `stackcord contract impact --json`, `stackcord contract check`, DBML validators,
   proposal-boundary replacement checks, and the root CI suite;
5. only then allow backend #146 to add the matching Flyway migration and implementation.

The proposal intentionally supplies no destructive down migration. Rollback is a
forward-compatible writer disablement while immutable audit and assignment evidence is
retained.
