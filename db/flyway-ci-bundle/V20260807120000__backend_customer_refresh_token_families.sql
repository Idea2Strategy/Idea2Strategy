CREATE TABLE identity.refresh_token_families (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id uuid NOT NULL,
    authenticated_by_login_identity_id uuid NOT NULL,
    auth_epoch_at_issue bigint NOT NULL,
    credential_version_at_issue bigint,
    current_token_digest varchar(128) NOT NULL UNIQUE,
    digest_key_version smallint NOT NULL,
    issued_at timestamptz NOT NULL DEFAULT now(),
    last_rotated_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    revoke_reason_code varchar(80),
    CONSTRAINT refresh_token_family_auth_epoch_positive CHECK (auth_epoch_at_issue > 0),
    CONSTRAINT refresh_token_family_credential_version_positive
        CHECK (credential_version_at_issue IS NULL OR credential_version_at_issue > 0),
    CONSTRAINT refresh_token_family_digest_key_version_positive CHECK (digest_key_version > 0),
    CONSTRAINT refresh_token_family_time_order_valid CHECK (expires_at > issued_at),
    CONSTRAINT refresh_token_family_login_identity_fk
        FOREIGN KEY (account_id, authenticated_by_login_identity_id)
        REFERENCES identity.login_identities (account_id, id)
);

CREATE INDEX refresh_token_families_account_expiry_idx
    ON identity.refresh_token_families (account_id, expires_at);
CREATE INDEX refresh_token_families_account_revoked_idx
    ON identity.refresh_token_families (account_id, revoked_at);

INSERT INTO identity.refresh_token_families (
    id,
    account_id,
    authenticated_by_login_identity_id,
    auth_epoch_at_issue,
    credential_version_at_issue,
    current_token_digest,
    digest_key_version,
    issued_at,
    last_rotated_at,
    expires_at,
    revoked_at,
    revoke_reason_code
)
SELECT
    id,
    account_id,
    authenticated_by_login_identity_id,
    auth_epoch_at_issue,
    credential_version_at_issue,
    token_digest,
    digest_key_version,
    issued_at,
    last_seen_at,
    expires_at,
    revoked_at,
    revoke_reason_code
FROM identity.sessions;

ALTER TABLE strategy.strategy_edit_leases
    ADD COLUMN account_id uuid;

UPDATE strategy.strategy_edit_leases lease
SET account_id = session.account_id
FROM identity.sessions session
WHERE lease.session_id = session.id;

ALTER TABLE strategy.strategy_edit_leases
    DROP CONSTRAINT strategy_edit_leases_session_id_fkey,
    DROP CONSTRAINT strategy_edit_lease_exactly_one_editor,
    DROP COLUMN session_id,
    ADD CONSTRAINT strategy_edit_lease_exactly_one_editor
        CHECK (
            (account_id IS NOT NULL AND delegated_credential_id IS NULL)
            OR (account_id IS NULL AND delegated_credential_id IS NOT NULL)
        ),
    ADD CONSTRAINT strategy_edit_leases_account_id_fkey
        FOREIGN KEY (account_id) REFERENCES identity.accounts (id);

DROP TABLE identity.sessions;

COMMENT ON TABLE identity.refresh_token_families IS
    'Minimal server state for rotating refresh JWT reuse detection. It is not a device session registry and has no concurrent-login policy.';
COMMENT ON TABLE strategy.strategy_edit_leases IS
    'Allows exactly one active editor. Customer leases are account-owned and independently protected by the lease token; authentication sessions are not editor identities.';
