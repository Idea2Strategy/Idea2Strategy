---
schema_version: 1
id: contract.market-data.publication.v1
kind: data
status: approved
revision: 2
refs:
  - technology.need.market-data
  - technology.need.object-storage
  - quality.failure-safety
---

# contract.market-data.publication.v1

Status: approved canonical contract. Product authority `user:pjy008008`
approved the original source proposal on root PR #219; product authority
`user:kcrmin` approved the historical feature-output extension on root PR #312.

## 1. Ownership and immutable objects

The Data Pipeline owns acquisition, normalization, validation, and publication
of historical market data and corporate action evidence. S3 owns immutable
large objects; PostgreSQL owns discoverable dataset manifests, object metadata,
claims, durable idempotency receipts, publication state, and watermarks.

Objects use content-addressed or otherwise collision-resistant immutable keys.
Upload completion does not make data readable by consumers. Size, checksum,
schema, codec/footer, observation period, provider/feed identity, and object
version must verify before PostgreSQL may mark the object and its manifest
`AVAILABLE`.

## 2. Claim and durable result ledger

Each semantic ingestion job has a stable idempotency identity and canonical
payload hash. First receipt creates a durable claim/result ledger entry.
Duplicate delivery with the same hash resumes the active claim or returns its
recorded result. Reusing an identity with a different hash fails closed.

Claims use database time, an opaque token, bounded lease, heartbeat, and
attempt lineage. Only the current unexpired token may commit publication or
failure. SQS visibility is renewed while work is active, but it never replaces
the PostgreSQL ownership decision.

## 3. Commit order and watermark

Publication order is: upload immutable S3 objects, verify them, commit object
metadata and the complete manifest in one PostgreSQL transaction, then advance
the durable watermark. Consumers select only `AVAILABLE` manifests.

A process-memory cursor, SQS acknowledgement, uploaded object, or partially
written manifest is not a committed watermark. Restart from a missing, stale,
or advanced checkpoint expands overlap discovery and relies on stable object
and item uniqueness instead of skipping uncertain work.

## 4. Corporate action evidence

Every corporate action records provider identity, provider event identity,
source and retrieval timestamps, affected security, effective dates, normalized
event version, canonical payload hash, and immutable raw evidence in S3. A
correction creates a new revision with explicit supersession; it never mutates
the prior evidence.

Backtest and Trading consume an exact corporate action dataset revision through
their locked manifest. Missing, conflicting, unlicensed, or unverifiable
corporate action evidence fails closed for the affected period/security.

## 5. Cancellation and failure

Cancellation is durable and checked between bounded units. An acknowledged
cancellation cannot publish an `AVAILABLE` manifest. Retryable, permanent,
quarantined, and cancelled outcomes are distinct and retain stable non-secret
failure codes. A poison item does not block unrelated later items.

## 6. Required verification

- duplicate and conflicting idempotency deliveries;
- lease expiry, late acknowledgement, visibility renewal failure, and restart;
- crash before upload, after upload, before manifest commit, and before queue
  acknowledgement;
- checksum/schema/footer rejection and unavailable partial manifests;
- durable watermark overlap recovery without missing or duplicate publication;
- corporate action correction/supersession and exact historical reproduction;
- cancellation race and DLQ redrive evidence.

## 7. Historical feature-output identity and encoding

An official feature output uses schema `feature-series.parquet.v1`, exactly one
immutable feature definition and instrument per manifest, strictly increasing
unique `bar_start_at` UTC timestamps, and decimal `value` rows at scale 8. A
value becomes visible only after its source bar completes. Feature and
instrument identity come from the authoritative relational materialization,
not an object path or caller payload.

Each immutable feature definition has its own deterministic internal feed. The
feed UUID is derived from the exact lowercase stored `definition_hash`,
including its `sha256:` prefix, the exact calculator version and resolution,
and `feature-series.parquet.v1`; consumers must not strip or normalize those
identity inputs differently. The first official definition is `RSI_14` with
calculator adapter `rsi:1.0.0`, definition ID
`0f1b0000-0000-4000-8000-000000000001`, definition hash
`sha256:1a7c3e5b9d2f4068a1c3e5b7d9f20416283a5c7e9b1d3f50627496a8c0e2b4d6`,
and deterministic feed ID `063f8f27-5c6a-5348-b2bb-abc3c634149c`.

That feed has code `FEATURE_RSI_14_1M_RSI_1_0_0`, kind `FEATURE_SERIES`,
resolution `1m`, timezone `UTC`, and version
`rsi-1.0.0+feature-series.parquet.v1`. It belongs to the deterministic
`IDEA2STRATEGY_INTERNAL` provider with rights version `internal-derived-v1`;
it is never an Alpaca BAR/BARS feed. Seeds are forward-only and idempotent and
must refuse immutable drift instead of updating it.

## 8. Trusted materialization lifecycle

`MATERIALIZE_FEATURE_OUTPUT` resolves the authoritative complete intersecting
source-object set from PostgreSQL. A caller-provided subset, output feed,
manifest, revision, hash, row count, or inline bars is not an attestation. Every
receipt must match storage provider, bucket, key and exact VersionId, size,
encryption, schema, ordering, period, row count and checksum. A missing service
checksum succeeds only when the implementation independently stream-hashes the
bytes against the receipt. Objects must cover the complete warm-up and
evaluation interval without gaps and be AVAILABLE at the exact instrument and
resolution.

The worker durably reconciles command ID and canonical input hash before local
duplicate suppression or queue acknowledgement. Same-input replay returns the
verified result; changed-input reuse fails closed. Its pipeline run has code
`MATERIALIZE_FEATURE_OUTPUT`, version `feature-series.parquet.v1`, input hash
equal to `feature_materializations.input_dataset_set_hash`, and output hash
equal to the materialization result hash. Success follows exact-version object
verification and atomic relational publication. Failure records a stable code;
cleanup deletes only the exact version created by that attempt. Catalog reads
are targeted and decoding is bounded/streamed; implementations must not load
whole production tables or silently truncate an interval to avoid memory use.

Required evidence includes changed-input redelivery, omitted canonical object,
period gap, wrong provider/bucket/version/checksum/schema/ordering/row count,
immutable UUID collision, PostgreSQL revision races, LocalStack exact-version
cleanup and concurrent writers, and bounded-memory decoding.
