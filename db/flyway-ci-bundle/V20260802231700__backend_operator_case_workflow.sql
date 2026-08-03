ALTER TYPE operations.case_event_type ADD VALUE IF NOT EXISTS 'ASSIGNED';
ALTER TYPE operations.case_event_type ADD VALUE IF NOT EXISTS 'REASSIGNED';
ALTER TYPE operations.case_event_type ADD VALUE IF NOT EXISTS 'UNASSIGNED';
ALTER TYPE operations.case_event_type ADD VALUE IF NOT EXISTS 'SANCTION_APPLIED';
ALTER TYPE operations.case_event_type ADD VALUE IF NOT EXISTS 'SANCTION_RELEASED';

ALTER TABLE operations.cases
    ADD COLUMN assignee_operator_id uuid,
    ADD CONSTRAINT case_assignee_operator_fk FOREIGN KEY (assignee_operator_id)
        REFERENCES operations.operator_accounts(id) DEFERRABLE INITIALLY IMMEDIATE;

CREATE INDEX case_operator_queue_idx
    ON operations.cases (case_type, status, assignee_operator_id, updated_at DESC, id DESC);

CREATE TABLE operations.operator_case_command_receipts (
    operator_id uuid NOT NULL,
    command_type varchar(40) NOT NULL,
    idempotency_key varchar(160) NOT NULL,
    request_hash varchar(64) NOT NULL,
    case_id uuid NOT NULL,
    case_event_id uuid,
    decision_status varchar(20) NOT NULL,
    response_code varchar(80) NOT NULL,
    response_document jsonb NOT NULL,
    audit_document jsonb NOT NULL,
    completed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (operator_id, command_type, idempotency_key),
    CONSTRAINT operator_case_receipt_operator_fk FOREIGN KEY (operator_id)
        REFERENCES operations.operator_accounts(id),
    CONSTRAINT operator_case_receipt_case_fk FOREIGN KEY (case_id)
        REFERENCES operations.cases(id),
    CONSTRAINT operator_case_receipt_event_fk FOREIGN KEY (case_id, case_event_id)
        REFERENCES operations.case_events(case_id, id) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT operator_case_receipt_hash_valid CHECK (request_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT operator_case_receipt_decision_valid CHECK (
        decision_status IN ('APPLIED', 'NO_OP', 'REJECTED')),
    CONSTRAINT operator_case_receipt_event_consistent CHECK (
        (decision_status = 'APPLIED' AND case_event_id IS NOT NULL)
        OR (decision_status <> 'APPLIED' AND case_event_id IS NULL)),
    CONSTRAINT operator_case_receipt_response_object CHECK (
        jsonb_typeof(response_document) = 'object'),
    CONSTRAINT operator_case_receipt_audit_object CHECK (
        jsonb_typeof(audit_document) = 'object')
);

CREATE INDEX operator_case_receipt_case_completed_idx
    ON operations.operator_case_command_receipts (case_id, completed_at);

CREATE TRIGGER operator_case_command_receipts_append_only
BEFORE UPDATE OR DELETE ON operations.operator_case_command_receipts
FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();

COMMENT ON COLUMN operations.cases.assignee_operator_id IS
    'Current A20 operator assignment. Every change increments case_version and appends one case event.';
COMMENT ON TABLE operations.operator_case_command_receipts IS
    'Immutable A20 idempotency and redacted audit evidence; rejected/no-op decisions never advance the case head.';
