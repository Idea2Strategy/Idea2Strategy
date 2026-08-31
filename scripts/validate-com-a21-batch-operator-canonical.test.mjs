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

test('pins approved canonical contracts and registry fingerprints', async () => {
  for (const [id, path] of contracts) {
    const contract = await readFile(new URL(path, import.meta.url), 'utf8');
    const fingerprint = `sha256:${createHash('sha256').update(contract).digest('hex')}`;
    assert.match(contract, new RegExp(`id: ${id.replaceAll('.', '\\.')}`));
    assert.match(contract, /status: approved/);
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

test('pins internal operator credentials, replay-safe TOTP, and server sessions', () => {
  for (const fragment of [
    'Table operations.operator_login_credentials',
    'Table operations.operator_sessions',
    'operator_credential_versions_positive',
    'operator_totp_nonce_valid',
    'last_accepted_totp_step bigint',
    'operator_session_versions_positive',
    'operator_session_expiry_coherent',
    'Ref: operations.operator_login_credentials.operator_account_id - operations.operator_accounts.id',
    'Ref: operations.operator_sessions.operator_account_id > operations.operator_accounts.id',
  ]) assert.ok(schema.includes(fragment), `missing operator trust canonical DBML: ${fragment}`);
});
