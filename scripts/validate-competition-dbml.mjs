import { readFile } from 'node:fs/promises';
import process from 'node:process';
import { Parser } from '@dbml/core';

const entry = process.argv[2] ?? 'proposals/dbml-redesign/schema.draft.dbml';
const source = await readFile(entry, 'utf8');
const database = Parser.parse(source, 'dbmlv2');
const schema = database.schemas.find((candidate) => candidate.name === 'competition');
if (!schema) throw new Error('competition schema is missing');

const tables = new Map(schema.tables.map((table) => [table.name, table]));
const requiredTables = [
  'scoring_template_versions',
  'rooms',
  'room_rules',
  'live_room_rules',
  'room_events',
  'room_invitations',
  'room_schedules',
  'participations',
  'participation_events',
  'backtest_evaluation_plans',
  'backtest_evaluation_periods',
  'backtest_period_datasets',
  'backtest_period_feature_materializations',
  'backtest_period_runs',
  'backtest_aggregate_results',
  'live_evaluation_segments',
];
for (const name of requiredTables) {
  if (!tables.has(name)) throw new Error(`required competition table is missing: ${name}`);
}

const forbiddenPatterns = [
  /\blate_submission_policy\b/,
  /Table competition\.evaluation_segments\s*\{/,
  /Enum competition\.participation_status\s*\{[^}]*\bWAITING\b/s,
  /Enum competition\.room_status\s*\{[^}]*\bWAITING\b/s,
  /Enum competition\.room_status\s*\{[^}]*\bSUBMISSION\b/s,
  /\(room_id, owner_account_id\) \[unique\]/,
  /Enum competition\.leaderboard_status\s*\{/,
  /Table competition\.leaderboard_snapshots\s*\{/,
  /Table competition\.leaderboard_entries\s*\{/,
];
for (const pattern of forbiddenPatterns) {
  if (pattern.test(source)) throw new Error(`obsolete competition structure remains: ${pattern}`);
}

const requireFields = (tableName, fieldNames) => {
  const actual = new Set(tables.get(tableName).fields.map((field) => field.name));
  for (const fieldName of fieldNames) {
    if (!actual.has(fieldName)) throw new Error(`${tableName}.${fieldName} is required`);
  }
};

requireFields('rooms', ['competition_type', 'organizer_type', 'creator_account_id', 'created_by_operator_id']);
requireFields('room_rules', ['bot_participation_limit', 'per_account_bot_limit']);
requireFields('room_schedules', [
  'participation_opens_at',
  'evaluation_starts_at',
  'participation_closes_at',
  'evaluation_ends_at',
  'finalization_deadline_at',
]);
requireFields('participations', [
  'room_id',
  'bot_id',
  'owner_account_id',
  'evaluation_started_at',
  'evaluation_finished_at',
  'evaluation_failure_code',
]);
requireFields('backtest_evaluation_plans', [
  'room_id',
  'period_count',
  'plan_hash',
  'commitment_hash',
  'commitment_nonce_ciphertext',
  'locked_at',
  'disclosed_at',
]);
requireFields('backtest_evaluation_periods', [
  'evaluation_plan_room_id',
  'evaluation_start',
  'evaluation_end',
  'importance_weight',
  'input_set_hash',
]);
requireFields('backtest_period_runs', ['participation_id', 'evaluation_period_id', 'run_id', 'verified_at']);
requireFields('backtest_aggregate_results', [
  'participation_id',
  'weighted_return_pct',
  'weighted_max_drawdown_pct',
  'worst_period_max_drawdown_pct',
  'final_score',
  'period_result_set_hash',
  'published_at',
]);
const requiredFragments = [
  "competition_type <> 'BACKTEST' OR organizer_type = 'PLATFORM'",
  'per_account_bot_limit > 0 AND per_account_bot_limit <= bot_participation_limit',
  'participation_closes_at <= evaluation_ends_at',
  'period_count >= 2',
  'importance_weight > 0 AND importance_weight <= 1',
  'commitment_hash varchar(128) [not null, unique]',
  'Ref: competition.backtest_period_runs.run_id > backtest.runs.id',
  'Ref: competition.backtest_aggregate_results.participation_id > competition.participations.id',
  'execution_eligible_from timestamptz [not null]',
];
for (const fragment of requiredFragments) {
  if (!source.includes(fragment)) throw new Error(`required competition invariant is missing: ${fragment}`);
}

for (const table of schema.tables) {
  const seen = new Set();
  for (const index of table.indexes) {
    const columns = index.columns.map((column) => String(column.value ?? column.name)).join(',');
    const signature = `${columns}|unique=${Boolean(index.unique)}|pk=${Boolean(index.pk)}`;
    if (seen.has(signature)) throw new Error(`duplicate index in competition.${table.name}: ${signature}`);
    seen.add(signature);
  }
}

for (const enumDefinition of schema.enums) {
  const used = schema.tables.some((table) =>
    table.fields.some((field) => field._enum?.id === enumDefinition.id),
  );
  if (!used) throw new Error(`unused competition enum: ${enumDefinition.name}`);
}

const rowsFor = (tableName) => tables.get(tableName).records.flatMap((record) =>
  record.values.map((row) => Object.fromEntries(
    record.columns.map((column, index) => [column, row[index]?.value]),
  )),
);

for (const table of schema.tables) {
  const fields = new Map(table.fields.map((field) => [field.name, field]));
  for (const record of table.records) {
    if (new Set(record.columns).size !== record.columns.length) {
      throw new Error(`duplicate Records column in competition.${table.name}`);
    }
    for (const column of record.columns) {
      if (!fields.has(column)) throw new Error(`unknown Records column competition.${table.name}.${column}`);
    }
    for (const row of record.values) {
      if (row.length !== record.columns.length) throw new Error(`Records arity mismatch in competition.${table.name}`);
      const values = new Map(record.columns.map((column, index) => [column, row[index]?.value]));
      for (const field of table.fields) {
        if (field.not_null && !field.dbdefault && !field.increment && !values.has(field.name)) {
          throw new Error(`Records row omits required field competition.${table.name}.${field.name}`);
        }
        if (field._enum && values.has(field.name) && values.get(field.name) !== null) {
          const allowed = new Set(field._enum.values.map((value) => value.name));
          if (!allowed.has(values.get(field.name))) {
            throw new Error(`invalid enum Records value competition.${table.name}.${field.name}=${values.get(field.name)}`);
          }
        }
      }
    }
  }
}

for (const room of rowsFor('rooms')) {
  if (room.competition_type === 'BACKTEST' && room.organizer_type !== 'PLATFORM') {
    throw new Error(`Records contain non-platform BACKTEST room: ${room.id}`);
  }
  const validActor = room.organizer_type === 'PLATFORM'
    ? room.creator_account_id === null && room.created_by_operator_id !== null
    : room.creator_account_id !== null && room.created_by_operator_id === null;
  if (!validActor) throw new Error(`Records room organizer actor mismatch: ${room.id}`);
}

const plans = new Map(rowsFor('backtest_evaluation_plans').map((row) => [row.room_id, row]));
for (const [roomId, plan] of plans) {
  const periods = rowsFor('backtest_evaluation_periods')
    .filter((row) => row.evaluation_plan_room_id === roomId)
    .sort((left, right) => Number(left.period_sequence) - Number(right.period_sequence));
  if (periods.length !== Number(plan.period_count)) {
    throw new Error(`Records period count mismatch for room: ${roomId}`);
  }
  const totalWeight = periods.reduce((sum, period) => sum + Number(period.importance_weight), 0);
  if (Math.abs(totalWeight - 1) > 1e-10) throw new Error(`Records period weights do not sum to 1: ${roomId}`);
  for (let index = 0; index < periods.length; index += 1) {
    if (Number(periods[index].period_sequence) !== index + 1) {
      throw new Error(`Records period sequence is not contiguous: ${roomId}`);
    }
    for (let other = index + 1; other < periods.length; other += 1) {
      const overlaps = periods[index].evaluation_start <= periods[other].evaluation_end
        && periods[other].evaluation_start <= periods[index].evaluation_end;
      if (overlaps) throw new Error(`Records evaluation periods overlap: ${roomId}`);
    }
  }
}

const rowsForExternal = (schemaName, tableName) => {
  const externalSchema = database.schemas.find((candidate) => candidate.name === schemaName);
  const table = externalSchema?.tables.find((candidate) => candidate.name === tableName);
  if (!table) throw new Error(`required external table is missing: ${schemaName}.${tableName}`);
  return table.records.flatMap((record) => record.values.map((row) => Object.fromEntries(
    record.columns.map((column, index) => [column, row[index]?.value]),
  )));
};

const participations = new Map(rowsFor('participations').map((row) => [row.id, row]));
const periods = new Map(rowsFor('backtest_evaluation_periods').map((row) => [row.id, row]));
const runs = new Map(rowsForExternal('backtest', 'runs').map((row) => [row.id, row]));
for (const link of rowsFor('backtest_period_runs')) {
  const participation = participations.get(link.participation_id);
  const period = periods.get(link.evaluation_period_id);
  const run = runs.get(link.run_id);
  if (!participation || !period || !run) throw new Error('Records competition period run has a missing owner');
  if (run.bot_id !== participation.bot_id) throw new Error(`Records period run crosses Bot ownership: ${link.run_id}`);
  if (run.evaluation_start !== period.evaluation_start || run.evaluation_end !== period.evaluation_end) {
    throw new Error(`Records period run dates do not match evaluation period: ${link.run_id}`);
  }
}

const publicSchema = database.schemas.find((candidate) => candidate.name === 'public');
for (const ref of publicSchema?.refs ?? []) {
  const [child, parent] = ref.endpoints;
  if (child.relation !== '*' || parent.relation !== '1') continue;
  if (child.schemaName !== 'competition' && parent.schemaName !== 'competition') continue;
  const parentTable = database.schemas
    .find((candidate) => candidate.name === parent.schemaName)
    ?.tables.find((table) => table.name === parent.tableName);
  if (!parentTable) throw new Error(`broken reference target: ${parent.schemaName}.${parent.tableName}`);
  const targetColumns = parent.fieldNames.join(',');
  const targetIsUnique =
    (parent.fieldNames.length === 1 && parent.fields[0]?.unique) ||
    (parent.fieldNames.length === 1 && parent.fields[0]?.pk) ||
    parentTable.indexes.some((index) =>
      (index.unique || index.pk) &&
      index.columns.map((column) => String(column.value ?? column.name)).join(',') === targetColumns,
    );
  if (!targetIsUnique) {
    throw new Error(`reference target is not unique: ${parent.schemaName}.${parent.tableName}(${targetColumns})`);
  }
}

process.stdout.write(`${JSON.stringify({
  entry,
  competitionTableCount: tables.size,
  competitionRecordBlockCount: schema.tables.reduce((count, table) => count + table.records.length, 0),
  status: 'passed',
})}\n`);
