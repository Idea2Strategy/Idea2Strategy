-- The preceding Flyway version commits CONSUMED_BY_FILL before this migration
-- uses the value in PostgreSQL check constraints.

-- The V1 schema did not persist per-component fill economics, so an existing
-- fill cannot be backfilled into authoritative allocations without inventing
-- quantities, fees or signed cash. Fail explicitly instead of losing provenance
-- or reaching an opaque NOT NULL failure later in the migration.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM "trading"."fills")
       OR EXISTS (SELECT 1 FROM "trading"."position_lots")
       OR EXISTS (SELECT 1 FROM "trading"."lot_movements") THEN
        RAISE EXCEPTION USING
            ERRCODE = '55000',
            MESSAGE = 'partial-fill allocation migration requires empty trading fills/lots',
            DETAIL = 'V1 did not preserve authoritative per-component fill economics, so existing rows cannot be deterministically backfilled.',
            HINT = 'Migrate before accepting trading traffic, or supply a separately reviewed provenance backfill migration.';
    END IF;
END $$;

CREATE UNIQUE INDEX ON "trading"."order_components"
    ("bot_id", "partition_id", "order_id", "id");

ALTER TABLE "trading"."resource_reservations"
    DROP CONSTRAINT "active_reservation_unsettled",
    ADD CONSTRAINT "active_reservation_not_released"
        CHECK (status <> 'ACTIVE' OR (released_amount = 0 AND released_quantity = 0));

ALTER TABLE "trading"."reservation_events"
    DROP CONSTRAINT "fill_settlement_source_required",
    DROP CONSTRAINT "non_fill_reservation_event_has_no_fill",
    DROP CONSTRAINT "fill_settlement_status_valid",
    DROP CONSTRAINT "release_event_status_valid",
    ADD CONSTRAINT "fill_consumption_source_required"
        CHECK (event_type NOT IN ('CONSUMED_BY_FILL', 'SETTLED_BY_FILL') OR source_fill_id IS NOT NULL),
    ADD CONSTRAINT "non_fill_reservation_event_has_no_fill"
        CHECK (event_type IN ('CONSUMED_BY_FILL', 'SETTLED_BY_FILL') OR source_fill_id IS NULL),
    ADD CONSTRAINT "partial_fill_consumption_stays_active"
        CHECK (event_type <> 'CONSUMED_BY_FILL' OR status_after = 'ACTIVE'),
    ADD CONSTRAINT "fill_settlement_status_valid"
        CHECK (event_type <> 'SETTLED_BY_FILL' OR status_after = 'SETTLED'),
    ADD CONSTRAINT "release_event_status_valid"
        CHECK (
            event_type NOT IN (
                'RELEASED_BY_CANCEL', 'RELEASED_BY_EXPIRY',
                'RELEASED_BY_REJECTION', 'RELEASED_BY_REPLACEMENT'
            ) OR status_after IN ('RELEASED', 'SETTLED')
        );

ALTER TABLE "trading"."order_state_projections"
    DROP CONSTRAINT "nonfilled_terminal_projection_has_no_fill",
    DROP CONSTRAINT "active_projection_has_no_partial_fill",
    ADD CONSTRAINT "rejected_projection_has_no_fill"
        CHECK (status <> 'REJECTED' OR (filled_quantity = 0 AND remaining_quantity = 0)),
    ADD CONSTRAINT "closed_projection_has_no_active_remainder"
        CHECK (status NOT IN ('CANCELLED', 'EXPIRED') OR remaining_quantity = 0),
    ADD CONSTRAINT "pending_projection_has_no_fill"
        CHECK (status <> 'PENDING' OR (filled_quantity = 0 AND remaining_quantity > 0)),
    ADD CONSTRAINT "open_projection_has_remaining_quantity"
        CHECK (status <> 'OPEN' OR remaining_quantity > 0);

DROP INDEX "trading"."fills_order_id_idx";

CREATE UNIQUE INDEX ON "trading"."fills"
    ("bot_id", "partition_id", "order_id", "id");
CREATE INDEX ON "trading"."fills"
    ("order_id", "occurred_at", "id");

CREATE TABLE "trading"."fill_component_allocations" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "bot_id" uuid NOT NULL,
    "partition_id" uuid NOT NULL,
    "order_id" uuid NOT NULL,
    "fill_id" uuid NOT NULL,
    "order_component_id" uuid NOT NULL,
    "allocation_sequence" int NOT NULL,
    "allocated_quantity" numeric(28,8) NOT NULL,
    "allocated_gross_amount" numeric(24,8) NOT NULL,
    "allocated_fee_amount" numeric(24,8) NOT NULL,
    "allocated_settlement_cash_delta" numeric(24,8) NOT NULL,
    "allocation_rules_version" varchar(40) NOT NULL,
    "created_at" timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT "fill_allocation_sequence_positive" CHECK (allocation_sequence > 0),
    CONSTRAINT "fill_allocation_quantity_positive" CHECK (allocated_quantity > 0),
    CONSTRAINT "fill_allocation_gross_positive" CHECK (allocated_gross_amount > 0),
    CONSTRAINT "fill_allocation_fee_nonnegative" CHECK (allocated_fee_amount >= 0),
    CONSTRAINT "fill_allocation_cash_delta_nonzero" CHECK (allocated_settlement_cash_delta <> 0)
);

CREATE UNIQUE INDEX ON "trading"."fill_component_allocations" ("bot_id", "partition_id", "id");
CREATE UNIQUE INDEX ON "trading"."fill_component_allocations"
    ("bot_id", "partition_id", "order_id", "fill_id", "id");
CREATE UNIQUE INDEX ON "trading"."fill_component_allocations"
    ("bot_id", "partition_id", "order_id", "order_component_id", "id");
CREATE UNIQUE INDEX ON "trading"."fill_component_allocations"
    ("bot_id", "partition_id", "order_component_id", "id");
CREATE UNIQUE INDEX ON "trading"."fill_component_allocations" ("fill_id", "order_component_id");
CREATE UNIQUE INDEX ON "trading"."fill_component_allocations" ("fill_id", "allocation_sequence");
CREATE INDEX ON "trading"."fill_component_allocations" ("order_component_id", "fill_id");

ALTER TABLE "trading"."fill_component_allocations"
    ADD CONSTRAINT "fill_allocation_fill_fk"
        FOREIGN KEY ("bot_id", "partition_id", "order_id", "fill_id")
        REFERENCES "trading"."fills" ("bot_id", "partition_id", "order_id", "id")
        DEFERRABLE INITIALLY IMMEDIATE,
    ADD CONSTRAINT "fill_allocation_component_fk"
        FOREIGN KEY ("bot_id", "partition_id", "order_id", "order_component_id")
        REFERENCES "trading"."order_components" ("bot_id", "partition_id", "order_id", "id")
        DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lots"
    DROP CONSTRAINT "position_lots_opening_order_component_id_key",
    ADD COLUMN "opening_fill_allocation_id" uuid;
ALTER TABLE "trading"."position_lots"
    ALTER COLUMN "opening_fill_allocation_id" SET NOT NULL;

CREATE UNIQUE INDEX ON "trading"."position_lots" ("opening_fill_allocation_id");
CREATE UNIQUE INDEX ON "trading"."position_lots"
    ("bot_id", "partition_id", "opening_order_component_id", "opening_fill_allocation_id");
CREATE INDEX ON "trading"."position_lots" ("opening_order_component_id", "opened_at", "id");

ALTER TABLE "trading"."position_lots"
    ADD CONSTRAINT "position_lot_opening_allocation_fk"
        FOREIGN KEY ("bot_id", "partition_id", "opening_order_component_id", "opening_fill_allocation_id")
        REFERENCES "trading"."fill_component_allocations"
            ("bot_id", "partition_id", "order_component_id", "id")
        DEFERRABLE INITIALLY IMMEDIATE;

DO $$
DECLARE
    target_constraint name;
BEGIN
    SELECT constraint_row.conname
      INTO target_constraint
      FROM pg_constraint constraint_row
      JOIN pg_attribute column_row
        ON column_row.attrelid = constraint_row.conrelid
       AND column_row.attnum = ANY (constraint_row.conkey)
     WHERE constraint_row.conrelid = 'trading.lot_movements'::regclass
       AND constraint_row.contype = 'f'
       AND column_row.attname = 'source_order_component_id'
     LIMIT 1;
    IF target_constraint IS NOT NULL THEN
        EXECUTE format('ALTER TABLE trading.lot_movements DROP CONSTRAINT %I', target_constraint);
    END IF;
END $$;

ALTER TABLE "trading"."lot_movements"
    RENAME COLUMN "source_order_component_id" TO "source_fill_allocation_id";
DROP INDEX "trading"."lot_movements_source_order_component_id_position_lot_id_idx";
CREATE INDEX ON "trading"."lot_movements" ("source_fill_allocation_id", "position_lot_id");

ALTER TABLE "trading"."lot_movements"
    ADD CONSTRAINT "lot_movement_fill_allocation_fk"
        FOREIGN KEY ("bot_id", "partition_id", "source_fill_allocation_id")
        REFERENCES "trading"."fill_component_allocations" ("bot_id", "partition_id", "id")
        DEFERRABLE INITIALLY IMMEDIATE;

CREATE OR REPLACE FUNCTION "trading"."assert_fill_allocation_totals"(target_fill_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    fill_row "trading"."fills"%ROWTYPE;
    quantity_total numeric(28,8);
    gross_total numeric(24,8);
    fee_total numeric(24,8);
    cash_total numeric(24,8);
BEGIN
    SELECT * INTO fill_row FROM "trading"."fills" WHERE id = target_fill_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(sum(allocated_quantity), 0),
           COALESCE(sum(allocated_gross_amount), 0),
           COALESCE(sum(allocated_fee_amount), 0),
           COALESCE(sum(allocated_settlement_cash_delta), 0)
      INTO quantity_total, gross_total, fee_total, cash_total
      FROM "trading"."fill_component_allocations"
     WHERE fill_id = target_fill_id;

    IF quantity_total <> fill_row.quantity
       OR gross_total <> fill_row.gross_amount
       OR fee_total <> fill_row.fee_amount
       OR cash_total <> fill_row.settlement_cash_delta THEN
        RAISE EXCEPTION 'fill % allocation totals do not match fill economics', target_fill_id;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION "trading"."assert_component_allocation_capacity"(target_component_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    requested numeric(28,8);
    allocated numeric(28,8);
BEGIN
    SELECT component_quantity INTO requested
      FROM "trading"."order_components" WHERE id = target_component_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(sum(allocation.allocated_quantity), 0)
      INTO allocated
      FROM "trading"."fill_component_allocations" allocation
     WHERE allocation.order_component_id = target_component_id
       AND NOT EXISTS (
           SELECT 1 FROM "trading"."fill_adjustments" adjustment
            WHERE adjustment.fill_id = allocation.fill_id
              AND adjustment.adjustment_type = 'REVERSAL'
       );
    IF allocated > requested THEN
        RAISE EXCEPTION 'component % effective allocation % exceeds component quantity %',
            target_component_id, allocated, requested;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION "trading"."assert_order_fill_state"(target_order_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    requested numeric(28,8);
    effective_filled numeric(28,8);
    projection "trading"."order_state_projections"%ROWTYPE;
BEGIN
    SELECT requested_quantity INTO requested FROM "trading"."orders" WHERE id = target_order_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(sum(fill.quantity), 0)
           + COALESCE((
               SELECT sum(adjustment.quantity_delta)
                 FROM "trading"."fill_adjustments" adjustment
                 JOIN "trading"."fills" adjusted_fill ON adjusted_fill.id = adjustment.fill_id
                WHERE adjusted_fill.order_id = target_order_id
           ), 0)
      INTO effective_filled
      FROM "trading"."fills" fill
     WHERE fill.order_id = target_order_id;

    IF effective_filled < 0 OR effective_filled > requested THEN
        RAISE EXCEPTION 'order % effective fill quantity % is outside [0,%]',
            target_order_id, effective_filled, requested;
    END IF;

    SELECT * INTO projection
      FROM "trading"."order_state_projections" WHERE order_id = target_order_id;
    IF FOUND THEN
        IF projection.filled_quantity <> effective_filled THEN
            RAISE EXCEPTION 'order % projection filled quantity does not match effective fills', target_order_id;
        END IF;
        IF projection.status IN ('PENDING', 'OPEN')
           AND projection.remaining_quantity <> requested - effective_filled THEN
            RAISE EXCEPTION 'order % active remaining quantity does not match effective fills', target_order_id;
        END IF;
        IF projection.status = 'FILLED' AND effective_filled <> requested THEN
            RAISE EXCEPTION 'order % is FILLED before requested quantity is reached', target_order_id;
        END IF;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION "trading"."assert_fill_adjustment"(target_adjustment_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    adjustment "trading"."fill_adjustments"%ROWTYPE;
    original "trading"."fills"%ROWTYPE;
BEGIN
    SELECT * INTO adjustment FROM "trading"."fill_adjustments" WHERE id = target_adjustment_id;
    IF NOT FOUND OR adjustment.adjustment_type <> 'REVERSAL' THEN
        RETURN;
    END IF;
    SELECT * INTO original FROM "trading"."fills" WHERE id = adjustment.fill_id;
    IF adjustment.quantity_delta <> -original.quantity
       OR adjustment.gross_amount_delta <> -original.gross_amount
       OR adjustment.fee_amount_delta <> -original.fee_amount
       OR adjustment.settlement_cash_delta <> -original.settlement_cash_delta THEN
        RAISE EXCEPTION 'fill reversal % must exactly negate fill %', adjustment.id, original.id;
    END IF;
END $$;

CREATE UNIQUE INDEX "one_reversal_per_fill"
    ON "trading"."fill_adjustments" ("fill_id")
    WHERE "adjustment_type" = 'REVERSAL';

CREATE OR REPLACE FUNCTION "trading"."assert_reservation_event_totals"(target_reservation_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    reservation "trading"."resource_reservations"%ROWTYPE;
    event_count bigint;
    max_sequence bigint;
    consumed_amount_total numeric(24,8);
    released_amount_total numeric(24,8);
    consumed_quantity_total numeric(28,8);
    released_quantity_total numeric(28,8);
    latest_status "trading"."reservation_status";
BEGIN
    SELECT * INTO reservation
      FROM "trading"."resource_reservations" WHERE id = target_reservation_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT count(*), COALESCE(max(reservation_sequence), 0),
           COALESCE(sum(consumed_amount_delta), 0), COALESCE(sum(released_amount_delta), 0),
           COALESCE(sum(consumed_quantity_delta), 0), COALESCE(sum(released_quantity_delta), 0)
      INTO event_count, max_sequence, consumed_amount_total, released_amount_total,
           consumed_quantity_total, released_quantity_total
      FROM "trading"."reservation_events" WHERE reservation_id = target_reservation_id;

    IF event_count = 0 OR event_count <> max_sequence OR reservation.last_event_sequence <> max_sequence THEN
        RAISE EXCEPTION 'reservation % event sequence is incomplete', target_reservation_id;
    END IF;
    IF consumed_amount_total <> reservation.consumed_amount
       OR released_amount_total <> reservation.released_amount
       OR consumed_quantity_total <> reservation.consumed_quantity
       OR released_quantity_total <> reservation.released_quantity THEN
        RAISE EXCEPTION 'reservation % event totals do not match projection', target_reservation_id;
    END IF;
    SELECT status_after INTO latest_status
      FROM "trading"."reservation_events"
     WHERE reservation_id = target_reservation_id
     ORDER BY reservation_sequence DESC
     LIMIT 1;
    IF latest_status <> reservation.status THEN
        RAISE EXCEPTION 'reservation % status does not match its latest event', target_reservation_id;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION "trading"."assert_fill_reservation_consumption"(target_event_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    reservation_event "trading"."reservation_events"%ROWTYPE;
    reservation "trading"."resource_reservations"%ROWTYPE;
    allocation_record "trading"."fill_component_allocations"%ROWTYPE;
BEGIN
    SELECT * INTO reservation_event FROM "trading"."reservation_events" WHERE id = target_event_id;
    IF NOT FOUND OR reservation_event.event_type NOT IN ('CONSUMED_BY_FILL', 'SETTLED_BY_FILL') THEN
        RETURN;
    END IF;
    SELECT * INTO reservation FROM "trading"."resource_reservations"
     WHERE id = reservation_event.reservation_id;
    SELECT fill_allocation.* INTO allocation_record
      FROM "trading"."order_component_reservations" link
      JOIN "trading"."fill_component_allocations" fill_allocation
        ON fill_allocation.order_component_id = link.order_component_id
       AND fill_allocation.fill_id = reservation_event.source_fill_id
     WHERE link.reservation_id = reservation_event.reservation_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'reservation fill event % has no matching component allocation', target_event_id;
    END IF;

    IF reservation.resource_type = 'CASH_BUYING_POWER'
       AND COALESCE(reservation_event.consumed_amount_delta, 0)
           <> abs(allocation_record.allocated_settlement_cash_delta) THEN
        RAISE EXCEPTION 'cash reservation event % consumption does not match fill allocation', target_event_id;
    END IF;
    IF reservation.resource_type = 'POSITION_QUANTITY'
       AND COALESCE(reservation_event.consumed_quantity_delta, 0) <> allocation_record.allocated_quantity THEN
        RAISE EXCEPTION 'position reservation event % consumption does not match fill allocation', target_event_id;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION "trading"."assert_position_lot_provenance"(target_lot_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    lot "trading"."position_lots"%ROWTYPE;
    allocation "trading"."fill_component_allocations"%ROWTYPE;
    intent "trading"."order_intents"%ROWTYPE;
BEGIN
    SELECT * INTO lot FROM "trading"."position_lots" WHERE id = target_lot_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;
    SELECT * INTO allocation FROM "trading"."fill_component_allocations"
     WHERE id = lot.opening_fill_allocation_id;
    SELECT intent_row.* INTO intent
      FROM "trading"."order_components" component
      JOIN "trading"."order_intents" intent_row ON intent_row.id = component.intent_id
     WHERE component.id = lot.opening_order_component_id;

    IF allocation.order_component_id <> lot.opening_order_component_id
       OR allocation.allocated_quantity <> lot.opened_quantity
       OR intent.bot_id <> lot.bot_id
       OR intent.partition_id <> lot.partition_id
       OR intent.flow_id <> lot.flow_id
       OR intent.instrument_id <> lot.instrument_id
       OR (lot.lot_side = 'LONG' AND intent.position_effect <> 'OPEN_LONG')
       OR (lot.lot_side = 'SHORT' AND intent.position_effect <> 'OPEN_SHORT') THEN
        RAISE EXCEPTION 'position lot % provenance does not match its fill allocation', target_lot_id;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION "trading"."assert_lot_movement_provenance"(target_movement_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    movement "trading"."lot_movements"%ROWTYPE;
    lot "trading"."position_lots"%ROWTYPE;
    allocation "trading"."fill_component_allocations"%ROWTYPE;
    intent "trading"."order_intents"%ROWTYPE;
BEGIN
    SELECT * INTO movement FROM "trading"."lot_movements" WHERE id = target_movement_id;
    IF NOT FOUND OR movement.movement_type NOT IN ('OPEN', 'CLOSE') THEN
        RETURN;
    END IF;
    SELECT * INTO lot FROM "trading"."position_lots" WHERE id = movement.position_lot_id;
    SELECT * INTO allocation FROM "trading"."fill_component_allocations"
     WHERE id = movement.source_fill_allocation_id;
    SELECT intent_row.* INTO intent
      FROM "trading"."order_components" component
      JOIN "trading"."order_intents" intent_row ON intent_row.id = component.intent_id
     WHERE component.id = allocation.order_component_id;

    IF allocation.bot_id <> lot.bot_id OR allocation.partition_id <> lot.partition_id
       OR intent.flow_id <> lot.flow_id OR intent.instrument_id <> lot.instrument_id THEN
        RAISE EXCEPTION 'lot movement % allocation is outside the lot scope', target_movement_id;
    END IF;
    IF movement.movement_type = 'OPEN'
       AND (movement.source_fill_allocation_id <> lot.opening_fill_allocation_id
            OR movement.quantity_delta <> lot.opened_quantity
            OR movement.quantity_delta <> allocation.allocated_quantity) THEN
        RAISE EXCEPTION 'opening movement % must use the lot opening allocation', target_movement_id;
    END IF;
    IF movement.movement_type = 'CLOSE'
       AND (movement.quantity_delta >= 0
            OR (lot.lot_side = 'LONG' AND intent.position_effect <> 'CLOSE_LONG')
            OR (lot.lot_side = 'SHORT' AND intent.position_effect <> 'CLOSE_SHORT')) THEN
        RAISE EXCEPTION 'closing movement % has incompatible fill allocation', target_movement_id;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION "trading"."check_fill_allocation_trigger"()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_fill_allocation_totals"(OLD.fill_id);
        PERFORM "trading"."assert_component_allocation_capacity"(OLD.order_component_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_fill_allocation_totals"(NEW.fill_id);
        PERFORM "trading"."assert_component_allocation_capacity"(NEW.order_component_id);
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION "trading"."assert_close_allocation_capacity"(target_allocation_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    allocation_capacity numeric(28,8);
    moved_quantity numeric(28,8);
BEGIN
    SELECT fill_allocation.allocated_quantity INTO allocation_capacity
      FROM "trading"."fill_component_allocations" fill_allocation
     WHERE fill_allocation.id = target_allocation_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;
    SELECT COALESCE(sum(abs(quantity_delta)), 0) INTO moved_quantity
      FROM "trading"."lot_movements"
     WHERE source_fill_allocation_id = target_allocation_id
       AND movement_type = 'CLOSE';
    IF moved_quantity > allocation_capacity THEN
        RAISE EXCEPTION 'closing allocation % movement quantity % exceeds allocation quantity %',
            target_allocation_id, moved_quantity, allocation_capacity;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION "trading"."check_fill_trigger"()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_fill_allocation_totals"(OLD.id);
        PERFORM "trading"."assert_order_fill_state"(OLD.order_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_fill_allocation_totals"(NEW.id);
        PERFORM "trading"."assert_order_fill_state"(NEW.order_id);
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION "trading"."check_fill_adjustment_trigger"()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    target_fill uuid;
    target_order uuid;
    target_component uuid;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        target_fill := OLD.fill_id;
        SELECT order_id INTO target_order FROM "trading"."fills" WHERE id = target_fill;
        PERFORM "trading"."assert_order_fill_state"(target_order);
        FOR target_component IN
            SELECT DISTINCT order_component_id
              FROM "trading"."fill_component_allocations" WHERE fill_id = target_fill
        LOOP
            PERFORM "trading"."assert_component_allocation_capacity"(target_component);
        END LOOP;
    END IF;
    IF TG_OP <> 'DELETE' THEN
        target_fill := NEW.fill_id;
        PERFORM "trading"."assert_fill_adjustment"(NEW.id);
        SELECT order_id INTO target_order FROM "trading"."fills" WHERE id = target_fill;
        PERFORM "trading"."assert_order_fill_state"(target_order);
        FOR target_component IN
            SELECT DISTINCT order_component_id
              FROM "trading"."fill_component_allocations" WHERE fill_id = target_fill
        LOOP
            PERFORM "trading"."assert_component_allocation_capacity"(target_component);
        END LOOP;
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION "trading"."check_order_projection_trigger"()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_order_fill_state"(OLD.order_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_order_fill_state"(NEW.order_id);
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION "trading"."check_reservation_trigger"()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_reservation_event_totals"(OLD.id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_reservation_event_totals"(NEW.id);
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION "trading"."check_reservation_event_trigger"()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_reservation_event_totals"(OLD.reservation_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_fill_reservation_consumption"(NEW.id);
        PERFORM "trading"."assert_reservation_event_totals"(NEW.reservation_id);
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION "trading"."check_position_lot_trigger"()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_position_lot_provenance"(NEW.id);
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION "trading"."check_lot_movement_trigger"()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' AND OLD.source_fill_allocation_id IS NOT NULL THEN
        PERFORM "trading"."assert_close_allocation_capacity"(OLD.source_fill_allocation_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_lot_movement_provenance"(NEW.id);
        IF NEW.source_fill_allocation_id IS NOT NULL THEN
            PERFORM "trading"."assert_close_allocation_capacity"(NEW.source_fill_allocation_id);
        END IF;
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER "fill_allocation_totals_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."fill_component_allocations"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION "trading"."check_fill_allocation_trigger"();

CREATE CONSTRAINT TRIGGER "fill_totals_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."fills"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION "trading"."check_fill_trigger"();

CREATE CONSTRAINT TRIGGER "fill_adjustments_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."fill_adjustments"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION "trading"."check_fill_adjustment_trigger"();

CREATE CONSTRAINT TRIGGER "order_fill_projection_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."order_state_projections"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION "trading"."check_order_projection_trigger"();

CREATE CONSTRAINT TRIGGER "reservation_projection_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."resource_reservations"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION "trading"."check_reservation_trigger"();

CREATE CONSTRAINT TRIGGER "reservation_events_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."reservation_events"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION "trading"."check_reservation_event_trigger"();

CREATE CONSTRAINT TRIGGER "position_lot_provenance_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."position_lots"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION "trading"."check_position_lot_trigger"();

CREATE CONSTRAINT TRIGGER "lot_movement_provenance_deferred"
AFTER INSERT OR UPDATE OR DELETE ON "trading"."lot_movements"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION "trading"."check_lot_movement_trigger"();

COMMENT ON TABLE "trading"."fill_component_allocations" IS
    'Append-only deterministic attribution of each individual fill to its order components. Deferred constraints enforce exact quantity, gross, fee and signed cash totals.';
COMMENT ON TABLE "trading"."fills" IS
    'Append-only individual fills. Multiple partial fills are allowed per order and deferred constraints enforce effective cumulative quantity.';
COMMENT ON TABLE "trading"."position_lots" IS
    'Each immutable FIFO lot originates from one exact fill-component allocation.';
COMMENT ON TABLE "trading"."lot_movements" IS
    'OPEN and CLOSE movements prove their scope through an exact fill-component allocation.';
