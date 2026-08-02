-- A12 account lifecycle, retention, legal-hold, and identifier-reuse contract.

CREATE TYPE identity.account_data_category AS ENUM (
    'PROFILE',
    'CONTACT_IDENTIFIER',
    'AUTH_CREDENTIAL',
    'POLICY_CONSENT',
    'ACCOUNT_LIFECYCLE_AUDIT',
    'TRADING_FINANCIAL_RECORD',
    'BOT_STRATEGY_EVALUATION',
    'OPERATIONS_DELIVERY_LOG'
);

CREATE TYPE identity.retention_disposition AS ENUM ('DELETE', 'ANONYMIZE', 'RETAIN');
CREATE TYPE identity.retention_obligation_status AS ENUM ('PENDING', 'HELD', 'COMPLETED', 'FAILED');
CREATE TYPE identity.legal_hold_status AS ENUM ('ACTIVE', 'RELEASED');

ALTER TABLE identity.accounts
    ADD COLUMN lifecycle_version bigint,
    ADD COLUMN last_lifecycle_event_id uuid,
    ADD COLUMN last_successful_auth_at timestamptz,
    ADD COLUMN dormant_at timestamptz,
    ADD COLUMN withdrawal_requested_at timestamptz,
    ADD COLUMN cancellation_deadline_at timestamptz,
    ADD COLUMN closing_previous_status identity.account_lifecycle_status,
    ADD COLUMN closed_at timestamptz,
    ADD COLUMN anonymized_at timestamptz;

ALTER TABLE identity.account_lifecycle_events
    ADD COLUMN previous_event_id uuid,
    ADD COLUMN lifecycle_version bigint,
    ADD COLUMN command_type varchar(60),
    ADD COLUMN actor_type varchar(40),
    ADD COLUMN actor_id varchar(160),
    ADD COLUMN correlation_id uuid,
    ADD COLUMN idempotency_key varchar(160),
    ADD COLUMN request_hash varchar(128),
    ADD COLUMN retention_policy_version varchar(80),
    ADD COLUMN cancellation_deadline_at timestamptz,
    ADD COLUMN dormancy_basis_at timestamptz;

-- Normalize legacy evidence into a deterministic chain before enforcing A12.
WITH ordered AS (
    SELECT id,
           account_id,
           event_sequence,
           lag(id) OVER (PARTITION BY account_id ORDER BY event_sequence, occurred_at, id) AS previous_event_id,
           lag(new_status) OVER (PARTITION BY account_id ORDER BY event_sequence, occurred_at, id) AS chained_previous_status,
           row_number() OVER (PARTITION BY account_id ORDER BY event_sequence, occurred_at, id) AS normalized_sequence
    FROM identity.account_lifecycle_events
)
UPDATE identity.account_lifecycle_events event
SET event_sequence = ordered.normalized_sequence,
    previous_event_id = ordered.previous_event_id,
    lifecycle_version = ordered.normalized_sequence,
    previous_status = ordered.chained_previous_status,
    command_type = 'LEGACY_LIFECYCLE_EVENT',
    actor_type = 'MIGRATION',
    actor_id = 'backend-a12',
    correlation_id = event.id,
    idempotency_key = 'legacy:' || event.id::text,
    request_hash = md5(event.id::text) || md5(event.id::text || ':2')
FROM ordered
WHERE ordered.id = event.id;

-- Reconcile a legacy projection whose final event did not describe its current state.
WITH last_event AS (
    SELECT DISTINCT ON (event.account_id)
           event.account_id,
           event.id,
           event.event_sequence,
           event.new_status
    FROM identity.account_lifecycle_events event
    ORDER BY event.account_id, event.event_sequence DESC
)
INSERT INTO identity.account_lifecycle_events (
    account_id, event_sequence, previous_event_id, lifecycle_version,
    previous_status, new_status, command_type, actor_type, actor_id,
    correlation_id, idempotency_key, request_hash, reason_code, occurred_at
)
SELECT account.id,
       last_event.event_sequence + 1,
       last_event.id,
       last_event.event_sequence + 1,
       last_event.new_status,
       account.lifecycle_status,
       'LEGACY_PROJECTION_RECONCILED',
       'MIGRATION',
       'backend-a12',
       gen_random_uuid(),
       'legacy-projection:' || account.id::text,
       md5(account.id::text || ':projection') || md5(account.id::text || ':projection:2'),
       'A12_BACKFILL',
       account.status_changed_at
FROM identity.accounts account
JOIN last_event ON last_event.account_id = account.id
WHERE last_event.new_status <> account.lifecycle_status;

-- Accounts without legacy evidence receive one explicit genesis event.
INSERT INTO identity.account_lifecycle_events (
    account_id, event_sequence, previous_event_id, lifecycle_version,
    previous_status, new_status, command_type, actor_type, actor_id,
    correlation_id, idempotency_key, request_hash, reason_code, occurred_at
)
SELECT account.id,
       1,
       NULL,
       1,
       NULL,
       account.lifecycle_status,
       'LEGACY_ACCOUNT_IMPORTED',
       'MIGRATION',
       'backend-a12',
       gen_random_uuid(),
       'legacy-account:' || account.id::text,
       md5(account.id::text || ':account') || md5(account.id::text || ':account:2'),
       'A12_BACKFILL',
       account.status_changed_at
FROM identity.accounts account
WHERE NOT EXISTS (
    SELECT 1
    FROM identity.account_lifecycle_events event
    WHERE event.account_id = account.id
);

-- Do not invent the state to which a legacy CLOSING account may be restored.
-- The immediately preceding event must prove it was ACTIVE or DORMANT.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM identity.accounts account
        JOIN LATERAL (
            SELECT event.previous_status
            FROM identity.account_lifecycle_events event
            WHERE event.account_id = account.id
            ORDER BY event.event_sequence DESC
            LIMIT 1
        ) head ON true
        WHERE account.lifecycle_status = 'CLOSING'
          AND (
              head.previous_status IS NULL
              OR head.previous_status NOT IN ('ACTIVE', 'DORMANT')
          )
    ) THEN
        RAISE EXCEPTION 'A12 cannot infer closing_previous_status for a legacy CLOSING account'
            USING ERRCODE = '23514';
    END IF;
END;
$$;

WITH head AS (
    SELECT DISTINCT ON (event.account_id)
           event.account_id, event.id, event.event_sequence, event.previous_status
    FROM identity.account_lifecycle_events event
    ORDER BY event.account_id, event.event_sequence DESC
), authentication AS (
    SELECT login.account_id, max(login.last_authenticated_at) AS last_successful_auth_at
    FROM identity.login_identities login
    WHERE login.last_authenticated_at IS NOT NULL
    GROUP BY login.account_id
)
UPDATE identity.accounts account
SET lifecycle_version = head.event_sequence,
    last_lifecycle_event_id = head.id,
    last_successful_auth_at = authentication.last_successful_auth_at,
    dormant_at = CASE WHEN account.lifecycle_status = 'DORMANT' THEN account.status_changed_at END,
    withdrawal_requested_at = CASE WHEN account.lifecycle_status = 'CLOSING' THEN account.status_changed_at END,
    cancellation_deadline_at = CASE WHEN account.lifecycle_status = 'CLOSING' THEN account.status_changed_at + interval '30 days' END,
    closing_previous_status = CASE WHEN account.lifecycle_status = 'CLOSING' THEN head.previous_status END,
    closed_at = CASE WHEN account.lifecycle_status = 'CLOSED' THEN account.status_changed_at END
FROM head
LEFT JOIN authentication ON authentication.account_id = head.account_id
WHERE account.id = head.account_id;

ALTER TABLE identity.account_lifecycle_events
    ALTER COLUMN lifecycle_version SET NOT NULL,
    ALTER COLUMN command_type SET NOT NULL,
    ALTER COLUMN actor_type SET NOT NULL,
    ALTER COLUMN correlation_id SET NOT NULL,
    ALTER COLUMN idempotency_key SET NOT NULL,
    ALTER COLUMN request_hash SET NOT NULL,
    ADD CONSTRAINT account_lifecycle_event_sequence_positive CHECK (event_sequence > 0),
    ADD CONSTRAINT account_lifecycle_event_version_matches_sequence CHECK (lifecycle_version = event_sequence),
    ADD CONSTRAINT account_lifecycle_event_previous_link_complete CHECK (
        (event_sequence = 1 AND previous_event_id IS NULL)
        OR (event_sequence > 1 AND previous_event_id IS NOT NULL)
    ),
    ADD CONSTRAINT account_lifecycle_event_status_chain_complete CHECK (
        (event_sequence = 1 AND previous_status IS NULL)
        OR (event_sequence > 1 AND previous_status IS NOT NULL AND previous_status <> new_status)
    ),
    ADD CONSTRAINT account_lifecycle_event_idempotency_complete CHECK (
        length(btrim(idempotency_key)) > 0 AND length(btrim(request_hash)) > 0
    ),
    ADD CONSTRAINT account_lifecycle_event_withdrawal_deadline_required CHECK (
        command_type <> 'WITHDRAWAL_REQUESTED'
        OR cancellation_deadline_at = occurred_at + interval '30 days'
    ),
    ADD CONSTRAINT account_lifecycle_event_dormancy_basis_required CHECK (
        command_type <> 'ACCOUNT_DORMANT'
        OR (
            dormancy_basis_at IS NOT NULL
            AND occurred_at >= dormancy_basis_at + interval '12 months'
        )
    ),
    ADD CONSTRAINT account_lifecycle_event_account_id_uq UNIQUE (account_id, id);

CREATE UNIQUE INDEX account_lifecycle_event_command_idempotency_uq
    ON identity.account_lifecycle_events (account_id, command_type, idempotency_key);
CREATE UNIQUE INDEX account_lifecycle_event_predecessor_uq
    ON identity.account_lifecycle_events (account_id, previous_event_id)
    WHERE previous_event_id IS NOT NULL;
CREATE UNIQUE INDEX account_lifecycle_event_genesis_uq
    ON identity.account_lifecycle_events (account_id)
    WHERE previous_event_id IS NULL;

ALTER TABLE identity.account_lifecycle_events
    ADD CONSTRAINT previous_event_account_fk
    FOREIGN KEY (account_id, previous_event_id)
    REFERENCES identity.account_lifecycle_events (account_id, id)
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE identity.accounts
    ALTER COLUMN lifecycle_version SET DEFAULT 1,
    ALTER COLUMN lifecycle_version SET NOT NULL,
    ADD CONSTRAINT account_lifecycle_version_positive CHECK (lifecycle_version > 0),
    ADD CONSTRAINT account_dormant_timestamp_required CHECK (
        lifecycle_status <> 'DORMANT' OR dormant_at IS NOT NULL
    ),
    ADD CONSTRAINT account_closing_projection_complete CHECK (
        lifecycle_status <> 'CLOSING'
        OR (
            withdrawal_requested_at IS NOT NULL
            AND cancellation_deadline_at = withdrawal_requested_at + interval '30 days'
            AND closing_previous_status IN ('ACTIVE', 'DORMANT')
        )
    ),
    ADD CONSTRAINT account_closed_timestamp_required CHECK (
        lifecycle_status <> 'CLOSED' OR closed_at IS NOT NULL
    ),
    ADD CONSTRAINT account_anonymized_after_close CHECK (
        anonymized_at IS NULL OR (closed_at IS NOT NULL AND anonymized_at >= closed_at)
    ),
    ADD CONSTRAINT last_lifecycle_event_account_fk
    FOREIGN KEY (id, last_lifecycle_event_id)
    REFERENCES identity.account_lifecycle_events (account_id, id)
    DEFERRABLE INITIALLY DEFERRED;

CREATE INDEX account_lifecycle_dormancy_scan_idx
    ON identity.accounts (lifecycle_status, last_successful_auth_at);
CREATE INDEX account_lifecycle_closing_deadline_idx
    ON identity.accounts (lifecycle_status, cancellation_deadline_at);

CREATE TABLE identity.account_retention_policy_versions (
    version varchar(80) PRIMARY KEY,
    effective_from timestamptz NOT NULL,
    approved_at timestamptz NOT NULL,
    approved_by varchar(120) NOT NULL,
    basis_reference varchar(160) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT account_retention_policy_approved_before_effective CHECK (approved_at <= effective_from)
);

CREATE TABLE identity.account_retention_policy_rules (
    policy_version varchar(80) NOT NULL,
    data_category identity.account_data_category NOT NULL,
    disposition identity.retention_disposition NOT NULL,
    retention_days integer,
    legal_basis_code varchar(160) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (policy_version, data_category),
    CONSTRAINT account_retention_policy_rule_days_nonnegative CHECK (retention_days IS NULL OR retention_days >= 0),
    CONSTRAINT account_retention_policy_destructive_rule_has_period CHECK (disposition = 'RETAIN' OR retention_days IS NOT NULL),
    CONSTRAINT account_retention_policy_rule_version_fk FOREIGN KEY (policy_version)
        REFERENCES identity.account_retention_policy_versions (version)
);

ALTER TABLE identity.account_lifecycle_events
    ADD CONSTRAINT account_lifecycle_event_retention_policy_fk
    FOREIGN KEY (retention_policy_version)
    REFERENCES identity.account_retention_policy_versions (version);

CREATE TABLE identity.account_retention_obligations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id uuid NOT NULL REFERENCES identity.accounts (id),
    lifecycle_event_id uuid NOT NULL,
    retention_policy_version varchar(80),
    data_category identity.account_data_category NOT NULL,
    disposition identity.retention_disposition,
    retention_days integer,
    retain_until timestamptz,
    status identity.retention_obligation_status NOT NULL DEFAULT 'PENDING',
    failure_code varchar(80),
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT account_retention_lifecycle_event_account_fk
        FOREIGN KEY (account_id, lifecycle_event_id)
        REFERENCES identity.account_lifecycle_events (account_id, id),
    CONSTRAINT account_retention_policy_version_fk
        FOREIGN KEY (retention_policy_version)
        REFERENCES identity.account_retention_policy_versions (version),
    CONSTRAINT account_retention_days_nonnegative CHECK (retention_days IS NULL OR retention_days >= 0),
    CONSTRAINT account_retention_period_complete_or_unapproved CHECK (
        (retention_days IS NULL AND retain_until IS NULL)
        OR (retention_days IS NOT NULL AND retain_until IS NOT NULL)
    ),
    CONSTRAINT account_retention_destructive_obligation_has_period CHECK (
        disposition IS NULL OR disposition = 'RETAIN' OR retention_days IS NOT NULL
    ),
    CONSTRAINT account_retention_policy_snapshot_or_fail_closed CHECK (
        (retention_policy_version IS NOT NULL AND disposition IS NOT NULL AND failure_code IS NULL)
        OR (
            retention_policy_version IS NULL
            AND disposition IS NULL
            AND retention_days IS NULL
            AND retain_until IS NULL
            AND status = 'FAILED'
            AND failure_code = 'RETENTION_POLICY_MISSING'
        )
    ),
    CONSTRAINT account_retention_completion_timestamp_required CHECK (
        status <> 'COMPLETED' OR completed_at IS NOT NULL
    ),
    UNIQUE (lifecycle_event_id, data_category)
);

CREATE INDEX account_retention_due_idx
    ON identity.account_retention_obligations (status, retain_until);
CREATE INDEX account_retention_account_category_idx
    ON identity.account_retention_obligations (account_id, data_category);

CREATE TABLE identity.account_legal_holds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id uuid NOT NULL REFERENCES identity.accounts (id),
    data_category identity.account_data_category NOT NULL,
    status identity.legal_hold_status NOT NULL DEFAULT 'ACTIVE',
    blocks_identifier_reuse boolean NOT NULL DEFAULT false,
    basis_reference varchar(160) NOT NULL,
    applied_by varchar(120) NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now(),
    released_by varchar(120),
    released_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT account_legal_hold_release_complete CHECK (
        status <> 'RELEASED' OR (released_at IS NOT NULL AND released_by IS NOT NULL)
    ),
    CONSTRAINT account_legal_hold_release_after_apply CHECK (released_at IS NULL OR released_at >= applied_at),
    CONSTRAINT account_legal_hold_identifier_scope CHECK (
        NOT blocks_identifier_reuse OR data_category = 'CONTACT_IDENTIFIER'
    )
);

CREATE INDEX account_legal_hold_account_category_status_idx
    ON identity.account_legal_holds (account_id, data_category, status);
CREATE INDEX account_legal_hold_status_applied_idx
    ON identity.account_legal_holds (status, applied_at);
CREATE UNIQUE INDEX account_legal_hold_active_uq
    ON identity.account_legal_holds (account_id, data_category)
    WHERE status = 'ACTIVE';

CREATE TABLE identity.account_identifier_quarantines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id uuid NOT NULL REFERENCES identity.accounts (id),
    lifecycle_event_id uuid NOT NULL,
    identifier_kind varchar(20) NOT NULL,
    provider_code varchar(40) NOT NULL,
    identifier_fingerprint varchar(128) NOT NULL,
    fingerprint_key_version smallint NOT NULL,
    quarantined_at timestamptz NOT NULL,
    reuse_eligible_at timestamptz NOT NULL,
    released_at timestamptz,
    release_reason_code varchar(80),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT account_identifier_quarantine_event_account_fk
        FOREIGN KEY (account_id, lifecycle_event_id)
        REFERENCES identity.account_lifecycle_events (account_id, id),
    CONSTRAINT account_identifier_quarantine_kind_supported CHECK (
        identifier_kind IN ('EMAIL', 'OIDC_SUBJECT')
    ),
    CONSTRAINT account_identifier_quarantine_exact_period CHECK (
        reuse_eligible_at = quarantined_at + interval '30 days'
    ),
    CONSTRAINT account_identifier_quarantine_release_complete CHECK (
        released_at IS NULL
        OR (released_at >= reuse_eligible_at AND release_reason_code IS NOT NULL)
    )
);

CREATE INDEX account_identifier_quarantine_due_idx
    ON identity.account_identifier_quarantines (reuse_eligible_at, released_at);
CREATE INDEX account_identifier_quarantine_account_kind_idx
    ON identity.account_identifier_quarantines (account_id, identifier_kind);
CREATE UNIQUE INDEX account_identifier_quarantine_active_fingerprint_uq
    ON identity.account_identifier_quarantines (
        identifier_kind, provider_code, identifier_fingerprint
    )
    WHERE released_at IS NULL;

CREATE FUNCTION identity.reject_immutable_account_contract_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION '% is immutable', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$$;

CREATE TRIGGER account_lifecycle_events_append_only
BEFORE UPDATE OR DELETE ON identity.account_lifecycle_events
FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();

CREATE TRIGGER account_retention_policy_versions_immutable
BEFORE UPDATE OR DELETE ON identity.account_retention_policy_versions
FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();

CREATE TRIGGER account_retention_policy_rules_immutable
BEFORE UPDATE OR DELETE ON identity.account_retention_policy_rules
FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();

CREATE FUNCTION identity.enforce_account_lifecycle_event_chain()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    predecessor identity.account_lifecycle_events%ROWTYPE;
BEGIN
    IF NEW.previous_event_id IS NULL THEN
        IF NEW.event_sequence <> 1
           OR NEW.lifecycle_version <> 1
           OR NEW.previous_status IS NOT NULL THEN
            RAISE EXCEPTION 'account lifecycle genesis must be sequence and version 1 without a predecessor'
                USING ERRCODE = '23514';
        END IF;
        RETURN NULL;
    END IF;

    SELECT * INTO predecessor
    FROM identity.account_lifecycle_events event
    WHERE event.account_id = NEW.account_id
      AND event.id = NEW.previous_event_id;

    IF predecessor.id IS NULL
       OR predecessor.event_sequence + 1 <> NEW.event_sequence
       OR predecessor.new_status IS DISTINCT FROM NEW.previous_status THEN
        RAISE EXCEPTION 'account lifecycle event must continue the exact predecessor sequence and status'
            USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER account_lifecycle_event_chain_guard
AFTER INSERT ON identity.account_lifecycle_events
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION identity.enforce_account_lifecycle_event_chain();

CREATE FUNCTION identity.create_account_lifecycle_genesis()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    genesis_event_id uuid := gen_random_uuid();
BEGIN
    INSERT INTO identity.account_lifecycle_events (
        id, account_id, event_sequence, previous_event_id, lifecycle_version,
        previous_status, new_status, command_type, actor_type, actor_id,
        correlation_id, idempotency_key, request_hash, reason_code, occurred_at
    ) VALUES (
        genesis_event_id, NEW.id, 1, NULL, 1,
        NULL, NEW.lifecycle_status, 'ACCOUNT_CREATED', 'SYSTEM', NULL,
        gen_random_uuid(), 'account-genesis:' || NEW.id::text,
        md5(NEW.id::text || ':genesis') || md5(NEW.id::text || ':genesis:2'),
        'ACCOUNT_CREATED', NEW.created_at
    );

    UPDATE identity.accounts
    SET lifecycle_version = 1,
        last_lifecycle_event_id = genesis_event_id
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER account_lifecycle_genesis
AFTER INSERT ON identity.accounts
FOR EACH ROW EXECUTE FUNCTION identity.create_account_lifecycle_genesis();

CREATE FUNCTION identity.enforce_account_lifecycle_projection_head()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    target_account_id uuid;
    projection identity.accounts%ROWTYPE;
    head identity.account_lifecycle_events%ROWTYPE;
BEGIN
    IF TG_TABLE_NAME = 'accounts' THEN
        target_account_id := NEW.id;
    ELSE
        target_account_id := NEW.account_id;
    END IF;

    SELECT * INTO projection
    FROM identity.accounts
    WHERE id = target_account_id;

    SELECT * INTO head
    FROM identity.account_lifecycle_events
    WHERE account_id = projection.id
    ORDER BY event_sequence DESC
    LIMIT 1;

    IF head.id IS NULL
       OR projection.last_lifecycle_event_id IS DISTINCT FROM head.id
       OR projection.lifecycle_version IS DISTINCT FROM head.lifecycle_version
       OR projection.lifecycle_status IS DISTINCT FROM head.new_status THEN
        RAISE EXCEPTION 'account lifecycle projection must match its event head'
            USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER account_lifecycle_projection_head_guard
AFTER INSERT ON identity.account_lifecycle_events
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION identity.enforce_account_lifecycle_projection_head();

CREATE CONSTRAINT TRIGGER account_lifecycle_account_projection_guard
AFTER UPDATE ON identity.accounts
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION identity.enforce_account_lifecycle_projection_head();

CREATE FUNCTION identity.guard_identifier_quarantine_release()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.released_at IS NULL AND NEW.released_at IS NOT NULL THEN
        IF NEW.released_at < NEW.reuse_eligible_at THEN
            RAISE EXCEPTION 'identifier quarantine cannot be released before reuse_eligible_at'
                USING ERRCODE = '23514';
        END IF;
        IF EXISTS (
            SELECT 1
            FROM identity.account_legal_holds hold
            WHERE hold.account_id = NEW.account_id
              AND hold.data_category = 'CONTACT_IDENTIFIER'
              AND hold.status = 'ACTIVE'
              AND hold.blocks_identifier_reuse
        ) THEN
            RAISE EXCEPTION 'active legal hold blocks identifier reuse'
                USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER account_identifier_quarantine_release_guard
BEFORE UPDATE ON identity.account_identifier_quarantines
FOR EACH ROW EXECUTE FUNCTION identity.guard_identifier_quarantine_release();

COMMENT ON TABLE identity.account_lifecycle_events IS
    'Append-only A12 lifecycle evidence; every predecessor has the same account, adjacent sequence, and matching status, and the account projection must point at its head.';
COMMENT ON TABLE identity.account_retention_obligations IS
    'Policy snapshot projection. A missing approved policy is represented only by RETENTION_POLICY_MISSING and denies physical deletion.';
COMMENT ON TABLE identity.account_identifier_quarantines IS
    'Keyed HMAC tombstones block email or OIDC subject reuse for exactly 30x24 hours after CLOSED; plaintext identifiers are forbidden.';
