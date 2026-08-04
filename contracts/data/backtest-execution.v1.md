---
schema_version: 1
id: contract.backtest.execution.v1
kind: data
status: approved
revision: 3
refs:
  - capability.backtest.automatic
  - journey.backtest.review
  - scenario.strategy.release
  - quality.failure-safety
---

# contract.backtest.execution.v1

Status: approved canonical contract. Product authority `user:pjy008008`
approved the exact source proposal on root PR #219 before this canonical write.

## 1. Lanes and immutable inputs

Every request belongs to exactly one lane: `BASIC`, `CUSTOM`, or `COMPETITION`.
Each lane has a distinct SQS queue and DLQ. One `t4g.medium` worker exposes a
2/1/1 logical concurrency boundary in that order; work above a lane limit stays
durably queued and cannot borrow a slot from another lane.

`BASIC` is created once from an immutable bot release. `CUSTOM` fixes the
requesting account, immutable bot release, inclusive evaluation dates,
versioned security universe, immutable dataset manifest, execution-policy
version, initial cash, and idempotency key. `COMPETITION` fixes the competition,
participation, immutable bot release, hidden evaluation period, shared dataset
manifest, scoring/execution policy, and idempotency key. A participant cannot
select or replace competition inputs.

The canonical payload carries stable identifiers and hashes, not mutable
strategy drafts, object bodies, credentials, or provider secrets. A request is
accepted only after every referenced release, policy, period, and manifest is
locked and mutually compatible.

`executionPolicyVersion` is an immutable identifier from the locked Backtest
execution-policy catalog. It is copied unchanged to the registered Run and its
work message. Accounting, fee, scoring-template, or room-policy identifiers are
not substitutes. Missing catalog versions or pinned artifacts fail closed
before either a Run or an Outbox event is committed.

`runs.configuration_hash` remains the immutable bot launch configuration hash;
it is not an execution-input digest. `input_bundle_fingerprint` is the
lane-versioned digest of every immutable execution input carried by that lane's
approved request contract. Its exact contract version is stored with the pin.
The worker must compare the queued fingerprint with the stored pin and must not
derive it from `runs.configuration_hash`.

At acceptance the Backend commits the Run, input bundle, every dataset/feature
pin, `run_input_pins`, and Outbox event in one transaction. Input-bundle rows
therefore exist while a run is `QUEUED`, `FAILED`, or `UNAVAILABLE`; result
publication verifies and reuses them instead of replacing them. Every lane first
enters a producer-request queue. A validating Backtest intake converts it to a
distinct execution-lane job queue only after the stored Run and pins match.

## 2. Idempotency and ordering

The Backend producer generates a stable `runId` before publication and commits
the Run, its immutable input rows, and lane-specific Outbox event in one
PostgreSQL transaction. The
Outbox payload carries that same `runId`, lane, `executionPolicyVersion`,
producer idempotency key, canonical payload hash, and aggregate sequence. The
consumer never creates or replaces Run identity.

For a Competition period, the producer also commits the unique
`(participationId, evaluationPeriodId, runId)` link in that transaction, before
work is visible. Relay cannot be enabled until the Run, link, and Outbox write
are proven atomic.

The idempotency identity is scoped by lane and owner. Repeating the same key
with the same canonical payload hash returns the existing run. Reusing it with
different semantic input fails with a stable conflict and emits no new event.

Consumers persist the message ID, producer idempotency key, canonical payload
hash, aggregate sequence, and result. Duplicate delivery cannot create another
run or publish another terminal result. An older aggregate sequence cannot
overwrite a newer accepted state.

## 3. Claim, lease, heartbeat, and reclaim

PostgreSQL is authoritative for execution state. Claim atomically records a
random `claimToken`, `workerId`, attempt number, `claimedAt`,
`claimExpiresAt`, and `lastHeartbeatAt` using database time. Every ownership
mutation compares both `attemptId` and `claimToken` and must affect exactly one
row; zero rows is a stale-owner failure. The current worker renews the claim
with a bounded heartbeat. An expired claim is reclaimable; reclaim closes the
prior attempt with terminal reason `LEASE_EXPIRED` and inserts the next attempt
with `previousAttemptId` lineage in the same transaction.

Only the current unexpired claim token may publish progress, checkpoint,
success, retry, failure, or cancellation. A late worker fails closed. SQS
visibility renewal is required while the claim remains active, but an SQS
receipt alone never proves database ownership or completion.

## 4. Cancellation, retry, and scale-down

Cancellation is persisted on the Run as request time and stable reason before
its delivery is acknowledged. The worker checks it before execution and at
bounded checkpoints. Cancellation completion and terminal publication use
database time and the current fenced claim. Once accepted, no success may be
published; cancellation and success are mutually exclusive terminal outcomes.
Partial artifacts are either unreferenced and later collected or retained as
explicitly non-result audit evidence.

Retryable failure records a stable code and schedules a policy-versioned retry.
Permanent or exhausted failure records one terminal result and leaves the
original request immutable. DLQ redrive requires an authorized, audited action
and preserves the original message identity.

Worker scale-down is permitted only after every lane has zero visible and
in-flight messages, PostgreSQL has no valid running claim owned by the worker,
all checkpoints/results are durable, and the configured idle grace elapsed.
Approximate SQS metrics alone cannot authorize termination.

## 5. Result publication

Large trades, replay ledger, positions, and series are immutable objects. The
worker verifies size, schema, checksum, and object version before PostgreSQL
commits the result manifest as available. Compact status and summary remain in
PostgreSQL. A result is complete only when relational state and every referenced
object agree; an object upload by itself is not success.

Competition publishes a period result only to its locked participation and
creates an aggregate only after all required periods succeed and verify.
Backtest delay or failure never changes live bot lifecycle, virtual orders,
positions, or the official trading ledger.

## 6. Required verification

- 2/1/1 lane saturation leaves excess work queued without starvation;
- same-key retry is stable and conflicting payload reuse fails closed;
- producer-request and execution queues are distinct for all three lanes;
- queued input rows and the lane-versioned fingerprint survive worker failure;
- Competition jobs consume every locked dataset and feature materialization and
  fail closed on missing, changed, unavailable, or hash-mismatched inputs;
- duplicate, reversed sequence, crash, visibility renewal failure, and DLQ
  handoff do not duplicate effects;
- lease expiry permits reclaim and rejects the first worker's late completion;
- PostgreSQL 16 races cover heartbeat versus reclaim, cancellation versus
  checkpoint/success, duplicate claim, and duplicate terminal delivery;
- cancellation wins against checkpoint and terminal publication races;
- result manifest cannot become available before every object verifies;
- worker shutdown with visible, in-flight, claimed, or unpublished work is
  rejected.
