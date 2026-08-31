import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const registry = await readFile(new URL('../contracts/registry.yaml', import.meta.url), 'utf8');
const entries = [
  {
    id: 'contract.operations.operator-trust.v1',
    source: 'business/operator-trust.v1.md',
    revision: 3,
    required: [
      'Argon2id',
      '6-digit 30-second TOTP',
      'opaque server-side session cookie',
      'CLI-only',
    ],
  },
  {
    id: 'contract.backtest.execution.v1',
    source: 'data/backtest-execution.v1.md',
    revision: 4,
    required: [
      'feature-series.parquet.v1',
      '063f8f27-5c6a-5348-b2bb-abc3c634149c',
      'sha256:1a7c3e5b9d2f4068a1c3e5b7d9f20416283a5c7e9b1d3f50627496a8c0e2b4d6',
    ],
  },
  {
    id: 'contract.market-data.publication.v1',
    source: 'data/market-data-publication.v1.md',
    revision: 2,
    required: [
      'FEATURE_RSI_14_1M_RSI_1_0_0',
      'internal-derived-v1',
      'MATERIALIZE_FEATURE_OUTPUT',
    ],
  },
];

for (const entry of entries) {
  test(`keeps ${entry.id} approved, versioned and fingerprinted`, async () => {
    const contract = await readFile(new URL(`../contracts/${entry.source}`, import.meta.url), 'utf8');
    assert.match(contract, new RegExp(`id: ${entry.id.replaceAll('.', '\\.')}`));
    assert.match(contract, /status: approved/);
    assert.match(contract, new RegExp(`revision: ${entry.revision}(?:\\r?\\n|$)`));
    for (const text of entry.required) assert.ok(contract.includes(text), `missing ${text}`);

    const start = registry.indexOf(`- id: ${entry.id}`);
    assert.notEqual(start, -1, `missing registry entry for ${entry.id}`);
    const next = registry.indexOf('\n  - id:', start + 1);
    const section = registry.slice(start, next === -1 ? undefined : next);
    const fingerprint = `sha256:${createHash('sha256').update(contract).digest('hex')}`;
    assert.match(section, new RegExp(`revision: ${entry.revision}(?:\\r?\\n|$)`));
    assert.ok(section.includes(`source: ${entry.source}`));
    assert.ok(section.includes(`fingerprint: ${fingerprint}`), `stale registry fingerprint for ${entry.id}`);
  });
}
