INSERT INTO identity.auth_providers (id, code, display_name, provider_type, issuer, is_active)
VALUES (1, 'PASSWORD', 'Email and password', 'PASSWORD', NULL, true)
ON CONFLICT (code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    is_active = true,
    updated_at = now();

CREATE UNIQUE INDEX email_verification_one_open_per_account
    ON identity.email_verification_requests (account_id)
    WHERE consumed_at IS NULL AND revoked_at IS NULL;

CREATE UNIQUE INDEX login_identity_one_pending_per_account
    ON identity.login_identities (account_id)
    WHERE status = 'PENDING';

CREATE UNIQUE INDEX login_identity_one_active_per_account
    ON identity.login_identities (account_id)
    WHERE status = 'ACTIVE';

ALTER TABLE identity.account_emails
    ADD CONSTRAINT account_email_status_timestamps_consistent CHECK (
        (status = 'PENDING_VERIFICATION' AND verified_at IS NULL AND revoked_at IS NULL)
        OR (status = 'VERIFIED' AND verified_at IS NOT NULL AND revoked_at IS NULL)
        OR (status = 'REVOKED' AND revoked_at IS NOT NULL)
    );

ALTER TABLE identity.login_identities
    ADD COLUMN failed_attempt_count integer NOT NULL DEFAULT 0,
    ADD COLUMN last_failed_at timestamptz,
    ADD CONSTRAINT login_identity_failed_attempt_count_nonnegative CHECK (failed_attempt_count >= 0);
