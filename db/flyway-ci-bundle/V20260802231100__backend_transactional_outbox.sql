CREATE TYPE operations.outbox_delivery_status AS ENUM (
    'PENDING', 'CLAIMED', 'PUBLISHED', 'DEAD_LETTERED'
);

CREATE TYPE operations.outbox_attempt_outcome AS ENUM (
    'PUBLISHED', 'RETRY_SCHEDULED', 'DEAD_LETTERED', 'LEASE_EXPIRED'
);

CREATE TYPE operations.consumer_receipt_status AS ENUM (
    'PROCESSING', 'COMPLETED', 'RETRYABLE_FAILURE', 'PERMANENT_FAILURE'
);

ALTER TABLE operations.outbox_messages
    ADD COLUMN payload_hash varchar(128),
    ADD COLUMN producer_idempotency_key varchar(160),
    ADD COLUMN original_message_id uuid,
    ADD COLUMN replayed_from_message_id uuid,
    ADD COLUMN replay_sequence integer NOT NULL DEFAULT 0,
    ADD COLUMN replay_audit_event_id uuid,
    ADD COLUMN delivery_status operations.outbox_delivery_status NOT NULL DEFAULT 'PENDING',
    ADD COLUMN claim_token uuid,
    ADD COLUMN claimed_by varchar(160),
    ADD COLUMN claimed_at timestamptz,
    ADD COLUMN claim_expires_at timestamptz,
    ADD COLUMN dead_lettered_at timestamptz,
    ADD COLUMN dead_letter_reason_code varchar(80);

UPDATE operations.outbox_messages
SET payload_hash = encode(sha256(convert_to(payload_document::text, 'UTF8')), 'hex'),
    producer_idempotency_key = idempotency_key,
    delivery_status = CASE
        WHEN published_at IS NOT NULL THEN 'PUBLISHED'::operations.outbox_delivery_status
        ELSE 'PENDING'::operations.outbox_delivery_status
    END,
    next_attempt_at = CASE WHEN published_at IS NOT NULL THEN NULL ELSE next_attempt_at END;

ALTER TABLE operations.outbox_messages
    ALTER COLUMN payload_hash SET NOT NULL,
    ALTER COLUMN producer_idempotency_key SET NOT NULL,
    ADD CONSTRAINT outbox_replay_sequence_nonnegative CHECK (replay_sequence >= 0),
    ADD CONSTRAINT outbox_replay_lineage_consistent CHECK (
        (replay_sequence = 0 AND original_message_id IS NULL
            AND replayed_from_message_id IS NULL AND replay_audit_event_id IS NULL)
        OR
        (replay_sequence > 0 AND original_message_id IS NOT NULL
            AND replayed_from_message_id IS NOT NULL AND replay_audit_event_id IS NOT NULL)
    ),
    ADD CONSTRAINT outbox_publish_attempt_count_nonnegative CHECK (publish_attempt_count >= 0),
    ADD CONSTRAINT outbox_claim_state_consistent CHECK (
        (delivery_status = 'CLAIMED' AND claim_token IS NOT NULL
            AND claimed_by IS NOT NULL AND claimed_at IS NOT NULL
            AND claim_expires_at > claimed_at)
        OR
        (delivery_status <> 'CLAIMED' AND claim_token IS NULL
            AND claimed_by IS NULL AND claimed_at IS NULL AND claim_expires_at IS NULL)
    ),
    ADD CONSTRAINT outbox_published_state_consistent CHECK (
        (delivery_status = 'PUBLISHED' AND published_at IS NOT NULL)
        OR (delivery_status <> 'PUBLISHED' AND published_at IS NULL)
    ),
    ADD CONSTRAINT outbox_dead_letter_state_consistent CHECK (
        (delivery_status = 'DEAD_LETTERED' AND dead_lettered_at IS NOT NULL
            AND dead_letter_reason_code IS NOT NULL)
        OR
        (delivery_status <> 'DEAD_LETTERED' AND dead_lettered_at IS NULL
            AND dead_letter_reason_code IS NULL)
    ),
    ADD CONSTRAINT outbox_next_attempt_pending_only CHECK (
        delivery_status = 'PENDING' OR next_attempt_at IS NULL
    ),
    ADD CONSTRAINT outbox_original_message_fk FOREIGN KEY (original_message_id)
        REFERENCES operations.outbox_messages(id) DEFERRABLE INITIALLY IMMEDIATE,
    ADD CONSTRAINT outbox_replayed_from_message_fk FOREIGN KEY (replayed_from_message_id)
        REFERENCES operations.outbox_messages(id) DEFERRABLE INITIALLY IMMEDIATE,
    ADD CONSTRAINT outbox_replay_audit_event_fk FOREIGN KEY (replay_audit_event_id)
        REFERENCES operations.audit_events(id) DEFERRABLE INITIALLY IMMEDIATE;

CREATE UNIQUE INDEX outbox_message_claim_token_unique
    ON operations.outbox_messages (claim_token) WHERE claim_token IS NOT NULL;
CREATE UNIQUE INDEX outbox_message_replayed_from_unique
    ON operations.outbox_messages (replayed_from_message_id) WHERE replayed_from_message_id IS NOT NULL;
CREATE UNIQUE INDEX outbox_message_replay_audit_unique
    ON operations.outbox_messages (replay_audit_event_id) WHERE replay_audit_event_id IS NOT NULL;
CREATE UNIQUE INDEX outbox_message_replay_sequence_unique
    ON operations.outbox_messages (original_message_id, replay_sequence)
    WHERE original_message_id IS NOT NULL;
CREATE INDEX outbox_message_delivery_due_idx
    ON operations.outbox_messages (delivery_status, next_attempt_at, claim_expires_at);
CREATE INDEX outbox_message_producer_key_idx
    ON operations.outbox_messages (producer_idempotency_key);

CREATE TABLE operations.outbox_delivery_attempts (
    outbox_message_id uuid NOT NULL,
    attempt_number integer NOT NULL,
    claim_token uuid NOT NULL UNIQUE,
    worker_id varchar(160) NOT NULL,
    runtime_policy_version varchar(80) NOT NULL,
    claimed_at timestamptz NOT NULL,
    claim_expires_at timestamptz NOT NULL,
    completed_at timestamptz,
    outcome operations.outbox_attempt_outcome,
    transport_message_key varchar(200),
    failure_code varchar(80),
    next_attempt_at timestamptz,
    PRIMARY KEY (outbox_message_id, attempt_number),
    CONSTRAINT outbox_attempt_message_fk FOREIGN KEY (outbox_message_id)
        REFERENCES operations.outbox_messages(id) DEFERRABLE INITIALLY IMMEDIATE,
    CONSTRAINT outbox_attempt_number_positive CHECK (attempt_number > 0),
    CONSTRAINT outbox_attempt_lease_positive CHECK (claim_expires_at > claimed_at),
    CONSTRAINT outbox_attempt_completion_consistent CHECK (
        (completed_at IS NULL AND outcome IS NULL AND failure_code IS NULL AND next_attempt_at IS NULL)
        OR (completed_at IS NOT NULL AND outcome IS NOT NULL)
    ),
    CONSTRAINT outbox_attempt_failure_code_consistent CHECK (
        (outcome = 'PUBLISHED' AND failure_code IS NULL)
        OR (outcome <> 'PUBLISHED' AND failure_code IS NOT NULL)
        OR outcome IS NULL
    ),
    CONSTRAINT outbox_attempt_retry_consistent CHECK (
        (outcome = 'RETRY_SCHEDULED' AND failure_code IS NOT NULL AND next_attempt_at IS NOT NULL)
        OR (outcome <> 'RETRY_SCHEDULED' AND next_attempt_at IS NULL)
        OR outcome IS NULL
    )
);

CREATE INDEX outbox_delivery_attempt_outcome_idx
    ON operations.outbox_delivery_attempts (outcome, completed_at);

CREATE TABLE operations.outbox_consumer_receipts (
    consumer_handler_id varchar(160) NOT NULL,
    outbox_message_id uuid NOT NULL,
    producer_idempotency_key varchar(160) NOT NULL,
    payload_hash varchar(128) NOT NULL,
    status operations.consumer_receipt_status NOT NULL,
    claim_token uuid UNIQUE,
    claimed_by varchar(160),
    claimed_at timestamptz,
    claim_expires_at timestamptz,
    receive_attempt_count integer NOT NULL DEFAULT 1,
    first_received_at timestamptz NOT NULL,
    last_received_at timestamptz NOT NULL,
    completed_at timestamptz,
    result_hash varchar(128),
    failure_code varchar(80),
    PRIMARY KEY (consumer_handler_id, outbox_message_id),
    CONSTRAINT outbox_consumer_receipt_message_fk FOREIGN KEY (outbox_message_id)
        REFERENCES operations.outbox_messages(id) DEFERRABLE INITIALLY IMMEDIATE,
    CONSTRAINT consumer_receipt_attempt_count_positive CHECK (receive_attempt_count > 0),
    CONSTRAINT consumer_receipt_receive_time_order CHECK (last_received_at >= first_received_at),
    CONSTRAINT consumer_receipt_claim_state_consistent CHECK (
        (status = 'PROCESSING' AND claim_token IS NOT NULL AND claimed_by IS NOT NULL
            AND claimed_at IS NOT NULL AND claim_expires_at > claimed_at AND completed_at IS NULL)
        OR
        (status <> 'PROCESSING' AND claim_token IS NULL AND claimed_by IS NULL
            AND claimed_at IS NULL AND claim_expires_at IS NULL)
    ),
    CONSTRAINT consumer_receipt_completion_consistent CHECK (
        (status = 'COMPLETED' AND completed_at IS NOT NULL AND failure_code IS NULL)
        OR (status <> 'COMPLETED' AND completed_at IS NULL)
    ),
    CONSTRAINT consumer_receipt_failure_consistent CHECK (
        (status IN ('RETRYABLE_FAILURE', 'PERMANENT_FAILURE') AND failure_code IS NOT NULL)
        OR (status NOT IN ('RETRYABLE_FAILURE', 'PERMANENT_FAILURE') AND failure_code IS NULL)
    )
);

CREATE INDEX outbox_consumer_receipt_producer_idx
    ON operations.outbox_consumer_receipts (consumer_handler_id, producer_idempotency_key);
CREATE INDEX outbox_consumer_receipt_status_idx
    ON operations.outbox_consumer_receipts (status, claim_expires_at);

CREATE FUNCTION operations.prepare_outbox_envelope() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.payload_hash IS NULL THEN
        NEW.payload_hash := encode(sha256(convert_to(NEW.payload_document::text, 'UTF8')), 'hex');
    END IF;
    IF NEW.producer_idempotency_key IS NULL THEN
        NEW.producer_idempotency_key := NEW.idempotency_key;
    END IF;
    IF NEW.published_at IS NOT NULL AND NEW.delivery_status = 'PENDING' THEN
        NEW.delivery_status := 'PUBLISHED';
        NEW.next_attempt_at := NULL;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER prepare_outbox_envelope_before_insert
BEFORE INSERT ON operations.outbox_messages
FOR EACH ROW EXECUTE FUNCTION operations.prepare_outbox_envelope();

CREATE FUNCTION operations.guard_outbox_immutable_envelope() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF (NEW.owner_domain, NEW.aggregate_id, NEW.aggregate_sequence,
        NEW.event_type, NEW.event_schema_version, NEW.payload_document,
        NEW.payload_hash, NEW.producer_idempotency_key, NEW.idempotency_key,
        NEW.original_message_id, NEW.replayed_from_message_id,
        NEW.replay_sequence, NEW.replay_audit_event_id, NEW.created_at)
        IS DISTINCT FROM
       (OLD.owner_domain, OLD.aggregate_id, OLD.aggregate_sequence,
        OLD.event_type, OLD.event_schema_version, OLD.payload_document,
        OLD.payload_hash, OLD.producer_idempotency_key, OLD.idempotency_key,
        OLD.original_message_id, OLD.replayed_from_message_id,
        OLD.replay_sequence, OLD.replay_audit_event_id, OLD.created_at) THEN
        RAISE EXCEPTION 'outbox envelope is immutable' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER guard_outbox_immutable_envelope_before_update
BEFORE UPDATE ON operations.outbox_messages
FOR EACH ROW EXECUTE FUNCTION operations.guard_outbox_immutable_envelope();

COMMENT ON TABLE operations.outbox_delivery_attempts IS
    'A17 proposal 52870121: durable publisher claim attempts; runtime numeric policy remains versioned configuration.';
COMMENT ON TABLE operations.outbox_consumer_receipts IS
    'A17 proposal 52870121: handler/message idempotency receipt; business effect and completion share a local transaction.';
