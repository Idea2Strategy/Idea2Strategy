import { readFile } from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const dbml = await readFile(new URL("./schema.draft.dbml", import.meta.url), "utf8");
const contract = await readFile(new URL("./contract.md", import.meta.url), "utf8");

test("pins conservative structured case types and states", () => {
  for (const fragment of [
    "Enum operations.case_type",
    "INQUIRY",
    "REPORT",
    "APPEAL",
    "Enum operations.case_status",
    "OPEN",
    "NEEDS_INFORMATION",
    "UNDER_REVIEW",
    "RESOLVED",
    "REJECTED",
    "case_terminal_state_consistent",
  ]) assert.ok(dbml.includes(fragment), `missing type/state fragment: ${fragment}`);

  assert.match(contract, /`RESOLVED` and `REJECTED` are terminal/);
  assert.match(contract, /not live chat, email support, or a file upload service/);
});

test("models one append-only current head", () => {
  for (const fragment of [
    "case_version bigint [not null, default: 1]",
    "current_event_sequence int [not null]",
    "last_case_event_id uuid",
    "case_head_required",
    "previous_event_id uuid",
    "(case_id, event_sequence) [unique]",
    "(case_id, previous_event_id) [unique]",
    "case_event_chain_start_valid",
    "Ref: operations.case_events.(case_id, previous_event_id) > operations.case_events.(case_id, id)",
    "Ref: operations.cases.(id, last_case_event_id) > operations.case_events.(case_id, id)",
  ]) assert.ok(dbml.includes(fragment), `missing head fragment: ${fragment}`);

  assert.match(contract, /Events are never updated or deleted/);
  assert.match(contract, /DEFERRABLE INITIALLY DEFERRED/);
});

test("persists immutable successful command receipts", () => {
  for (const fragment of [
    "Table operations.case_command_receipts",
    "(account_id, command_type, idempotency_key) [pk]",
    "request_hash varchar(128) [not null]",
    "response_status int [not null]",
    "response_document jsonb [not null]",
    "case_command_receipt_success_status",
    "Ref: operations.case_command_receipts.(case_id, case_event_id) > operations.case_events.(case_id, id)",
  ]) assert.ok(dbml.includes(fragment), `missing receipt fragment: ${fragment}`);

  assert.match(contract, /409 IDEMPOTENCY_KEY_REUSED/);
  assert.match(contract, /returns the original response without another case, event, evidence link, or outbox message/);
});

test("models immutable evidence ownership proof", () => {
  for (const fragment of [
    "Table operations.case_evidence_references",
    "(case_id, storage_object_id) [pk]",
    "source_domain varchar(40) [not null]",
    "source_resource_id uuid [not null]",
    "owner_account_id uuid [not null]",
    "ownership_policy_version varchar(80) [not null]",
    "owner_account_id = account_id",
    "Ref: operations.case_evidence_references.storage_object_id > storage.objects.id",
  ]) assert.ok(dbml.includes(fragment), `missing evidence fragment: ${fragment}`);

  assert.match(contract, /existing `AVAILABLE` `storage\.objects` row/);
  assert.match(contract, /same non-enumerating result and create no case, event, receipt, or outbox record/);
});

test("keeps A17 and later operations outside A19 proposal", () => {
  assert.match(contract, /Operator assignment, investigation, and disposition belong to A20/);
  assert.match(contract, /production publishing waits for the approved A17 implementation/);
  assert.match(contract, /remain a proposal until a configured product authority approves the exact Git commit/);
});
