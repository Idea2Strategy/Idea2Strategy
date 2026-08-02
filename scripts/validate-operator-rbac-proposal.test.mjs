import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import { validateOperatorRbacProposal } from './validate-operator-rbac-proposal.mjs';

const [dbml, contract] = await Promise.all([
  readFile(new URL('../proposals/operator-rbac/schema.draft.dbml', import.meta.url), 'utf8'),
  readFile(new URL('../proposals/operator-rbac/operator-rbac-contract.v1.md', import.meta.url), 'utf8'),
]);

test('accepts the complete isolated COM-A13 proposal', () => {
  const result = validateOperatorRbacProposal({ dbml, contract });

  assert.equal(result.status, 'passed');
  assert.equal(result.contractId, 'contract.operations.operator-rbac.v1');
  assert.ok(result.operationsTableCount > 0);
});

test('rejects audit evidence without an explicit catalog version', () => {
  const invalid = dbml.replaceAll('rbac_catalog_version', 'removed_catalog_version');

  assert.throws(
    () => validateOperatorRbacProposal({ dbml: invalid, contract }),
    /rbac_catalog_version/,
  );
});

test('rejects a delegability model that is not catalog-versioned', () => {
  const invalid = dbml.replace(
    '(catalog_version, role_id, permission_id) [pk]',
    '(role_id, permission_id) [pk]',
  );

  assert.throws(
    () => validateOperatorRbacProposal({ dbml: invalid, contract }),
    /catalog-versioned delegability/,
  );
});

test('rejects contracts that invent product permission codes', () => {
  const invalid = `${contract}\n- Permission seed: OPERATOR_ACCOUNT_DELETE\n`;

  assert.throws(
    () => validateOperatorRbacProposal({ dbml, contract: invalid }),
    /product permission catalog entry/,
  );
});

test('rejects lossy audit-field overloading', () => {
  const invalid = contract.replace(
    '기존 필드에 catalog version이나 증적 JSON을 겹쳐 싣지 않는다.',
    'catalog version은 reason_code에 합쳐 저장한다.',
  );

  assert.throws(
    () => validateOperatorRbacProposal({ dbml, contract: invalid }),
    /lossy audit-field overloading/,
  );
});
