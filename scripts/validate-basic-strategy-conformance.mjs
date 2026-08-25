import { readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const EXPECTED_SCHEMA_VERSION = 'basic-element-conformance/v1';
const EXPECTED_CATALOG_VERSION = 'basic-elements:2026-08-25';
const EXPECTED_ELEMENTS = [
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
const ALLOWED_RESOLUTIONS = new Set(['30m', '1h', '4h', '1d']);

class ContractError extends Error {
  constructor(code, detail) {
    super(detail);
    this.code = code;
  }
}

function parseArgs(argv) {
  const options = {
    corpus: path.resolve('contracts/fixtures/basic-strategy/v1/basic-element-conformance.v1.json'),
    copies: [],
  };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    const value = argv[index + 1];
    if ((flag === '--corpus' || flag === '--copy') && !value) {
      throw new ContractError('ARGUMENT_VALUE_REQUIRED', `${flag} requires a path`);
    }
    if (flag === '--corpus') {
      options.corpus = path.resolve(value);
      index += 1;
    } else if (flag === '--copy') {
      options.copies.push(path.resolve(value));
      index += 1;
    } else {
      throw new ContractError('UNKNOWN_ARGUMENT', flag);
    }
  }
  return options;
}

function requireObject(value, code, detail) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new ContractError(code, detail);
  }
}

function validateCase(testCase, index) {
  requireObject(testCase, 'CASE_OBJECT_REQUIRED', `cases[${index}]`);
  if (typeof testCase.operation !== 'string' || testCase.operation.trim() === '') {
    throw new ContractError('OPERATION_REQUIRED', testCase.elementCode ?? `cases[${index}]`);
  }
  if (!Array.isArray(testCase.containers) || testCase.containers.length === 0) {
    throw new ContractError('CONTAINERS_REQUIRED', testCase.elementCode);
  }
  if (!testCase.containers.every((container) => container === 'BUY' || container === 'SELL')) {
    throw new ContractError('INVALID_CONTAINER', testCase.elementCode);
  }
  requireObject(testCase.validParameters, 'VALID_PARAMETERS_REQUIRED', testCase.elementCode);
  if (
    Object.hasOwn(testCase.validParameters, 'resolution')
    && !ALLOWED_RESOLUTIONS.has(testCase.validParameters.resolution)
  ) {
    throw new ContractError('INVALID_RESOLUTION', `${testCase.elementCode}:${testCase.validParameters.resolution}`);
  }
  if (!Array.isArray(testCase.invalidParameters) || testCase.invalidParameters.length === 0) {
    throw new ContractError('INVALID_PARAMETERS_REQUIRED', testCase.elementCode);
  }
  requireObject(testCase.arguments, 'ARGUMENTS_REQUIRED', testCase.elementCode);
  requireObject(testCase.trueInputs, 'TRUE_INPUTS_REQUIRED', testCase.elementCode);
  requireObject(testCase.falseInputs, 'FALSE_INPUTS_REQUIRED', testCase.elementCode);
  if (typeof testCase.expectedReviewKo !== 'string' || testCase.expectedReviewKo.trim() === '') {
    throw new ContractError('REVIEW_COPY_REQUIRED', testCase.elementCode);
  }
}

function validateCorpus(corpus) {
  requireObject(corpus, 'CORPUS_OBJECT_REQUIRED', 'root');
  if (corpus.schemaVersion !== EXPECTED_SCHEMA_VERSION) {
    throw new ContractError('SCHEMA_VERSION_MISMATCH', String(corpus.schemaVersion));
  }
  if (corpus.catalogVersion !== EXPECTED_CATALOG_VERSION) {
    throw new ContractError('CATALOG_VERSION_MISMATCH', String(corpus.catalogVersion));
  }
  if (!Array.isArray(corpus.cases)) {
    throw new ContractError('CASES_REQUIRED', 'cases');
  }
  const codes = corpus.cases.map(({ elementCode } = {}) => elementCode);
  const duplicates = codes.filter((code, index) => codes.indexOf(code) !== index);
  if (duplicates.length > 0) {
    throw new ContractError('DUPLICATE_ELEMENT', [...new Set(duplicates)].join(','));
  }
  const actual = [...codes].sort();
  const expected = [...EXPECTED_ELEMENTS].sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new ContractError('ELEMENT_SET_MISMATCH', `expected=${expected.join(',')} actual=${actual.join(',')}`);
  }
  corpus.cases.forEach(validateCase);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const canonicalBytes = await readFile(options.corpus, 'utf8');
  let corpus;
  try {
    corpus = JSON.parse(canonicalBytes);
  } catch (error) {
    throw new ContractError('INVALID_JSON', error.message);
  }
  validateCorpus(corpus);
  for (const copy of options.copies) {
    const copyBytes = await readFile(copy, 'utf8');
    if (copyBytes !== canonicalBytes) {
      throw new ContractError('FIXTURE_PARITY_MISMATCH', copy);
    }
  }
  process.stdout.write(`${JSON.stringify({
    status: 'passed',
    schemaVersion: corpus.schemaVersion,
    catalogVersion: corpus.catalogVersion,
    cases: corpus.cases.length,
    copies: options.copies.length,
  })}\n`);
}

main().catch((error) => {
  const code = error instanceof ContractError ? error.code : 'VALIDATION_FAILED';
  process.stderr.write(`${JSON.stringify({ status: 'failed', code, detail: error.message })}\n`);
  process.exitCode = 1;
});
