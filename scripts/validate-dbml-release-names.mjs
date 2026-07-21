import { readFile } from 'node:fs/promises';

const entry = process.argv[2] ?? 'db/schema.dbml';
const source = await readFile(entry, 'utf8');

const requiredTables = [
  'strategy.strategy_releases',
  'strategy.component_releases',
  'strategy.release_components',
  'strategy.release_instruments',
];

const forbiddenIdentifiers = [
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

if (missingTables.length > 0 || remainingOldNames.length > 0) {
  console.error(
    JSON.stringify({ entry, missingTables, remainingOldNames }),
  );
  process.exit(1);
}

console.log(
  JSON.stringify({
    entry,
    requiredTables,
    status: 'release naming verified',
  }),
);
