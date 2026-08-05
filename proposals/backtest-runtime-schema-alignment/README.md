# Backtest runtime schema alignment proposal

Status: **isolated proposal only; not approved, integrated, deployable, or releasable**.

`stackcord governance check --json` returned `unknown` at root
`4232f3be6c0fc529c3dc2037c702799339308699`. This directory therefore records an
exact adoption candidate without changing `db/schema.dbml`, the central Flyway
bundle, contracts, specifications, governance, or collaboration policy.

## Evidence baseline

- Root baseline: `4232f3be6c0fc529c3dc2037c702799339308699`.
- Root protected fingerprint observed by Stackcord:
  `sha256:6e015a609756c60fed0332ac57aa31935acf328832e4dd76fae93d72e980900a`.
- Merged backtest `develop`: `b8cedcedcb00c3876a1e815fe3bdc4b1fa556046`
  (PR #55, `fix(runtime): consume canonical backtest input bundles`).
- Backtest parent before that correction:
  `155316694bad94c094ccd04ef04d33d7c702a533`.
- Backtest outcome contribution:
  `db/migration-contributions/migrations/V20260802143000__backtest_run_outcome_detail.sql`
  at Git blob `ba62042c14d0f59340adf9b0dde9f5234db4dbe1`.
- Root provider-owned pin migration:
  `db/flyway-ci-bundle/V20260805130000__backtest_run_input_pins.sql`, SHA-256
  `0311a2767e99ead8910afa5f5b5f578e6ca1e0fd7a41f1c321888a61eac0a022`.
- Root runtime grants:
  `db/flyway-ci-bundle/R__database_runtime_grants.sql`, SHA-256
  `04a5ec1558cbf199e942463b321dd95e866a4e6d847dce1ea849645603ab266f`.

`evidence.json` is the machine-readable copy of this baseline. The proposal
validator fails if its evidence, SQL, checksum, or six-column disposition drifts.

## Six-column live drift disposition

The 2026-08-05 runtime boot reported all six names as missing. They do not all
have the same resolution.

| Live-missing column | Historical consumer location | Approved-shape candidate | Owner and disposition |
|---|---|---|---|
| `backtest.run_input_pins.dataset_manifest_id` | pre-#55 singular pin mapping | `backtest.input_datasets.dataset_manifest_id`, joined through `run_input_pins.input_bundle_id` | Backend owns atomic production of the normalized bundle; Backtest consumes it. **Do not add this legacy column.** |
| `backtest.run_input_pins.dataset_hash` | pre-#55 singular pin mapping | `backtest.input_datasets.locked_dataset_hash` | Same provider/consumer split. **Do not add this legacy column.** |
| `backtest.run_input_pins.feature_materialization_version` | pre-#55 singular pin mapping | one or more `backtest.input_feature_materializations.feature_materialization_id` rows and their locked result hashes | Same provider/consumer split. A singular version cannot represent the normalized set. **Do not add this legacy column.** |
| `backtest.runs.result_manifest_id` | merged backtest outcome persistence | nullable UUID on `backtest.runs`; meaningful for `COMPLETED` | Backtest owns the result outcome and writes it. Add with the proposed forward migration after authority approval. |
| `backtest.runs.retryable` | merged backtest outcome persistence | nullable boolean on `backtest.runs`; meaningful for `FAILED` | Backtest owns the failure outcome and writes it. No default: `NULL` and `false` are distinct facts. |
| `backtest.runs.missing_requirements` | merged backtest outcome persistence | nullable JSONB non-empty string array on `backtest.runs`; meaningful for `UNAVAILABLE` | Backtest owns the availability outcome and preserves producer order. Enforce the contract's non-empty string-array shape. |

The merged `b8cedced` table mapping contains the provider-owned normalized
`run_input_pins` columns (`input_bundle_id`, fingerprint, contract version,
checksums, policy version, and pin time) and reads datasets/features through the
bundle child tables. It no longer asks PostgreSQL for the three legacy singular
columns. Adding them now would recreate two sources of truth and reverse PR #55.

## Proposed forward-only migration

`V20260805170000__backtest_run_outcome_detail.sql.proposal` is a timestamp-forward
candidate derived from the merged backtest contribution. Its version is later
than the currently published root migration
`V20260805130000__backtest_run_input_pins.sql`; the older
`V20260802143000` filename must not be inserted into an already migrated database.

The candidate:

- only adds the three durable outcome columns to an existing table;
- retains the non-empty string-array check from the backtest contribution;
- has no `DROP`, rewrite, destructive update, default, or `NOT NULL` backfill;
- deliberately does not add the three retired `run_input_pins` columns.

Its normalized LF SHA-256 is recorded in `CHECKSUMS.sha256`. Adoption must copy
the reviewed bytes exactly or intentionally update this proposal and repeat the
authority review.

## Ownership and grants

- Product/schema meaning: protected root canonical source; configured product
  authority approval is mandatory before adoption.
- Migration contribution owner: `backtest` (`schemas=backtest` in the merged
  backtest contribution metadata).
- Runtime producer for normalized run/input acceptance: Backend.
- Runtime consumer for normalized input evidence: Backtest.
- Runtime writer for the three outcome columns: Backtest.
- Flyway/database object owner: the central migration owner, never an application
  login role.

No new table or sequence is created. PostgreSQL table-level privileges already
cover columns added later, and the root repeatable grant unit currently gives:

- `idea2strategy_backend`: `SELECT, INSERT` on `backtest.runs` and the normalized
  input tables;
- `idea2strategy_batch`: `SELECT` on those tables;
- `idea2strategy_backtest`: `SELECT, INSERT, UPDATE` on those tables.

Therefore no privilege expansion is proposed. After the repeatable grant unit is
re-applied, run `grants-verification.sql.proposal`; it verifies the existing
least-privilege matrix reaches the new columns and that the Backtest role does not
own the table.

## Exact adoption sequence after authority approval

1. Refresh the Git review provider observation for the exact integration head and
   protected fingerprint. Run `stackcord governance check --json`; proceed only
   when it names one configured product authority and reports approval.
2. Advance the root `backtest-engine` gitlink to reviewed commit `b8cedced` (or a
   descendant that preserves PR #55) and verify the submodule is clean.
3. In the backtest repository, supersede the old out-of-order contribution with a
   new migration version later than every published central migration. Start from
   the exact approved SQL in this proposal; do not deploy the historical
   `V20260802143000` filename into the current database.
4. Extend the root bundle assembly to accept the exact pinned Backtest contribution
   directory, with the same regular-directory, clean-worktree, pinned-gitlink, name,
   collision, and checksum checks used for other service contributions.
5. Update the protected root DBML `backtest.runs` table with the three nullable
   outcome columns and the `missing_requirements` check. Do not add the three legacy
   `run_input_pins` columns.
6. Regenerate the central Flyway bundle and manifest. Confirm the adopted migration
   checksum equals the approved checksum, or obtain a new exact review if ownership
   headers or bytes necessarily differ.
7. Apply on a fresh PostgreSQL 16 database, re-run to pending `0`, then upgrade a
   snapshot at the current `V20260805130000` history. Run
   `grants-verification.sql.proposal` after the repeatable grants.
8. Run the merged Backtest schema guard and the outcome round trips for
   `COMPLETED`, `FAILED`, and `UNAVAILABLE`; verify Basic 2, custom 1, and competition
   1 lanes read normalized bundle inputs without legacy columns.
9. Rebuild Backtest API/worker images from the exact pinned commit, deploy without
   manual SQL, and retain API/worker health plus retry/reordering evidence on root
   issues #248 and #266.

Until all steps pass, this proposal is neither a migration source nor release
evidence.
