# COM-A19 user case contract proposal

Issue: Idea2Strategy/Idea2Strategy#132

Blocked implementation: Idea2Strategy/Idea2Strategy-backend#147

Base: root `origin/develop` at `616044d934e9e9874ad1b0e197fc9d116062acad`

This directory is isolated because governance approval is unknown. It changes no canonical DBML, contract, or package script and must not be presented as approved.

## Contents and delta

- `schema.draft.dbml`: complete 152-table candidate based on the exact root commit above;
- `contract.md`: type/state transitions, head/sequence, idempotency, evidence ownership, privacy, and A17 port boundary;
- `validate-contract.test.mjs`: five proposal-specific regression tests;
- additive proposal: typed cases, head/version, append-only event chain, successful command receipts, and immutable evidence ownership references.

## Validation

```text
node scripts/validate-dbml.mjs proposals/com-a19-case-contract/schema.draft.dbml
node --test proposals/com-a19-case-contract/validate-contract.test.mjs
npm run dbml:validate:a12
npm run proposal:validate:boundary
git diff --no-index -- db/schema.dbml proposals/com-a19-case-contract/schema.draft.dbml
```

After exact-commit approval, rebase the full schema draft, apply only the reviewed A19 delta to canonical DBML/contract paths, merge root first, and then restart backend #147 from current backend `develop`. Backend A19 must depend only on an application outbox port until the separately approved A17 worker contract is integrated.
