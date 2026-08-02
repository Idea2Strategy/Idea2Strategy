-- A12 close coordination and a non-canonical product proposal evidence record.

CREATE TYPE identity.account_closure_domain AS ENUM (
    'BOT', 'TRADING', 'COMPETITION', 'NOTIFICATION', 'INTEGRATION'
);
CREATE TYPE identity.account_closure_readiness_status AS ENUM (
    'FREEZE_REQUESTED', 'FROZEN', 'SETTLEMENT_REQUIRED', 'SETTLED', 'BLOCKED'
);

CREATE TABLE identity.account_closure_runs (
    correlation_id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES identity.accounts (id),
    lifecycle_version bigint NOT NULL,
    cancellation_deadline_at timestamptz NOT NULL,
    generation bigint NOT NULL DEFAULT 0,
    started_at timestamptz NOT NULL,
    last_checked_at timestamptz NOT NULL,
    closed_at timestamptz,
    UNIQUE (account_id, lifecycle_version, cancellation_deadline_at)
);

CREATE TABLE identity.account_closure_readiness (
    correlation_id uuid NOT NULL REFERENCES identity.account_closure_runs (correlation_id) ON DELETE CASCADE,
    generation bigint NOT NULL,
    account_id uuid NOT NULL REFERENCES identity.accounts (id),
    domain identity.account_closure_domain NOT NULL,
    status identity.account_closure_readiness_status NOT NULL,
    reason_code varchar(80) NOT NULL,
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    observed_at timestamptz NOT NULL,
    PRIMARY KEY (correlation_id, generation, domain),
    CONSTRAINT account_closure_readiness_generation_positive CHECK (generation > 0),
    CONSTRAINT account_closure_readiness_evidence_object CHECK (jsonb_typeof(evidence) = 'object')
);

CREATE INDEX account_closure_readiness_account_idx
    ON identity.account_closure_readiness (account_id, status, observed_at);

CREATE TABLE operations.account_integrations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id uuid NOT NULL REFERENCES identity.accounts (id),
    integration_code varchar(80) NOT NULL,
    status varchar(20) NOT NULL,
    freeze_requested_at timestamptz,
    closed_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT account_integration_status_supported CHECK (status IN ('ACTIVE', 'CLOSING', 'CLOSED')),
    CONSTRAINT account_integration_closing_timestamp CHECK (status <> 'CLOSING' OR freeze_requested_at IS NOT NULL),
    CONSTRAINT account_integration_closed_timestamp CHECK (status <> 'CLOSED' OR closed_at IS NOT NULL),
    UNIQUE (account_id, integration_code)
);

CREATE TABLE identity.account_retention_policy_proposals (
    proposal_key varchar(80) PRIMARY KEY,
    canonical_status varchar(20) NOT NULL DEFAULT 'PROPOSED',
    proposal_document jsonb NOT NULL,
    product_approver_subject varchar(160) NOT NULL,
    product_approval_evidence text NOT NULL,
    product_approved_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT account_retention_policy_proposal_status CHECK (canonical_status = 'PROPOSED'),
    CONSTRAINT account_retention_policy_proposal_document_object CHECK (jsonb_typeof(proposal_document) = 'object')
);

INSERT INTO identity.account_retention_policy_proposals
    (proposal_key, proposal_document, product_approver_subject,
     product_approval_evidence, product_approved_at)
VALUES (
    'A12-2026-08-02',
    '{
      "retentionStartsAt":"CLOSED",
      "profile":{"disposition":"ANONYMIZE","days":0},
      "emailOidcBinding":{"disposition":"RELEASE","days":30},
      "consentTradingSecurityAudit":{"disposition":"RETAIN","days":1825},
      "competition":{"disposition":"ANONYMIZE","days":365},
      "botStrategy":{"disposition":"DELETE","days":30},
      "generalOperationsLog":{"disposition":"DELETE","days":365}
    }'::jsonb,
    'user:kcrmin',
    'https://github.com/Idea2Strategy/Idea2Strategy-backend/issues/127#issuecomment-5156817219',
    '2026-08-02 09:20:30+00'
)
ON CONFLICT (proposal_key) DO NOTHING;

CREATE TRIGGER account_retention_policy_proposals_immutable
BEFORE UPDATE OR DELETE ON identity.account_retention_policy_proposals
FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();

CREATE FUNCTION identity.require_active_account(target_account_id uuid, operation_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM identity.accounts account
        WHERE account.id = target_account_id AND account.lifecycle_status = 'ACTIVE'
        FOR SHARE
    ) THEN
        RAISE EXCEPTION 'account is not ACTIVE for %', operation_name USING ERRCODE = '55000';
    END IF;
END;
$$;

CREATE FUNCTION identity.guard_owner_account_creation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    PERFORM identity.require_active_account(NEW.owner_account_id, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME);
    RETURN NEW;
END;
$$;

CREATE TRIGGER bot_account_creation_gate
BEFORE INSERT ON bot.bots
FOR EACH ROW EXECUTE FUNCTION identity.guard_owner_account_creation();

CREATE FUNCTION identity.guard_competition_participation_creation()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    actual_owner_account_id uuid;
BEGIN
    SELECT owner_account_id INTO actual_owner_account_id
    FROM bot.bots WHERE id = NEW.bot_id FOR SHARE;
    IF actual_owner_account_id IS NULL OR actual_owner_account_id <> NEW.owner_account_id THEN
        RAISE EXCEPTION 'participation owner does not match bot owner' USING ERRCODE = '55000';
    END IF;
    PERFORM identity.require_active_account(
        actual_owner_account_id, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME);
    RETURN NEW;
END;
$$;

CREATE TRIGGER competition_participation_creation_gate
BEFORE INSERT ON competition.participations
FOR EACH ROW EXECUTE FUNCTION identity.guard_competition_participation_creation();

CREATE FUNCTION identity.guard_account_scoped_activation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_TABLE_NAME = 'notification_preferences' THEN
        IF NEW.enabled THEN
            PERFORM identity.require_active_account(NEW.account_id, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME);
        END IF;
    ELSIF TG_TABLE_NAME = 'account_integrations' THEN
        IF NEW.status = 'ACTIVE' THEN
            PERFORM identity.require_active_account(NEW.account_id, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME);
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER notification_preference_activation_gate
BEFORE INSERT OR UPDATE OF enabled ON operations.notification_preferences
FOR EACH ROW EXECUTE FUNCTION identity.guard_account_scoped_activation();

CREATE TRIGGER account_integration_activation_gate
BEFORE INSERT OR UPDATE OF status ON operations.account_integrations
FOR EACH ROW EXECUTE FUNCTION identity.guard_account_scoped_activation();

CREATE FUNCTION identity.guard_trading_order_creation()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    owner_id uuid;
BEGIN
    SELECT owner_account_id INTO owner_id FROM bot.bots WHERE id = NEW.bot_id;
    PERFORM identity.require_active_account(owner_id, 'trading.orders');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trading_order_account_creation_gate
BEFORE INSERT ON trading.orders
FOR EACH ROW EXECUTE FUNCTION identity.guard_trading_order_creation();

COMMENT ON TABLE identity.account_closure_readiness IS
    'Generation-scoped fail-closed evidence. CLOSED requires TRADING=SETTLED and every other domain=FROZEN.';
COMMENT ON TABLE identity.account_retention_policy_proposals IS
    'Product-approved recommendation only. It is excluded from canonical policy selection until a canonical policy PR is approved.';
COMMENT ON TABLE operations.account_integrations IS
    'Concrete shared-database boundary for external integrations; missing rows mean no integration, never an assumed remote success.';
