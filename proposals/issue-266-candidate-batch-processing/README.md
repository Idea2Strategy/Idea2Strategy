# Root #266: candidate batch processing canonicalization proposal

Status: isolated proposal; **not approved, integrated, or releasable**.

`stackcord governance check --json` returned `unknown` on 2026-08-05 for
protected fingerprint
`sha256:7bb58d50af4c61980d2353a60344e8cf470a7fb00a02c08b729b507816838651`.
Therefore this directory deliberately does not modify `db/schema.dbml`, a
canonical migration contribution, or any protected product/contract source.

## Observed release blocker

The exact root `origin/develop` candidate was
`d522fc23e06b510c00583b493785b90786e64895`. Its trading pointer was
`7e5d464be8ca676fdd6de539e6e5292a65661950`.

At those revisions, `CandidateBatchProcessingEntity` validates
`trading.candidate_batch_processing`, but the table exists only in the
trading-engine private runtime migration
`V2026080101__create_candidate_batch_processing.sql`. The production central
Flyway bundle never executes that private migration. A database migrated only
through the canonical bundle therefore makes `trading-worker` fail Hibernate
schema validation during startup.

## Proposed canonical changes after exact authority approval

1. Add the fragment in `candidate_batch_processing.dbml` to
   `db/schema.dbml`, adjacent to the trading execution-intake tables.
2. Add `V20260805090000__trading_add_candidate_batch_processing.sql` to
   `trading-engine/db/migration-contributions/migrations/`.
3. Make the private Testcontainers migration use `CREATE TABLE IF NOT EXISTS`
   and `CREATE INDEX IF NOT EXISTS`, so a test database with the canonical
   baseline remains compatible. Do not change the columns or constraints.
4. Update `CanonicalBaselineContractTest`: remove
   `candidate_batch_processing` from the private-only negative set and add it to
   the canonical trading write-path positive set. The current negative assertion
   is direct evidence that the F90 runtime and canonical schema disagree.
5. Refresh the root Flyway CI bundle and the root trading submodule pointer.

The generated runtime grants require no hand-written ACL change:
`DatabaseAccessPolicy` derives ownership from the qualified table, maps the
entire `trading` schema to `MigrationOwner.TRADING`, and grants the trading role
read/insert/update/delete on trading-owned tables. The integration test must
still prove those generated privileges against PostgreSQL 16.

## Required approval and verification

Before moving either fragment to a canonical path, obtain a fresh provider
observation for the exact proposal commit and protected fingerprint approving
one configured authority: `user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`, or
`user:hjcud`. Then rerun `stackcord governance check --json`.

The integrating PR must prove:

- canonical bundle assembly includes the new migration exactly once;
- a fresh PostgreSQL 16 database migrates and reports the table, index, primary
  key, status check, and trading runtime DML grants;
- Flyway replay is a no-op;
- `trading-worker` starts with private Flyway disabled and Hibernate validation
  enabled;
- the private Testcontainers migration remains compatible when the canonical
  table already exists.
