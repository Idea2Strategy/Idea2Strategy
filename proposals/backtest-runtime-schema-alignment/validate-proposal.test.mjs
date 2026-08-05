import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const proposalDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(proposalDir, '..', '..');
const migrationName = 'V20260805170000__backtest_run_outcome_detail.sql.proposal';

async function text(relativePath) {
  return readFile(path.join(proposalDir, relativePath), 'utf8');
}

test('records the exact observed root and merged backtest evidence', async () => {
  const evidence = JSON.parse(await text('evidence.json'));
  assert.equal(evidence.status, 'isolated-proposal-not-approved');
  assert.equal(evidence.root.governanceStatus, 'unknown');
  assert.equal(evidence.root.commit, '4232f3be6c0fc529c3dc2037c702799339308699');
  assert.equal(
    evidence.backtest.mergedDevelopCommit,
    'b8cedcedcb00c3876a1e815fe3bdc4b1fa556046',
  );
  assert.equal(
    evidence.backtest.outcomeContribution.gitBlob,
    'ba62042c14d0f59340adf9b0dde9f5234db4dbe1',
  );
  assert.equal(evidence.liveMissingColumns.length, 6);
  assert.equal(evidence.adoptedColumnCandidates.length, 3);
  assert.equal(evidence.retiredConsumerColumns.length, 3);
});

test('keeps the root provider-owned normalized run_input_pins shape', async () => {
  const rootPinMigration = await readFile(
    path.join(root, 'db', 'flyway-ci-bundle', 'V20260805130000__backtest_run_input_pins.sql'),
    'utf8',
  );
  for (const canonicalColumn of [
    'input_bundle_id',
    'input_bundle_fingerprint',
    'input_contract_version',
    'compiled_plan_checksum',
    'strategy_snapshot_hash',
    'execution_policy_version',
  ]) {
    assert.match(rootPinMigration, new RegExp(`\\b${canonicalColumn}\\b`));
  }
  for (const retiredColumn of [
    'dataset_manifest_id',
    'dataset_hash',
    'feature_materialization_version',
  ]) {
    assert.doesNotMatch(rootPinMigration, new RegExp(`\\b${retiredColumn}\\b`));
  }
});

test('proposes only the three forward-only outcome columns', async () => {
  const migration = await text(migrationName);
  assert.match(migration, /ALTER TABLE "backtest"\."runs"/);
  for (const outcomeColumn of [
    'result_manifest_id',
    'retryable',
    'missing_requirements',
  ]) {
    assert.match(migration, new RegExp(`ADD COLUMN "${outcomeColumn}"`));
  }
  for (const retiredColumn of [
    'dataset_manifest_id',
    'dataset_hash',
    'feature_materialization_version',
  ]) {
    assert.doesNotMatch(migration, new RegExp(`\\b${retiredColumn}\\b`));
  }
  assert.match(migration, /jsonb_array_length\("missing_requirements"\) > 0/);
  assert.match(migration, /jsonb_path_exists/);
  assert.doesNotMatch(migration, /\b(?:DROP|TRUNCATE|DELETE|UPDATE)\b/i);
  assert.doesNotMatch(migration, /\bNOT NULL\b/i);
  assert.doesNotMatch(migration, /\bDEFAULT\b/i);
});

test('pins normalized-LF proposal checksums', async () => {
  const checksumLines = (await text('CHECKSUMS.sha256')).trim().split(/\r?\n/);
  const expected = new Map(
    checksumLines.map((line) => {
      const match = line.match(/^([0-9a-f]{64})  (.+)$/);
      assert.ok(match, `invalid checksum line: ${line}`);
      return [match[2], match[1]];
    }),
  );

  for (const fileName of [migrationName, 'grants-verification.sql.proposal']) {
    const normalized = (await text(fileName)).replace(/\r\n/g, '\n');
    const actual = createHash('sha256').update(normalized, 'utf8').digest('hex');
    assert.equal(actual, expected.get(fileName), `checksum drift: ${fileName}`);
  }
});

test('verifies existing grants without proposing privilege expansion', async () => {
  const verification = await text('grants-verification.sql.proposal');
  assert.doesNotMatch(verification, /\bGRANT\b/i);
  assert.match(verification, /idea2strategy_backend/);
  assert.match(verification, /idea2strategy_batch/);
  assert.match(verification, /idea2strategy_backtest/);
  assert.match(verification, /has_column_privilege/);
  assert.match(verification, /'SELECT'/);
  assert.match(verification, /'INSERT'/);
  assert.match(verification, /'UPDATE'/);
  assert.match(verification, /must not own backtest\.runs/);
});
