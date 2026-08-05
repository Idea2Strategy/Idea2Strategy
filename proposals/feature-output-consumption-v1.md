# Proposal: historical feature-output consumption v1

Status: isolated, unapproved proposal. This is not a release contract and must
not be used to remove `FEATURE_OUTPUT_CONSUMPTION_UNSUPPORTED` until the
protected root contract change has fresh product-authority approval.

Related issue: [#248](https://github.com/Idea2Strategy/Idea2Strategy/issues/248)

## Existing approved meaning

The approved backtest contract and DBML already require official BASIC and
COMPETITION runs to pin shared successful feature materializations and forbid
hidden per-bot recomputation. A materialization identifies a feature definition,
instrument, source-input hash, period, result hash, and one output DERIVED
dataset manifest. The output manifest identifies immutable dataset objects.

Those sources do not yet define the bytes or row schema of a feature-output
object, the time-key interpretation used by `LOAD_FEATURE`, or the exact
completeness join between a compiled plan and the pinned materialization set.
Pipeline code has a canonical JSON hash payload (`[{"at", "value"}, ...]`) but
does not yet make those rows a cross-service storage contract.

## Recommended decision A: binding

1. For every tuple in `requiredFeatures × instruments`, exactly one pinned
   `SUCCEEDED` materialization must exist.
2. `requiredFeatures[].featureId` equals
   `market_data.feature_materializations.feature_definition_id`; the referenced
   definition's semantic version and resolution exactly equal the compiled plan
   values.
3. The materialization instrument equals the plan instrument and its period
   covers warm-up plus the full evaluation window.
4. Missing, duplicate, extra, mismatched, unavailable, or hash-mismatched pins
   fail before execution. Runtime recomputation is forbidden.

## Recommended decision B: object encoding

1. Publish a named schema, `feature-series.parquet.v1`, on both the storage
   object and DERIVED dataset manifest.
2. One materialization manifest contains exactly one feature definition and one
   instrument. Rows are strictly increasing and unique by `bar_start_at`.
3. Required Parquet columns are `bar_start_at` (UTC timestamp) and `value`
   (decimal with scale 8). Feature-definition and instrument IDs remain in the
   authoritative materialization row and are not inferred from paths.
4. `bar_start_at` is the source bar start. A value becomes visible only when
   `bar_start_at + plan resolution <= evaluation as_of`.
5. The consumer verifies exact versioned object bytes against
   `storage.objects.content_hash`, validates schema and ordering, and recomputes
   pipeline `result_hash` from decoded rows and materialization identity. Both
   hashes must match before execution.

## Recommended decision C: runtime behavior

1. `LOAD_FEATURE` reads the latest completed pinned feature row at `as_of` and
   records that value as its operand. Market bars remain separately pinned and
   provide reference and execution prices.
2. A missing feature instant is a deterministic data gap under the existing
   skip/fail policy; it never falls back to calculating the feature from bars.

## Provider work after approval

Data pipeline:

- write `MaterializationResult.values` as immutable
  `feature-series.parquet.v1` objects, including versioned S3 receipt rows;
- atomically publish storage object, dataset-object membership, AVAILABLE
  manifest, lineage, and only then the SUCCEEDED materialization/result hash;
- prove byte hash, decoded result hash, duplicate retry, partial-upload cleanup,
  ordering, schema, and LocalStack version-pinning behavior.

Backend BASIC producer:

- resolve and pin the complete required feature set at release time;
- insert `backtest.input_bundles`, `input_datasets`, and
  `input_feature_materializations`, then expose exact pins to request-to-job
  conversion. The current BASIC request carries no feature materializations.

Backtest consumer:

- resolve definition, output manifest, dataset objects, and versioned storage
  receipts for every pin;
- download and validate feature objects, enforce the compiled-plan completeness
  join, inject the pinned series into `LOAD_FEATURE`, and retain market bars only
  for price and execution;
- add unit, PostgreSQL 16, LocalStack, duplicate, missing-row, wrong-version,
  checksum, schema, ordering, and look-ahead tests before removing the
  fail-closed blocker.

Provider draft implementations must remain unmerged until this proposal is
approved and represented in the protected contract.

## Independent mismatch to repair

The root seed registers RSI_14 as feature definition
`0f1b0000-0000-4000-8000-000000000001`, and the backend compiler emits that
database feature ID. Backtest's element catalog currently recognizes only the
fixture ID `00000000-0000-4000-8000-000000000401`. A production compiled plan
using the seeded catalog is rejected before feature consumption. The consumer
must bind to the approved catalog ID, or load the exact catalog mapping from the
database, instead of relying on a test-fixture UUID.
