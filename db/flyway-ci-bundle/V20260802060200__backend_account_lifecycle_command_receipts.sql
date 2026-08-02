-- Immutable A12 idempotency receipts reproduce completed command responses.
CREATE TABLE identity.account_lifecycle_command_receipts (
    account_id uuid NOT NULL,
    command_type varchar(60) NOT NULL,
    idempotency_key varchar(160) NOT NULL,
    request_hash varchar(128) NOT NULL,
    response_status smallint NOT NULL,
    response_code varchar(80),
    response_document jsonb NOT NULL,
    lifecycle_event_id uuid,
    completed_at timestamptz NOT NULL,
    PRIMARY KEY (account_id, command_type, idempotency_key),
    CONSTRAINT account_lifecycle_receipt_account_fk
        FOREIGN KEY (account_id)
        REFERENCES identity.accounts (id),
    CONSTRAINT account_lifecycle_receipt_event_account_fk
        FOREIGN KEY (account_id, lifecycle_event_id)
        REFERENCES identity.account_lifecycle_events (account_id, id),
    CONSTRAINT account_lifecycle_receipt_command_nonblank CHECK (
        length(btrim(command_type)) > 0
    ),
    CONSTRAINT account_lifecycle_receipt_idempotency_key_nonblank CHECK (
        length(btrim(idempotency_key)) > 0
    ),
    CONSTRAINT account_lifecycle_receipt_request_hash_nonblank CHECK (
        length(btrim(request_hash)) > 0
    ),
    CONSTRAINT account_lifecycle_receipt_response_status_range CHECK (
        response_status BETWEEN 100 AND 599
    )
);

CREATE INDEX account_lifecycle_receipt_completed_idx
    ON identity.account_lifecycle_command_receipts (completed_at);

CREATE TRIGGER account_lifecycle_command_receipts_immutable
BEFORE UPDATE OR DELETE ON identity.account_lifecycle_command_receipts
FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();

COMMENT ON TABLE identity.account_lifecycle_command_receipts IS
    'Immutable completed-command receipts keyed by account, command type, and idempotency key; request hash rejects key reuse with a different request and response_document reproduces the original response.';
