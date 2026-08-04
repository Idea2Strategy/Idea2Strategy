---
schema_version: 1
id: contract.trading.virtual-execution.v1
kind: business
status: approved
revision: 1
refs:
  - policy.user.no-direct-orders
  - quality.failure-safety
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

## 4. Failure and shutdown

Missing/stale/gapped market data, provider disconnect, rights failure, clock or
calendar inconsistency, database unavailability, or ledger imbalance fails
closed for affected evaluation and order generation. Existing durable state is
not converted into success.

On scheduled stop or SIGTERM, readiness is removed first, intake closes,
in-flight work drains within a bounded deadline, durable checkpoints and outbox
state commit, and the process exits. Forced termination remains recoverable by
the startup reconcile.

## 5. Required verification

- no production path can construct or send a live broker order;
- SIP subscription and provider-rights failures keep readiness false;
- duplicate/reversed market events and reconnect replay do not duplicate fills;
- restart reconcile detects missing fills, ledger imbalance, and stale claims;
- degraded data blocks affected trading and recovery requires verified coverage;
- scheduled stop and SIGTERM preserve durable, idempotent recovery evidence.
