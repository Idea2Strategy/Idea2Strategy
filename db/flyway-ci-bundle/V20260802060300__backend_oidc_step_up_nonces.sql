CREATE TABLE identity.oidc_step_up_nonces (
    id uuid PRIMARY KEY,
    provider_id smallint NOT NULL,
    nonce_digest varchar(128) NOT NULL UNIQUE,
    digest_key_version smallint NOT NULL,
    requested_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    verification_attempt_count integer NOT NULL DEFAULT 0,
    last_verification_attempt_at timestamptz,
    consumed_at timestamptz,
    consumed_by_account_id uuid,
    CONSTRAINT oidc_step_up_nonce_provider_fk FOREIGN KEY (provider_id)
        REFERENCES identity.auth_providers (id),
    CONSTRAINT oidc_step_up_nonce_consumed_account_fk FOREIGN KEY (consumed_by_account_id)
        REFERENCES identity.accounts (id),
    CONSTRAINT oidc_step_up_nonce_digest_key_positive CHECK (digest_key_version > 0),
    CONSTRAINT oidc_step_up_nonce_window_valid CHECK (expires_at > requested_at),
    CONSTRAINT oidc_step_up_nonce_attempts_bounded CHECK (
        verification_attempt_count BETWEEN 0 AND 5
        AND ((verification_attempt_count = 0 AND last_verification_attempt_at IS NULL)
             OR (verification_attempt_count > 0 AND last_verification_attempt_at IS NOT NULL))
    ),
    CONSTRAINT oidc_step_up_nonce_consumption_complete CHECK (
        (consumed_at IS NULL AND consumed_by_account_id IS NULL)
        OR (consumed_at IS NOT NULL AND consumed_by_account_id IS NOT NULL
            AND consumed_at >= requested_at AND consumed_at <= expires_at)
    )
);

CREATE INDEX oidc_step_up_nonce_expiry_idx
    ON identity.oidc_step_up_nonces (expires_at)
    WHERE consumed_at IS NULL;

CREATE INDEX oidc_step_up_nonce_provider_expiry_idx
    ON identity.oidc_step_up_nonces (provider_id, expires_at)
    WHERE consumed_at IS NULL;

COMMENT ON TABLE identity.oidc_step_up_nonces IS
    'Server-issued, single-use OIDC lifecycle step-up challenges. Only an HMAC digest is stored; plaintext nonce and ID token are forbidden.';
