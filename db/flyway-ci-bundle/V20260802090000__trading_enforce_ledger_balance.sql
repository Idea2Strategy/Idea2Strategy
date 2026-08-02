-- Enforce the double-entry invariant the canonical model already documents.
--
-- db/schema.dbml, trading.ledger_entries:
--   '추가 전용 차변·대변 분개. ... 지연 트리거가 Fill 없는 체결 분개, 파티션 불일치,
--    구성별 금액·수수료 합계 불일치와 불균형 분개를 커밋 시 차단한다.'
--
-- Of those four, only two are actually enforced by the shipped bundle:
--   - partition mismatch  -> the composite FK
--     ledger_entries (bot_id, partition_id, transaction_id)
--       -> ledger_transactions (bot_id, partition_id, id)
--   - per-component fee and amount totals -> not enforceable yet, because the canonical
--     account_type vocabulary that would identify a fee entry is not constrained anywhere.
--     Defining it here would be inventing product meaning, so it is deliberately left out.
--
-- The remaining two have no enforcement at all: the bundle contains no trigger on any ledger
-- table. This migration adds them, in the same deferred-constraint-trigger style the canonical
-- partial-fill contribution already uses, so an unbalanced posting can never commit.

CREATE OR REPLACE FUNCTION "trading"."assert_ledger_transaction_balanced"(target_transaction_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    entry_count integer;
    signed_total numeric(24,8);
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "trading"."ledger_transactions" WHERE "id" = target_transaction_id
    ) THEN
        RETURN;
    END IF;

    SELECT count(*),
           COALESCE(sum(CASE WHEN "direction" = 'DEBIT' THEN "amount" ELSE -"amount" END), 0)
      INTO entry_count, signed_total
      FROM "trading"."ledger_entries"
     WHERE "transaction_id" = target_transaction_id;

    -- A single-sided posting is not double-entry bookkeeping.
    IF entry_count < 2 THEN
        RAISE EXCEPTION 'ledger transaction % has % entries; double-entry requires at least two',
            target_transaction_id, entry_count;
    END IF;

    -- ledger_transactions.currency_code is a single header currency and ledger_entries carries no
    -- currency of its own, so one signed total over the transaction is the complete balance test.
    IF signed_total <> 0 THEN
        RAISE EXCEPTION 'ledger transaction % is unbalanced by %', target_transaction_id, signed_total;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION "trading"."assert_ledger_transaction_source"(target_transaction_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    transaction_row "trading"."ledger_transactions"%rowtype;
BEGIN
    SELECT * INTO transaction_row
      FROM "trading"."ledger_transactions"
     WHERE "id" = target_transaction_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- 'Fill 없는 체결 분개' blocked. Only the two source types the canonical note names verbatim
    -- are checked; this is a safety net over the documented vocabulary, not a new constraint on it,
    -- so an unrecognised source_type is left alone rather than rejected.
    IF transaction_row."source_type" = 'FILL'
       AND NOT EXISTS (
           SELECT 1 FROM "trading"."fills"
            WHERE "id" = transaction_row."source_id"
              AND "bot_id" = transaction_row."bot_id") THEN
        RAISE EXCEPTION 'ledger transaction % claims fill % which does not exist for this bot',
            target_transaction_id, transaction_row."source_id";
    END IF;

    IF transaction_row."source_type" = 'FILL_ADJUSTMENT'
       AND NOT EXISTS (
           SELECT 1 FROM "trading"."fill_adjustments"
            WHERE "id" = transaction_row."source_id"
              AND "bot_id" = transaction_row."bot_id") THEN
        RAISE EXCEPTION 'ledger transaction % claims fill adjustment % which does not exist for this bot',
            target_transaction_id, transaction_row."source_id";
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION "trading"."check_ledger_transaction_trigger"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM "trading"."assert_ledger_transaction_balanced"(OLD."id");
        RETURN OLD;
    END IF;
    PERFORM "trading"."assert_ledger_transaction_balanced"(NEW."id");
    PERFORM "trading"."assert_ledger_transaction_source"(NEW."id");
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION "trading"."check_ledger_entry_trigger"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM "trading"."assert_ledger_transaction_balanced"(OLD."transaction_id");
        RETURN OLD;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD."transaction_id" <> NEW."transaction_id" THEN
        PERFORM "trading"."assert_ledger_transaction_balanced"(OLD."transaction_id");
    END IF;
    PERFORM "trading"."assert_ledger_transaction_balanced"(NEW."transaction_id");
    RETURN NEW;
END;
$$;

-- Deferred so that a transaction header and its entries can be inserted in any order within one
-- unit of work, exactly like the partial-fill contribution's triggers.
CREATE CONSTRAINT TRIGGER "ledger_transaction_balanced_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."ledger_transactions"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "trading"."check_ledger_transaction_trigger"();

CREATE CONSTRAINT TRIGGER "ledger_entry_balanced_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."ledger_entries"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "trading"."check_ledger_entry_trigger"();
