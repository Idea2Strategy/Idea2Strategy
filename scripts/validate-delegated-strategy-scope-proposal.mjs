import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import process from 'node:process';

import { Parser } from '@dbml/core';

const CONTRACT_ID = 'contract.identity.delegated-strategy-scope.v1';

const requireIncludes = (source, fragment, label = fragment) => {
  if (!source.includes(fragment)) throw new Error(`missing ${label}: ${fragment}`);
};

export function validateDelegatedStrategyScopeProposal({ dbml, contract }) {
  const database = Parser.parse(dbml, 'dbmlv2');
  const identity = database.schemas.find((schema) => schema.name === 'identity');
  const strategy = database.schemas.find((schema) => schema.name === 'strategy');
  if (!identity || !strategy) throw new Error('identity and strategy schemas are required');

  const identityTables = new Map(identity.tables.map((table) => [table.name, table]));
  const strategyTables = new Map(strategy.tables.map((table) => [table.name, table]));
  const requiredIdentityTables = [
    'delegated_authorizations',
    'delegated_authorization_scopes',
    'delegated_authorization_strategy_targets',
    'delegated_strategy_derivations',
    'delegated_credentials',
    'delegated_authorization_events',
  ];
  for (const name of requiredIdentityTables) {
    if (!identityTables.has(name)) throw new Error(`required identity table is missing: ${name}`);
  }

  const requireFields = (tables, tableName, names) => {
    const fields = new Set(tables.get(tableName).fields.map((field) => field.name));
    for (const name of names) {
      if (!fields.has(name)) throw new Error(`missing ${tableName}.${name}`);
    }
  };

  requireFields(identityTables, 'delegated_authorizations', [
    'authorization_version',
    'replaces_authorization_id',
    'strategy_target_set_hash',
  ]);
  requireFields(identityTables, 'delegated_authorization_strategy_targets', [
    'authorization_id',
    'strategy_id',
    'owner_account_id_at_grant',
    'strategy_access_epoch_at_grant',
  ]);
  requireFields(identityTables, 'delegated_strategy_derivations', [
    'authorization_id',
    'credential_id',
    'derivation_type',
    'source_strategy_id',
    'result_strategy_id',
    'owner_account_id_at_creation',
    'strategy_access_epoch_at_creation',
    'correlation_id',
    'idempotency_key',
    'request_hash',
  ]);
  requireFields(strategyTables, 'strategies', ['delegated_access_epoch']);

  for (const fragment of [
    '(replaces_authorization_id) [unique]',
    '(authorization_id, strategy_id) [pk]',
    '(authorization_id, idempotency_key) [unique]',
    "(derivation_type = 'CREATE' AND source_strategy_id IS NULL) OR (derivation_type = 'COPY' AND source_strategy_id IS NOT NULL AND source_strategy_id <> result_strategy_id)",
    'Ref: identity.delegated_authorization_strategy_targets.(authorization_id, owner_account_id_at_grant) > identity.delegated_authorizations.(id, account_id)',
    'Ref: identity.delegated_strategy_derivations.(authorization_id, credential_id) > identity.delegated_credentials.(authorization_id, id)',
    'Ref: identity.delegated_strategy_derivations.(authorization_id, source_strategy_id) > identity.delegated_authorization_strategy_targets.(authorization_id, strategy_id)',
    'Ref: identity.delegated_strategy_derivations.result_strategy_id > strategy.strategies.id',
  ]) {
    requireIncludes(
      dbml,
      fragment,
      fragment.includes('source_strategy_id) > identity.delegated_authorization_strategy_targets')
        ? 'COPY source explicit-target reference'
        : 'delegated Strategy invariant',
    );
  }

  const delegatedScope = identity.enums.find((candidate) => candidate.name === 'delegated_scope');
  if (!delegatedScope) throw new Error('identity.delegated_scope is missing');
  const scopeNames = new Set(delegatedScope.values.map((value) => value.name));
  const allowedScopes = new Set([
    'ACCOUNT_RESOURCE_READ',
    'STRATEGY_CREATE',
    'STRATEGY_COPY',
    'STRATEGY_EDIT',
    'STRATEGY_VALIDATE',
  ]);
  for (const scope of scopeNames) {
    if (!allowedScopes.has(scope)) throw new Error(`forbidden delegated scope: ${scope}`);
  }
  for (const scope of allowedScopes) {
    if (!scopeNames.has(scope)) throw new Error(`required delegated scope is missing: ${scope}`);
  }

  for (const tableName of [
    'delegated_authorization_strategy_targets',
    'delegated_strategy_derivations',
  ]) {
    if (identityTables.get(tableName).records.length !== 0) {
      throw new Error(`proposal must not seed delegated Strategy resources: ${tableName}`);
    }
  }

  requireIncludes(contract, `id: ${CONTRACT_ID}`, 'contract id');
  requireIncludes(contract, 'status: proposed', 'proposal status');
  if (contract.includes('명시 allowlist 행은 authorization 활성화 뒤 수정할 수 있다.')) {
    throw new Error('contract violates the immutable explicit allowlist');
  }
  for (const phrase of [
    '명시 allowlist 행은 authorization 활성화 뒤 UPDATE·DELETE할 수 없다.',
    'COPY source는 명시 target만 허용한다.',
    'result owner는 authorization account와 같아야 하며',
    'auth epoch → sanction → authorization/credential expiry·revoke → scope → resource',
    'release가 성공해 독립 Bot snapshot을',
    '소유권 변경 transaction은 epoch를 정확히 1 증가',
    'token digest·token 원문·private Strategy source·편집 payload',
    '정확한 proposal commit에 대한 제품 권한자 승인과 DBML 보류 해제',
  ]) {
    requireIncludes(
      contract,
      phrase,
      phrase.startsWith('auth epoch') ? 'fail-closed evaluation order' : 'contract obligation',
    );
  }

  return {
    status: 'passed',
    contractId: CONTRACT_ID,
    identityTableCount: identity.tables.length,
  };
}

async function main() {
  const dbmlEntry = process.argv[2] ?? 'proposals/delegated-strategy-scope/schema.draft.dbml';
  const contractEntry = process.argv[3]
    ?? 'proposals/delegated-strategy-scope/delegated-strategy-scope-contract.v1.md';
  const [dbml, contract] = await Promise.all([
    readFile(dbmlEntry, 'utf8'),
    readFile(contractEntry, 'utf8'),
  ]);
  const result = validateDelegatedStrategyScopeProposal({ dbml, contract });
  process.stdout.write(`${JSON.stringify({ dbmlEntry, contractEntry, ...result })}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
