import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import { validateDelegatedStrategyScopeProposal } from './validate-delegated-strategy-scope-proposal.mjs';

const [dbml, contract] = await Promise.all([
  readFile(new URL('../proposals/delegated-strategy-scope/schema.draft.dbml', import.meta.url), 'utf8'),
  readFile(new URL('../proposals/delegated-strategy-scope/delegated-strategy-scope-contract.v1.md', import.meta.url), 'utf8'),
]);

test('accepts the complete isolated COM-A15 proposal', () => {
  const result = validateDelegatedStrategyScopeProposal({ dbml, contract });

  assert.equal(result.status, 'passed');
  assert.equal(result.contractId, 'contract.identity.delegated-strategy-scope.v1');
  assert.ok(result.identityTableCount > 0);
});

test('rejects a mutable explicit allowlist', () => {
  const invalid = contract.replace(
    '명시 allowlist 행은 authorization 활성화 뒤 UPDATE·DELETE할 수 없다.',
    '명시 allowlist 행은 authorization 활성화 뒤 수정할 수 있다.',
  );

  assert.throws(
    () => validateDelegatedStrategyScopeProposal({ dbml, contract: invalid }),
    /immutable explicit allowlist/,
  );
});

test('rejects COPY provenance whose source is not an explicit target', () => {
  const invalid = dbml.replace(
    'Ref: identity.delegated_strategy_derivations.(authorization_id, source_strategy_id) > identity.delegated_authorization_strategy_targets.(authorization_id, strategy_id)',
    'Ref: identity.delegated_strategy_derivations.source_strategy_id > strategy.strategies.id',
  );

  assert.throws(
    () => validateDelegatedStrategyScopeProposal({ dbml: invalid, contract }),
    /COPY source explicit-target reference/,
  );
});

test('rejects a derived output without account and strategy epoch snapshots', () => {
  const invalid = dbml
    .replaceAll('owner_account_id_at_creation', 'removed_owner_snapshot')
    .replaceAll('strategy_access_epoch_at_creation', 'removed_access_epoch');

  assert.throws(
    () => validateDelegatedStrategyScopeProposal({ dbml: invalid, contract }),
    /owner_account_id_at_creation|strategy_access_epoch_at_creation/,
  );
});

test('rejects any delegated release scope', () => {
  const invalid = dbml.replace(
    'STRATEGY_VALIDATE\n}',
    'STRATEGY_VALIDATE\n  STRATEGY_RELEASE\n}',
  );

  assert.throws(
    () => validateDelegatedStrategyScopeProposal({ dbml: invalid, contract }),
    /forbidden delegated scope/,
  );
});

test('rejects a contract that omits the fail-closed evaluation order', () => {
  const invalid = contract.replace(
    'auth epoch → sanction → authorization/credential expiry·revoke → scope → resource',
    'scope → resource',
  );

  assert.throws(
    () => validateDelegatedStrategyScopeProposal({ dbml, contract: invalid }),
    /fail-closed evaluation order/,
  );
});
