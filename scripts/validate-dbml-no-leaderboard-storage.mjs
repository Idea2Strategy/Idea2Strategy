import { readFile } from 'node:fs/promises';

const entry = process.argv[2] ?? 'db/schema.dbml';
const source = await readFile(entry, 'utf8');

const forbiddenIdentifiers = [
  'competition.leaderboard_snapshots',
  'competition.leaderboard_entries',
  'leaderboard_snapshots',
  'leaderboard_entries',
];

const remainingIdentifiers = forbiddenIdentifiers.filter((identifier) =>
  source.includes(identifier),
);

if (remainingIdentifiers.length > 0) {
  console.error(JSON.stringify({ entry, remainingIdentifiers }));
  process.exit(1);
}

console.log(
  JSON.stringify({ entry, status: 'leaderboard persistence is absent' }),
);
