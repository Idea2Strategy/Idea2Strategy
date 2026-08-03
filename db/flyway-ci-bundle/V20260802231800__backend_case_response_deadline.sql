ALTER TYPE operations.case_event_type
    ADD VALUE IF NOT EXISTS 'INFORMATION_RESPONSE_DEADLINE_EXPIRED';

ALTER TABLE operations.cases
    ADD COLUMN response_deadline_at timestamptz,
    ADD COLUMN deadline_policy_version varchar(80),
    ADD CONSTRAINT case_response_deadline_pair CHECK (
        (response_deadline_at IS NULL AND deadline_policy_version IS NULL)
        OR (response_deadline_at IS NOT NULL AND deadline_policy_version IS NOT NULL));

CREATE INDEX case_response_deadline_due_idx
    ON operations.cases (response_deadline_at, id)
    WHERE response_deadline_at IS NOT NULL;

CREATE TABLE operations.case_deadline_receipts (
    case_id uuid NOT NULL,
    expected_case_version bigint NOT NULL,
    response_deadline_at timestamptz NOT NULL,
    decision_status varchar(32) NOT NULL,
    case_event_id uuid,
    correlation_id uuid NOT NULL,
    decided_at timestamptz NOT NULL,
    PRIMARY KEY (case_id, expected_case_version, response_deadline_at),
    CONSTRAINT case_deadline_receipt_event_uq UNIQUE (case_id, case_event_id),
    CONSTRAINT case_deadline_receipt_case_fk FOREIGN KEY (case_id)
        REFERENCES operations.cases(id),
    CONSTRAINT case_deadline_receipt_event_fk FOREIGN KEY (case_id, case_event_id)
        REFERENCES operations.case_events(case_id, id) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT case_deadline_receipt_decision_valid CHECK (
        decision_status IN ('APPLIED', 'ALREADY_TRANSITIONED')),
    CONSTRAINT case_deadline_receipt_event_consistent CHECK (
        (decision_status = 'APPLIED' AND case_event_id IS NOT NULL)
        OR (decision_status = 'ALREADY_TRANSITIONED' AND case_event_id IS NULL))
);

CREATE TRIGGER case_deadline_receipts_append_only
BEFORE UPDATE OR DELETE ON operations.case_deadline_receipts
FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();

COMMENT ON COLUMN operations.cases.response_deadline_at IS
    'Exclusive end of the versioned information-response window, evaluated with database time.';
COMMENT ON TABLE operations.case_deadline_receipts IS
    'Immutable A20 result for one case/version/deadline identity; retries never append another event.';
