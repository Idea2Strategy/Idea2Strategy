ALTER TABLE identity.delegated_authorizations
    ADD COLUMN authorization_version bigint NOT NULL DEFAULT 1,
    ADD COLUMN replaces_authorization_id uuid,
    ADD COLUMN strategy_target_set_hash varchar(128),
    ADD CONSTRAINT delegated_authorization_version_positive CHECK (authorization_version > 0),
    ADD CONSTRAINT delegated_authorization_strategy_target_hash_format CHECK (
        strategy_target_set_hash IS NULL OR strategy_target_set_hash ~ '^[0-9a-f]{64}$'
    ),
    ADD CONSTRAINT delegated_authorization_id_account_uq UNIQUE (id, account_id),
    ADD CONSTRAINT delegated_authorization_replacement_uq UNIQUE (replaces_authorization_id),
    ADD CONSTRAINT delegated_authorization_replacement_fk
        FOREIGN KEY (replaces_authorization_id, account_id)
        REFERENCES identity.delegated_authorizations (id, account_id)
        DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE identity.delegated_credentials
    ADD CONSTRAINT delegated_credential_authorization_id_uq UNIQUE (authorization_id, id);

ALTER TABLE strategy.strategies
    ADD COLUMN delegated_access_epoch bigint NOT NULL DEFAULT 1,
    ADD CONSTRAINT strategy_delegated_access_epoch_positive CHECK (delegated_access_epoch > 0),
    ADD CONSTRAINT strategy_id_owner_uq UNIQUE (id, owner_account_id);

CREATE TABLE identity.delegated_authorization_strategy_targets (
    authorization_id uuid NOT NULL,
    strategy_id uuid NOT NULL,
    owner_account_id_at_grant uuid NOT NULL,
    strategy_access_epoch_at_grant bigint NOT NULL,
    granted_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (authorization_id, strategy_id),
    CONSTRAINT delegated_strategy_target_epoch_positive CHECK (strategy_access_epoch_at_grant > 0),
    CONSTRAINT delegated_strategy_target_authorization_fk
        FOREIGN KEY (authorization_id, owner_account_id_at_grant)
        REFERENCES identity.delegated_authorizations (id, account_id)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT delegated_strategy_target_strategy_fk
        FOREIGN KEY (strategy_id, owner_account_id_at_grant)
        REFERENCES strategy.strategies (id, owner_account_id)
        DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE identity.delegated_strategy_derivations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    authorization_id uuid NOT NULL,
    credential_id uuid NOT NULL,
    derivation_type varchar(16) NOT NULL,
    source_strategy_id uuid,
    result_strategy_id uuid NOT NULL,
    owner_account_id_at_creation uuid NOT NULL,
    strategy_access_epoch_at_creation bigint NOT NULL,
    correlation_id uuid NOT NULL,
    idempotency_key varchar(160) NOT NULL,
    request_hash varchar(128) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT delegated_strategy_derivation_type_valid CHECK (
        (derivation_type = 'CREATE' AND source_strategy_id IS NULL)
        OR (derivation_type = 'COPY' AND source_strategy_id IS NOT NULL AND source_strategy_id <> result_strategy_id)
    ),
    CONSTRAINT delegated_strategy_derivation_epoch_positive CHECK (strategy_access_epoch_at_creation > 0),
    CONSTRAINT delegated_strategy_derivation_request_hash_format CHECK (request_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT delegated_strategy_derivation_command_uq UNIQUE (authorization_id, idempotency_key),
    CONSTRAINT delegated_strategy_derivation_result_uq UNIQUE (result_strategy_id),
    CONSTRAINT delegated_strategy_derivation_credential_fk
        FOREIGN KEY (authorization_id, credential_id)
        REFERENCES identity.delegated_credentials (authorization_id, id)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT delegated_strategy_derivation_source_fk
        FOREIGN KEY (authorization_id, source_strategy_id)
        REFERENCES identity.delegated_authorization_strategy_targets (authorization_id, strategy_id)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT delegated_strategy_derivation_result_fk
        FOREIGN KEY (result_strategy_id, owner_account_id_at_creation)
        REFERENCES strategy.strategies (id, owner_account_id)
        DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX delegated_strategy_target_strategy_idx
    ON identity.delegated_authorization_strategy_targets (strategy_id, authorization_id);
CREATE INDEX delegated_strategy_derivation_authorization_idx
    ON identity.delegated_strategy_derivations (authorization_id, created_at);

CREATE FUNCTION identity.reject_delegated_strategy_scope_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'delegated Strategy scope evidence is append-only';
END;
$$;

CREATE TRIGGER delegated_strategy_targets_append_only
BEFORE UPDATE OR DELETE ON identity.delegated_authorization_strategy_targets
FOR EACH ROW EXECUTE FUNCTION identity.reject_delegated_strategy_scope_mutation();

CREATE TRIGGER delegated_strategy_derivations_append_only
BEFORE UPDATE OR DELETE ON identity.delegated_strategy_derivations
FOR EACH ROW EXECUTE FUNCTION identity.reject_delegated_strategy_scope_mutation();

COMMENT ON TABLE identity.delegated_authorization_strategy_targets IS
    'Immutable explicit Strategy allowlist. Existing authorizations are intentionally not backfilled and therefore fail closed.';
COMMENT ON TABLE identity.delegated_strategy_derivations IS
    'Append-only CREATE/COPY result provenance. COPY sources must be explicit targets; derived results never become COPY sources.';
