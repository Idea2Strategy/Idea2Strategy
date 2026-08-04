# Proposal only: move room evaluation ledger initialization to F

Status: **unapproved, non-canonical proposal**  
Issue: `Idea2Strategy/Idea2Strategy#181`  
Prepared against root commit: `28de9b01b4363b333ca2097cdd30263670e72473`  
Protected fingerprint: `sha256:6e015a609756c60fed0332ac57aa31935acf328832e4dd76fae93d72e980900a`

This document is intentionally outside `specs/**` and `contracts/**`. On 2026-08-04,
`stackcord governance check --json` returned `unknown` because no fresh provider
approval observation was available. Nothing here is approved, integrated, or
releasable. A configured product authority must review the product meaning and the
canonical contract before implementation can be merged.

## Problem and existing reusable fact

`RoomEvaluationStartJooqAdapter` currently performs four writes owned by F:

- `trading.ledger_accounts`
- `trading.ledger_transactions`
- `trading.ledger_entries`
- `bot.bot_events`

The same E-owned transaction already writes a durable
`ROOM_EVALUATION_START_COMMAND` outbox message (`room-performance.v1`) with stable
`commandId`, `roomId`, `participationId`, `botId`, `evaluationSegmentId`, schedule,
effective time, and a content-derived idempotency key. That fact is the preferred
handoff boundary; no polling or manual database operation is required.

The missing inputs for an F-owned initial-capital command are the locked currency and
initial cash amount. They must be added by a reviewed canonical contract revision (or
by a separately reviewed F command derived from a canonical E fact). F must not query
E-owned room tables to reconstruct them after delivery.

## Proposed ownership flow

1. E validates the room, bot launch snapshot, schedule, locked policies, and empty
   evaluation state as it does today.
2. In one E transaction, E creates its evaluation segment and participation event,
   advances the participation to an explicit pending-start state, and appends the
   versioned outbox message. E does not write any F-owned table.
3. The durable outbox relay publishes the message with its existing message identity,
   sequence, payload hash, retries, and dead-letter behavior.
4. An F worker validates the version and locked initial-capital inputs, claims the
   producer idempotency key durably, and opens the CASH/CAPITAL accounts plus the
   balanced `INITIAL_CAPITAL` transaction through an F-owned transaction.
5. F emits an idempotent completion or rejection fact. E consumes it and moves the
   participation from pending to `EVALUATING`, or to a visible failed/retryable state.
   E must not report evaluation started before F confirms the official ledger exists.

```text
E room transaction
  -> operations.outbox_messages
  -> relay / retry / DLQ
  -> F durable consumer receipt
  -> F ledger + bot event transaction
  -> F completion fact
  -> E participation transition
```

## Proposed contract decisions requiring authority

The authority review must settle these points before code changes:

- whether `ROOM_EVALUATION_START_COMMAND` gains a new compatible schema version or a
  dedicated `ROOM_EVALUATION_ACCOUNT_OPEN_REQUESTED` message is introduced;
- the exact initial-capital representation (decimal string, currency, precision and
  locked fee/buying-power policy identifiers);
- whether the F-owned `bot.bot_events` entry is part of the same F transaction or a
  second F-owned projection;
- the E state used while F is pending, and the user-visible failure/retry semantics;
- the completion/rejection event names, schemas, owner, and retention requirements;
- the replay rule after E has marked pending but the request or completion is delayed.

## Required safety and acceptance tests

- E's schema ownership test has zero tolerated F-write exceptions.
- F creates exactly two ledger accounts and one balanced transaction for duplicate,
  concurrent, and redelivered requests.
- A reused idempotency key with different content is rejected and audited.
- Out-of-order completion before E observes the request is safely retained/retried.
- F transaction rollback leaves no partial account, entry, transaction, or bot event.
- Relay outage, consumer crash after commit, DLQ, replay, and poison-message paths are
  exercised with PostgreSQL and LocalStack/Redis as applicable.
- E never exposes `EVALUATING` until the matching F completion is consumed.
- The end-to-end room start flow proves the locked initial cash and currency exactly
  match the double-entry ledger and that a rebuild produces the same balance.

## Dependency-ordered implementation units after approval

1. Canonical product/contract decision and versioned fixtures.
2. F consumer, durable receipt, F command path, and completion/rejection publisher.
3. E outbox payload upgrade and removal of all direct F writes.
4. E completion consumer and pending/failure state handling.
5. Cross-repository failure, retry, duplicate, and ordering verification.
6. Trading and backend PRs, followed by a verified root submodule-pointer PR.

Until those units are approved and merged, #181 remains an external governance
blocker and the project must not be described as Deploy Ready.
