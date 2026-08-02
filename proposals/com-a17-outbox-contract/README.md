# COM-A17 outbox contract proposal

Issue: Idea2Strategy/Idea2Strategy#129

Blocked implementation: Idea2Strategy/Idea2Strategy-backend#145

Base: root `origin/develop` at `616044d934e9e9874ad1b0e197fc9d116062acad`

This directory is intentionally isolated because the configured product-authority check is currently unknown. Nothing here is canonical or approved. The proposal must not be copied into `db/schema.dbml` or a canonical contract path until `user:kcrmin` approves the exact proposal commit through the configured GitHub review provider.

## Contents

- `schema.draft.dbml`: full canonical-schema candidate, not a partial fragment.
- `contract.md`: human-readable delivery, replay, and consumer-idempotency behavior.
- `validate-contract.test.mjs`: proposal-specific structural and semantic regression checks.

## Proposed additive delta

- delivery state enums for pending, claimed, published, and dead-lettered messages;
- immutable envelope hash and producer idempotency evidence plus durable current claim token, owner, and lease;
- append-only publisher attempt evidence with the runtime policy version used;
- replay as a new message row with immutable original/immediate-source lineage and an authorization audit link;
- consumer receipts keyed by stable handler ID and message ID, with producer key and payload hash retained as evidence;
- references, indexes, and consistency checks for claim, completion, dead-letter, replay, and receipt states.

These choices match the recommended decision comment on root issue #129. They remain a proposal until exact-commit product-authority approval.

The proposal keeps lease/retry/dead-letter numbers and production transport outside the canonical contract. Those values are supplied by versioned runtime configuration and production infrastructure remains A91 scope.

## Validation

```text
node scripts/validate-dbml.mjs proposals/com-a17-outbox-contract/schema.draft.dbml
node --test proposals/com-a17-outbox-contract/validate-contract.test.mjs
npm run dbml:validate:a12
npm run proposal:validate:boundary
```

`stackcord db diff` currently cannot compare the repository's full canonical schema because its parser stops on the pre-existing duplicate `identity.accounts.lifecycle_version` declaration. The repository's DBML parser succeeds on the proposal and reports 152 tables. Reviewers can inspect the exact additive change with:

```text
git diff --no-index -- db/schema.dbml proposals/com-a17-outbox-contract/schema.draft.dbml
```

## Canonical apply order after approval

1. Rebase the full-schema proposal onto the then-current root `develop` and re-run semantic diff/validators.
2. Apply only the reviewed operations enums, outbox columns/tables, and references to `db/schema.dbml`.
3. Add the approved contract and validator to canonical locations in the same exact commit.
4. Merge the root contract before starting backend migration and implementation on issue #145.
5. Integrate the reviewed backend commit and root submodule pointer only after PostgreSQL concurrency, migration, worker, and full-suite evidence passes.
