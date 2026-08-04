---
schema_version: 1
id: contract.trading.virtual-execution.v1
kind: business
status: approved
revision: 3
refs:
  - policy.user.no-direct-orders
  - quality.failure-safety
  - contract.operations.outbox-delivery.v1
---

# contract.trading.virtual-execution.v1

Status: approved canonical contract. Product authority `user:pjy008008`
approved the exact source proposal on root PR #219 before this canonical write.

## 1. Initial release boundary

The initial release performs virtual execution using licensed Alpaca SIP market
data. It does not send a live broker order, consume a live broker fill, hold
customer assets, or present a simulated fill as broker-confirmed. Alpaca API
credentials authorize the required data feed only under this contract.

## 2. Startup and materialization

Before intake, the scheduled Trading host downloads versioned symbol mapping,
provider-rights, calendar, and warm-up bundles from the approved S3 location,
verifies their version and checksum, and mounts them read-only. Missing,
expired, unauthorized, or inconsistent material fails closed.

The gateway becomes ready only after SIP connectivity, subscription approval,
mapping/calendar validation, and required warm-up coverage. The worker becomes
ready only after database migration compatibility and durable state reconcile.

## 3. Virtual execution and reconcile

Orders, fills, positions, reservations, and the double-entry ledger are virtual
but remain authoritative PostgreSQL records. Every derived fill fixes the input
market event, policy versions, time, price/quantity calculation, fees/slippage,
and idempotency identity.

Restart must reconcile open intents, orders, fills, positions, reservations,
outbox receipts, and ledger balance before accepting new evaluation. A mismatch
blocks the affected bot and emits operational evidence; it is never repaired by
inventing a broker response or deleting history.

## 4. Room evaluation account opening

E requests an F-owned official ledger through
`ROOM_EVALUATION_ACCOUNT_OPEN_REQUESTED` with schema version
`room-evaluation-account-open-requested.v1`. The immutable payload contains
`commandId`, `messageId`, `producerIdempotencyKey`, `roomId`, `participationId`,
`botId`, `evaluationSegmentId`, `initialCash`, `currency`,
`feePolicyVersionId`, `buyingPowerPolicyVersionId`, `effectiveAt`, and the
canonical `payloadHash`. UUID identities use lower-case canonical text.
`initialCash` is a positive, non-exponent decimal string with at most eight
fractional digits; `currency` is an upper-case ISO 4217 code. Missing or
unlocked policy identifiers, unsupported versions, invalid money, and a
message identity reused with another hash fail closed.

E commits its evaluation segment, a participation transition to
`PENDING_LEDGER`, and the request outbox row atomically. It does not write
`bot.bot_events` or any `trading` table and must not expose `EVALUATING` before
the matching F success fact is consumed.

F handles the request according to
`contract.operations.outbox-delivery.v1`. In one PostgreSQL transaction it
claims or completes the content-hash-bound consumer receipt, appends the
official bot event, opens the bot-wide `CASH` and `CAPITAL` accounts, posts one
balanced `INITIAL_CAPITAL` transaction, and appends exactly one completion
outbox fact. Duplicate and concurrent delivery of identical content returns
the recorded result without another effect. A reused message or producer key
with different content becomes a permanent, audited conflict and is routed to
dead-letter handling. Database, lease, and transport failures remain
retryable under the pinned runtime policy; retries never report success.

Success uses `ROOM_EVALUATION_ACCOUNT_OPENED` with schema version
`room-evaluation-account-opened.v1` and records the request identities,
`botEventId`, its positive Trading-owned `botEventSequence`,
`ledgerTransactionId`, account IDs, amount, currency, policy IDs, and
`completedAt`. Permanent domain rejection uses
`ROOM_EVALUATION_ACCOUNT_OPEN_REJECTED` with schema version
`room-evaluation-account-open-rejected.v1` and records the same request
identities, a stable reason code, and `rejectedAt`, without credentials or
private strategy content. Both facts retain the request payload hash and
producer idempotency key.

E durably records a matching completion or rejection even when it arrives
before local request observation. While the participation is `PENDING_LEDGER`,
its live evaluation segment has a null `start_event_sequence` and
`initial_state_hash` pair. Matching success immutably fills both fields from the
Trading fact and then advances exactly one `PENDING_LEDGER` participation to
`EVALUATING`; no other participation state may retain a null pair. Matching
rejection advances it to a visible failed state. A duplicate fact is a no-op,
while mismatched
identity, amount, currency, policy, or hash is a permanent audited conflict.
Out-of-order facts are retained and replayed after the request becomes visible;
they are never discarded or converted into success.

The bot-wide ledger relationship must preserve header-to-entry integrity even
when `partition_id` is null. Service migrations and the canonical DB model must
prevent a ledger transaction header from being deleted while entries remain.

## 5. Failure and shutdown

Missing/stale/gapped market data, provider disconnect, rights failure, clock or
calendar inconsistency, database unavailability, or ledger imbalance fails
closed for affected evaluation and order generation. Existing durable state is
not converted into success.

On scheduled stop or SIGTERM, readiness is removed first, intake closes,
in-flight work drains within a bounded deadline, durable checkpoints and outbox
state commit, and the process exits. Forced termination remains recoverable by
the startup reconcile.

## 6. Required verification

- no production path can construct or send a live broker order;
- SIP subscription and provider-rights failures keep readiness false;
- duplicate/reversed market events and reconnect replay do not duplicate fills;
- restart reconcile detects missing fills, ledger imbalance, and stale claims;
- degraded data blocks affected trading and recovery requires verified coverage;
- scheduled stop and SIGTERM preserve durable, idempotent recovery evidence.
- room account opening creates one event, two accounts, one balanced posting,
  one completed receipt, and one completion outbox fact under duplicate and
  concurrent delivery;
- a content conflict is audited and dead-lettered without changing the ledger;
- crash and rollback at every write boundary leave no partial receipt, event,
  account, posting, entry, or completion fact;
- E never exposes `EVALUATING` before matching success and safely replays a
  completion that arrived before its request observation;
- bot-wide ledger entries cannot outlive their transaction header.
