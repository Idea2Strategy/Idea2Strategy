---
schema_version: 1
id: contract.operations.case-response-deadline.v1
kind: business
status: approved
revision: 1
refs:
  - contract.operations.user-case.v1
  - capability.audit.evidence
---

# contract.operations.case-response-deadline.v1

Status: approved canonical contract. Product authority `user:kcrmin` merged the exact proposal in PR [#158](https://github.com/Idea2Strategy/Idea2Strategy/pull/158).

## 1. Purpose and non-goals

An operator information request may open a bounded response window. Expiry returns the case to human review without deciding the case for the user. Expiry never resolves or rejects a case, applies a sanction, or changes account eligibility.

## 2. State and time rules

`INFORMATION_REQUESTED` may transition `OPEN` or `UNDER_REVIEW` to `NEEDS_INFORMATION` only with a non-null `response_deadline_at` and `deadline_policy_version`. A versioned policy resolver selects the deadline; API callers and batch workers cannot provide a duration or override the resolved instant.

The response window is `[information_requested_at, response_deadline_at)` and is evaluated with PostgreSQL database time after locking the current `operations.cases` row. `ADD_EVIDENCE` succeeds only while locked database time is strictly before the deadline. A successful response clears the current deadline and returns the case to `OPEN` under `contract.operations.user-case.v1`.

At `database_now >= response_deadline_at`, the A20 deadline port transitions a still-matching `NEEDS_INFORMATION` head to `UNDER_REVIEW`, clears the deadline pair, and appends `INFORMATION_RESPONSE_DEADLINE_EXPIRED`.

## 3. Concurrency and idempotency

Evidence and expiry lock the same case row before reading database time, status, version, and deadline. Exactly one command may advance a head. A stale version, changed state, or replaced deadline returns `ALREADY_TRANSITIONED` without another event or notification.

The expiry identity is `(case_id, expected_case_version, response_deadline_at)`. An immutable receipt preserves the first `APPLIED` or `ALREADY_TRANSITIONED` result across retry and worker restart. Due scans use `(response_deadline_at, id)` ordering, bounded pages, database time, and `FOR UPDATE SKIP LOCKED` or an equivalent single-owner claim.

A21 claims due identities and invokes the A20 application port. It must not duplicate the transition rules.

## 4. Event, notification, and audit evidence

The expiry event is `USER_VISIBLE`, uses actor type `SYSTEM`, and has stable reason and event code `INFORMATION_RESPONSE_DEADLINE_EXPIRED`. Its payload contains the expired deadline and policy version, but no operator-only note or private evidence. Implementations use a stable internal system actor UUID where the shared event schema requires an actor identifier.

The event, case head, immutable receipt, and user notification outbox message commit atomically. Delivery failure does not roll back the transition and remains retryable through A17/A18.

Audit evidence records correlation ID, expected and resulting version, expired deadline, policy version, database decision time, and `APPLIED` or `ALREADY_TRANSITIONED`.

## 5. Rollout and verification

The schema change is additive. Once deadline events or receipts exist, rollback is forward-fix only and must not delete case history. Required verification covers just-before versus exact-deadline evidence, both evidence/expiry lock orders, duplicate delivery and lease recovery, stale state/version/replaced-deadline no-op, one event and notification, durable receipt replay, backlog catch-up, and empty/upgrade migration.

## 6. Approval source

PR [#158](https://github.com/Idea2Strategy/Idea2Strategy/pull/158) preserves the approved proposal. Product authority `user:kcrmin` merged exact proposal commit `f132f575f8d33a78dfe8fd55c5e1db45a8c19d08`.
