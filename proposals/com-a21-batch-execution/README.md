# COM-A21 durable batch execution proposal

This isolated proposal closes the durable ownership gap that remains in backend A21. It does not change `contracts/**` or canonical `db/schema.dbml`, and it is not approved until product authority `user:kcrmin` reviews the exact proposal commit.

Tracking issue: [COM-A21 #164](https://github.com/Idea2Strategy/Idea2Strategy/issues/164).

## Recommended decision

- PostgreSQL is the source of truth for job versions, runs, item ownership, attempts, retry timing, quarantine, and discovery checkpoints.
- A due item has a stable non-sensitive identity `(category_code, source_key, source_version, due_at, replay_sequence)`; repeated scans insert generation zero once.
- A worker may act only while presenting the current unexpired `claim_token`. Expired leases are closed as `LEASE_EXPIRED` before another worker owns the item.
- Every adapter invokes an idempotent domain application port. A batch success record never substitutes for the domain receipt or aggregate state.
- Checkpoints optimize discovery only. Restart and catch-up must rescan an overlap window, and a checkpoint can never authorize skipping an unfinished item.
- Retryable failures return to `PENDING` with a policy-selected `next_attempt_at`. Permanent or exhausted failures become `QUARANTINED` without blocking the rest of a chunk.
- Manual replay never rewrites the quarantined row. An authorized operator action creates the next replay generation with immutable lineage and audit evidence.
- Lease duration, chunk size, retry schedule, maximum attempts, overlap window, and cadence belong to versioned runtime policy rather than DB defaults.

## Rollout order

1. Product-authority review of this isolated proposal.
2. Canonical contract, DBML, and additive migration integration.
3. Disabled backend-batch persistence and worker validation.
4. SESSION, delegated credential/authorization, sanction, notification, and case-deadline adapters.
5. Multi-worker, crash, backlog, poison-item, empty-migration, and upgrade E2E.
6. Explicit scheduler enablement only after the exact integrated commit passes CI.

## Rollback

Before any item is written, the new scheduler and worker can be disabled and the additive schema left unused. After run, attempt, or replay evidence exists, rollback is forward-fix only: stop new claims, preserve every row, and deploy a compatible reader/worker correction.
