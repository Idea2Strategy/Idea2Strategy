import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import process from 'node:process';

import { Parser } from '@dbml/core';

const CONTRACT_ID = 'contract.operations.operator-rbac.v1';

const requireIncludes = (source, fragment, label = fragment) => {
  if (!source.includes(fragment)) throw new Error(`missing ${label}: ${fragment}`);
};

export function validateOperatorRbacProposal({ dbml, contract }) {
  const database = Parser.parse(dbml, 'dbmlv2');
  const operations = database.schemas.find((schema) => schema.name === 'operations');
  if (!operations) throw new Error('operations schema is missing');

  const tables = new Map(operations.tables.map((table) => [table.name, table]));
  const requiredTables = [
    'operator_accounts',
    'roles',
    'permissions',
    'role_permissions',
    'rbac_catalog_versions',
    'rbac_catalog_roles',
    'rbac_catalog_permissions',
    'rbac_catalog_role_permissions',
    'operator_role_assignments',
    'audit_events',
  ];
  for (const name of requiredTables) {
    if (!tables.has(name)) throw new Error(`required operations table is missing: ${name}`);
  }

  const requireFields = (tableName, names) => {
    const fields = new Set(tables.get(tableName).fields.map((field) => field.name));
    for (const name of names) {
      if (!fields.has(name)) throw new Error(`missing operations.${tableName}.${name}`);
    }
  };

  requireFields('rbac_catalog_versions', [
    'catalog_version',
    'content_hash',
    'status',
    'activated_at',
    'retired_at',
  ]);
  requireFields('rbac_catalog_roles', [
    'catalog_version',
    'role_id',
    'hierarchy_rank',
    'role_status',
  ]);
  requireFields('rbac_catalog_permissions', [
    'catalog_version',
    'permission_id',
    'permission_status',
  ]);
  requireFields('rbac_catalog_role_permissions', [
    'catalog_version',
    'role_id',
    'permission_id',
    'delegable',
  ]);
  requireFields('operator_role_assignments', ['catalog_version']);
  requireFields('audit_events', [
    'rbac_catalog_version',
    'resolved_rbac_catalog_version',
    'request_hash',
    'decision_status',
    'response_status',
    'response_code',
    'request_document',
    'response_document',
    'before_document',
    'after_document',
    'evidence_document',
    'before_hash',
    'after_hash',
    'evidence_hash',
  ]);

  for (const fragment of [
    '(catalog_version, role_id, permission_id) [pk]',
    "status IN ('DRAFT', 'ACTIVE', 'RETIRED')",
    "target_domain <> 'OPERATOR_RBAC' OR",
    "request_hash = encode(digest(request_document::text, 'sha256'), 'hex')",
    "before_hash = encode(digest(before_document::text, 'sha256'), 'hex')",
    "after_hash = encode(digest(after_document::text, 'sha256'), 'hex')",
    "evidence_hash = encode(digest(evidence_document::text, 'sha256'), 'hex')",
    "resolved_rbac_catalog_version = rbac_catalog_version",
    "decision_status = 'REJECTED' AND response_status BETWEEN 400 AND 499 AND before_hash = after_hash",
    'Ref: operations.rbac_catalog_role_permissions.(catalog_version, role_id) > operations.rbac_catalog_roles.(catalog_version, role_id)',
    'Ref: operations.rbac_catalog_role_permissions.(catalog_version, permission_id) > operations.rbac_catalog_permissions.(catalog_version, permission_id)',
    'Ref: operations.operator_role_assignments.(catalog_version, role_id) > operations.rbac_catalog_roles.(catalog_version, role_id)',
    'Ref: operations.audit_events.resolved_rbac_catalog_version > operations.rbac_catalog_versions.catalog_version',
  ]) {
    requireIncludes(
      dbml,
      fragment,
      fragment.startsWith('(catalog_version, role_id, permission_id)')
        ? 'catalog-versioned delegability'
        : 'RBAC invariant',
    );
  }

  for (const tableName of [
    'rbac_catalog_versions',
    'rbac_catalog_roles',
    'rbac_catalog_permissions',
    'rbac_catalog_role_permissions',
  ]) {
    if (tables.get(tableName).records.length !== 0) {
      throw new Error(`proposal must not seed a product permission catalog entry: operations.${tableName}`);
    }
  }

  requireIncludes(contract, `id: ${CONTRACT_ID}`, 'contract id');
  requireIncludes(contract, 'status: proposed', 'proposal status');
  if (/catalog version(?:은|을)?\s+(?:reason_code|target_domain|action_type)/u.test(contract)) {
    throw new Error('proposal permits lossy audit-field overloading');
  }
  for (const phrase of [
    '실제 role code, permission code, hierarchy rank 값, delegable 값은 이 계약이 정하지 않는다.',
    '기존 필드에 catalog version이나 증적 JSON을 겹쳐 싣지 않는다.',
    '같은 key와 같은 hash는 저장된 response status/code/document를',
    '같은 key와 다른 hash는 `409`로 거절',
    'before_hash = after_hash',
    'DBML 변경 보류가 해제된 뒤에만',
  ]) {
    requireIncludes(contract, phrase, 'contract obligation');
  }

  if (/Permission seed:\s*(?!REVIEW_EXAMPLE\b)[A-Z][A-Z0-9_]+/u.test(contract)) {
    throw new Error('proposal invents a product permission catalog entry');
  }

  return {
    status: 'passed',
    contractId: CONTRACT_ID,
    operationsTableCount: operations.tables.length,
  };
}

async function main() {
  const dbmlEntry = process.argv[2] ?? 'proposals/operator-rbac/schema.draft.dbml';
  const contractEntry = process.argv[3] ?? 'proposals/operator-rbac/operator-rbac-contract.v1.md';
  const [dbml, contract] = await Promise.all([
    readFile(dbmlEntry, 'utf8'),
    readFile(contractEntry, 'utf8'),
  ]);
  const result = validateOperatorRbacProposal({ dbml, contract });
  process.stdout.write(`${JSON.stringify({ dbmlEntry, contractEntry, ...result })}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
