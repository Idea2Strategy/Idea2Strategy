import { execFileSync } from 'node:child_process';
import process from 'node:process';

const base = process.argv[2] ?? 'origin/develop';
const output = execFileSync('git', ['diff', '--name-only', base, '--'], {
  encoding: 'utf8',
});

const changedPaths = output
  .split(/\r?\n/u)
  .map((value) => value.trim())
  .filter(Boolean);

const protectedPaths = changedPaths.filter((path) =>
  path === 'docs/product-authorities.yaml'
  || path === 'docs/collaboration-policy.md'
  || path === 'db/schema.dbml'
  || path.startsWith('specs/')
  || path.startsWith('contracts/'),
);

if (protectedPaths.length > 0) {
  throw new Error(`proposal modifies protected canonical paths: ${protectedPaths.join(', ')}`);
}

process.stdout.write(`${JSON.stringify({
  base,
  changedPathCount: changedPaths.length,
  protectedCanonicalChanges: 0,
  status: 'passed',
})}\n`);
