import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const contract = readFileSync(new URL('../contracts/data/backtest-execution.v1.md', import.meta.url), 'utf8');
const schema = readFileSync(new URL('../db/schema.dbml', import.meta.url), 'utf8');

test('approved contract binds producer identity, policy, and atomic competition linkage', () => {
  assert.match(contract, /revision: 3/);
  assert.match(contract, /stable `runId`/);
  assert.match(contract, /`executionPolicyVersion`/);
  assert.match(contract, /`\(participationId, evaluationPeriodId, runId\)`/);
  assert.match(contract, /zero rows is a stale-owner failure/);
  assert.match(contract, /`LEASE_EXPIRED`/);
  assert.match(contract, /`runs\.configuration_hash` remains the immutable bot launch configuration hash/);
  assert.match(contract, /`input_bundle_fingerprint` is the\s+lane-versioned digest/);
  assert.match(contract, /Run, input bundle, every dataset\/feature\s+pin, `run_input_pins`, and Outbox event in one transaction/);
});

test('canonical DBML exposes fenced attempts and durable cancellation', () => {
  assert.match(schema, /Enum backtest\.run_lane \{[\s\S]*BASIC[\s\S]*CUSTOM[\s\S]*COMPETITION/);
  for (const field of [
    'execution_policy_version', 'canonical_payload_hash', 'claim_token', 'claim_expires_at',
    'last_heartbeat_at', 'previous_attempt_id', 'terminal_reason_code', 'cancellation_requested_at',
  ]) assert.match(schema, new RegExp(`\\b${field}\\b`));
  assert.match(schema, /\(participation_id, evaluation_period_id, run_id\) \[pk\]/);
  assert.match(schema, /Ref: backtest\.run_attempts\.previous_attempt_id > backtest\.run_attempts\.id/);
  assert.match(schema, /Table backtest\.execution_policy_versions \{[\s\S]*policy_artifact_hash[\s\S]*policy_document[\s\S]*locked_at/);
  assert.match(schema, /Ref: backtest\.runs\.execution_policy_version > backtest\.execution_policy_versions\.version/);
  assert.match(schema, /Table backtest\.run_input_pins \{[\s\S]*input_bundle_fingerprint varchar\(128\) \[not null\][\s\S]*input_contract_version varchar\(80\) \[not null\][\s\S]*compiled_plan_checksum varchar\(128\) \[not null\][\s\S]*strategy_snapshot_hash varchar\(128\) \[not null\]/);
  assert.match(schema, /Ref: backtest\.run_input_pins\.input_bundle_id > backtest\.input_bundles\.id/);
});

test('canonical DBML persists durable outcomes without restoring retired singular pins', () => {
  const runs = schema.match(/Table backtest\.runs \{[\s\S]*?\n\}/)?.[0] ?? '';
  assert.match(runs, /\bresult_manifest_id uuid\b/);
  assert.match(runs, /\bretryable boolean\b/);
  assert.match(runs, /\bmissing_requirements jsonb\b/);
  assert.match(runs, /runs_missing_requirements_is_a_non_empty_string_array/);

  const pins = schema.match(/Table backtest\.run_input_pins \{[\s\S]*?\n\}/)?.[0] ?? '';
  for (const retired of ['dataset_manifest_id', 'dataset_hash', 'feature_materialization_version']) {
    assert.doesNotMatch(pins, new RegExp(`\\b${retired}\\b`));
  }
});

test('canonical DBML preserves content hashes while exempting zero-object manifests', () => {
  assert.match(schema, /dataset_hash varchar\(128\) \[not null\]/);
  assert.match(schema, /object_count bigint \[not null, default: 0/);
  assert.match(schema, /dataset_hash WHERE object_count > 0.*uq_dataset_manifests_dataset_hash/);
});

test('bot-wide ledger entries directly retain their transaction header', () => {
  assert.match(schema, /Ref ledger_entry_transaction_header_fk: trading\.ledger_entries\.transaction_id > trading\.ledger_transactions\.id \[delete: restrict\]/);
  assert.match(schema, /Table operations\.outbox_messages \{[\s\S]*event_schema_version varchar\(80\)/);
});
