import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const contract = await readFile(
  new URL('../contracts/business/case-response-deadline.v1.md', import.meta.url),
  'utf8',
);
const dbml = await readFile(new URL('../db/schema.dbml', import.meta.url), 'utf8');
const registry = await readFile(new URL('../contracts/registry.yaml', import.meta.url), 'utf8');

test('publishes the approved case response deadline contract', () => {
  assert.match(contract, /id: contract\.operations\.case-response-deadline\.v1/);
  assert.match(contract, /status: approved/);
  assert.match(contract, /\[information_requested_at, response_deadline_at\)/);
  assert.match(contract, /NEEDS_INFORMATION.*UNDER_REVIEW/s);
  assert.match(contract, /INFORMATION_RESPONSE_DEADLINE_EXPIRED/);

  const fingerprint = `sha256:${createHash('sha256').update(contract).digest('hex')}`;
  assert.ok(registry.includes('source: business/case-response-deadline.v1.md'));
  assert.ok(registry.includes(`fingerprint: ${fingerprint}`));
});

test('integrates the deadline projection, receipt, and event exactly once', () => {
  for (const fragment of [
    'INFORMATION_RESPONSE_DEADLINE_EXPIRED',
    'deadline_policy_version varchar(80)',
    'Table operations.case_deadline_receipts',
    "decision_status IN ('APPLIED', 'ALREADY_TRANSITIONED')",
    'Ref: operations.case_deadline_receipts.case_id > operations.cases.id',
    'Ref: operations.case_deadline_receipts.(case_id, case_event_id) > operations.case_events.(case_id, id)',
  ]) {
    assert.equal(dbml.split(fragment).length - 1, 1, `${fragment} must occur exactly once`);
  }
  assert.equal(
    dbml.split('response_deadline_at timestamptz').length - 1,
    2,
    'the case head and immutable deadline receipt each store the deadline',
  );
});

test('keeps deadline fields paired and due scans indexed', () => {
  assert.ok(dbml.includes(
    '(response_deadline_at IS NOT NULL AND deadline_policy_version IS NOT NULL) '
      + 'OR (response_deadline_at IS NULL AND deadline_policy_version IS NULL)',
  ));
  assert.ok(dbml.includes('(response_deadline_at, id)'));
  assert.ok(dbml.includes('(case_id, expected_case_version, response_deadline_at) [pk]'));
});
