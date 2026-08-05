# Root #266: backtest canonical schema alignment proposal

Status: isolated proposal; **not approved, integrated, or releasable**.

The 2026-08-05 local container boot used root commit `f3069b9` merged with
`origin/develop` `5a5fa3f`, backtest runtime commit
`affb332c4b46425e33c25a8d03996eae6f6eaeb8`, and a freshly applied 44-unit
central Flyway bundle. Flyway succeeded, but `backtest-api` failed closed with:

- `backtest.runs.result_manifest_id` missing;
- `backtest.runs.retryable` missing;
- `backtest.runs.missing_requirements` missing;
- `backtest.run_input_pins.dataset_manifest_id` missing;
- `backtest.run_input_pins.dataset_hash` missing;
- `backtest.run_input_pins.feature_materialization_version` missing.

This is not a Compose default problem. It is a canonical model conflict:

- root `db/schema.dbml` and central
  `V20260805130000__backtest_run_input_pins.sql` define the provider-owned pin
  row with `input_bundle_id` and `input_contract_version`;
- backtest's merged runtime table mapping and its historical unintegrated
  `V20260802094500__backtest_run_input_pins.sql` define a different row that
  duplicates dataset and feature fields;
- backtest's merged `V20260802143000__backtest_run_outcome_detail.sql` defines
  the three outcome fields, but root DBML and the assembled central bundle do
  not include them;
- root `prepare-flyway-bundle.ps1` intentionally assembles backend, trading and
  pipeline sources only, so neither backtest contribution is applied.

## Recommended protected decision

Keep the current root/provider pin ownership and shape. It already states that
Backend atomically writes the run, input bundle, dataset/feature pins and Outbox
message. Do **not** reintroduce a second dataset/feature source on
`run_input_pins`.

After exact authority approval:

1. Update the backtest consumer mapping and repository query to read the root
   canonical `run_input_pins` columns and resolve dataset/feature evidence
   through `input_bundle_id` -> `input_datasets` and
   `input_feature_materializations`.
2. Supersede or retire the conflicting historical backtest pin contribution;
   do not add its older `CREATE TABLE` unit to a database where the root table
   already exists.
3. Add `result_manifest_id`, nullable `retryable`, and nullable
   `missing_requirements` to root DBML and a new forward-only backtest-owned
   migration whose timestamp is later than `V20260805130000`.
4. Preserve the non-empty string-array check for `missing_requirements` and
   document that each nullable outcome field applies only to its corresponding
   terminal status.
5. Register backtest as an explicit source in the root bundle workflow only
   after its contribution directory contains forward-only units compatible
   with the already published central history. An alternative is to copy the
   approved forward migration into the existing central owner source, but the
   source revision and owner evidence must remain exact.

## Required authority approval

`stackcord governance check --json` is currently `unknown`. Before changing
DBML, canonical migration meaning, or the consumer obligation, a fresh provider
observation for the exact integrating commit and protected fingerprint must
approve one configured authority: `user:kcrmin`, `user:pjy008008`,
`user:Juwon-Na`, or `user:hjcud`.

The approval must explicitly accept:

- root/provider ownership and normalization of the pin row;
- backtest resolving dataset/feature evidence through the canonical bundle;
- persistence of result manifest, retryability and missing-requirement detail.

## Integration evidence required

- fresh PostgreSQL 16 migration and replay;
- upgrade from the current 44-unit database without out-of-order Flyway;
- exact schema guard success for API and worker;
- provider write followed by backtest consumer read for Basic, Custom and
  Competition lanes;
- COMPLETED/FAILED/UNAVAILABLE round trips retaining the corresponding outcome
  detail;
- generated runtime grants and ownership verification.
