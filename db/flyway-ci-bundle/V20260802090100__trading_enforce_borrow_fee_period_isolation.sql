-- Enforce the borrow-fee period isolation the canonical model already documents.
--
-- db/schema.dbml, trading.short_borrow_fee_accruals:
--   '열린 가상 SHORT lot에 플랫폼 고정 연간 대차료를 기간별로 추가 전용 계산하고 공식 원장과
--    1:1 연결한다. ... PostgreSQL 마이그레이션은 같은 lot의 비용 기간이 겹치지 않도록
--    exclusion constraint를 둔다.'
--
-- The shipped bundle only has
--   CREATE UNIQUE INDEX ON "trading"."short_borrow_fee_accruals"
--       ("position_lot_id", "period_start", "period_end");
-- which blocks an exact duplicate period but not an overlapping one, so the same short lot can
-- still be billed twice for the same hours.
--
-- Mechanism note. The canonical note names an exclusion constraint. A real EXCLUDE over
-- (position_lot_id WITH =, tstzrange(period_start, period_end) WITH &&) needs btree_gist for the
-- uuid equality operator, and no CREATE EXTENSION exists anywhere in the bundle. Installing a
-- database-global extension is outside what a trading-owned contribution may decide, so this
-- migration enforces the same invariant with a deferred constraint trigger instead, matching the
-- style already used by the canonical partial-fill contribution. A transaction-scoped advisory
-- lock keyed on the lot makes the check race-free: two concurrent transactions inserting
-- overlapping periods for one lot serialise, so the second sees the first and fails, which a bare
-- trigger could not guarantee. If the team later accepts btree_gist, this can be replaced by a
-- true EXCLUDE constraint without changing the invariant.

CREATE OR REPLACE FUNCTION "trading"."assert_borrow_fee_period_isolation"(target_accrual_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    accrual_row "trading"."short_borrow_fee_accruals"%rowtype;
    conflicting_id uuid;
BEGIN
    SELECT * INTO accrual_row
      FROM "trading"."short_borrow_fee_accruals"
     WHERE "id" = target_accrual_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Serialise every isolation check for one lot, so a concurrent overlapping insert cannot slip
    -- past both checks. The lock is transaction scoped and released at commit.
    PERFORM pg_advisory_xact_lock(hashtextextended(accrual_row."position_lot_id"::text, 0));

    SELECT other."id" INTO conflicting_id
      FROM "trading"."short_borrow_fee_accruals" AS other
     WHERE other."position_lot_id" = accrual_row."position_lot_id"
       AND other."id" <> accrual_row."id"
       AND tstzrange(other."period_start", other."period_end", '[)')
           && tstzrange(accrual_row."period_start", accrual_row."period_end", '[)')
     LIMIT 1;

    IF conflicting_id IS NOT NULL THEN
        RAISE EXCEPTION
            'short borrow fee accrual % overlaps accrual % on lot % for period [%, %)',
            target_accrual_id, conflicting_id, accrual_row."position_lot_id",
            accrual_row."period_start", accrual_row."period_end";
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION "trading"."check_borrow_fee_accrual_trigger"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    PERFORM "trading"."assert_borrow_fee_period_isolation"(NEW."id");
    RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER "borrow_fee_period_isolation_deferred"
AFTER INSERT OR UPDATE ON "trading"."short_borrow_fee_accruals"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "trading"."check_borrow_fee_accrual_trigger"();
