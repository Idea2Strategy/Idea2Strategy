import { readFile } from 'node:fs/promises';
import process from 'node:process';
import { Parser } from '@dbml/core';

const entry = process.argv[2] ?? 'proposals/dbml-redesign/schema.draft.dbml';
const source = await readFile(entry, 'utf8');
const database = Parser.parse(source, 'dbmlv2');

const tradingSchema = database.schemas.find((schema) => schema.name === 'trading');
if (!tradingSchema) throw new Error('trading schema is missing');

const tableNames = new Set(tradingSchema.tables.map((table) => table.name));
const requiredTables = [
  'resource_reservations',
  'reservation_lot_allocations',
  'order_reservation_allocations',
  'reservation_events',
  'order_group_members',
  'order_group_events',
  'fill_allocations',
  'ledger_accounts',
  'ledger_transactions',
  'ledger_entries',
  'position_lots',
  'lot_movements',
  'position_lot_projections',
  'short_trade_checks',
  'short_position_obligations',
  'short_obligation_events',
  'short_borrow_fee_accruals',
  'forced_liquidation_actions',
];

for (const table of requiredTables) {
  if (!tableNames.has(table)) throw new Error(`required trading table is missing: ${table}`);
}

const forbiddenPatterns = [
  /Table trading\.capital_reservations\s*\{/,
  /\bnetted_quantity\b/,
  /\borders\.order_group_id\b/,
  /\bopening_fill_id\b/,
  /\bsource_fill_id\b/,
  /Ref: trading\.fill_allocations\.intent_id/,
  /Ref: trading\.fill_allocations\.reservation_id/,
];

for (const pattern of forbiddenPatterns) {
  if (pattern.test(source)) throw new Error(`obsolete trading structure remains: ${pattern}`);
}

const requiredFragments = [
  "post_netting_quantity numeric(28,8)",
  "origin_type trading.intent_origin_type",
  "slippage_rate_bps = 5",
  "fee_rate_bps = 20",
  "settlement_cash_delta numeric(24,8)",
  "opening_fill_allocation_id uuid",
  "lot_side trading.lot_side",
  "account_key varchar(240)",
  "source_type varchar(40)",
  "source_id uuid",
  "Ref: trading.reservation_events.(bot_id, source_fill_allocation_id) > trading.fill_allocations.(bot_id, id)",
  "Ref: trading.position_lots.(bot_id, opening_fill_allocation_id) > trading.fill_allocations.(bot_id, id)",
  "Ref: trading.order_intent_allocations.(bot_id, order_id) > trading.orders.(bot_id, id)",
  "Ref: trading.order_intent_allocations.(bot_id, intent_id) > trading.order_intents.(bot_id, id)",
  "Ref: trading.fill_allocations.(bot_id, fill_id) > trading.fills.(bot_id, id)",
  "Ref: trading.ledger_entries.(bot_id, transaction_id) > trading.ledger_transactions.(bot_id, id)",
  "Ref: trading.ledger_entries.(bot_id, ledger_account_id) > trading.ledger_accounts.(bot_id, id)",
  "Ref: trading.partition_budget_projections.(bot_id, partition_id) > bot.bot_partitions.(bot_id, id)",
];

for (const fragment of requiredFragments) {
  if (!source.includes(fragment)) throw new Error(`required trading invariant is missing: ${fragment}`);
}

process.stdout.write(`${JSON.stringify({ entry, tradingTableCount: tableNames.size, status: 'passed' })}\n`);
