import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const entries = [
  ['contract.operations.operator-rbac.v1', '../contracts/business/operator-rbac.v1.md'],
  ['contract.identity.delegated-strategy-scope.v1', '../contracts/business/delegated-strategy-scope.v1.md'],
  ['contract.operations.outbox-delivery.v1', '../contracts/data/outbox-delivery.v1.md'],
  ['contract.operations.user-case.v1', '../contracts/business/user-case.v1.md'],
];

const dbml = await readFile(new URL('../db/schema.dbml', import.meta.url), 'utf8');
const registry = await readFile(new URL('../contracts/registry.yaml', import.meta.url), 'utf8');
const contracts = await Promise.all(entries.map(async ([id, source]) => [
  id,
  source,
  await readFile(new URL(source, import.meta.url), 'utf8'),
]));

test('integrates every approved COM A schema delta exactly once', () => {
  const fragments = [
    'Table operations.rbac_catalog_versions',
    'Table operations.rbac_catalog_role_permissions',
    'Table identity.delegated_authorization_strategy_targets',
    'Table identity.delegated_strategy_derivations',
    'Table operations.outbox_delivery_attempts',
    'Table operations.outbox_consumer_receipts',
    'Table operations.case_command_receipts',
    'Table operations.case_evidence_references',
  ];

  for (const fragment of fragments) {
    assert.equal(dbml.split(fragment).length - 1, 1, `${fragment} must occur exactly once`);
  }
});

test('keeps the four approved contracts canonical and fingerprinted', () => {
  for (const [id, source, contract] of contracts) {
    assert.match(contract, new RegExp(`id: ${id.replaceAll('.', '\\.')}`));
    assert.match(contract, /status: approved/);

    const registrySource = source.replace('../contracts/', '');
    const fingerprint = `sha256:${createHash('sha256').update(contract).digest('hex')}`;
    assert.ok(registry.includes(`source: ${registrySource}`), `missing registry source for ${id}`);
    assert.ok(registry.includes(`fingerprint: ${fingerprint}`), `stale registry fingerprint for ${id}`);
  }
});

test('preserves cross-delta references in the combined schema', () => {
  for (const fragment of [
    'Ref: operations.audit_events.resolved_rbac_catalog_version > operations.rbac_catalog_versions.catalog_version',
    'Ref: identity.delegated_strategy_derivations.(authorization_id, source_strategy_id) > identity.delegated_authorization_strategy_targets.(authorization_id, strategy_id)',
    'Ref: operations.outbox_messages.replay_audit_event_id > operations.audit_events.id',
    'Ref: operations.case_evidence_references.storage_object_id > storage.objects.id',
  ]) {
    assert.ok(dbml.includes(fragment), `missing combined-schema reference: ${fragment}`);
  }
});
