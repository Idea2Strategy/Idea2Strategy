---
schema_version: 1
id: contract.operations.outbox-delivery.v1
kind: data
status: approved
revision: 1
refs:
  - capability.audit.evidence
---

# contract.operations.outbox-delivery.v1

Status: approved canonical contract. Product authority `user:kcrmin` merged proposal PR [#149](https://github.com/Idea2Strategy/Idea2Strategy/pull/149).

Consumers: backend issue Idea2Strategy/Idea2Strategy-backend#145 and the later A18, A20, A21, A22, and A90 integrations.

## 1. Source of truth and envelope

PostgreSQL `operations.outbox_messages` is the delivery source of truth. A domain transaction inserts the outbox row in the same commit as its aggregate mutation. Failure to insert either side rolls back both.

The envelope fields `owner_domain`, `aggregate_id`, `aggregate_sequence`, `event_type`, `event_schema_version`, `payload_document`, `payload_hash`, `producer_idempotency_key`, and replay lineage are immutable after insert. `idempotency_key` uniquely identifies the command that created one message row. Delivery state may change, but replay never edits or replaces an existing envelope. A transport or cache cannot authorize a state that PostgreSQL does not authorize.

`payload_hash` is calculated from the canonical serialized payload before insertion. Unsupported event schema versions, invalid payloads, and a message key reused with another payload hash fail closed. They are never coerced into a supported version. The producer idempotency key remains stable across an authorized replay chain as evidence, while every replay row has a new message ID and unique row-creation idempotency key.

## 2. Delivery states

| State | Meaning | Allowed next state |
| --- | --- | --- |
| `PENDING` | Eligible when `next_attempt_at` is null or due. | `CLAIMED` |
| `CLAIMED` | Exactly one current worker owns an unexpired claim token. | `PUBLISHED`, `PENDING`, `DEAD_LETTERED` |
| `PUBLISHED` | The current generation received a successful transport acknowledgement. | terminal |
| `DEAD_LETTERED` | Automatic delivery stopped after a permanent or policy-exhausted failure. | terminal; it may be the immutable source of a new authorized replay row |

The row is claimable when it is due `PENDING`, or when it is `CLAIMED` and `claim_expires_at <= database_now`. Reclaim first closes the old append-only attempt as `LEASE_EXPIRED`, then creates a new attempt and replaces the head claim token atomically.

Only the worker presenting the current, unexpired `claim_token` may acknowledge or fail a claim. A late acknowledgement or failure from a stale token returns a conflict and changes neither the head nor attempt evidence.

## 3. Attempts, retry, and dead letter

Every claim creates one append-only `operations.outbox_delivery_attempts` row scoped by `(outbox_message_id, attempt_number)`. An attempt is open until it records exactly one outcome:

- `PUBLISHED`: transport acknowledged the event.
- `RETRY_SCHEDULED`: the versioned policy classified the failure as retryable and supplied the next attempt instant.
- `DEAD_LETTERED`: the failure is permanent or the versioned policy exhausted its budget.
- `LEASE_EXPIRED`: a later worker recovered an abandoned claim.

Lease duration, retry budget, backoff, jitter, timeout, and alert thresholds are not stored as product constants. A versioned runtime policy supplies those values, and the stable `runtime_policy_version` used for each attempt is persisted. Missing or ambiguous policy fails closed without marking the message published.

Dead letter is explicit state, not `next_attempt_at = null`. It requires a reason code and timestamp and is eligible for an operational alert. Delivery and audit metadata must not copy credentials, private strategy source, or unnecessary holdings.

## 4. Authorized replay

Replay is allowed only from `DEAD_LETTERED`. It requires an active operator with the proposed `OPERATIONS_OUTBOX_REPLAY` permission, a non-empty reason code, a correlation ID, and a unique command idempotency key.

The replay command creates a new `operations.outbox_messages` row and an `operations.audit_events` record in one transaction. The source row remains `DEAD_LETTERED` and is never modified. The new row:

- copies owner, aggregate, event type, event schema version, payload bytes/hash, and producer idempotency key exactly;
- receives a new message ID, a new unique row-creation idempotency key, zero attempts, and `PENDING` state;
- points `original_message_id` to the first immutable message in the chain and `replayed_from_message_id` to the immediate dead-lettered source;
- increments `replay_sequence` and links the authorizing audit event.

The replay transaction locks the source and chain root. A given dead-lettered row can have only one direct replay child, and `(original_message_id, replay_sequence)` is unique. Replaying a `PENDING`, `CLAIMED`, or `PUBLISHED` row is rejected. The same command key returns its original new message; the same key with another request hash is rejected.

Production transport provisioning and the operator UI are outside this contract.

## 5. Consumer idempotency receipt

Each consumer handler uses a stable versioned `consumer_handler_id`. Its receipt uniqueness scope is `(consumer_handler_id, outbox_message_id)`. `producer_idempotency_key` and `payload_hash` remain immutable evidence on the receipt, but they are not its unique key.

On first receipt of one message ID, the consumer inserts a `PROCESSING` receipt with the producer idempotency key, canonical payload hash, and a local claim lease. Business effect and transition to `COMPLETED` commit in the same local PostgreSQL transaction. A duplicate delivery of that same message ID and hash behaves as follows:

- `COMPLETED`: return the recorded result identity/hash without rerunning the effect.
- `PROCESSING` with an active lease: report in progress; do not steal the claim.
- `PROCESSING` with an expired lease, or `RETRYABLE_FAILURE`: claim with a new token and retry.
- `PERMANENT_FAILURE`: reject without rerunning the effect.

The same message ID with a different payload hash is a permanent idempotency conflict. It is rejected, audited, and routed to permanent failure/dead-letter handling; an operator cannot overwrite the existing receipt. Authorized reprocessing creates a new replay message and therefore a new `(consumer_handler_id, outbox_message_id)` receipt while preserving the producer key and payload hash evidence.

This receipt guarantees one local handler effect when the effect and receipt share the same transaction. A remote side effect that cannot join that transaction still requires its own provider idempotency key and is verified during A90 integration.

## 6. Concurrency and failure rules

- Claim selection and head update use one PostgreSQL transaction and row-level locking such as `FOR UPDATE SKIP LOCKED`.
- Database time, not worker wall-clock time, decides due and lease-expiry boundaries.
- Crash before transport send leaves an expiring claim; crash after send but before acknowledgement may redeliver, so consumer idempotency remains mandatory.
- A transport acknowledgement never deletes the outbox row or attempt evidence.
- Unknown state, unsupported schema, missing runtime policy, stale token, and ambiguous receipt ownership fail closed.
- Retry or replay never performs domain compensation. Compensation belongs to the owning domain contract.

## 7. Migration and rollout

The change is additive. Existing rows are backfilled with a canonical payload hash and `producer_idempotency_key = idempotency_key` before new writers are enabled. They receive null replay lineage and sequence zero. Rows with `published_at` become `PUBLISHED`; other rows become `PENDING`. Existing attempt counts and failure fields are preserved. No row is inferred as dead-lettered solely because `next_attempt_at` is null.

Deployment order is schema, dual-compatible writer/reader, disabled worker validation, then explicit worker enablement. Rollback after new-state writes is forward-fix only; migrations must not delete delivery or receipt evidence. Production transport, retry numbers, and infrastructure are activated only by later A91 configuration.

## 8. Required verification

- aggregate mutation and outbox insertion commit or roll back together;
- two workers cannot own the same current claim;
- expired claim recovery rejects the first worker's stale acknowledgement;
- crash-after-send redelivery produces one consumer effect;
- retryable and permanent failures produce distinct durable states;
- authorized replay preserves the source row, creates one new message with identical payload/hash/schema/producer key, and records complete lineage;
- unauthorized or duplicate replay is rejected and audited;
- the same handler/message receipt with another payload hash fails closed and cannot be overwritten;
- empty and upgraded database migrations satisfy all checks, references, and indexes.

## 9. Approval and canonical source

Proposal PR [#149](https://github.com/Idea2Strategy/Idea2Strategy/pull/149) records the approved decision source.
This contract and the A17 additive delta in `db/schema.dbml` are canonical.
