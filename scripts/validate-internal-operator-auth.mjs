const requireAll = (source, fragments, message) => {
  if (fragments.some((fragment) => !source.includes(fragment))) throw new Error(message);
};

export function validateInternalOperatorAuth({ dbml, contract, releaseWorkflow }) {
  requireAll(dbml, [
    'Table operations.operator_accounts {',
    'Table operations.operator_login_credentials {',
    'Table operations.operator_sessions {',
    'Ref: operations.operator_login_credentials.operator_account_id - operations.operator_accounts.id',
    'Ref: operations.operator_sessions.operator_account_id > operations.operator_accounts.id',
  ], 'operator authentication schema is incomplete');
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
