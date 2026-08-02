import { readFile } from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const dbml = await readFile(new URL("./schema.draft.dbml", import.meta.url), "utf8");
const contract = await readFile(
  new URL("./contract.md", import.meta.url),
  "utf8",
);

test("models an immutable envelope with a durable delivery head", () => {
  for (const fragment of [
    "Enum operations.outbox_delivery_status",
    "PENDING",
    "CLAIMED",
    "PUBLISHED",
    "DEAD_LETTERED",
    "payload_hash varchar(128) [not null]",
    "producer_idempotency_key varchar(160) [not null]",
    "original_message_id uuid",
    "replayed_from_message_id uuid [unique]",
    "replay_sequence int [not null, default: 0]",
    "replay_audit_event_id uuid [unique]",
    "claim_token uuid [unique]",
    "claim_expires_at timestamptz",
    "dead_letter_reason_code varchar(80)",
    "outbox_claim_state_consistent",
    "outbox_dead_letter_state_consistent",
    "outbox_next_attempt_pending_only",
    "outbox_replay_lineage_consistent",
  ]) {
    assert.ok(dbml.includes(fragment), `missing outbox head fragment: ${fragment}`);
  }

  assert.match(contract, /envelope fields[\s\S]*immutable after insert/);
  assert.match(contract, /Database time, not worker wall-clock time/);
  assert.doesNotMatch(dbml, /delivery_generation/);
});

test("keeps append-only claim attempt evidence with versioned runtime policy", () => {
  for (const fragment of [
    "Table operations.outbox_delivery_attempts",
    "Enum operations.outbox_attempt_outcome",
    "(outbox_message_id, attempt_number) [pk]",
    "claim_token uuid [not null, unique]",
    "runtime_policy_version varchar(80) [not null]",
    "LEASE_EXPIRED",
    "RETRY_SCHEDULED",
    "outbox_attempt_completion_consistent",
    "outbox_attempt_failure_code_consistent",
    "Ref: operations.outbox_delivery_attempts.outbox_message_id > operations.outbox_messages.id",
  ]) {
    assert.ok(dbml.includes(fragment), `missing attempt fragment: ${fragment}`);
  }

  assert.match(contract, /Lease duration, retry budget, backoff, jitter, timeout, and alert thresholds/);
  assert.match(contract, /Missing or ambiguous policy fails closed/);
});

test("pins authorized replay without mutating the envelope", () => {
  for (const fragment of [
    "(original_message_id, replay_sequence) [unique]",
    "Ref: operations.outbox_messages.original_message_id > operations.outbox_messages.id",
    "Ref: operations.outbox_messages.replayed_from_message_id > operations.outbox_messages.id",
    "Ref: operations.outbox_messages.replay_audit_event_id > operations.audit_events.id",
  ]) {
    assert.ok(dbml.includes(fragment), `missing replay fragment: ${fragment}`);
  }

  assert.match(contract, /Replay is allowed only from `DEAD_LETTERED`/);
  assert.match(contract, /`OPERATIONS_OUTBOX_REPLAY` permission/);
  assert.match(contract, /creates a new `operations\.outbox_messages` row/);
  assert.match(contract, /source row remains `DEAD_LETTERED` and is never modified/);
  assert.match(contract, /points `original_message_id` to the first immutable message/);
  assert.match(contract, /given dead-lettered row can have only one direct replay child/);
  assert.match(contract, /same key with another request hash is rejected/i);
});

test("models consumer idempotency by handler and message ID", () => {
  for (const fragment of [
    "Enum operations.consumer_receipt_status",
    "Table operations.outbox_consumer_receipts",
    "(consumer_handler_id, outbox_message_id) [pk]",
    "(consumer_handler_id, producer_idempotency_key)",
    "outbox_message_id uuid [not null]",
    "producer_idempotency_key varchar(160) [not null]",
    "payload_hash varchar(128) [not null]",
    "result_hash varchar(128)",
    "consumer_receipt_claim_state_consistent",
    "consumer_receipt_completion_consistent",
    "Ref: operations.outbox_consumer_receipts.outbox_message_id > operations.outbox_messages.id",
  ]) {
    assert.ok(dbml.includes(fragment), `missing receipt fragment: ${fragment}`);
  }

  assert.match(contract, /receipt uniqueness scope is `\(consumer_handler_id, outbox_message_id\)`/);
  assert.match(contract, /they are not its unique key/);
  assert.match(contract, /Business effect and transition to `COMPLETED` commit in the same local PostgreSQL transaction/);
  assert.match(contract, /same message ID with a different payload hash is a permanent idempotency conflict/i);
  assert.match(contract, /operator cannot overwrite the existing receipt/i);
});

test("keeps infrastructure and numeric SLO values outside the canonical contract", () => {
  assert.match(contract, /Production transport provisioning[\s\S]*outside this contract/);
  assert.match(contract, /Production transport, retry numbers, and infrastructure/);
  assert.match(contract, /not approved until product authority `user:kcrmin` reviews the exact commit/);
});
