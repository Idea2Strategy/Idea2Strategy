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

## Recommended decision D: collision-safe feed identity

`market_data.dataset_manifests` is unique by feed, instrument, data layer,
resolution, period start, and revision. It does not include a feature-definition
ID. A single generic feature feed would therefore make two feature definitions
for the same instrument and period collide even though their values are
different. Reusing an Alpaca `BAR`/`BARS` feed would also mislabel an internal
derived result as provider market data.

Use one deterministic feed identity per immutable feature definition and output
schema version. The provider computes the feed ID with the existing project UUID
namespace as:

```text
deterministic_uuid(
  "feature-output-feed",
  feature_definition.definition_hash,
  feature_definition.calculator_version,
  feature_definition.resolution,
  "feature-series.parquet.v1"
)
```

The first authority-owned seed should register these exact recommended values:

The internal provider ID is
`deterministic_uuid("provider", "IDEA2STRATEGY_INTERNAL")`; it is not an
Alpaca-owned identity.

| Record | Field | Proposed value |
| --- | --- | --- |
| internal provider | `code` | `IDEA2STRATEGY_INTERNAL` |
| internal provider | `display_name` | `Idea2Strategy Derived Data` |
| internal provider | `rights_version` | `internal-derived-v1` |
| internal provider | `status` | `ACTIVE` |
| RSI feed | `code` | `FEATURE_RSI_14_1M_RSI_1_0_0` |
| RSI feed | `data_kind` | `FEATURE_SERIES` |
| RSI feed | `resolution` | `1m` |
| RSI feed | `timezone_name` | `UTC` |
| RSI feed | `feed_version` | `rsi-1.0.0+feature-series.parquet.v1` |

The RSI seed is bound to feature-definition ID
`0f1b0000-0000-4000-8000-000000000001` and definition hash
`sha256:1a7c3e5b9d2f4068a1c3e5b7d9f20416283a5c7e9b1d3f50627496a8c0e2b4d6`.
The UUID input uses that exact lowercase database value, including the
`sha256:` prefix; consumers must not silently strip the prefix for feed
identity while providers use the bare digest. With calculator version
`rsi:1.0.0`, resolution `1m`, and schema `feature-series.parquet.v1`, the exact
feed UUID is `063f8f27-5c6a-5348-b2bb-abc3c634149c`. The production calculator
adapter resolves the approved definition tuple `RSI_14` / `rsi:1.0.0`; it must
not require an unrelated `RSI` / `1.0.0` alias or create a second identity.
The seed migration must pin the deterministic provider and feed UUID literals,
recompute them in a test, insert idempotently, and fail on any pre-existing row
whose immutable fields differ. It must not silently update drift.

This per-definition rule is deliberately narrower than adding a new mapping
table. If product authority later wants a shared multi-feature dataset, the
protected model must first add feature identity to the manifest and its
uniqueness rules; a shared feed cannot be introduced only in provider code.

## Recommended decision E: trusted production input

The production command must not trust a caller-supplied `output_feed_id`, output
manifest ID, revision, source hash, source row count, or inline bar values.
Identifiers in a queue message are requests, not storage attestations.

1. Resolve the feature definition by its approved definition hash and derive the
   feed identity by decision D. Reject a missing, retired, wrong-kind,
   wrong-resolution, or drifted feed.
2. Accept source dataset-object IDs, then load their manifests and
   `storage.objects` receipts from PostgreSQL. Require AVAILABLE state, matching
   instrument and resolution, complete period coverage, and exact lineage-ready
   identities. Resolve the authoritative intersecting object set from the
   catalog and require the request to name that complete set; a non-empty subset,
   overlapping gaps, or objects outside the required warm-up/evaluation interval
   cannot satisfy completeness.
3. Open each source object by its exact `provider_version_id`, verify S3 metadata
   SHA-256, service checksum, size, encryption state, schema, ordering, period,
   row count, and instrument before decoding bars. The receipt's storage
   provider and bucket must equal the selected adapter as well as its key and
   VersionId. An absent service checksum is not success; the implementation must
   require the checksum or independently stream-hash the returned bytes against
   the receipt. Never read the latest key without a VersionId and never calculate
   from inline bars.
4. Derive the input-set hash only from those verified canonical receipts. For
   RSI_14, require an AVAILABLE 1m source and at least fifteen ordered completed
   1m bars. A 30m SIP catalog is not a valid substitute merely because the
   current adapter can deserialize it.
5. Derive the output manifest ID from the materialization identity and
   `feature-series.parquet.v1`; do not let the producer choose an unrelated UUID.

Malformed identity requests are rejected before S3 or PostgreSQL writes.
Transient reads remain retryable. An attestation mismatch is a permanent,
auditable data-integrity failure and never falls back to caller values.

## Recommended decision F: pipeline-run lifecycle and retry

The worker owns the `market_data.pipeline_runs` lifecycle for this command.
Manual SQL is not an operational prerequisite.

1. Derive a stable run ID and idempotency key from
   `MATERIALIZE_FEATURE_OUTPUT` plus the command ID, and persist a RUNNING row
   with an input hash before any materialization row can reference it.
2. Reusing a command ID with the same input reconciles the same run. A prior
   SUCCEEDED result returns the already verified output without uploading or
   inserting again. Reusing it with a different input fails closed.
   Process-local duplicate suppression must not acknowledge this command before
   the durable PostgreSQL reconciliation and changed-input check executes.
3. Success sets the pipeline run to SUCCEEDED with `output_hash` equal to the
   materialization result hash and a completion time, after the exact S3 version,
   storage object, dataset object, lineage, AVAILABLE manifest, and SUCCEEDED
   materialization agree. The materialization must reference that same run, and
   the run's exact pipeline code/version and `input_hash` must match the approved
   feature materialization command and `input_dataset_set_hash`; a merely
   SUCCEEDED unrelated run with a copied output hash is invalid.
4. Failure stores a stable failure code. If this attempt created an S3 version
   but relational publication fails, cleanup deletes that exact VersionId only.
   It must not delete a pre-existing reconciled version or a newer version.
5. Queue acknowledgement occurs only after durable success or successful
   reconciliation. Retry exhaustion parks the original message without
   manufacturing an AVAILABLE output.

## Required provider tests after approval

| Boundary | Required failing and passing evidence |
| --- | --- |
| feed seed | deterministic UUID, idempotent replay, immutable drift refusal, and no mutation of Alpaca bar feeds |
| feed collision | two definitions for one instrument and period publish to distinct feeds; a generic shared feed is rejected |
| command trust | arbitrary output feed/manifest/revision and inline bars cannot redirect or forge publication |
| source attestation | missing, unavailable, wrong-resolution, wrong-instrument, wrong-version, checksum, schema, ordering, period, and row-count mismatches fail closed |
| storage binding | wrong provider or bucket, absent service checksum without verified stream hash, omitted canonical object, and period gap fail closed |
| RSI_14 | exactly fifteen real 1m bars produce one warm result; 30m bars and fewer than fifteen 1m bars are rejected |
| pipeline run | worker-level create, same-input replay, changed-input conflict, exact pipeline/input binding, success completion, stable failure, and retry exhaustion |
| publication | PostgreSQL 16 transaction races, immutable-field collision refusal, one immutable object and manifest, complete manifest/object lineage, and no duplicate rows |
| S3 | LocalStack version pinning, read-after-write verification, exact-version cleanup, pre-existing object reconciliation, and concurrent writer race |
| consumer | missing/extra/duplicate pin, wrong feed/schema/version/hash, look-ahead, and unavailable output remain fail closed |

The first production one-shot smoke is permitted only after these checks pass on
the exact provider and consumer commits. It must use an actual AVAILABLE 1m
source, an on-demand one-off worker, one otherwise-empty command queue, and
assert the CloudWatch success record, zero source/DLQ backlog, pipeline-run
completion, relational lineage, and exact S3 VersionId. Smoke success cannot
approve missing product meaning.

## Authority-owned adoption order

As observed on 2026-08-06, `stackcord governance check --json` reports
`unknown` because fresh exact-commit provider evidence is unavailable. This
proposal therefore remains isolated. A merge or implementation PR does not by
itself turn these recommendations into protected product meaning.

1. `user:kcrmin` (or another configured product authority verified by a fresh
   provider observation) reviews the exact proposal commit and decides the feed
   identity, trusted-input, run-lifecycle, and failure semantics above.
2. The authority-owned change represents accepted meaning in protected
   contracts and, only if the shared-feed alternative is chosen, protected
   DBML. Re-run governance against that exact commit and fingerprint.
3. Add the idempotent provider/feed seed and its drift tests through central
   Flyway. No manual production database insert is an accepted bootstrap path.
4. Implement the pipeline command in order: run lifecycle, canonical source
   resolution, exact-version decode, deterministic output identity, atomic
   publication, cleanup, and retry tests.
5. Implement backend complete-pin production, then backtest exact-version
   consumption and fail-closed completeness tests.
6. Integrate provider, consumer, migrations, deployment configuration, and root
   submodule pointers in dependency order; then run the one-shot smoke and full
   release verification.

Until steps 1 and 2 complete, provider code may be reviewed only as a draft and
must not be described as approved, release-ready, or safe for production
feature-output publication.

## Provider work after approval

Data pipeline:

- write `MaterializationResult.values` as immutable
  `feature-series.parquet.v1` objects, including versioned S3 receipt rows;
- atomically publish storage object, dataset-object membership, AVAILABLE
  manifest, lineage, and only then the SUCCEEDED materialization/result hash;
- prove byte hash, decoded result hash, duplicate retry, partial-upload cleanup,
  ordering, schema, and LocalStack version-pinning behavior.
- use targeted catalog queries and bounded Arrow batch decoding rather than
  loading every catalog table and the whole Parquet result into Python object
  lists. Any maximum supported period or row-count limit is a separate product
  decision; an implementation-only memory shortcut must not silently truncate a
  requested interval.

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
