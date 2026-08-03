---
schema_version: 1
id: contract.operations.durable-batch-execution.v1
kind: data
status: approved
revision: 1
refs:
  - contract.operations.outbox-delivery.v1
  - contract.operations.case-response-deadline.v1
  - capability.audit.evidence
  - quality.failure-safety
---

# contract.operations.durable-batch-execution.v1

Status: approved canonical contract. Product authority `user:kcrmin` merged proposal PR [#166](https://github.com/Idea2Strategy/Idea2Strategy/pull/166).

## 1. Purpose and boundaries

`backend-batch` discovers time-based work and invokes existing idempotent domain application ports. It owns durable scheduling evidence, item ownership, retry, quarantine, and restart recovery. It does not own session, credential, sanction, notification, or case transition rules and cannot turn a failed domain command into success.

The initial registered categories are `SESSION_EXPIRY`, `DELEGATED_CREDENTIAL_EXPIRY`, `DELEGATED_AUTHORIZATION_EXPIRY`, `SANCTION_EXPIRY`, `NOTIFICATION_RETRY`, and `CASE_RESPONSE_DEADLINE`. A category is executable only when its adapter and policy version are registered. Unknown categories fail closed and are not claimed.

## 2. Versioned registry and runs

A published job version fixes the allowed category set and a content hash. Published versions are immutable. At most one version of a job code is active; activating or retiring a version is an audited deployment action, not a public API command.

A run fixes `job_code`, `job_version`, `runtime_policy_version`, a half-open discovery window `[window_start, window_end)`, trigger identity, and database start time. The unique trigger identity prevents duplicate runs for the same scheduler event. A run may finish `SUCCEEDED`, `PARTIAL_FAILED`, `FAILED`, or `CANCELLED`; item and attempt rows remain authoritative evidence even if the run process disappears before updating its summary.

## 3. Stable item identity

Each category adapter emits a non-sensitive `source_key`, `source_version`, and exact `due_at`. Generation-zero identity is `(category_code, source_key, source_version, due_at, 0)`. Repeated scans use insert-on-conflict and do not replace its first discovery evidence.

`source_key` is an opaque UUID or HMAC-safe stable identifier and cannot contain email, token, OIDC subject, free-form case text, notification body, or another secret. `source_version` identifies the expected domain head or immutable deadline identity. The item row stores no domain command payload.

An authorized manual replay creates a new row with incremented `replay_sequence`, `original_item_id`, `replayed_from_item_id`, and `replay_audit_event_id`. It never changes a terminal item or erases failure history.

## 4. Claim and lease

An item is claimable when it is due `PENDING`, or when it is `CLAIMED` with `claim_expires_at <= database_now`. Claim uses bounded keyset selection ordered by `(next_attempt_at, due_at, id)` and row locking with `FOR UPDATE SKIP LOCKED` or an equivalent single-owner transaction.

Claim atomically assigns a random `claim_token`, worker ID, claim time, lease expiry, and next attempt number. Reclaim first closes the previous open attempt as `LEASE_EXPIRED`, then issues a new token. Only the current token while `database_now < claim_expires_at` can record success, retry, quarantine, or skip. A stale acknowledgement fails closed and cannot change the item head.

The worker invokes the domain port with the stable item identity and correlation ID. Domain state and its durable idempotency receipt decide whether the business effect is `APPLIED` or `ALREADY_APPLIED`; the batch item records that result but cannot replace it.

## 5. Retry, quarantine, and chunk isolation

Retry policy is selected by stable `runtime_policy_version`. A retryable failure closes the current attempt as `RETRY_SCHEDULED`, clears ownership, increments the item attempt count, and sets a policy-selected `next_attempt_at`. A permanent failure or policy-exhausted retry closes the attempt and item as `QUARANTINED` with a stable failure code.

One item failure never rolls back already completed items or permanently blocks later items in the chunk. Secrets, raw payloads, stack traces, and user content are excluded from failure codes and audit documents. Operational logs correlate by run, item, attempt, and correlation UUID.

## 6. Checkpoint and restart

A checkpoint is a discovery optimization scoped by job version, category, and shard. It stores only the last scanned `(due_at, source_key)` cursor and counts. It never marks an item complete and never overrides an item or domain receipt.

Restart uses a policy-defined overlap before the checkpoint and relies on stable item uniqueness to absorb duplicate discovery. If a checkpoint is missing, stale, ahead of unfinished work, or inconsistent with its job version, the scanner expands the rescan rather than skipping work. A graceful stop stops claiming, allows bounded in-flight work to finish, and leaves expired leases recoverable.

## 7. Time, enablement, and failure behavior

All due, lease, retry, and boundary decisions use PostgreSQL database time after required locks. JVM time may drive metrics only. Cadence, lease duration, chunk size, maximum attempts, overlap, and retry delays are versioned configuration values and have no product-semantic DB defaults.

The production scheduler defaults disabled. It may be enabled only when the canonical migration, all registered adapters, exact policy version, PostgreSQL concurrency tests, and deployment configuration are present. Missing registry, policy, adapter, database time, or audit persistence fails closed before claiming.

## 8. Ownership, classification, retention, and deletion

The backend operations domain owns these records. They are internal operational evidence and may contain opaque aggregate identifiers, timestamps, stable result/failure codes, and hashes, but never raw credentials, notification bodies, case evidence, email addresses, OIDC subjects, or free-form user/operator text.

Until a separately approved operations-retention policy assigns this category a disposition and duration, run, item, attempt, replay, and checkpoint evidence is retained and no cleanup job may delete or scrub it. Legal hold always blocks destructive processing. An approved cleanup may remove obsolete checkpoints first because they are only discovery optimizations; it cannot delete a checkpoint in a way that suppresses overlap rescan. Item/attempt/replay evidence may be archived or deleted only after linked domain idempotency, audit, incident, and legal obligations allow it, and cleanup itself must be auditable and idempotent.

Migration is additive and precedes disabled worker validation. No production data is backfilled by inference. Once evidence exists, schema rollback is forward-fix only.

## 9. Required verification

- two workers cannot own the same current item;
- expired lease recovery rejects the first worker's late success or failure;
- crash before the domain call, after the domain commit, and before batch acknowledgement does not duplicate the domain effect;
- exact due boundary and backlog catch-up use database time without early or missing transitions;
- retryable, permanent, and exhausted failures produce distinct durable outcomes;
- poison items do not block later chunk items;
- restart with missing, stale, and advanced checkpoints safely rescans overlap;
- authorized replay preserves lineage and unauthorized replay creates no row;
- empty and upgraded PostgreSQL migrations, disabled-startup, and the full backend suite pass.
