---
schema_version: 1
id: contract.market-data.publication.v1
kind: data
status: approved
revision: 1
refs:
  - technology.need.market-data
  - technology.need.object-storage
  - quality.failure-safety
---

# contract.market-data.publication.v1

Status: approved canonical contract. Product authority `user:pjy008008`
approved the exact source proposal on root PR #219 before this canonical write.

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
