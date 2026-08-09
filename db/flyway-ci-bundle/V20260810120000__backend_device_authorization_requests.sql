-- Browser approval for a command-line client.
--
-- Today the CLI takes a password on standard input, which means anything driving the CLI —
-- including an AI agent asked to "set it up" — has to be handed the customer's password. This
-- table is what lets the browser hold the credential instead: the CLI never sees it, and the
-- customer approves a short code in a session they already trust.
--
-- The user code and the device code are separate secrets on purpose. The short one is read aloud
-- and typed by a person, so it is guessable by construction and must not be enough to collect a
-- token; the long one never leaves the CLI. Only digests are stored, so a database reader cannot
-- complete somebody's pending login.

CREATE TYPE identity.device_authorization_status AS ENUM (
    'PENDING',
    'APPROVED',
    'CONSUMED',
    'DENIED',
    'EXPIRED'
);

CREATE TABLE identity.device_authorization_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_code_digest varchar(128) NOT NULL UNIQUE,
    user_code_digest varchar(128) NOT NULL UNIQUE,
    digest_key_version smallint NOT NULL,
    client_label varchar(80) NOT NULL,
    status identity.device_authorization_status NOT NULL,
    approved_account_id uuid REFERENCES identity.accounts (id),
    approved_login_identity_id uuid REFERENCES identity.login_identities (id),
    poll_interval_seconds smallint NOT NULL DEFAULT 5,
    requested_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    approved_at timestamptz,
    consumed_at timestamptz,
    denied_at timestamptz,
    failed_attempt_count integer NOT NULL DEFAULT 0,
    last_polled_at timestamptz,

    -- An approved request names who approved it; a pending one cannot.
    CONSTRAINT device_authorization_requests_approval_is_complete CHECK (
        (status IN ('APPROVED', 'CONSUMED'))
            = (approved_account_id IS NOT NULL AND approved_at IS NOT NULL)
    ),
    -- A token may be collected once. CONSUMED is the record of that having happened.
    CONSTRAINT device_authorization_requests_consumed_is_approved CHECK (
        (status = 'CONSUMED') = (consumed_at IS NOT NULL)
    ),
    CONSTRAINT device_authorization_requests_denied_is_marked CHECK (
        (status = 'DENIED') = (denied_at IS NOT NULL)
    )
);

CREATE INDEX ON identity.device_authorization_requests (status, expires_at);
CREATE INDEX ON identity.device_authorization_requests (approved_account_id, requested_at);

COMMENT ON TABLE identity.device_authorization_requests IS
    '브라우저 승인으로 CLI 를 인증시키는 기기 인증 요청. 사용자가 보는 짧은 user_code 와 CLI 가 폴링하는 device_code 는 서로 다른 비밀이며 둘 다 다이제스트로만 저장한다. 승인은 브라우저 세션이, 토큰 수령은 device_code 소지자가 한다. 소진은 1회 한정.';
