ALTER TYPE competition.participation_status ADD VALUE IF NOT EXISTS 'PENDING_LEDGER';

ALTER TABLE operations.outbox_messages
    ALTER COLUMN event_schema_version TYPE varchar(80);

-- E owns the segment identity and schedule before F can append the official opening bot event.
-- The pair is therefore empty only during PENDING_LEDGER and is completed from F's success fact.
ALTER TABLE competition.live_evaluation_segments
    ALTER COLUMN start_event_sequence DROP NOT NULL,
    ALTER COLUMN initial_state_hash DROP NOT NULL;

CREATE TABLE competition.room_evaluation_account_results (
    request_message_id uuid PRIMARY KEY,
    result_message_id uuid UNIQUE NOT NULL,
    participation_id uuid NOT NULL,
    bot_id uuid NOT NULL,
    evaluation_segment_id uuid NOT NULL,
    result_type varchar(20) NOT NULL,
    producer_idempotency_key varchar(160) NOT NULL,
    request_payload_hash varchar(128) NOT NULL,
    result_payload_hash varchar(128) NOT NULL,
    payload_document jsonb NOT NULL,
    received_at timestamptz NOT NULL,
    applied_at timestamptz,
    failure_code varchar(80),
    CONSTRAINT room_evaluation_account_result_participation_fk
        FOREIGN KEY (participation_id) REFERENCES competition.participations(id)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT room_evaluation_account_result_type_check
        CHECK (result_type IN ('OPENED', 'REJECTED')),
    CONSTRAINT room_evaluation_account_result_application_check
        CHECK ((result_type = 'OPENED' AND failure_code IS NULL)
            OR (result_type = 'REJECTED' AND failure_code IS NOT NULL))
);

CREATE INDEX room_evaluation_account_result_pending_idx
    ON competition.room_evaluation_account_results (participation_id, received_at)
    WHERE applied_at IS NULL;

CREATE FUNCTION competition.validate_room_ledger_handoff() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    participant_status competition.participation_status;
BEGIN
    SELECT status INTO participant_status
    FROM competition.participations WHERE id = NEW.participation_id;

    IF (NEW.start_event_sequence IS NULL) <> (NEW.initial_state_hash IS NULL) THEN
        RAISE EXCEPTION 'room evaluation segment ledger evidence must be set as a pair'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.start_event_sequence IS NULL AND participant_status <> 'PENDING_LEDGER' THEN
        RAISE EXCEPTION 'room evaluation segment may lack ledger evidence only while PENDING_LEDGER'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.start_event_sequence IS NOT NULL AND NEW.start_event_sequence <= 0 THEN
        RAISE EXCEPTION 'room evaluation start event sequence must be positive'
            USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'UPDATE'
       AND OLD.start_event_sequence IS NOT NULL
       AND (NEW.start_event_sequence, NEW.initial_state_hash)
           IS DISTINCT FROM (OLD.start_event_sequence, OLD.initial_state_hash) THEN
        RAISE EXCEPTION 'room evaluation ledger evidence is immutable once recorded'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER validate_room_ledger_handoff
AFTER INSERT OR UPDATE ON competition.live_evaluation_segments
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION competition.validate_room_ledger_handoff();
