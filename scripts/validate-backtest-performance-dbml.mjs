import { readFile } from 'node:fs/promises';
import process from 'node:process';
import { Parser } from '@dbml/core';

const entry = process.argv[2] ?? 'proposals/dbml-redesign/schema.draft.dbml';
const source = await readFile(entry, 'utf8');
const database = Parser.parse(source, 'dbmlv2');

const schemaMap = new Map(database.schemas.map((schema) => [schema.name, schema]));
const backtest = schemaMap.get('backtest');
const performance = schemaMap.get('performance');
if (!backtest || !performance) throw new Error('backtest or performance schema is missing');

const tableMap = (schema) => new Map(schema.tables.map((table) => [table.name, table]));
const backtestTables = tableMap(backtest);
const performanceTables = tableMap(performance);

for (const name of [
  'runs',
  'run_attempts',
  'input_bundles',
  'input_datasets',
  'input_feature_materializations',
  'monthly_judgment_summaries',
  'failure_condition_counts',
  'performance_summaries',
  'detail_manifests',
]) {
  if (!backtestTables.has(name)) throw new Error(`required backtest table is missing: ${name}`);
}

for (const name of ['bot_current_projections', 'bot_snapshots', 'series_manifests']) {
  if (!performanceTables.has(name)) throw new Error(`required performance table is missing: ${name}`);
}

const requireFields = (tables, tableName, names) => {
  const actual = new Set(tables.get(tableName).fields.map((field) => field.name));
  for (const name of names) {
    if (!actual.has(name)) throw new Error(`${tableName}.${name} is required`);
  }
};

requireFields(backtestTables, 'runs', [
  'bot_id',
  'evaluation_start',
  'evaluation_end',
  'initial_cash_amount',
  'fee_policy_id',
  'slippage_rate_bps',
  'buying_power_buffer_policy_id',
  'idempotency_key',
]);
requireFields(backtestTables, 'detail_manifests', [
  'object_id',
  'week_start_date',
  'supersedes_manifest_id',
  'detail_hash',
]);
requireFields(performanceTables, 'bot_current_projections', [
  'equity_amount',
  'total_return_pct',
  'max_drawdown_pct',
  'last_event_sequence',
]);
requireFields(performanceTables, 'bot_snapshots', [
  'equity_amount',
  'total_return_pct',
  'max_drawdown_pct',
  'snapshot_hash',
]);
requireFields(performanceTables, 'series_manifests', [
  'object_id',
  'week_start_date',
  'revision_number',
  'supersedes_manifest_id',
  'available_at',
]);

const rowsFor = (table) => table.records.flatMap((record) =>
  record.values.map((row) => Object.fromEntries(
    record.columns.map((column, index) => [column, row[index]?.value]),
  )),
);

const runs = rowsFor(backtestTables.get('runs'));
const runsByBot = new Map();
const idempotencyKeys = new Set();
for (const run of runs) {
  if (idempotencyKeys.has(run.idempotency_key)) {
    throw new Error(`duplicate backtest idempotency key: ${run.idempotency_key}`);
  }
  idempotencyKeys.add(run.idempotency_key);
  const periods = runsByBot.get(run.bot_id) ?? new Set();
  periods.add(`${run.evaluation_start}/${run.evaluation_end}`);
  runsByBot.set(run.bot_id, periods);
}
if (![...runsByBot.values()].some((periods) => periods.size >= 2)) {
  throw new Error('Records must demonstrate multiple periods for one bot');
}

for (const row of rowsFor(backtestTables.get('monthly_judgment_summaries'))) {
  if (!/^\d{4}-(0[1-9]|1[0-2])$/u.test(String(row.et_year_month))) {
    throw new Error(`invalid ET year-month example: ${row.et_year_month}`);
  }
}

for (const row of rowsFor(backtestTables.get('detail_manifests'))) {
  if (row.supersedes_manifest_id === row.id) {
    throw new Error(`backtest detail manifest supersedes itself: ${row.id}`);
  }
}

for (const row of rowsFor(performanceTables.get('series_manifests'))) {
  if (row.supersedes_manifest_id === row.id) {
    throw new Error(`performance series manifest supersedes itself: ${row.id}`);
  }
  if (new Date(row.available_at).getTime() < new Date(row.created_at).getTime()) {
    throw new Error(`performance series is available before creation: ${row.id}`);
  }
}

for (const fragment of [
  'Ref: backtest.runs.bot_id > bot.bots.id',
  'Ref: backtest.detail_manifests.object_id > storage.objects.id',
  'Ref: performance.bot_current_projections.bot_id > bot.bots.id',
  'Ref: performance.bot_snapshots.bot_id > bot.bots.id',
  'Ref: performance.series_manifests.object_id > storage.objects.id',
  '봇 생성 트랜잭션에서 최초 자동 백테스트 한 건을 원자적으로 생성하고',
  '이후 같은 봇에 사용자가 선택한 기간',
]) {
  if (!source.includes(fragment)) throw new Error(`required backtest/performance invariant is missing: ${fragment}`);
}

process.stdout.write(`${JSON.stringify({
  entry,
  backtestTableCount: backtest.tables.length,
  performanceTableCount: performance.tables.length,
  backtestRunRecordCount: runs.length,
  status: 'passed',
})}\n`);
