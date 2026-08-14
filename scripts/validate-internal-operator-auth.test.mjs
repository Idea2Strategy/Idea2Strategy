import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import { validateInternalOperatorAuth } from './validate-internal-operator-auth.mjs';

const [dbml, contract, releaseWorkflow] = await Promise.all([
  readFile(new URL('../db/schema.dbml', import.meta.url), 'utf8'),
  readFile(new URL('../contracts/business/operator-rbac.v1.md', import.meta.url), 'utf8'),
  readFile(new URL('../.github/workflows/development-release.yml', import.meta.url), 'utf8'),
]);

test('accepts internal operator credentials while preserving deployment OIDC', () => {
  assert.deepEqual(validateInternalOperatorAuth({ dbml, contract, releaseWorkflow }), {
    status: 'passed',
    authority: 'user:kcrmin',
  });
});

test('rejects a browser bearer or human OIDC operator contract', () => {
  const invalid = contract
    .replace('Browser operator requests use an opaque server-side session cookie.', 'Browser operator requests use a bearer token.')
    .replace('Human operator Cognito/OIDC is not an accepted authentication path.', 'Human operator Cognito/OIDC is accepted.');

  assert.throws(
    () => validateInternalOperatorAuth({ dbml, contract: invalid, releaseWorkflow }),
    /internal operator authentication contract/,
  );
});

test('rejects a schema without credential and session ownership', () => {
  const invalid = dbml
    .replace('Table operations.operator_login_credentials', 'Table operations.removed_login_credentials')
    .replace('Table operations.operator_sessions', 'Table operations.removed_sessions')
    .replace('Ref: operations.operator_login_credentials.operator_account_id - operations.operator_accounts.id', '')
    .replace('Ref: operations.operator_sessions.operator_account_id > operations.operator_accounts.id', '');

  assert.throws(
    () => validateInternalOperatorAuth({ dbml: invalid, contract, releaseWorkflow }),
    /operator authentication schema/,
  );
});

test('rejects removal of GitHub Actions AWS OIDC', () => {
  const invalid = releaseWorkflow.replaceAll('id-token: write', 'id-token: none');

  assert.throws(
    () => validateInternalOperatorAuth({ dbml, contract, releaseWorkflow: invalid }),
    /GitHub Actions AWS OIDC/,
  );
});
