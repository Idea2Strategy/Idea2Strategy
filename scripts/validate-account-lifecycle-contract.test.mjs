import { readFile } from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const dbml = await readFile(new URL("../db/schema.dbml", import.meta.url), "utf8");
const contract = await readFile(
  new URL("../docs/contracts/account-lifecycle-v1.md", import.meta.url),
  "utf8",
);

test("pins the approved account lifecycle state and deadline projections", () => {
  for (const fragment of [
    "DORMANT",
    "lifecycle_version bigint",
    "last_lifecycle_event_id uuid",
    "last_successful_auth_at timestamptz",
    "dormant_at timestamptz",
    "withdrawal_requested_at timestamptz",
    "cancellation_deadline_at timestamptz",
    "closing_previous_status identity.account_lifecycle_status",
    "closed_at timestamptz",
    "anonymized_at timestamptz",
  ]) {
    assert.match(dbml, new RegExp(fragment.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
});

test("pins an append-only single-head lifecycle event chain", () => {
  for (const fragment of [
    "previous_event_id uuid",
    "command_type varchar(60)",
    "actor_type varchar(40)",
    "actor_id varchar(160)",
    "correlation_id uuid",
    "idempotency_key varchar(160)",
    "request_hash varchar(128)",
    "retention_policy_version varchar(80)",
    "cancellation_deadline_at timestamptz",
    "dormancy_basis_at timestamptz",
    "(account_id, command_type, idempotency_key) [unique]",
    "(account_id, previous_event_id) [unique]",
    "Ref: identity.account_lifecycle_events.(account_id, previous_event_id) > identity.account_lifecycle_events.(account_id, id)",
    "Ref: identity.accounts.(id, last_lifecycle_event_id) > identity.account_lifecycle_events.(account_id, id)",
  ]) {
    assert.ok(dbml.includes(fragment), `missing lifecycle chain fragment: ${fragment}`);
  }
});

test("models versioned retention obligations and legal holds", () => {
  for (const fragment of [
    "Table identity.account_retention_policy_versions",
    "Table identity.account_retention_policy_rules",
    "Table identity.account_retention_obligations",
    "Table identity.account_legal_holds",
    "blocks_identifier_reuse boolean",
    "retention_days integer",
    "retain_until timestamptz",
    "failure_code varchar(80)",
    "failure_code = 'RETENTION_POLICY_MISSING'",
    "Ref: identity.account_retention_obligations.(account_id, lifecycle_event_id) > identity.account_lifecycle_events.(account_id, id)",
  ]) {
    assert.ok(dbml.includes(fragment), `missing retention fragment: ${fragment}`);
  }
});

test("records the confirmed product values without claiming legal retention periods", () => {
  assert.match(contract, /30일\(30 × 24시간\)/);
  assert.match(contract, /최근 성공 인증 시각부터 연속 12개월/);
  assert.match(contract, /최근 10분 이내/);
  assert.match(contract, /CLOSED 후 30일 격리 기간/);
  assert.match(contract, /승인된 retention policy/);
});

test("models releasable 30-day identifier quarantine without storing plaintext", () => {
  for (const fragment of [
    "Table identity.account_identifier_quarantines",
    "identifier_fingerprint varchar(128)",
    "reuse_eligible_at timestamptz",
    "reuse_eligible_at = quarantined_at + interval '30 days'",
    "Ref: identity.account_identifier_quarantines.(account_id, lifecycle_event_id) > identity.account_lifecycle_events.(account_id, id)",
  ]) {
    assert.ok(dbml.includes(fragment), `missing identifier quarantine fragment: ${fragment}`);
  }
  assert.match(contract, /별도 tombstone/);
});
