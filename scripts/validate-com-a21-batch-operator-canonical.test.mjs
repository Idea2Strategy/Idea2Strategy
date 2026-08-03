import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const registry = await readFile(new URL('../contracts/registry.yaml', import.meta.url), 'utf8');
const schema = await readFile(new URL('../db/schema.dbml', import.meta.url), 'utf8');

const contracts = [
  ['contract.operations.durable-batch-execution.v1', '../contracts/data/durable-batch-execution.v1.md'],
  ['contract.operations.operator-trust.v1', '../contracts/business/operator-trust.v1.md'],
];

test('pins the exact approved proposal evidence and registry fingerprints', async () => {
  for (const [id, path] of contracts) {
    const contract = await readFile(new URL(path, import.meta.url), 'utf8');
    const fingerprint = `sha256:${createHash('sha256').update(contract).digest('hex')}`;
    assert.match(contract, new RegExp(`id: ${id.replaceAll('.', '\\.')}`));
    assert.match(contract, /status: approved/);
    assert.match(contract, /Idea2Strategy\/pull\/166/);
    assert.ok(registry.includes(`id: ${id}`), `missing registry entry for ${id}`);
    assert.ok(registry.includes(`fingerprint: ${fingerprint}`), `stale registry fingerprint for ${id}`);
  }
});

test('pins durable batch ownership, lease recovery, and checkpoint evidence', () => {
  for (const fragment of [
    'Enum operations.batch_job_version_status',
    'Table operations.batch_job_versions',
    'Table operations.batch_runs',
    'Table operations.batch_items',
    '(category_code, source_key, source_version, due_at, replay_sequence) [unique]',
    'Table operations.batch_item_attempts',
    'LEASE_EXPIRED',
    'runtime_policy_version',
    'Table operations.batch_run_checkpoints',
    'batch_checkpoint_cursor_pair',
  ]) assert.ok(schema.includes(fragment), `missing batch canonical DBML: ${fragment}`);
});

test('pins versioned operator mapping and immutable one-shot bootstrap evidence', () => {
  for (const fragment of [
    'external_identity_key_version smallint [not null]',
    'operator_identity_key_version_positive',
    'Table operations.operator_bootstrap_receipts',
    'operator_bootstrap_key_version_positive',
    'operator_role_assignment_id > operations.operator_role_assignments.id',
    'audit_event_id > operations.audit_events.id',
  ]) assert.ok(schema.includes(fragment), `missing operator trust canonical DBML: ${fragment}`);
});
