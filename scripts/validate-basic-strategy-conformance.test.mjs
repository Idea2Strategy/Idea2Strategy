import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..');
const validator = path.join(root, 'scripts', 'validate-basic-strategy-conformance.mjs');
const elementCodes = [
  'BASIC_PRICE_COMPARE',
  'BASIC_PRICE_CHANGE_PERCENT',
  'BASIC_VOLUME_COMPARE',
  'BASIC_STREAK',
  'BASIC_SMA_CROSS',
  'BASIC_RSI_CROSS',
  'BASIC_MACD_CROSS',
  'BASIC_BOLLINGER_REVERSAL',
  'BASIC_POSITION_RETURN',
  'BASIC_HOLDING_PERIOD',
  'BASIC_PEAK_RETURN',
  'BASIC_DRAWDOWN_FROM_PEAK',
  'BASIC_SCHEDULE',
  'BASIC_EQUAL_ALLOCATION_ORDER',
];

const validCorpus = () => ({
  schemaVersion: 'basic-element-conformance/v1',
  catalogVersion: 'basic-elements:2026-08-25',
  cases: elementCodes.map((elementCode) => ({
    elementCode,
    containers: elementCode === 'BASIC_SCHEDULE' ? ['BUY'] : ['BUY', 'SELL'],
    validParameters: elementCode === 'BASIC_PRICE_COMPARE'
      ? { resolution: '30m', operator: 'GT', reference: 'PREVIOUS_CLOSE' }
      : {},
    invalidParameters: [{ name: 'fixture-invalid', parameters: {} }],
    operation: elementCode.replace(/^BASIC_/, ''),
    arguments: {},
    trueInputs: {},
    falseInputs: {},
    expectedReviewKo: elementCode,
  })),
});

async function run(corpus, copies = []) {
  const temp = await mkdtemp(path.join(os.tmpdir(), 'basic-conformance-'));
  try {
    const corpusPath = path.join(temp, 'corpus.json');
    await writeFile(corpusPath, `${JSON.stringify(corpus, null, 2)}\n`);
    const result = spawnSync(process.execPath, [
      validator,
      '--corpus', corpusPath,
      ...copies.flatMap((copy) => ['--copy', copy]),
    ], { cwd: root, encoding: 'utf8' });
    return { ...result, output: `${result.stdout}\n${result.stderr}` };
  } finally {
    await rm(temp, { recursive: true, force: true });
  }
}

test('accepts the complete versioned Basic element contract', async () => {
  const result = await run(validCorpus());
  assert.equal(result.status, 0, result.output);
});

test('rejects a missing published element', async () => {
  const corpus = validCorpus();
  corpus.cases = corpus.cases.filter(({ elementCode }) => elementCode !== 'BASIC_MACD_CROSS');
  const result = await run(corpus);
  assert.notEqual(result.status, 0);
  assert.match(result.output, /ELEMENT_SET_MISMATCH/);
});

test('rejects duplicate element codes', async () => {
  const corpus = validCorpus();
  corpus.cases.push(structuredClone(corpus.cases[0]));
  const result = await run(corpus);
  assert.notEqual(result.status, 0);
  assert.match(result.output, /DUPLICATE_ELEMENT/);
});

test('rejects a condition resolution outside the four product clocks', async () => {
  const corpus = validCorpus();
  corpus.cases[0].validParameters.resolution = '5m';
  const result = await run(corpus);
  assert.notEqual(result.status, 0);
  assert.match(result.output, /INVALID_RESOLUTION/);
});

test('rejects a case without a compiler operation', async () => {
  const corpus = validCorpus();
  delete corpus.cases[0].operation;
  const result = await run(corpus);
  assert.notEqual(result.status, 0);
  assert.match(result.output, /OPERATION_REQUIRED/);
});

test('rejects a repository copy that differs from the canonical bytes', async () => {
  const temp = await mkdtemp(path.join(os.tmpdir(), 'basic-conformance-copy-'));
  try {
    const copyPath = path.join(temp, 'copy.json');
    await writeFile(copyPath, '{}\n');
    const result = await run(validCorpus(), [copyPath]);
    assert.notEqual(result.status, 0);
    assert.match(result.output, /FIXTURE_PARITY_MISMATCH/);
  } finally {
    await rm(temp, { recursive: true, force: true });
  }
});
