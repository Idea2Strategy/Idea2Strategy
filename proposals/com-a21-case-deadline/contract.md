---
schema_version: 1
id: proposal.operations.case-response-deadline.v1
kind: business
status: proposed
revision: 1
refs:
  - contract.operations.user-case.v1
  - capability.audit.evidence
---

# Case response deadline

## Purpose

An operator information request may open a bounded response window. Expiry returns the case to human review without deciding the case on the user's behalf.

## State and time rules

1. `INFORMATION_REQUESTED` may transition `OPEN` or `UNDER_REVIEW` to `NEEDS_INFORMATION` only with non-null `response_deadline_at` and `deadline_policy_version`.
2. The application obtains the deadline from a versioned policy resolver. API callers and batch workers cannot supply a duration or override the resolved instant.
3. The response window is `[information_requested_at, response_deadline_at)`, evaluated with PostgreSQL database time.
4. `ADD_EVIDENCE` succeeds only when the case is `NEEDS_INFORMATION` and locked database time is strictly earlier than `response_deadline_at`. Success clears the current deadline and returns the case to `OPEN` as already defined by the user-case contract.
5. At `database_now >= response_deadline_at`, the idempotent A20 application port transitions a still-matching `NEEDS_INFORMATION` head to `UNDER_REVIEW`, clears the current deadline, and appends `INFORMATION_RESPONSE_DEADLINE_EXPIRED`.
6. Expiry never produces `RESOLVED`, `REJECTED`, a sanction, or a negative account eligibility decision.

## Concurrency and idempotency

- Evidence and expiry lock the same `operations.cases` row before reading database time and expected case version.
- Exactly one command can advance a given head. A stale version, changed status, or changed deadline returns `ALREADY_TRANSITIONED` without another event or notification.
- The expiry idempotency identity is `(case_id, expected_case_version, response_deadline_at)`. A durable system receipt or equivalent unique constraint preserves the first result across worker restart.
- A21 only claims due keys and invokes the A20 port. It does not reproduce transition rules.
- Due scans use `(response_deadline_at, id)` keyset ordering, bounded chunks, database time, and `FOR UPDATE SKIP LOCKED` or an equivalent single-owner claim.

## Evidence and visibility

- The expiry event is `USER_VISIBLE`, actor type `SYSTEM`, and uses stable reason code `INFORMATION_RESPONSE_DEADLINE_EXPIRED`.
- The event records the expired deadline and policy version but no operator-only note or private evidence.
- The case event and user notification outbox message commit atomically. Delivery failure does not roll back the state transition and remains retryable through A17/A18.
- Audit evidence records correlation ID, expected and resulting version, deadline, policy version, database decision time, and `APPLIED` or `ALREADY_TRANSITIONED`.

## Required verification

- just-before versus exact-deadline evidence acceptance;
- evidence/expiry row-lock race in both lock orders;
- duplicate worker delivery and lease recovery;
- stale status, stale version, and replaced deadline no-op;
- one event, one notification envelope, and one durable receipt;
- backlog catch-up after downtime without early or missing transitions;
- empty and upgrade migration coverage.
