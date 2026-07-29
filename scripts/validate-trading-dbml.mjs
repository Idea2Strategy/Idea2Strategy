import { readFile } from 'node:fs/promises';
import process from 'node:process';
import { Parser } from '@dbml/core';

const entry = process.argv[2] ?? 'proposals/dbml-redesign/schema.draft.dbml';
const source = await readFile(entry, 'utf8');
const database = Parser.parse(source, 'dbmlv2');

const tradingSchema = database.schemas.find((schema) => schema.name === 'trading');
if (!tradingSchema) throw new Error('trading schema is missing');

const tradingTables = new Map(tradingSchema.tables.map((table) => [table.name, table]));
const requiredTables = [
  'buying_power_buffer_policy_versions',
  'fee_policy_versions',
  'short_risk_policy_versions',
  'short_borrow_fee_policy_versions',
  'order_intent_batches',
  'order_intents',
  'orders',
  'order_components',
  'resource_reservations',
  'position_lot_reservations',
  'order_component_reservations',
  'reservation_events',
  'order_events',
  'order_state_projections',
  'fills',
  'fill_adjustments',
  'ledger_accounts',
  'ledger_transactions',
  'ledger_entries',
  'position_lots',
  'lot_movements',
  'position_lot_projections',
  'short_trade_checks',
  'system_close_actions',
  'short_borrow_fee_accruals',
  'flow_position_projections',
  'partition_position_projections',
  'bot_budget_projections',
  'partition_budget_projections',
];

for (const tableName of requiredTables) {
  if (!tradingTables.has(tableName)) throw new Error(`required trading table is missing: ${tableName}`);
}

const forbiddenPatterns = [
  /Table trading\.capital_reservations\s*\{/,
  /Table trading\.fill_allocations\s*\{/,
  /Table trading\.order_intent_allocations\s*\{/,
  /Table trading\.reservation_lot_allocations\s*\{/,
  /Table trading\.order_reservation_allocations\s*\{/,
  /\border_intent_allocation_id\b/,
  /\bopening_order_intent_allocation_id\b/,
  /\bsource_order_intent_allocation_id\b/,
  /\bfill_allocation_id\b/,
  /\bsource_fill_allocation_id\b/,
  /\bopening_fill_allocation_id\b/,
  /\bPARTIALLY_FILLED\b/,
  /\bPARTIALLY_CONSUMED\b/,
  /\bnetted_quantity\b/,
  /Table trading\.position_projections\s*\{/,
  /Table trading\.short_position_obligations\s*\{/,
  /Table trading\.short_obligation_events\s*\{/,
  /Table trading\.forced_liquidation_actions\s*\{/,
  /\bSHORT_BORROW_QUANTITY\b/,
  /\bSHORT_SALE_PROCEEDS\b/,
  /\bBORROW_RECALL\b/,
  /\bborrow_available_quantity\b/,
  /\bborrow_fee_rate_bps\b/,
];

for (const pattern of forbiddenPatterns) {
  if (pattern.test(source)) throw new Error(`obsolete trading structure remains: ${pattern}`);
}

const requireFields = (tableName, fieldNames) => {
  const table = tradingTables.get(tableName);
  const actual = new Set(table.fields.map((field) => field.name));
  for (const fieldName of fieldNames) {
    if (!actual.has(fieldName)) throw new Error(`${tableName}.${fieldName} is required`);
  }
};

requireFields('order_intent_batches', ['bot_id', 'partition_id', 'source_event_id']);
requireFields('orders', ['bot_id', 'partition_id', 'replaces_order_id', 'requested_quantity']);
requireFields('order_components', [
  'bot_id',
  'partition_id',
  'order_id',
  'intent_id',
  'component_quantity',
  'component_sequence',
  'composition_rules_version',
]);
requireFields('resource_reservations', [
  'bot_id',
  'partition_id',
  'reserved_amount',
  'fee_policy_id',
  'precision_rules_version',
  'consumed_amount',
  'released_amount',
  'reserved_quantity',
  'consumed_quantity',
  'released_quantity',
]);
requireFields('position_lot_reservations', [
  'bot_id',
  'partition_id',
  'flow_id',
  'reservation_id',
  'position_lot_id',
  'reserved_quantity',
]);
requireFields('order_component_reservations', [
  'bot_id',
  'partition_id',
  'reservation_id',
  'order_component_id',
]);
requireFields('reservation_events', ['bot_id', 'partition_id', 'source_fill_id', 'event_key']);
requireFields('order_events', ['bot_id', 'partition_id', 'order_id', 'order_sequence']);
requireFields('order_state_projections', ['bot_id', 'partition_id', 'order_id']);
requireFields('fills', ['bot_id', 'partition_id', 'order_id', 'provider_fill_key']);
requireFields('fill_adjustments', ['bot_id', 'partition_id', 'fill_id', 'adjustment_type']);
requireFields('ledger_transactions', ['bot_id', 'partition_id', 'source_type', 'source_id']);
requireFields('ledger_entries', ['bot_id', 'partition_id', 'order_component_id']);
requireFields('position_lots', ['bot_id', 'partition_id', 'flow_id', 'opening_order_component_id']);
requireFields('lot_movements', ['bot_id', 'partition_id', 'source_order_component_id']);
requireFields('short_trade_checks', [
  'intent_id',
  'short_risk_policy_id',
  'projected_short_quantity',
  'projected_exposure_amount',
  'required_initial_collateral_amount',
  'required_maintenance_collateral_amount',
  'rule_201_triggered',
  'prior_regular_close_price',
  'national_best_bid_price',
  'price_rule_market_hash',
  'approved',
]);
requireFields('system_close_actions', [
  'bot_id',
  'partition_id',
  'flow_id',
  'reason_type',
  'generated_intent_id',
]);
requireFields('short_borrow_fee_accruals', [
  'bot_id',
  'partition_id',
  'position_lot_id',
  'short_borrow_fee_policy_id',
  'ledger_transaction_id',
  'annual_fee_rate_bps',
  'accrued_fee_amount',
]);

const requiredFragments = [
  '"orderSizePercent":40',
  '"minReactivationIntervalSeconds":1800',
  'LAST_SUCCESSFUL_FILL_AT',
  'CANCELLED는 사용자·봇 중지·운영자 조작으로 만들 수 없고',
  '기존 미체결 주문을 취소하지 않은 채',
  "slippage_rate_bps = 5",
  "fee_rate_bps = 20",
  "status = 'ACTIVE' OR consumed_amount + released_amount = reserved_amount",
  "status = 'ACTIVE' OR consumed_quantity + released_quantity = reserved_quantity",
  "Ref: trading.order_intent_batches.(bot_id, partition_id) > bot.bot_partitions.(bot_id, id)",
  "Ref: trading.order_intents.(bot_id, partition_id, batch_id) > trading.order_intent_batches.(bot_id, partition_id, id)",
  "Ref: trading.orders.(bot_id, partition_id) > bot.bot_partitions.(bot_id, id)",
  "Ref: trading.order_components.(bot_id, partition_id, order_id) > trading.orders.(bot_id, partition_id, id)",
  "Ref: trading.order_components.(bot_id, partition_id, intent_id) > trading.order_intents.(bot_id, partition_id, id)",
  "Ref: trading.position_lot_reservations.(bot_id, partition_id, flow_id, reservation_id) > trading.resource_reservations.(bot_id, partition_id, flow_id, id)",
  "Ref: trading.position_lot_reservations.(bot_id, partition_id, flow_id, position_lot_id) > trading.position_lots.(bot_id, partition_id, flow_id, id)",
  "Ref: trading.order_component_reservations.(bot_id, partition_id, reservation_id) > trading.resource_reservations.(bot_id, partition_id, id)",
  "Ref: trading.order_component_reservations.(bot_id, partition_id, order_component_id) > trading.order_components.(bot_id, partition_id, id)",
  "Ref: trading.fills.(bot_id, partition_id, order_id) > trading.orders.(bot_id, partition_id, id)",
  "Ref: trading.ledger_entries.(bot_id, partition_id, order_component_id) > trading.order_components.(bot_id, partition_id, id)",
  "Ref: trading.position_lots.(bot_id, partition_id, opening_order_component_id) > trading.order_components.(bot_id, partition_id, id)",
  "Ref: trading.lot_movements.(bot_id, partition_id, source_order_component_id) > trading.order_components.(bot_id, partition_id, id)",
  "Ref: trading.partition_position_projections.(bot_id, partition_id) > bot.bot_partitions.(bot_id, id)",
  "Ref: trading.system_close_actions.(bot_id, partition_id, generated_intent_id) > trading.order_intents.(bot_id, partition_id, id)",
  "Ref: trading.short_borrow_fee_accruals.short_borrow_fee_policy_id > trading.short_borrow_fee_policy_versions.id",
  'segregated_short_proceeds_amount',
  'SEGREGATED_SHORT_PROCEEDS',
  'rule_201_triggered',
];

for (const fragment of requiredFragments) {
  if (!source.includes(fragment)) throw new Error(`required trading invariant is missing: ${fragment}`);
}

for (const table of tradingSchema.tables) {
  const seen = new Set();
  for (const index of table.indexes) {
    const columns = index.columns.map((column) => String(column.value ?? column.name)).join(',');
    const signature = `${columns}|unique=${Boolean(index.unique)}|pk=${Boolean(index.pk)}`;
    if (seen.has(signature)) throw new Error(`duplicate index in trading.${table.name}: ${signature}`);
    seen.add(signature);
  }
}

for (const enumDefinition of tradingSchema.enums) {
  const used = tradingSchema.tables.some((table) =>
    table.fields.some((field) => field._enum?.id === enumDefinition.id),
  );
  if (!used) throw new Error(`unused trading enum: ${enumDefinition.name}`);
}

const rowsFor = (tableName) => {
  const table = tradingTables.get(tableName);
  return table.records.flatMap((record) =>
    record.values.map((row) => Object.fromEntries(
      record.columns.map((column, index) => [column, row[index]?.value]),
    )),
  );
};

const nearlyEqual = (left, right) => Math.abs(Number(left) - Number(right)) < 1e-8;
const orderRows = new Map(rowsFor('orders').map((row) => [row.id, row]));
const componentRows = rowsFor('order_components');
for (const order of orderRows.values()) {
  if (Number.isInteger(Number(order.requested_quantity))) {
    throw new Error(`Records order quantity must demonstrate fractional-share execution: ${order.id}`);
  }
  const componentQuantity = componentRows
    .filter((row) => row.order_id === order.id)
    .reduce((sum, row) => sum + Number(row.component_quantity), 0);
  if (!nearlyEqual(componentQuantity, order.requested_quantity)) {
    throw new Error(`Records component sum does not match order quantity: ${order.id}`);
  }
}

const fillCountByOrder = new Map();
for (const fill of rowsFor('fills')) {
  const order = orderRows.get(fill.order_id);
  if (!order) throw new Error(`Records fill references missing order: ${fill.order_id}`);
  if (fill.bot_id !== order.bot_id || fill.partition_id !== order.partition_id) {
    throw new Error(`Records fill crosses order partition: ${fill.id}`);
  }
  if (!nearlyEqual(fill.quantity, order.requested_quantity)) {
    throw new Error(`Records fill quantity does not match order quantity: ${fill.id}`);
  }
  fillCountByOrder.set(fill.order_id, (fillCountByOrder.get(fill.order_id) ?? 0) + 1);
}
for (const [orderId, count] of fillCountByOrder) {
  if (count > 1) throw new Error(`Records contain multiple normal fills for order: ${orderId}`);
}

for (const reservation of rowsFor('resource_reservations')) {
  if (reservation.status === 'ACTIVE') continue;
  if (reservation.reserved_amount !== undefined && reservation.reserved_amount !== null) {
    if (!nearlyEqual(
      Number(reservation.consumed_amount ?? 0) + Number(reservation.released_amount ?? 0),
      reservation.reserved_amount,
    )) throw new Error(`Records amount reservation is not conserved: ${reservation.id}`);
  }
  if (reservation.reserved_quantity !== undefined && reservation.reserved_quantity !== null) {
    if (!nearlyEqual(
      Number(reservation.consumed_quantity ?? 0) + Number(reservation.released_quantity ?? 0),
      reservation.reserved_quantity,
    )) throw new Error(`Records quantity reservation is not conserved: ${reservation.id}`);
  }
}

for (const table of tradingSchema.tables) {
  const fields = new Map(table.fields.map((field) => [field.name, field]));
  for (const record of table.records) {
    if (new Set(record.columns).size !== record.columns.length) {
      throw new Error(`duplicate Records column in trading.${table.name}`);
    }
    for (const column of record.columns) {
      if (!fields.has(column)) throw new Error(`unknown Records column trading.${table.name}.${column}`);
    }
    for (const row of record.values) {
      if (row.length !== record.columns.length) throw new Error(`Records arity mismatch in trading.${table.name}`);
      const values = new Map(record.columns.map((column, index) => [column, row[index]?.value]));
      for (const field of table.fields) {
        if (field.not_null && !field.dbdefault && !field.increment && !values.has(field.name)) {
          throw new Error(`Records row omits required field trading.${table.name}.${field.name}`);
        }
        if (field._enum && values.has(field.name) && values.get(field.name) !== null) {
          const allowed = new Set(field._enum.values.map((value) => value.name));
          if (!allowed.has(values.get(field.name))) {
            throw new Error(`invalid enum Records value trading.${table.name}.${field.name}=${values.get(field.name)}`);
          }
        }
      }
    }
  }
}

const publicSchema = database.schemas.find((schema) => schema.name === 'public');
for (const ref of publicSchema?.refs ?? []) {
  const [child, parent] = ref.endpoints;
  if (child.relation !== '*' || parent.relation !== '1') continue;
  if (child.schemaName !== 'trading' && parent.schemaName !== 'trading') continue;
  const parentTable = database.schemas
    .find((schema) => schema.name === parent.schemaName)
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
  tradingTableCount: tradingTables.size,
  tradingRecordCount: tradingSchema.tables.reduce((count, table) => count + table.records.length, 0),
  status: 'passed',
})}\n`);
