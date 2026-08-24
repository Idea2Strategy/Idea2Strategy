import assert from 'node:assert/strict';
import { chmod, cp, mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const repositoryRoot = path.resolve(import.meta.dirname, '..');

function git(cwd, ...args) {
  return spawnSync('git', args, { cwd, encoding: 'utf8' });
}

test('pre-commit rejects the GitGuardian generic-password trigger before it reaches GitHub', async () => {
  const fixture = await mkdtemp(path.join(os.tmpdir(), 'idea2strategy-secret-hook-'));
  try {
    assert.equal(git(fixture, 'init', '--quiet').status, 0);
    assert.equal(git(fixture, 'config', 'user.name', 'Secret Gate Test').status, 0);
    assert.equal(git(fixture, 'config', 'user.email', 'secret-gate@example.invalid').status, 0);
    assert.equal(git(fixture, 'config', 'core.hooksPath', '.githooks').status, 0);

    await cp(path.join(repositoryRoot, '.githooks', 'pre-commit'), path.join(fixture, '.githooks', 'pre-commit'), {
      recursive: true,
    });
    await chmod(path.join(fixture, '.githooks', 'pre-commit'), 0o755);
    await writeFile(path.join(fixture, 'README.md'), 'fixture\n');
    assert.equal(git(fixture, 'add', 'README.md').status, 0);
    assert.equal(git(fixture, 'commit', '--quiet', '-m', 'fixture baseline').status, 0);

    // Assemble the detector fixture only at runtime. Keeping the complete known
    // false-positive string in this test source would itself trigger GitGuardian.
    const scannerTrigger = ['$pass', "word = Get-EnvValue 'POSTGRES_", "PASSWORD'\n"].join('');
    await writeFile(path.join(fixture, 'restore.ps1'), scannerTrigger);
    assert.equal(git(fixture, 'add', 'restore.ps1').status, 0);
    const commit = git(fixture, 'commit', '--quiet', '-m', 'must be rejected');

    assert.notEqual(commit.status, 0, 'the unsafe scanner-triggering assignment was committed');
    assert.match(`${commit.stdout}\n${commit.stderr}`, /GitGuardian|generic.password/i);
  } finally {
    await rm(fixture, { recursive: true, force: true });
  }
});

test('tracked restore script avoids generic password variable assignments', async () => {
  const restoreScript = await import('node:fs/promises').then(({ readFile }) =>
    readFile(path.join(repositoryRoot, 'scripts', 'restore-local-baseline.ps1'), 'utf8'),
  );
  assert.doesNotMatch(restoreScript, /\$[A-Za-z0-9_]*password\s*=\s*Get-EnvValue\s+['"][A-Z0-9_]*PASSWORD['"]/i);
});
