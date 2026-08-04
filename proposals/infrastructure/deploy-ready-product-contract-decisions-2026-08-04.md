# Deploy-ready product and contract decision proposal — 2026-08-04

Status: **requester-selected recommendation; isolated proposal pending an exact GitHub product-authority approval**

This file records the decisions needed to unblock the non-AWS implementation.
It is intentionally outside `specs/**` and `contracts/**`. It must not be
described as canonical, integrated, or releasable until a fresh GitHub review
observation for an allowed product authority passes
`stackcord governance check --json` for the exact commit and protected
fingerprint.

## Backtest request boundaries

- Basic backtest is triggered automatically from an immutable bot release and
  routes to the Basic lane.
- Custom backtest identifies the user, bot release, inclusive requested period,
  versioned security universe, immutable market-data manifest, execution-policy
  version, and idempotency key. Repeating the same key and semantic input returns
  the same job; reusing the key for different input fails closed.
- Competition backtest identifies the competition, participant, immutable bot
  release, competition-defined period, fixed dataset manifest, and fixed
  execution/scoring policy. A participant cannot choose those fixed inputs.
- Basic, Custom, and Competition use distinct SQS queues and DLQs. The worker
  has logical concurrency 2/1/1 respectively; excess requests wait durably in
  the appropriate queue.
- PostgreSQL owns job state. A claim has an owner, lease expiry, and heartbeat;
  expired claims are reclaimable. Completion, failure, cancellation, and result
  publication are idempotent and reject stale claim owners.
- Cancellation is persisted before delivery is acknowledged. A worker checks
  cancellation at bounded checkpoints, publishes no success after cancellation,
  and records whether a partial artifact was discarded or retained for audit.

## Pipeline publication and corporate actions

- The Pipeline owns raw/normalized market-data object publication and a durable
  claim-result ledger. S3 object content is immutable and content addressed;
  PostgreSQL publishes the discoverable manifest only after all required
  objects exist and validate.
- Re-delivery resumes or returns the recorded result for the same semantic job.
  A conflicting payload under the same idempotency identity fails closed.
- A durable watermark advances only after publication commit. Process memory,
  an SQS receipt, or an object upload alone is not a committed watermark.
- Corporate actions require provider identity, source timestamp, retrieval
  evidence, normalized event version, and immutable raw evidence in S3. Their
  effective application is versioned and reproducible by Backtest and Trading.

## Trading and operator scope

- The initial release is virtual execution driven by Alpaca SIP market data. It
  does not place live broker orders and must not present simulated fills as
  broker-confirmed fills.
- Trading restart reconciles durable orders, fills, positions, and ledger state
  before intake. Missing or degraded market data fails closed for affected
  evaluation and order generation.
- Admin MCP is read-only in the initial release. Mutating operator tools remain
  unavailable until their authorization, audit, confirmation, idempotency, and
  rollback contracts receive a separate approval.

## Runtime implications

- Core continuously hosts `backend-api`, `backend-worker`, and result-reading
  `backtest-api`; `backend-batch` and read-only `admin-mcp` are on demand.
- Trading materializes versioned mapping/provider-rights/warm-up bundles from S3
  before startup, verifies checksums, and mounts them read-only.
- Scheduled batch and operator sessions use SSM, acquire a durable execution
  lock, emit correlated audit evidence, and never require SSH.

## Required approval sequence

1. An allowed product authority approves the exact proposal commit in GitHub.
2. A fresh normalized GitHub observation passes the Stackcord pre-write gate.
3. The proposal is implemented into canonical specifications/contracts and
   provider/consumer tests in dependency order.
4. The exact resulting commit receives a fresh product-authority approval.
5. Stackcord is rerun before integration and release; any changed protected
   fingerprint or head commit invalidates the earlier observation.
