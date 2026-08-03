ALTER TABLE operations.operator_accounts
    ADD COLUMN external_identity_key_version smallint;

ALTER TABLE operations.operator_accounts
    ADD CONSTRAINT operator_identity_key_version_positive
    CHECK (external_identity_key_version IS NULL OR external_identity_key_version > 0);

COMMENT ON COLUMN operations.operator_accounts.external_identity_key_version IS
    'Version of the deployment HMAC key used for the length-delimited issuer/subject mapping. NULL legacy mappings fail closed until verified backfill.';

CREATE FUNCTION operations.require_versioned_operator_identity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.external_identity_key_version IS NULL THEN
        RAISE EXCEPTION 'new operator identity mappings require a key version';
    END IF;
    IF TG_OP = 'UPDATE'
        AND OLD.external_identity_key_version IS NOT NULL
        AND NEW.external_identity_key_version IS NULL THEN
        RAISE EXCEPTION 'operator identity mappings cannot become unversioned';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER require_versioned_operator_identity_before_write
BEFORE INSERT OR UPDATE ON operations.operator_accounts
FOR EACH ROW EXECUTE FUNCTION operations.require_versioned_operator_identity();

CREATE TABLE operations.operator_bootstrap_receipts (
    bootstrap_key varchar(160) PRIMARY KEY,
    manifest_hash varchar(128) NOT NULL UNIQUE,
    catalog_version varchar(80) NOT NULL,
    operator_account_id uuid NOT NULL,
    operator_role_assignment_id uuid NOT NULL,
    external_identity_key_version smallint NOT NULL,
    correlation_id uuid NOT NULL,
    audit_event_id uuid NOT NULL UNIQUE,
    applied_at timestamptz NOT NULL,
    CONSTRAINT operator_bootstrap_catalog_fk FOREIGN KEY (catalog_version)
        REFERENCES operations.rbac_catalog_versions(catalog_version),
    CONSTRAINT operator_bootstrap_account_fk FOREIGN KEY (operator_account_id)
        REFERENCES operations.operator_accounts(id),
    CONSTRAINT operator_bootstrap_assignment_fk FOREIGN KEY (operator_role_assignment_id)
        REFERENCES operations.operator_role_assignments(id),
    CONSTRAINT operator_bootstrap_audit_fk FOREIGN KEY (audit_event_id)
        REFERENCES operations.audit_events(id),
    CONSTRAINT operator_bootstrap_assignment_unique
        UNIQUE (operator_account_id, operator_role_assignment_id),
    CONSTRAINT operator_bootstrap_key_version_positive
        CHECK (external_identity_key_version > 0)
);

CREATE FUNCTION operations.guard_operator_bootstrap_receipt_immutable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'operator bootstrap receipts are immutable';
END $$;

CREATE FUNCTION operations.require_coherent_operator_bootstrap_receipt()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM operations.operator_accounts account
        JOIN operations.operator_role_assignments assignment
          ON assignment.id = NEW.operator_role_assignment_id
         AND assignment.operator_account_id = account.id
        WHERE account.id = NEW.operator_account_id
          AND account.external_identity_key_version = NEW.external_identity_key_version
    ) THEN
        RAISE EXCEPTION 'operator bootstrap receipt references incoherent identity evidence';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER require_coherent_operator_bootstrap_receipt_before_insert
BEFORE INSERT ON operations.operator_bootstrap_receipts
FOR EACH ROW EXECUTE FUNCTION operations.require_coherent_operator_bootstrap_receipt();

CREATE TRIGGER guard_operator_bootstrap_receipt_immutable
BEFORE UPDATE OR DELETE ON operations.operator_bootstrap_receipts
FOR EACH ROW EXECUTE FUNCTION operations.guard_operator_bootstrap_receipt_immutable();

COMMENT ON TABLE operations.operator_bootstrap_receipts IS
    'Immutable one-shot deployment bootstrap evidence. No HTTP or MCP bootstrap route is permitted.';
