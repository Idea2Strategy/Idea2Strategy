CREATE TYPE operations.case_type AS ENUM ('INQUIRY', 'REPORT', 'APPEAL');
CREATE TYPE operations.case_status AS ENUM (
    'OPEN', 'NEEDS_INFORMATION', 'UNDER_REVIEW', 'RESOLVED', 'REJECTED'
);
CREATE TYPE operations.case_command_type AS ENUM ('SUBMIT', 'ADD_EVIDENCE');
CREATE TYPE operations.case_event_type AS ENUM (
    'SUBMITTED', 'EVIDENCE_ADDED', 'INFORMATION_REQUESTED',
    'REVIEW_STARTED', 'RESOLVED', 'REJECTED'
);
CREATE TYPE operations.case_actor_type AS ENUM ('ACCOUNT', 'OPERATOR', 'SYSTEM');
CREATE TYPE operations.case_event_visibility AS ENUM ('USER_VISIBLE', 'OPERATOR_ONLY');

ALTER TABLE operations.cases
    ALTER COLUMN case_type TYPE operations.case_type
        USING case_type::operations.case_type,
    ALTER COLUMN status TYPE operations.case_status
        USING status::operations.case_status,
    ADD COLUMN case_version bigint,
    ADD COLUMN current_event_sequence integer,
    ADD COLUMN last_case_event_id uuid,
    ADD COLUMN updated_at timestamptz;

ALTER TABLE operations.case_events
    ALTER COLUMN actor_type TYPE operations.case_actor_type
        USING actor_type::operations.case_actor_type,
    ALTER COLUMN event_type TYPE operations.case_event_type
        USING event_type::operations.case_event_type,
    ADD COLUMN account_id uuid,
    ADD COLUMN previous_event_id uuid,
    ADD COLUMN resulting_status operations.case_status,
    ADD COLUMN visibility operations.case_event_visibility,
    ADD COLUMN reason_code varchar(80),
    ADD COLUMN correlation_id uuid;

WITH ordered AS (
    SELECT event.id,
           target.account_id,
           lag(event.id) OVER (PARTITION BY event.case_id ORDER BY event.event_sequence) AS previous_event_id,
           CASE event.event_type
               WHEN 'SUBMITTED' THEN 'OPEN'::operations.case_status
               WHEN 'EVIDENCE_ADDED' THEN 'OPEN'::operations.case_status
               WHEN 'INFORMATION_REQUESTED' THEN 'NEEDS_INFORMATION'::operations.case_status
               WHEN 'REVIEW_STARTED' THEN 'UNDER_REVIEW'::operations.case_status
               WHEN 'RESOLVED' THEN 'RESOLVED'::operations.case_status
               WHEN 'REJECTED' THEN 'REJECTED'::operations.case_status
           END AS resulting_status
    FROM operations.case_events event
    JOIN operations.cases target ON target.id = event.case_id
)
UPDATE operations.case_events event
SET account_id = ordered.account_id,
    previous_event_id = ordered.previous_event_id,
    resulting_status = ordered.resulting_status,
    visibility = 'USER_VISIBLE',
    correlation_id = gen_random_uuid()
FROM ordered
WHERE ordered.id = event.id;

WITH heads AS (
    SELECT DISTINCT ON (event.case_id)
           event.case_id, event.id, event.event_sequence, event.created_at
    FROM operations.case_events event
    ORDER BY event.case_id, event.event_sequence DESC
)
UPDATE operations.cases target
SET case_version = heads.event_sequence,
    current_event_sequence = heads.event_sequence,
    last_case_event_id = heads.id,
    updated_at = greatest(target.created_at, heads.created_at)
FROM heads
WHERE heads.case_id = target.id;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM operations.cases
        WHERE case_version IS NULL OR current_event_sequence IS NULL
           OR last_case_event_id IS NULL OR updated_at IS NULL
    ) THEN
        RAISE EXCEPTION 'legacy case has no valid event head';
    END IF;
    IF EXISTS (
        SELECT 1 FROM operations.case_events
        WHERE account_id IS NULL OR resulting_status IS NULL OR visibility IS NULL
    ) THEN
        RAISE EXCEPTION 'legacy case event cannot be upgraded safely';
    END IF;
END;
$$;

ALTER TABLE operations.cases
    ALTER COLUMN case_version SET DEFAULT 1,
    ALTER COLUMN case_version SET NOT NULL,
    ALTER COLUMN current_event_sequence SET NOT NULL,
    ALTER COLUMN last_case_event_id SET NOT NULL,
    ALTER COLUMN updated_at SET DEFAULT now(),
    ALTER COLUMN updated_at SET NOT NULL,
    ADD CONSTRAINT case_version_positive CHECK (case_version > 0),
    ADD CONSTRAINT case_current_sequence_positive CHECK (current_event_sequence > 0),
    ADD CONSTRAINT case_head_required CHECK (last_case_event_id IS NOT NULL),
    ADD CONSTRAINT case_terminal_state_consistent CHECK (
        (status IN ('RESOLVED', 'REJECTED') AND closed_at IS NOT NULL AND resolution_code IS NOT NULL)
        OR (status NOT IN ('RESOLVED', 'REJECTED') AND closed_at IS NULL AND resolution_code IS NULL)
    ),
    ADD CONSTRAINT case_update_time_order CHECK (updated_at >= created_at),
    ADD CONSTRAINT case_account_id_uq UNIQUE (account_id, id),
    ADD CONSTRAINT case_id_head_uq UNIQUE (id, last_case_event_id);

ALTER TABLE operations.case_events
    ALTER COLUMN account_id SET NOT NULL,
    ALTER COLUMN resulting_status SET NOT NULL,
    ALTER COLUMN visibility SET NOT NULL,
    ALTER COLUMN correlation_id SET NOT NULL,
    ADD CONSTRAINT case_event_sequence_positive CHECK (event_sequence > 0),
    ADD CONSTRAINT case_event_chain_start_valid CHECK (
        (event_sequence = 1 AND previous_event_id IS NULL
            AND event_type = 'SUBMITTED' AND resulting_status = 'OPEN')
        OR (event_sequence > 1 AND previous_event_id IS NOT NULL)
    ),
    ADD CONSTRAINT case_event_case_id_uq UNIQUE (case_id, id),
    ADD CONSTRAINT case_event_previous_uq UNIQUE (case_id, previous_event_id),
    ADD CONSTRAINT case_event_account_case_fk FOREIGN KEY (account_id, case_id)
        REFERENCES operations.cases (account_id, id) DEFERRABLE INITIALLY DEFERRED,
    ADD CONSTRAINT case_event_previous_fk FOREIGN KEY (case_id, previous_event_id)
        REFERENCES operations.case_events (case_id, id) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE operations.cases
    ADD CONSTRAINT case_head_event_fk FOREIGN KEY (id, last_case_event_id)
        REFERENCES operations.case_events (case_id, id) DEFERRABLE INITIALLY DEFERRED;

CREATE INDEX case_account_status_created_idx
    ON operations.cases (account_id, status, created_at, id);
CREATE INDEX case_event_account_created_idx
    ON operations.case_events (account_id, created_at);
CREATE INDEX case_event_correlation_idx
    ON operations.case_events (correlation_id);

CREATE TABLE operations.case_command_receipts (
    account_id uuid NOT NULL,
    command_type operations.case_command_type NOT NULL,
    idempotency_key varchar(160) NOT NULL,
    request_hash varchar(128) NOT NULL,
    case_id uuid NOT NULL,
    case_event_id uuid NOT NULL,
    response_status integer NOT NULL,
    response_code varchar(80) NOT NULL,
    response_document jsonb NOT NULL,
    completed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, command_type, idempotency_key),
    CONSTRAINT case_command_receipt_event_uq UNIQUE (case_id, case_event_id),
    CONSTRAINT case_command_receipt_success_status CHECK (response_status BETWEEN 200 AND 299),
    CONSTRAINT case_command_receipt_case_fk FOREIGN KEY (account_id, case_id)
        REFERENCES operations.cases (account_id, id) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT case_command_receipt_event_fk FOREIGN KEY (case_id, case_event_id)
        REFERENCES operations.case_events (case_id, id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE operations.case_evidence_references (
    case_id uuid NOT NULL,
    account_id uuid NOT NULL,
    case_event_id uuid NOT NULL,
    storage_object_id uuid NOT NULL,
    source_domain varchar(40) NOT NULL,
    source_resource_id uuid NOT NULL,
    owner_account_id uuid NOT NULL,
    ownership_policy_version varchar(80) NOT NULL,
    ownership_verified_at timestamptz NOT NULL,
    attached_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (case_id, storage_object_id),
    CONSTRAINT case_evidence_owner_matches_case_account CHECK (owner_account_id = account_id),
    CONSTRAINT case_evidence_verification_time_order CHECK (attached_at >= ownership_verified_at),
    CONSTRAINT case_evidence_case_fk FOREIGN KEY (account_id, case_id)
        REFERENCES operations.cases (account_id, id) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT case_evidence_event_fk FOREIGN KEY (case_id, case_event_id)
        REFERENCES operations.case_events (case_id, id) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT case_evidence_object_fk FOREIGN KEY (storage_object_id)
        REFERENCES storage.objects (id) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT case_evidence_owner_fk FOREIGN KEY (owner_account_id)
        REFERENCES identity.accounts (id) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX case_evidence_account_attached_idx
    ON operations.case_evidence_references (account_id, attached_at);
CREATE INDEX case_evidence_source_idx
    ON operations.case_evidence_references (source_domain, source_resource_id);

CREATE FUNCTION operations.reject_case_append_only_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'case history, receipt, and evidence proof are append-only'
        USING ERRCODE = '23514';
END;
$$;

CREATE TRIGGER case_events_append_only
BEFORE UPDATE OR DELETE ON operations.case_events
FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();
CREATE TRIGGER case_command_receipts_append_only
BEFORE UPDATE OR DELETE ON operations.case_command_receipts
FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();
CREATE TRIGGER case_evidence_references_append_only
BEFORE UPDATE OR DELETE ON operations.case_evidence_references
FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();

CREATE FUNCTION operations.verify_case_head_and_chain() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    head operations.case_events%ROWTYPE;
    previous_sequence integer;
BEGIN
    IF TG_TABLE_NAME = 'cases' THEN
        SELECT * INTO head FROM operations.case_events WHERE id = NEW.last_case_event_id;
        IF head.case_id IS DISTINCT FROM NEW.id
           OR head.account_id IS DISTINCT FROM NEW.account_id
           OR head.event_sequence IS DISTINCT FROM NEW.current_event_sequence
           OR head.resulting_status IS DISTINCT FROM NEW.status
           OR NEW.case_version IS DISTINCT FROM NEW.current_event_sequence THEN
            RAISE EXCEPTION 'case projection does not match its event head' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    END IF;
    IF NEW.previous_event_id IS NOT NULL THEN
        SELECT event_sequence INTO previous_sequence
        FROM operations.case_events
        WHERE case_id = NEW.case_id AND id = NEW.previous_event_id;
        IF previous_sequence IS DISTINCT FROM NEW.event_sequence - 1 THEN
            RAISE EXCEPTION 'case event does not extend the immediate previous head' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER verify_case_projection_head
AFTER INSERT OR UPDATE ON operations.cases
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION operations.verify_case_head_and_chain();
CREATE CONSTRAINT TRIGGER verify_case_event_chain
AFTER INSERT ON operations.case_events
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION operations.verify_case_head_and_chain();

COMMENT ON TABLE operations.cases IS
    'Current user case head projection. A19 owns user submit/read/supplement only; operator workflow is A20.';
COMMENT ON TABLE operations.case_events IS
    'Append-only case history. User APIs expose USER_VISIBLE events only.';
COMMENT ON TABLE operations.case_command_receipts IS
    'Immutable successful command receipts for exact account-scoped idempotent replay.';
COMMENT ON TABLE operations.case_evidence_references IS
    'Immutable proof that an AVAILABLE object belonged to the case account through its source resource when linked.';
