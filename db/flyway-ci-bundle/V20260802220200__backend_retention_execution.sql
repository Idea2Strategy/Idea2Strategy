INSERT INTO identity.account_retention_policy_versions
    (version, effective_from, approved_at, approved_by, basis_reference)
VALUES (
    'A12-2026-08-02',
    '2026-08-02 10:54:25+00',
    '2026-08-02 09:20:30+00',
    'user:kcrmin',
    'https://github.com/Idea2Strategy/Idea2Strategy/pull/125'
)
ON CONFLICT (version) DO NOTHING;

INSERT INTO identity.account_retention_policy_rules
    (policy_version, data_category, disposition, retention_days, legal_basis_code)
VALUES
    ('A12-2026-08-02', 'PROFILE', 'ANONYMIZE', 0, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'CONTACT_IDENTIFIER', 'DELETE', 30, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'AUTH_CREDENTIAL', 'DELETE', 0, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'POLICY_CONSENT', 'RETAIN', 1825, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'ACCOUNT_LIFECYCLE_AUDIT', 'RETAIN', 1825, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'TRADING_FINANCIAL_RECORD', 'RETAIN', 1825, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'BOT_STRATEGY_EVALUATION', 'RETAIN', NULL, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'BOT_STRATEGY_PRIVATE_DATA', 'DELETE', 30, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'COMPETITION_RESULT_EVIDENCE', 'ANONYMIZE', 365, 'A12-PRODUCT-APPROVAL'),
    ('A12-2026-08-02', 'OPERATIONS_DELIVERY_LOG', 'DELETE', 365, 'A12-PRODUCT-APPROVAL')
ON CONFLICT (policy_version, data_category) DO NOTHING;

ALTER TABLE identity.account_retention_policy_rules
    ADD CONSTRAINT account_retention_legacy_combined_retain_only CHECK (
        data_category <> 'BOT_STRATEGY_EVALUATION'
        OR (disposition = 'RETAIN' AND retention_days IS NULL)
    );

-- #141 could close accounts after this policy became effective but before this
-- executable policy seed shipped. Upgrade those fail-closed snapshots only;
-- earlier CLOSED events deliberately remain RETENTION_POLICY_MISSING.
UPDATE identity.account_retention_obligations obligation
SET retention_policy_version = rule.policy_version,
    disposition = rule.disposition,
    retention_days = rule.retention_days,
    retain_until = CASE WHEN rule.retention_days IS NULL THEN NULL
        ELSE event.occurred_at + make_interval(days => rule.retention_days) END,
    status = 'PENDING',
    failure_code = NULL,
    completed_at = NULL
FROM identity.account_lifecycle_events event
JOIN identity.account_retention_policy_rules rule
  ON rule.policy_version = 'A12-2026-08-02'
JOIN identity.account_retention_policy_versions policy
  ON policy.version = rule.policy_version
WHERE obligation.lifecycle_event_id = event.id
  AND rule.data_category = obligation.data_category
  AND event.command_type = 'ACCOUNT_CLOSED'
  AND event.occurred_at >= policy.effective_from
  AND obligation.status = 'FAILED'
  AND obligation.failure_code = 'RETENTION_POLICY_MISSING'
  AND obligation.retention_policy_version IS NULL;

INSERT INTO identity.account_retention_obligations
    (account_id, lifecycle_event_id, retention_policy_version, data_category,
     disposition, retention_days, retain_until, status)
SELECT event.account_id, event.id, rule.policy_version, rule.data_category,
       rule.disposition, rule.retention_days,
       CASE WHEN rule.retention_days IS NULL THEN NULL
            ELSE event.occurred_at + make_interval(days => rule.retention_days) END,
       'PENDING'
FROM identity.account_lifecycle_events event
JOIN identity.account_retention_policy_versions policy
  ON policy.version = 'A12-2026-08-02'
JOIN identity.account_retention_policy_rules rule
  ON rule.policy_version = policy.version
WHERE event.command_type = 'ACCOUNT_CLOSED'
  AND event.occurred_at >= policy.effective_from
  AND EXISTS (
      SELECT 1 FROM identity.account_retention_obligations existing
      WHERE existing.lifecycle_event_id = event.id
        AND existing.retention_policy_version = policy.version
  )
  AND NOT EXISTS (
      SELECT 1 FROM identity.account_retention_obligations existing
      WHERE existing.lifecycle_event_id = event.id
        AND existing.data_category = rule.data_category
  );

CREATE FUNCTION identity.lock_account_retention_category()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    target_account_id uuid := CASE WHEN TG_OP = 'DELETE' THEN OLD.account_id ELSE NEW.account_id END;
    target_category identity.account_data_category :=
        CASE WHEN TG_OP = 'DELETE' THEN OLD.data_category ELSE NEW.data_category END;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended(
        'account-retention:' || target_account_id::text, 0));
    IF TG_OP <> 'DELETE' AND NEW.status = 'ACTIVE' THEN
        UPDATE identity.account_retention_obligations
        SET status = 'HELD', failure_code = NULL
        WHERE account_id = target_account_id
          AND data_category = target_category
          AND status = 'PENDING';
        INSERT INTO identity.account_retention_execution_attempts
            (obligation_id, account_id, data_category, correlation_id, legal_hold_id,
             outcome, evidence, occurred_at)
        SELECT obligation.id, obligation.account_id, obligation.data_category,
               NEW.id, NEW.id, 'HELD',
               jsonb_build_object('legalHoldId', NEW.id::text,
                                  'basisReference', NEW.basis_reference),
               NEW.applied_at
        FROM identity.account_retention_obligations obligation
        WHERE obligation.account_id = target_account_id
          AND obligation.data_category = target_category
          AND obligation.status = 'HELD'
        ON CONFLICT (obligation_id, legal_hold_id, outcome)
            WHERE outcome = 'HELD' DO NOTHING;
    ELSIF (TG_OP = 'DELETE'
           OR (TG_OP = 'UPDATE' AND OLD.status = 'ACTIVE' AND NEW.status <> 'ACTIVE'))
          AND NOT EXISTS (
              SELECT 1 FROM identity.account_legal_holds other_hold
              WHERE other_hold.account_id = target_account_id
                AND other_hold.data_category = target_category
                AND other_hold.status = 'ACTIVE'
                AND other_hold.id <> OLD.id
          ) THEN
        UPDATE identity.account_retention_obligations
        SET status = 'PENDING'
        WHERE account_id = target_account_id
          AND data_category = target_category
          AND status = 'HELD';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE TRIGGER account_legal_hold_retention_lock
BEFORE INSERT OR UPDATE OR DELETE ON identity.account_legal_holds
FOR EACH ROW EXECUTE FUNCTION identity.lock_account_retention_category();

CREATE FUNCTION identity.lock_identifier_quarantine_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended(
        'account-retention:' || NEW.account_id::text, 0));
    PERFORM pg_advisory_xact_lock(hashtextextended(
        NEW.identifier_kind || ':' || NEW.provider_code || ':'
        || NEW.fingerprint_key_version::text || ':' || NEW.identifier_fingerprint, 0));
    RETURN NEW;
END;
$$;

CREATE TRIGGER account_identifier_quarantine_category_lock
BEFORE INSERT OR UPDATE ON identity.account_identifier_quarantines
FOR EACH ROW EXECUTE FUNCTION identity.lock_identifier_quarantine_change();

ALTER TABLE competition.rooms
    DROP CONSTRAINT competition_room_organizer_actor,
    ADD COLUMN creator_anonymized_at timestamptz,
    ADD CONSTRAINT competition_room_organizer_actor CHECK (
        (organizer_type = 'USER'
         AND ((creator_account_id IS NOT NULL AND creator_anonymized_at IS NULL)
              OR (creator_account_id IS NULL AND creator_anonymized_at IS NOT NULL))
         AND created_by_operator_id IS NULL)
        OR
        (organizer_type = 'PLATFORM' AND creator_account_id IS NULL
         AND creator_anonymized_at IS NULL AND created_by_operator_id IS NOT NULL)
    );

ALTER TABLE competition.participations
    ALTER COLUMN owner_account_id DROP NOT NULL,
    ADD COLUMN owner_anonymized_at timestamptz,
    ADD CONSTRAINT competition_participation_owner_state CHECK (
        (owner_account_id IS NOT NULL AND owner_anonymized_at IS NULL)
        OR (owner_account_id IS NULL AND owner_anonymized_at IS NOT NULL)
    );

ALTER TABLE bot.bots
    ALTER COLUMN owner_account_id DROP NOT NULL,
    ADD COLUMN owner_anonymized_at timestamptz,
    ADD CONSTRAINT bot_owner_state CHECK (
        (owner_account_id IS NOT NULL AND owner_anonymized_at IS NULL)
        OR (owner_account_id IS NULL AND owner_anonymized_at IS NOT NULL)
    );

CREATE TABLE identity.account_retention_execution_attempts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    obligation_id uuid NOT NULL REFERENCES identity.account_retention_obligations (id),
    account_id uuid NOT NULL REFERENCES identity.accounts (id),
    data_category identity.account_data_category NOT NULL,
    correlation_id uuid NOT NULL,
    legal_hold_id uuid,
    outcome varchar(20) NOT NULL,
    failure_code varchar(80),
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    CONSTRAINT account_retention_attempt_outcome CHECK (outcome IN ('COMPLETED', 'HELD', 'FAILED')),
    CONSTRAINT account_retention_attempt_failure_shape CHECK (
        (outcome = 'FAILED' AND failure_code IS NOT NULL)
        OR (outcome <> 'FAILED' AND failure_code IS NULL)
    )
);

CREATE INDEX account_retention_attempt_obligation_idx
    ON identity.account_retention_execution_attempts (obligation_id, occurred_at);
CREATE UNIQUE INDEX account_retention_attempt_held_state_uq
    ON identity.account_retention_execution_attempts (obligation_id, legal_hold_id, outcome)
    WHERE outcome = 'HELD';

CREATE TRIGGER account_retention_execution_attempts_append_only
BEFORE UPDATE OR DELETE ON identity.account_retention_execution_attempts
FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();

COMMENT ON TABLE identity.account_retention_execution_attempts IS
    'Append-only per-account retention worker outcomes. Each destructive action and legal-hold skip is independently auditable.';

CREATE FUNCTION identity.delete_proven_private_bots(target_account_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    candidate_ids uuid[];
    deleted_count integer;
BEGIN
    IF EXISTS (
        SELECT 1 FROM bot.bots candidate
        WHERE candidate.owner_account_id = target_account_id
          AND NOT EXISTS (SELECT 1 FROM competition.participations p WHERE p.bot_id = candidate.id)
          AND (
              EXISTS (SELECT 1 FROM trading.order_intent_batches x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.orders x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.order_groups x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.resource_reservations x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.fills x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.ledger_accounts x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.ledger_transactions x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.position_lots x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.system_close_actions x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.flow_position_projections x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.bot_budget_projections x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.partition_position_projections x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM trading.partition_budget_projections x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM backtest.runs x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM performance.bot_current_projections x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM performance.bot_snapshots x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM performance.series_manifests x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM operations.notification_preferences x WHERE x.bot_id = candidate.id)
              OR EXISTS (SELECT 1 FROM operations.notifications x WHERE x.bot_id = candidate.id)
          )
    ) THEN
        RAISE EXCEPTION 'PRIVATE_BOT_EVIDENCE_CONFLICT' USING ERRCODE = '55000';
    END IF;

    SELECT coalesce(array_agg(candidate.id), ARRAY[]::uuid[]) INTO candidate_ids
    FROM bot.bots candidate
    WHERE candidate.owner_account_id = target_account_id
      AND NOT EXISTS (SELECT 1 FROM competition.participations p WHERE p.bot_id = candidate.id);

    DELETE FROM bot.continuation_deadlines WHERE bot_id = ANY(candidate_ids);
    PERFORM trading.delete_private_bot_runtime(candidate_ids, false);
    DELETE FROM bot.flow_feature_requirements requirement
    USING bot.flows flow, bot.bot_partitions partition
    WHERE requirement.flow_id = flow.id AND flow.partition_id = partition.id
      AND partition.bot_id = ANY(candidate_ids);
    DELETE FROM bot.flow_instruments instrument
    USING bot.flows flow, bot.bot_partitions partition
    WHERE instrument.flow_id = flow.id AND flow.partition_id = partition.id
      AND partition.bot_id = ANY(candidate_ids);
    DELETE FROM bot.flow_time_triggers time_trigger
    USING bot.flows flow, bot.bot_partitions partition
    WHERE time_trigger.flow_id = flow.id AND flow.partition_id = partition.id
      AND partition.bot_id = ANY(candidate_ids);
    DELETE FROM bot.flows flow USING bot.bot_partitions partition
    WHERE flow.partition_id = partition.id AND partition.bot_id = ANY(candidate_ids);
    DELETE FROM bot.bot_partitions WHERE bot_id = ANY(candidate_ids);
    DELETE FROM bot.launch_snapshots WHERE bot_id = ANY(candidate_ids);
    DELETE FROM bot.launch_configurations WHERE bot_id = ANY(candidate_ids);
    UPDATE bot.bots SET execution_block_event_id = NULL WHERE id = ANY(candidate_ids);
    PERFORM trading.delete_private_bot_runtime(candidate_ids, true);
    DELETE FROM bot.bots WHERE id = ANY(candidate_ids);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

COMMENT ON FUNCTION identity.delete_proven_private_bots(uuid) IS
    'Physically deletes only non-competition bots with no retained trading/backtest/performance/operations evidence; ambiguity fails closed.';

CREATE FUNCTION competition.enforce_anonymized_bot_participation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.owner_account_id IS NULL AND EXISTS (
        SELECT 1 FROM competition.participations participation
        WHERE participation.bot_id = NEW.id
          AND participation.owner_account_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'an anonymized competition bot requires anonymized participation ownership'
            USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER competition_bot_owner_anonymization_guard
AFTER UPDATE OF owner_account_id, owner_anonymized_at ON bot.bots
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION competition.enforce_anonymized_bot_participation();
