import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const proposal = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(proposal, '..', '..');
const catalogPath = path.join(proposal, 'catalog.json');
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

const requiredCodes = new Set([
  'OPERATOR_RBAC_CATALOG_READ', 'OPERATOR_RBAC_ASSIGNMENT_READ',
  'OPERATOR_RBAC_GRANT', 'OPERATOR_RBAC_REVOKE',
  'ACCOUNT_SANCTION_APPLY', 'ACCOUNT_SANCTION_LIFT',
  'OPERATOR_CASE_QUEUE_READ', 'OPERATOR_CASE_DETAIL_READ',
  'OPERATOR_CASE_ASSIGN', 'OPERATOR_CASE_REASSIGN', 'OPERATOR_CASE_UNASSIGN',
  'OPERATOR_CASE_START_REVIEW', 'OPERATOR_CASE_REQUEST_INFORMATION',
  'OPERATOR_CASE_RESOLVE', 'OPERATOR_CASE_REJECT',
  'OPERATOR_CASE_APPLY_SANCTION', 'OPERATOR_CASE_RELEASE_SANCTION',
  'COMPETITION_ROOM_READ', 'COMPETITION_ROOM_MANAGE',
]);

const exactDefaultIds = new Map([
  ['ACCOUNT_SANCTION_APPLY', '40000000-0000-4000-8000-000000000004'],
  ['ACCOUNT_SANCTION_LIFT', '50000000-0000-4000-8000-000000000005'],
  ['OPERATOR_CASE_QUEUE_READ', 'a2000000-0000-4000-8000-000000000018'],
  ['OPERATOR_CASE_DETAIL_READ', 'a2000000-0000-4000-8000-000000000019'],
  ['OPERATOR_CASE_ASSIGN', 'a2000000-0000-4000-8000-000000000020'],
  ['OPERATOR_CASE_REASSIGN', 'a2000000-0000-4000-8000-000000000021'],
  ['OPERATOR_CASE_UNASSIGN', 'a2000000-0000-4000-8000-000000000022'],
  ['OPERATOR_CASE_START_REVIEW', 'a2000000-0000-4000-8000-000000000023'],
  ['OPERATOR_CASE_REQUEST_INFORMATION', 'a2000000-0000-4000-8000-000000000024'],
  ['OPERATOR_CASE_RESOLVE', 'a2000000-0000-4000-8000-000000000025'],
  ['OPERATOR_CASE_REJECT', 'a2000000-0000-4000-8000-000000000026'],
  ['OPERATOR_CASE_APPLY_SANCTION', 'a2000000-0000-4000-8000-000000000027'],
  ['OPERATOR_CASE_RELEASE_SANCTION', 'a2000000-0000-4000-8000-000000000028'],
  ['COMPETITION_ROOM_READ', 'e3000000-0000-4000-8000-000000000001'],
  ['COMPETITION_ROOM_MANAGE', 'e3000000-0000-4000-8000-000000000002'],
]);

const generatedIds = new Set([
  '72c9c03f-f66d-4095-8c1f-b79e8f4d0eb0',
  '34db0223-cce2-49e0-bdc0-fd00230ac789',
  '2a20a8a6-11fd-45ae-acae-28fa52f041cb',
  '155b2fbe-218e-44a7-ae4e-a7201ff5bac3',
  '85a4296a-9b35-40c6-a070-f9d414b4c9f6',
  'ecbfc92d-133b-45f7-a7c8-48fb2d4d0dae',
]);

async function text(relative) {
  return readFile(path.join(proposal, relative), 'utf8');
}

async function json(relative) {
  return JSON.parse(await text(relative));
}

function byCode(catalog) {
  return new Map(catalog.permissions.map((permission) => [permission.code, permission]));
}

test('pins the exact backend, UI, issue, and governance evidence', async () => {
  const evidence = await json('evidence.json');
  assert.equal(evidence.status, 'isolated-proposal-not-approved');
  assert.equal(evidence.governanceStatus, 'unknown');
  assert.equal(evidence.rootCommit, '21437cb2e940679b800645a6adae33943fd0dee3');
  assert.equal(evidence.backend.commit, 'bef4de6969d3ad83d147bf55c479fecd4116b76d');
  assert.equal(evidence.ui.commit, 'ac0469a14d2a4d929368e42dbb768802073f0c8c');
  assert.equal(evidence.ui.issue, 110);
});

test('enumerates every required guard exactly once and preserves production IDs', async () => {
  const catalog = await json('catalog.json');
  assert.equal(catalog.catalogVersion, 'development-operator-rbac-v1');
  assert.equal(catalog.permissions.length, 19);
  assert.deepEqual(new Set(catalog.permissions.map((item) => item.code)), requiredCodes);
  assert.equal(new Set(catalog.permissions.map((item) => item.id)).size, 19);
  for (const item of catalog.permissions) assert.match(item.id, uuid);
  const permissions = byCode(catalog);
  for (const [code, id] of exactDefaultIds) assert.equal(permissions.get(code)?.id, id);

  const newPermissionIds = [
    permissions.get('OPERATOR_RBAC_CATALOG_READ').id,
    permissions.get('OPERATOR_RBAC_ASSIGNMENT_READ').id,
    permissions.get('OPERATOR_RBAC_GRANT').id,
    permissions.get('OPERATOR_RBAC_REVOKE').id,
  ];
  assert.ok(newPermissionIds.every((id) => generatedIds.has(id) && id[14] === '4'));
  assert.ok(catalog.roles.every((role) => generatedIds.has(role.id) && role.id[14] === '4'));
});

test('runtime inputs cover all 19 guards and both UI visibility IDs', async () => {
  const catalog = await json('catalog.json');
  const inputs = await json('runtime-guard-inputs.json');
  const bindings = [...inputs.backendSpringProperties, ...inputs.backendCodeGuards];
  assert.equal(bindings.length, 19);
  assert.deepEqual(new Set(bindings.map((item) => item.permissionCode)), requiredCodes);
  const permissions = byCode(catalog);
  for (const binding of bindings) {
    assert.equal(binding.permissionId, permissions.get(binding.permissionCode)?.id);
  }
  assert.equal(inputs.sharedSettings['idea2strategy.operator-rbac.read-guard.catalog-read-mfa-required'], true);
  assert.equal(inputs.sharedSettings['idea2strategy.operator-rbac.read-guard.assignment-read-mfa-required'], true);
  assert.equal(
    inputs.frontendBuildInputs.VITE_OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID,
    permissions.get('OPERATOR_RBAC_CATALOG_READ').id,
  );
  assert.equal(
    inputs.frontendBuildInputs.VITE_OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID,
    permissions.get('OPERATOR_RBAC_ASSIGNMENT_READ').id,
  );
  assert.equal(inputs.terraformInputs.operator_rbac_catalog_version, catalog.catalogVersion);
  assert.equal(
    inputs.terraformInputs.operator_rbac_catalog_read_permission_id,
    permissions.get('OPERATOR_RBAC_CATALOG_READ').id,
  );
  assert.equal(
    inputs.terraformInputs.operator_rbac_assignment_read_permission_id,
    permissions.get('OPERATOR_RBAC_ASSIGNMENT_READ').id,
  );
  assert.equal(
    inputs.terraformInputs.operator_rbac_grant_permission_id,
    permissions.get('OPERATOR_RBAC_GRANT').id,
  );
  assert.equal(
    inputs.terraformInputs.operator_rbac_revoke_permission_id,
    permissions.get('OPERATOR_RBAC_REVOKE').id,
  );
});

test('matches backend sanction, case, and competition production defaults', async () => {
  const sanction = await readFile(path.join(
    root, 'backend', 'apps', 'backend-api', 'src', 'main', 'java', 'com', 'idea2strategy',
    'backend', 'api', 'sanction', 'AccountSanctionConfiguration.java'), 'utf8');
  assert.match(sanction, /40000000-0000-4000-8000-000000000004/);
  assert.match(sanction, /50000000-0000-4000-8000-000000000005/);

  const cases = await readFile(path.join(
    root, 'backend', 'apps', 'backend-api', 'src', 'main', 'java', 'com', 'idea2strategy',
    'backend', 'api', 'caseoperations', 'OperatorCaseConfiguration.java'), 'utf8');
  assert.match(cases, /permission\(18\), permission\(19\), permissions/);
  assert.match(cases, /int suffix = 20/);

  const actions = await readFile(path.join(
    root, 'backend', 'modules', 'backend-application', 'src', 'main', 'java', 'com',
    'idea2strategy', 'backend', 'application', 'caseoperations', 'OperatorCaseCommand.java'), 'utf8');
  const enumBody = actions.match(/public enum Action\s*\{([\s\S]*?)\}/)?.[1];
  assert.ok(enumBody);
  const positions = ['ASSIGN', 'REASSIGN', 'UNASSIGN', 'START_REVIEW', 'REQUEST_INFORMATION',
    'RESOLVE', 'REJECT', 'APPLY_SANCTION', 'RELEASE_SANCTION'].map((action) => enumBody.indexOf(action));
  assert.ok(positions.every((position) => position >= 0));
  assert.deepEqual([...positions].sort((a, b) => a - b), positions);

  const competition = await readFile(path.join(
    root, 'backend', 'db-migration', 'src', 'main', 'resources', 'db', 'migration',
    'V20260802230000__backend_operator_room_permissions.sql'), 'utf8');
  for (const [code, id] of [
    ['COMPETITION_ROOM_READ', 'e3000000-0000-4000-8000-000000000001'],
    ['COMPETITION_ROOM_MANAGE', 'e3000000-0000-4000-8000-000000000002'],
  ]) {
    assert.match(competition, new RegExp(id));
    assert.match(competition, new RegExp(code));
  }
  assert.match(competition, /Read operator-safe official competition room state and result provenance/);
  assert.match(competition, /Cancel or invalidate official competition rooms through audited commands/);
});

test('matches the UI #110 read visibility and all nine command surfaces', async () => {
  const app = await readFile(path.join(root, 'ui', 'src', 'App.tsx'), 'utf8');
  assert.match(app, /VITE_OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID/);
  assert.match(app, /VITE_OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID/);

  const operations = await readFile(path.join(root, 'ui', 'src', 'api', 'accountOperations.ts'), 'utf8');
  for (const action of ['ASSIGN', 'REASSIGN', 'UNASSIGN', 'START_REVIEW', 'REQUEST_INFORMATION',
    'RESOLVE', 'REJECT', 'APPLY_SANCTION', 'RELEASE_SANCTION']) {
    assert.match(operations, new RegExp(`'${action}'`));
  }
  assert.match(operations, /applySanction/);
  assert.match(operations, /liftSanction/);
});

test('supplies every RBAC UUID required by the current root Terraform runtime', async () => {
  const variables = await readFile(path.join(
    root, 'infra', 'terraform', 'environments', 'development', 'variables.tf'), 'utf8');
  const userData = await readFile(path.join(
    root, 'infra', 'terraform', 'environments', 'development', 'templates',
    'ec2-user-data.sh.tftpl'), 'utf8');
  const inputs = await json('runtime-guard-inputs.json');
  for (const name of [
    'operator_rbac_catalog_read_permission_id',
    'operator_rbac_assignment_read_permission_id',
    'operator_rbac_grant_permission_id',
    'operator_rbac_revoke_permission_id',
  ]) {
    assert.match(variables, new RegExp(`variable "${name}"`));
    assert.match(inputs.terraformInputs[name], uuid);
  }
  assert.match(userData, /OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID=\$\{operator_rbac_catalog_read_permission_id\}/);
  assert.match(userData, /OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID=\$\{operator_rbac_assignment_read_permission_id\}/);
  assert.match(userData, /IDEA2STRATEGY_OPERATOR_RBAC_GUARD_GRANT_PERMISSION_ID=\$\{operator_rbac_grant_permission_id\}/);
  assert.match(userData, /IDEA2STRATEGY_OPERATOR_RBAC_GUARD_REVOKE_PERMISSION_ID=\$\{operator_rbac_revoke_permission_id\}/);
});

test('bootstrap template embeds the exact catalog but remains fail-closed and unfilled', async () => {
  const catalogBytes = (await readFile(catalogPath, 'utf8')).replace(/\r\n/g, '\n');
  const catalogHash = createHash('sha256').update(catalogBytes, 'utf8').digest('hex');
  const catalog = JSON.parse(catalogBytes);
  const manifest = await json('bootstrap-manifest.template.json');
  assert.equal(manifest.catalogContentHash, catalogHash);
  assert.equal(manifest.catalogVersion, catalog.catalogVersion);
  assert.deepEqual(manifest.roles, catalog.roles);
  assert.deepEqual(manifest.permissions, catalog.permissions);
  assert.deepEqual(manifest.rolePermissions, catalog.rolePermissions);
  assert.equal(manifest.initialRoleId, catalog.roles[0].id);
  assert.equal(manifest.externalIdentityKeyVersion, 0);
  assert.doesNotMatch(manifest.externalIdentityKeyHmac, /^[0-9a-f]{64}$/);
  for (const field of [
    'expectedDatabaseRole', 'externalIdentityKeyHmac', 'operatorAccountId',
    'operatorRoleAssignmentId', 'deploymentActorId', 'correlationId', 'auditEventId',
  ]) assert.match(String(manifest[field]), /UNFILLED/);
});

test('root can delegate exactly the lower role while the lower role cannot delegate', async () => {
  const catalog = await json('catalog.json');
  const [rootRole, lowerRole] = catalog.roles;
  assert.ok(rootRole.hierarchyRank > lowerRole.hierarchyRank);
  const rootMappings = catalog.rolePermissions.filter((item) => item.roleId === rootRole.id);
  const lowerMappings = catalog.rolePermissions.filter((item) => item.roleId === lowerRole.id);
  const rootPermissions = new Set(rootMappings.map((item) => item.permissionId));
  const rootDelegable = new Set(rootMappings.filter((item) => item.delegable).map((item) => item.permissionId));
  const lowerPermissions = new Set(lowerMappings.map((item) => item.permissionId));
  assert.equal(rootPermissions.size, 19);
  assert.equal(lowerPermissions.size, 17);
  assert.ok([...lowerPermissions].every((id) => rootDelegable.has(id)));
  assert.ok(lowerMappings.every((item) => item.delegable === false));
  const permissions = byCode(catalog);
  assert.ok(!lowerPermissions.has(permissions.get('OPERATOR_RBAC_GRANT').id));
  assert.ok(!lowerPermissions.has(permissions.get('OPERATOR_RBAC_REVOKE').id));
});

test('pins normalized-LF checksums for every deploy-input artifact', async () => {
  const lines = (await text('CHECKSUMS.sha256')).trim().split(/\r?\n/);
  const expected = new Map(lines.map((line) => {
    const match = line.match(/^([0-9a-f]{64})  (.+)$/);
    assert.ok(match, `invalid checksum line: ${line}`);
    return [match[2], match[1]];
  }));
  for (const file of ['catalog.json', 'runtime-guard-inputs.json', 'bootstrap-manifest.template.json']) {
    const normalized = (await text(file)).replace(/\r\n/g, '\n');
    const actual = createHash('sha256').update(normalized, 'utf8').digest('hex');
    assert.equal(actual, expected.get(file), `checksum drift: ${file}`);
  }
});
