import { readFile } from 'node:fs/promises';

const entry = process.argv[2] ?? 'db/schema.dbml';
const source = await readFile(entry, 'utf8');

const requiredTables = [
  'strategy.strategy_drafts',
  'strategy.strategy_templates',
  'strategy.strategy_releases',
  'strategy.release_instruments',
];

const forbiddenIdentifiers = [
  'strategy.validation_runs',
  'validation_run_id',
  'strategy.component_drafts',
  'strategy.component_releases',
  'strategy.release_components',
  'source_template_id',
  'strategy_template_id',
  'strategy.strategy_versions',
  'strategy.component_versions',
  'strategy.version_components',
  'strategy.version_instruments',
  'strategy_version_id',
  'component_version_id',
];

const missingTables = requiredTables.filter(
  (table) => !source.includes(`Table ${table} {`),
);
const remainingOldNames = forbiddenIdentifiers.filter((name) =>
  source.includes(name),
);
const releaseBody = source.match(
  /Table strategy\.strategy_releases \{([\s\S]*?)\n\}/,
)?.[1];
const missingReleaseEvidence = [
  'validator_version varchar [not null]',
  'validated_at timestamp [not null]',
].filter((field) => !releaseBody?.includes(field));

if (
  missingTables.length > 0 ||
  remainingOldNames.length > 0 ||
  missingReleaseEvidence.length > 0
) {
  console.error(
    JSON.stringify({
      entry,
      missingTables,
      remainingOldNames,
      missingReleaseEvidence,
    }),
  );
  process.exit(1);
}

console.log(
  JSON.stringify({
    entry,
    requiredTables,
    status: 'strategy release model verified',
  }),
);
