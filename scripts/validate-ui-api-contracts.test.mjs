import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { backendRoutes, frontendRoutes, normalizeRoute, pythonRoutes, validateContracts } from './validate-ui-api-contracts.mjs';

test('normalizes frontend and Spring path variables to the same contract shape', () => {
  assert.equal(normalizeRoute('/api/v1/bots/${encodeURIComponent(botId)}?view=full'), '/api/v1/bots/{param}');
  assert.deepEqual([...frontendRoutes('request(`/api/v1/bots/${botId}`)')], ['/api/v1/bots/{param}']);
  assert.deepEqual([...backendRoutes('@RequestMapping("/api/v1/bots") public class Bots { @GetMapping("/{botId}") void one() {} }')], ['/api/v1/bots/{param}']);
});

test('discovers FastAPI routes built from a stable API prefix', () => {
  assert.deepEqual([...pythonRoutes('API_PREFIX = "/api/v1"\n@app.get(f"{API_PREFIX}/backtests/{run_id}")\ndef one(): pass')], ['/api/v1/backtests/{param}']);
});

test('fails when a frontend API path has no backend controller mapping', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'i2s-contract-'));
  const uiRoot = path.join(root, 'ui');
  const backendRoot = path.join(root, 'backend');
  await mkdir(uiRoot); await mkdir(backendRoot);
  try {
    await writeFile(path.join(uiRoot, 'client.ts'), "fetch('/api/v1/known'); fetch('/api/v1/missing');");
    await writeFile(path.join(backendRoot, 'Known.java'), '@RequestMapping("/api/v1") class Known { @GetMapping("/known") void known() {} }');
    const result = await validateContracts({ uiRoot, backendRoot });
    assert.deepEqual(result.missing, ['/api/v1/missing']);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
