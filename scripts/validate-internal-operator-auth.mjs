import { Parser } from '@dbml/core';

const requireAll = (source, fragments, message) => {
  if (fragments.some((fragment) => !source.includes(fragment))) throw new Error(message);
};

export function validateInternalOperatorAuth({ dbml, contract, releaseWorkflow }) {
  const database = Parser.parse(dbml, 'dbmlv2');
  const operations = database.schemas.find((schema) => schema.name === 'operations');
  const tables = new Set(operations?.tables.map((table) => table.name) ?? []);
  if (!tables.has('operator_accounts')
      || !tables.has('operator_login_credentials')
      || !tables.has('operator_sessions')) {
    throw new Error('operator authentication schema is incomplete');
  }
  requireAll(contract, [
    'Approved authority: `user:kcrmin`',
    'Browser operator requests use an opaque server-side session cookie.',
    'Human operator Cognito/OIDC is not an accepted authentication path.',
    'TOTP',
    'Argon2id',
  ], 'internal operator authentication contract is incomplete');
  if (!releaseWorkflow.includes('id-token: write')
      || !releaseWorkflow.includes('aws-actions/configure-aws-credentials')) {
    throw new Error('GitHub Actions AWS OIDC boundary is missing');
  }
  return { status: 'passed', authority: 'user:kcrmin' };
}
