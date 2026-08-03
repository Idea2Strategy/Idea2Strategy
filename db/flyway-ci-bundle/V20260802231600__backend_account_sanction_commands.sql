CREATE TABLE identity.account_sanction_heads (
    account_id uuid PRIMARY KEY REFERENCES identity.accounts(id) DEFERRABLE INITIALLY IMMEDIATE,
    aggregate_version bigint NOT NULL DEFAULT 0 CHECK (aggregate_version >= 0),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE identity.account_sanctions
    ADD COLUMN public_reference uuid NOT NULL DEFAULT gen_random_uuid(),
    ADD CONSTRAINT account_sanction_public_reference_uq UNIQUE (public_reference),
    ADD CONSTRAINT account_sanction_type_valid CHECK (sanction_type IN ('SUSPENSION', 'PERMANENT')),
    ADD CONSTRAINT account_sanction_expiry_valid CHECK (
        (sanction_type = 'SUSPENSION' AND expires_at IS NOT NULL AND expires_at > effective_at)
        OR (sanction_type = 'PERMANENT' AND expires_at IS NULL)
    );

ALTER TABLE identity.account_sanction_events
    ADD COLUMN account_id uuid,
    ADD COLUMN correlation_id uuid,
    ADD COLUMN previous_status identity.sanction_status,
    ADD COLUMN resulting_status identity.sanction_status;

UPDATE identity.account_sanction_events event
SET account_id = sanction.account_id,
    correlation_id = gen_random_uuid(),
    previous_status = CASE WHEN event.event_type = 'APPLIED' THEN NULL ELSE sanction.status END,
    resulting_status = CASE event.event_type
        WHEN 'APPLIED' THEN 'ACTIVE'::identity.sanction_status
        WHEN 'LIFTED' THEN 'LIFTED'::identity.sanction_status
        WHEN 'EXPIRED' THEN 'EXPIRED'::identity.sanction_status
    END
FROM identity.account_sanctions sanction
WHERE sanction.id = event.sanction_id;

ALTER TABLE identity.account_sanction_events
    ALTER COLUMN account_id SET NOT NULL,
    ALTER COLUMN correlation_id SET NOT NULL,
    ALTER COLUMN resulting_status SET NOT NULL,
    ADD CONSTRAINT account_sanction_event_account_fk FOREIGN KEY (account_id)
        REFERENCES identity.accounts(id) DEFERRABLE INITIALLY IMMEDIATE,
    ADD CONSTRAINT account_sanction_event_type_valid CHECK (event_type IN ('APPLIED', 'LIFTED', 'EXPIRED')),
    ADD CONSTRAINT account_sanction_event_sequence_positive CHECK (event_sequence > 0);

CREATE TABLE identity.account_sanction_command_receipts (
    account_id uuid NOT NULL,
    command_type varchar(20) NOT NULL CHECK (command_type IN ('APPLY', 'LIFT', 'EXPIRE')),
    idempotency_key varchar(160) NOT NULL,
    request_hash varchar(128) NOT NULL,
    sanction_id uuid NOT NULL,
    correlation_id uuid NOT NULL,
    response_document jsonb NOT NULL,
    completed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, command_type, idempotency_key),
    CONSTRAINT sanction_receipt_account_fk FOREIGN KEY (account_id)
        REFERENCES identity.accounts(id) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE INDEX account_sanction_due_idx
    ON identity.account_sanctions (expires_at, account_id, id)
    WHERE status = 'ACTIVE' AND sanction_type = 'SUSPENSION';
CREATE INDEX account_sanction_event_account_time_idx
    ON identity.account_sanction_events (account_id, occurred_at, sanction_id);

CREATE FUNCTION identity.reject_account_sanction_history_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'sanction history and command receipts are append-only' USING ERRCODE = '23514';
END;
$$;

CREATE TRIGGER account_sanction_events_append_only
BEFORE UPDATE OR DELETE ON identity.account_sanction_events
FOR EACH ROW EXECUTE FUNCTION identity.reject_account_sanction_history_mutation();
CREATE TRIGGER account_sanction_receipts_append_only
BEFORE UPDATE OR DELETE ON identity.account_sanction_command_receipts
FOR EACH ROW EXECUTE FUNCTION identity.reject_account_sanction_history_mutation();

COMMENT ON COLUMN identity.account_sanctions.public_reference IS
    'Stable non-secret sanction reference exposed to an A19 appeal without copying sanction evidence.';
COMMENT ON TABLE identity.account_sanction_heads IS
    'Per-account sanction aggregate version serialized across apply, lift, and expiry commands.';
COMMENT ON TABLE identity.account_sanction_command_receipts IS
    'Immutable account-scoped idempotency receipts for sanction commands.';
