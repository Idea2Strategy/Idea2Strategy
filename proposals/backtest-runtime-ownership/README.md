# Backtest runtime ownership and fencing proposal

Status: **isolated proposal; not canonical and not releasable**

This proposal closes the two implementation gaps found while wiring the
approved `contract.backtest.execution.v1`. It does not edit `db/schema.dbml`,
`specs/**`, or `contracts/**`. Canonical adoption requires a fresh GitHub
provider observation and a successful `stackcord governance check --json` for
the exact Root commit and protected fingerprint.

## Recommended decisions

### 1. Backend registers every run before publishing work

Backend remains the request producer and commits all of the following in one
PostgreSQL transaction:

- a stable `backtest.runs.id` generated before publication;
- the immutable run inputs and explicit `execution_policy_version`;
- for Competition, the unique
  `(participation_id, evaluation_period_id, run_id)` link;
- the lane-specific transactional Outbox event carrying that same `runId`.

The Backtest consumer must not invent another run identifier. Duplicate
delivery claims or resumes the already registered run. This directly implements
the approved contract statement that the producer commits the run and Outbox
event atomically, avoids a second accepted-event handshake, and makes the
Competition period link valid before work begins.

`execution_policy_version` is a first-class immutable identifier. It must be
resolved from the locked Backtest execution-policy catalog and copied to the
run and message. `accounting_rules_version`, a fee policy UUID, or a room
scoring-template UUID is not an acceptable substitute. A request fails closed
when the catalog version or its pinned policy artifact cannot be resolved.

Migration order for existing rows is expand/backfill/constrain:

1. add nullable `execution_policy_version`;
2. backfill from an explicitly reviewed legacy-version mapping table or abort;
3. verify every row resolves to a pinned policy artifact;
4. make the column non-null and index it;
5. deploy producers that include `runId` and the version before enabling relay.

No default version is allowed because it would silently relabel historical
economics.

### 2. Attempts use database-time fenced leases

`backtest.run_attempts` gains:

- `claim_token uuid` (random, unique while present);
- `worker_id varchar(160)`;
- `claimed_at timestamptz`;
- `claim_expires_at timestamptz`;
- `last_heartbeat_at timestamptz`;
- `previous_attempt_id uuid` for reclaim lineage;
- `terminal_reason_code varchar(80)`.

`backtest.runs` gains `cancellation_requested_at`,
`cancellation_reason_code`, and `cancelled_at`. Cancellation is durable run
state, not an SQS receipt or process flag.

Required database invariants:

- a claimed/non-terminal attempt has all five claim fields and an expiry after
  claim/heartbeat time;
- terminal attempts have no valid lease and cannot heartbeat;
- `previous_attempt_id` belongs to the same run and has a lower attempt number;
- only one non-expired claim per run may be returned by the atomic claim query;
- a terminal run has no valid claim;
- cancellation and success are mutually exclusive terminal outcomes.

Claim, heartbeat, expiry/reclaim, cancellation, and terminal publication use
database time and compare both `attempt_id` and `claim_token`. The affected-row
count must be exactly one; zero is a stale-owner failure. Reclaim first closes
the expired attempt with `LEASE_EXPIRED`, then inserts the next attempt in the
same transaction.

Automatic ASG scale-down remains disabled until PostgreSQL 16 race tests prove:

- expiry/reclaim and the first worker's late completion;
- heartbeat versus reclaim;
- cancellation versus checkpoint/success;
- duplicate claim and duplicate terminal delivery;
- shutdown rejection while any lane has visible/in-flight work or the worker
  owns an unexpired database claim.

## Repository integration order

1. Canonical Root DBML alignment and forward migration contribution.
2. Backend run registration + Outbox producer TDD.
3. Backtest claim/heartbeat/reclaim/cancel adapters and worker TDD.
4. Backend/Backtest contract fixtures and three-lane relay integration.
5. Root Flyway bundle and Trading pinned test baseline refresh.
6. Enable `enable_backtest_outbox_relay` only at the verified candidate commit.

Rollback is application-first: disable relay, drain queues, return the Backtest
ASG to desired zero, and roll back producers/consumers. Added columns and
history are retained; destructive down-migration is not permitted.
