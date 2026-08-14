-- Idea2Strategy pre-launch V1 baseline.
-- Generated from the last verified historical Flyway bundle.
-- Future schema changes must use new timestamped Flyway migrations.
--
-- PostgreSQL database dump
--



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: backtest; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA backtest;


--
-- Name: bot; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA bot;


--
-- Name: competition; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA competition;


--
-- Name: identity; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA identity;


--
-- Name: market_data; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA market_data;


--
-- Name: operations; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA operations;


--
-- Name: performance; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA performance;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: strategy; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA strategy;


--
-- Name: trading; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA trading;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: run_lane; Type: TYPE; Schema: backtest; Owner: -
--

CREATE TYPE backtest.run_lane AS ENUM (
    'BASIC',
    'CUSTOM',
    'COMPETITION'
);


--
-- Name: run_status; Type: TYPE; Schema: backtest; Owner: -
--

CREATE TYPE backtest.run_status AS ENUM (
    'QUEUED',
    'RUNNING',
    'COMPLETED',
    'FAILED',
    'UNAVAILABLE',
    'CANCELLED'
);


--
-- Name: lifecycle_status; Type: TYPE; Schema: bot; Owner: -
--

CREATE TYPE bot.lifecycle_status AS ENUM (
    'RUNNING',
    'STOPPING',
    'STOPPED'
);


--
-- Name: runtime_value_type; Type: TYPE; Schema: bot; Owner: -
--

CREATE TYPE bot.runtime_value_type AS ENUM (
    'BOOLEAN',
    'INTEGER',
    'DECIMAL',
    'STRING',
    'TIMESTAMP',
    'JSON'
);


--
-- Name: time_trigger_type; Type: TYPE; Schema: bot; Owner: -
--

CREATE TYPE bot.time_trigger_type AS ENUM (
    'MARKET_OPEN',
    'MARKET_CLOSE',
    'SCHEDULE'
);


--
-- Name: competition_type; Type: TYPE; Schema: competition; Owner: -
--

CREATE TYPE competition.competition_type AS ENUM (
    'LIVE_PAPER',
    'BACKTEST'
);


--
-- Name: invitation_credential_type; Type: TYPE; Schema: competition; Owner: -
--

CREATE TYPE competition.invitation_credential_type AS ENUM (
    'LINK',
    'CODE'
);


--
-- Name: leaderboard_status; Type: TYPE; Schema: competition; Owner: -
--

CREATE TYPE competition.leaderboard_status AS ENUM (
    'PUBLISHED',
    'FINAL'
);


--
-- Name: organizer_type; Type: TYPE; Schema: competition; Owner: -
--

CREATE TYPE competition.organizer_type AS ENUM (
    'PLATFORM',
    'USER'
);


--
-- Name: participation_status; Type: TYPE; Schema: competition; Owner: -
--

CREATE TYPE competition.participation_status AS ENUM (
    'REGISTERED',
    'ACTIVE',
    'EVALUATING',
    'WITHDRAWN',
    'EXPELLED',
    'COMPLETED',
    'EVALUATION_FAILED',
    'PENDING_LEDGER'
);


--
-- Name: post_room_action; Type: TYPE; Schema: competition; Owner: -
--

CREATE TYPE competition.post_room_action AS ENUM (
    'CONTINUE_PRIVATE',
    'STOP'
);


--
-- Name: room_access_type; Type: TYPE; Schema: competition; Owner: -
--

CREATE TYPE competition.room_access_type AS ENUM (
    'PUBLIC',
    'SECRET'
);


--
-- Name: room_status; Type: TYPE; Schema: competition; Owner: -
--

CREATE TYPE competition.room_status AS ENUM (
    'DRAFT',
    'RECRUITING',
    'EVALUATING',
    'ENDED',
    'CANCELLED',
    'INVALIDATED'
);


--
-- Name: account_closure_domain; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.account_closure_domain AS ENUM (
    'BOT',
    'TRADING',
    'COMPETITION',
    'NOTIFICATION',
    'INTEGRATION'
);


--
-- Name: account_closure_readiness_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.account_closure_readiness_status AS ENUM (
    'FREEZE_REQUESTED',
    'FROZEN',
    'SETTLEMENT_REQUIRED',
    'SETTLED',
    'BLOCKED'
);


--
-- Name: account_data_category; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.account_data_category AS ENUM (
    'PROFILE',
    'CONTACT_IDENTIFIER',
    'AUTH_CREDENTIAL',
    'POLICY_CONSENT',
    'ACCOUNT_LIFECYCLE_AUDIT',
    'TRADING_FINANCIAL_RECORD',
    'BOT_STRATEGY_EVALUATION',
    'OPERATIONS_DELIVERY_LOG',
    'BOT_STRATEGY_PRIVATE_DATA',
    'COMPETITION_RESULT_EVIDENCE'
);


--
-- Name: account_lifecycle_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.account_lifecycle_status AS ENUM (
    'PENDING_VERIFICATION',
    'ACTIVE',
    'DORMANT',
    'CLOSING',
    'CLOSED'
);


--
-- Name: auth_provider_type; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.auth_provider_type AS ENUM (
    'PASSWORD',
    'OIDC'
);


--
-- Name: consent_decision; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.consent_decision AS ENUM (
    'ACCEPTED',
    'DECLINED',
    'WITHDRAWN'
);


--
-- Name: delegated_authorization_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.delegated_authorization_status AS ENUM (
    'ACTIVE',
    'EXPIRED',
    'REVOKED'
);


--
-- Name: delegated_credential_type; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.delegated_credential_type AS ENUM (
    'ACCESS_TOKEN',
    'REFRESH_TOKEN'
);


--
-- Name: delegated_expiry_mode; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.delegated_expiry_mode AS ENUM (
    'SESSION_END',
    'AT_TIME',
    'UNTIL_REVOKED'
);


--
-- Name: delegated_scope; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.delegated_scope AS ENUM (
    'ACCOUNT_RESOURCE_READ',
    'STRATEGY_CREATE',
    'STRATEGY_COPY',
    'STRATEGY_EDIT',
    'STRATEGY_VALIDATE'
);


--
-- Name: device_authorization_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.device_authorization_status AS ENUM (
    'PENDING',
    'APPROVED',
    'CONSUMED',
    'DENIED',
    'EXPIRED'
);


--
-- Name: email_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.email_status AS ENUM (
    'PENDING_VERIFICATION',
    'VERIFIED',
    'REVOKED'
);


--
-- Name: legal_hold_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.legal_hold_status AS ENUM (
    'ACTIVE',
    'RELEASED'
);


--
-- Name: login_identity_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.login_identity_status AS ENUM (
    'PENDING',
    'ACTIVE',
    'REPLACED',
    'DISABLED'
);


--
-- Name: retention_disposition; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.retention_disposition AS ENUM (
    'DELETE',
    'ANONYMIZE',
    'RETAIN'
);


--
-- Name: retention_obligation_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.retention_obligation_status AS ENUM (
    'PENDING',
    'HELD',
    'COMPLETED',
    'FAILED'
);


--
-- Name: sanction_status; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.sanction_status AS ENUM (
    'ACTIVE',
    'LIFTED',
    'EXPIRED'
);


--
-- Name: theme_preference; Type: TYPE; Schema: identity; Owner: -
--

CREATE TYPE identity.theme_preference AS ENUM (
    'LIGHT',
    'DARK',
    'SYSTEM'
);


--
-- Name: TYPE theme_preference; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TYPE identity.theme_preference IS 'Account-synchronized display preference. It does not affect trading, market-time calculations, or authorization.';


--
-- Name: asset_type; Type: TYPE; Schema: market_data; Owner: -
--

CREATE TYPE market_data.asset_type AS ENUM (
    'STOCK',
    'ETF',
    'INDEX'
);


--
-- Name: dataset_status; Type: TYPE; Schema: market_data; Owner: -
--

CREATE TYPE market_data.dataset_status AS ENUM (
    'BUILDING',
    'AVAILABLE',
    'QUARANTINED',
    'SUPERSEDED',
    'DELETED'
);


--
-- Name: partition_granularity; Type: TYPE; Schema: market_data; Owner: -
--

CREATE TYPE market_data.partition_granularity AS ENUM (
    'DAY',
    'WEEK',
    'MONTH',
    'YEAR'
);


--
-- Name: batch_attempt_outcome; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.batch_attempt_outcome AS ENUM (
    'SUCCEEDED',
    'RETRY_SCHEDULED',
    'QUARANTINED',
    'LEASE_EXPIRED',
    'SKIPPED'
);


--
-- Name: batch_item_status; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.batch_item_status AS ENUM (
    'PENDING',
    'CLAIMED',
    'SUCCEEDED',
    'QUARANTINED',
    'SKIPPED'
);


--
-- Name: batch_job_version_status; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.batch_job_version_status AS ENUM (
    'DRAFT',
    'ACTIVE',
    'RETIRED'
);


--
-- Name: batch_run_status; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.batch_run_status AS ENUM (
    'RUNNING',
    'SUCCEEDED',
    'PARTIAL_FAILED',
    'FAILED',
    'CANCELLED'
);


--
-- Name: case_actor_type; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.case_actor_type AS ENUM (
    'ACCOUNT',
    'OPERATOR',
    'SYSTEM'
);


--
-- Name: case_command_type; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.case_command_type AS ENUM (
    'SUBMIT',
    'ADD_EVIDENCE'
);


--
-- Name: case_event_type; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.case_event_type AS ENUM (
    'SUBMITTED',
    'EVIDENCE_ADDED',
    'INFORMATION_REQUESTED',
    'REVIEW_STARTED',
    'RESOLVED',
    'REJECTED',
    'ASSIGNED',
    'REASSIGNED',
    'UNASSIGNED',
    'SANCTION_APPLIED',
    'SANCTION_RELEASED',
    'INFORMATION_RESPONSE_DEADLINE_EXPIRED'
);


--
-- Name: case_event_visibility; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.case_event_visibility AS ENUM (
    'USER_VISIBLE',
    'OPERATOR_ONLY'
);


--
-- Name: case_status; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.case_status AS ENUM (
    'OPEN',
    'NEEDS_INFORMATION',
    'UNDER_REVIEW',
    'RESOLVED',
    'REJECTED'
);


--
-- Name: case_type; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.case_type AS ENUM (
    'INQUIRY',
    'REPORT',
    'APPEAL'
);


--
-- Name: consumer_receipt_status; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.consumer_receipt_status AS ENUM (
    'PROCESSING',
    'COMPLETED',
    'RETRYABLE_FAILURE',
    'PERMANENT_FAILURE'
);


--
-- Name: outbox_attempt_outcome; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.outbox_attempt_outcome AS ENUM (
    'PUBLISHED',
    'RETRY_SCHEDULED',
    'DEAD_LETTERED',
    'LEASE_EXPIRED'
);


--
-- Name: outbox_delivery_status; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.outbox_delivery_status AS ENUM (
    'PENDING',
    'CLAIMED',
    'PUBLISHED',
    'DEAD_LETTERED'
);


--
-- Name: work_status; Type: TYPE; Schema: operations; Owner: -
--

CREATE TYPE operations.work_status AS ENUM (
    'PENDING',
    'RUNNING',
    'SUCCEEDED',
    'FAILED',
    'CANCELLED',
    'SKIPPED'
);


--
-- Name: snapshot_type; Type: TYPE; Schema: performance; Owner: -
--

CREATE TYPE performance.snapshot_type AS ENUM (
    'ET_DAILY_CLOSE',
    'ROOM_START',
    'ROOM_END',
    'BOT_STOP',
    'LEADERBOARD_CUTOFF'
);


--
-- Name: object_status; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.object_status AS ENUM (
    'STAGED',
    'AVAILABLE',
    'QUARANTINED',
    'SUPERSEDED',
    'DELETED'
);


--
-- Name: strategy_mode; Type: TYPE; Schema: strategy; Owner: -
--

CREATE TYPE strategy.strategy_mode AS ENUM (
    'BASIC',
    'PRO'
);


--
-- Name: fill_adjustment_type; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.fill_adjustment_type AS ENUM (
    'CORRECTION',
    'REVERSAL'
);


--
-- Name: intent_decision; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.intent_decision AS ENUM (
    'APPROVED',
    'REJECTED',
    'REDUCED',
    'NETTED',
    'CONFLICTED'
);


--
-- Name: intent_origin_type; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.intent_origin_type AS ENUM (
    'FLOW_EVALUATION',
    'SYSTEM_STOP_LIQUIDATION',
    'SYSTEM_FORCED_BUY_IN',
    'CORPORATE_ACTION'
);


--
-- Name: ledger_direction; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.ledger_direction AS ENUM (
    'DEBIT',
    'CREDIT'
);


--
-- Name: lot_movement_type; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.lot_movement_type AS ENUM (
    'OPEN',
    'CLOSE',
    'CORPORATE_ACTION_ADJUSTMENT',
    'CORRECTION',
    'REVERSAL'
);


--
-- Name: lot_side; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.lot_side AS ENUM (
    'LONG',
    'SHORT'
);


--
-- Name: order_group_member_role; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.order_group_member_role AS ENUM (
    'ENTRY',
    'TAKE_PROFIT',
    'STOP_LOSS',
    'LEG'
);


--
-- Name: order_group_status; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.order_group_status AS ENUM (
    'PENDING',
    'ACTIVE',
    'COMPLETED',
    'CANCELLED',
    'FAILED'
);


--
-- Name: order_group_type; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.order_group_type AS ENUM (
    'OCO',
    'BRACKET',
    'MULTI_LEG'
);


--
-- Name: order_side; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.order_side AS ENUM (
    'BUY',
    'SELL'
);


--
-- Name: order_status; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.order_status AS ENUM (
    'PENDING',
    'OPEN',
    'FILLED',
    'CANCELLED',
    'EXPIRED',
    'REJECTED'
);


--
-- Name: order_type; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.order_type AS ENUM (
    'MARKET',
    'LIMIT',
    'STOP',
    'STOP_LIMIT',
    'TRAILING_STOP'
);


--
-- Name: position_effect; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.position_effect AS ENUM (
    'OPEN_LONG',
    'CLOSE_LONG',
    'OPEN_SHORT',
    'CLOSE_SHORT'
);


--
-- Name: reservation_event_type; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.reservation_event_type AS ENUM (
    'CREATED',
    'CONSUMED_BY_FILL',
    'SETTLED_BY_FILL',
    'RELEASED_BY_CANCEL',
    'RELEASED_BY_EXPIRY',
    'RELEASED_BY_REJECTION',
    'RELEASED_BY_REPLACEMENT'
);


--
-- Name: reservation_resource_type; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.reservation_resource_type AS ENUM (
    'CASH_BUYING_POWER',
    'POSITION_QUANTITY',
    'SHORT_COLLATERAL_CASH'
);


--
-- Name: reservation_status; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.reservation_status AS ENUM (
    'ACTIVE',
    'SETTLED',
    'RELEASED'
);


--
-- Name: system_close_reason; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.system_close_reason AS ENUM (
    'RISK_LIMIT_BREACH',
    'BOT_STOP',
    'COMPETITION_END',
    'DATA_INTEGRITY_BLOCK'
);


--
-- Name: time_in_force; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.time_in_force AS ENUM (
    'DAY',
    'GTC',
    'GTD'
);


--
-- Name: trailing_offset_type; Type: TYPE; Schema: trading; Owner: -
--

CREATE TYPE trading.trailing_offset_type AS ENUM (
    'AMOUNT',
    'PERCENT'
);


--
-- Name: anonymize_official_competition_run_owners(uuid, timestamp with time zone); Type: FUNCTION; Schema: backtest; Owner: -
--

CREATE FUNCTION backtest.anonymize_official_competition_run_owners(target_account_id uuid, anonymized_at timestamp with time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    affected integer;
BEGIN
    UPDATE backtest.runs run
    SET owner_account_id = NULL,
        owner_anonymized_at = anonymized_at
    WHERE run.owner_account_id = target_account_id
      AND EXISTS (
          SELECT 1
          FROM competition.backtest_period_runs period_run
          JOIN competition.participations participation
            ON participation.id = period_run.participation_id
          WHERE period_run.run_id = run.id
            AND participation.owner_account_id = target_account_id
      );
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;


--
-- Name: FUNCTION anonymize_official_competition_run_owners(target_account_id uuid, anonymized_at timestamp with time zone); Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON FUNCTION backtest.anonymize_official_competition_run_owners(target_account_id uuid, anonymized_at timestamp with time zone) IS 'Backtest-owned, narrowly scoped command invoked inside the backend retention transaction for official competition evidence only.';


--
-- Name: validate_attempt_lineage(); Type: FUNCTION; Schema: backtest; Owner: -
--

CREATE FUNCTION backtest.validate_attempt_lineage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.previous_attempt_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
          FROM backtest.run_attempts previous
         WHERE previous.id = NEW.previous_attempt_id
           AND previous.run_id = NEW.run_id
           AND previous.attempt_number < NEW.attempt_number
    ) THEN
        RAISE EXCEPTION 'BACKTEST_ATTEMPT_LINEAGE_INVALID'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END
$$;


--
-- Name: enforce_anonymized_bot_participation(); Type: FUNCTION; Schema: competition; Owner: -
--

CREATE FUNCTION competition.enforce_anonymized_bot_participation() RETURNS trigger
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


--
-- Name: enforce_leaderboard_result_source(); Type: FUNCTION; Schema: competition; Owner: -
--

CREATE FUNCTION competition.enforce_leaderboard_result_source() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    snapshot_room_id uuid;
    room_type competition.competition_type;
    participation_room_id uuid;
    participation_bot_id uuid;
    performance_bot_id uuid;
    aggregate_participation_id uuid;
    aggregate_room_id uuid;
BEGIN
    SELECT snapshot.room_id, room.competition_type
      INTO snapshot_room_id, room_type
      FROM competition.leaderboard_snapshots snapshot
      JOIN competition.rooms room ON room.id = snapshot.room_id
     WHERE snapshot.id = NEW.snapshot_id;

    SELECT participation.room_id, participation.bot_id
      INTO participation_room_id, participation_bot_id
      FROM competition.participations participation
     WHERE participation.id = NEW.participation_id;

    IF snapshot_room_id IS NULL OR participation_room_id IS DISTINCT FROM snapshot_room_id THEN
        RAISE EXCEPTION 'leaderboard participation must belong to the snapshot room'
            USING ERRCODE = '23514';
    END IF;

    IF room_type = 'LIVE_PAPER' THEN
        IF NEW.performance_snapshot_id IS NULL OR NEW.backtest_aggregate_result_id IS NOT NULL THEN
            RAISE EXCEPTION 'LIVE_PAPER leaderboard requires a live performance snapshot'
                USING ERRCODE = '23514';
        END IF;
        SELECT snapshot.bot_id
          INTO performance_bot_id
          FROM performance.bot_snapshots snapshot
         WHERE snapshot.id = NEW.performance_snapshot_id;
        IF performance_bot_id IS DISTINCT FROM participation_bot_id THEN
            RAISE EXCEPTION 'live performance snapshot must belong to the participation bot'
                USING ERRCODE = '23514';
        END IF;
    ELSIF room_type = 'BACKTEST' THEN
        IF NEW.backtest_aggregate_result_id IS NULL OR NEW.performance_snapshot_id IS NOT NULL THEN
            RAISE EXCEPTION 'BACKTEST leaderboard requires a backtest aggregate result'
                USING ERRCODE = '23514';
        END IF;
        SELECT aggregate.participation_id, aggregate.evaluation_plan_room_id
          INTO aggregate_participation_id, aggregate_room_id
          FROM competition.backtest_aggregate_results aggregate
         WHERE aggregate.id = NEW.backtest_aggregate_result_id;
        IF aggregate_participation_id IS DISTINCT FROM NEW.participation_id
                OR aggregate_room_id IS DISTINCT FROM snapshot_room_id THEN
            RAISE EXCEPTION 'backtest aggregate must belong to the participation and snapshot room'
                USING ERRCODE = '23514';
        END IF;
    ELSE
        RAISE EXCEPTION 'unsupported competition type for leaderboard result source'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: validate_room_ledger_handoff(); Type: FUNCTION; Schema: competition; Owner: -
--

CREATE FUNCTION competition.validate_room_ledger_handoff() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    participant_status competition.participation_status;
BEGIN
    SELECT status INTO participant_status
    FROM competition.participations WHERE id = NEW.participation_id;

    IF (NEW.start_event_sequence IS NULL) <> (NEW.initial_state_hash IS NULL) THEN
        RAISE EXCEPTION 'room evaluation segment ledger evidence must be set as a pair'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.start_event_sequence IS NULL AND participant_status <> 'PENDING_LEDGER' THEN
        RAISE EXCEPTION 'room evaluation segment may lack ledger evidence only while PENDING_LEDGER'
            USING ERRCODE = '23514';
    END IF;
    IF NEW.start_event_sequence IS NOT NULL AND NEW.start_event_sequence <= 0 THEN
        RAISE EXCEPTION 'room evaluation start event sequence must be positive'
            USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'UPDATE'
       AND OLD.start_event_sequence IS NOT NULL
       AND (NEW.start_event_sequence, NEW.initial_state_hash)
           IS DISTINCT FROM (OLD.start_event_sequence, OLD.initial_state_hash) THEN
        RAISE EXCEPTION 'room evaluation ledger evidence is immutable once recorded'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: create_account_lifecycle_genesis(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.create_account_lifecycle_genesis() RETURNS trigger
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


--
-- Name: delete_proven_private_bots(uuid); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.delete_proven_private_bots(target_account_id uuid) RETURNS integer
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


--
-- Name: FUNCTION delete_proven_private_bots(target_account_id uuid); Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON FUNCTION identity.delete_proven_private_bots(target_account_id uuid) IS 'Physically deletes only non-competition bots with no retained trading/backtest/performance/operations evidence; ambiguity fails closed.';


--
-- Name: enforce_account_lifecycle_event_chain(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.enforce_account_lifecycle_event_chain() RETURNS trigger
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


--
-- Name: enforce_account_lifecycle_projection_head(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.enforce_account_lifecycle_projection_head() RETURNS trigger
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


--
-- Name: guard_account_scoped_activation(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.guard_account_scoped_activation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: guard_competition_participation_creation(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.guard_competition_participation_creation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: guard_identifier_quarantine_release(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.guard_identifier_quarantine_release() RETURNS trigger
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


--
-- Name: guard_owner_account_creation(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.guard_owner_account_creation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM identity.require_active_account(NEW.owner_account_id, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME);
    RETURN NEW;
END;
$$;


--
-- Name: guard_trading_order_creation(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.guard_trading_order_creation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    owner_id uuid;
BEGIN
    SELECT owner_account_id INTO owner_id FROM bot.bots WHERE id = NEW.bot_id;
    PERFORM identity.require_active_account(owner_id, 'trading.orders');
    RETURN NEW;
END;
$$;


--
-- Name: lock_account_retention_category(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.lock_account_retention_category() RETURNS trigger
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


--
-- Name: lock_identifier_quarantine_change(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.lock_identifier_quarantine_change() RETURNS trigger
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


--
-- Name: reject_account_sanction_history_mutation(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.reject_account_sanction_history_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'sanction history and command receipts are append-only' USING ERRCODE = '23514';
END;
$$;


--
-- Name: reject_delegated_strategy_scope_mutation(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.reject_delegated_strategy_scope_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'delegated Strategy scope evidence is append-only';
END;
$$;


--
-- Name: reject_immutable_account_contract_change(); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.reject_immutable_account_contract_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION '% is immutable', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$$;


--
-- Name: require_active_account(uuid, text); Type: FUNCTION; Schema: identity; Owner: -
--

CREATE FUNCTION identity.require_active_account(target_account_id uuid, operation_name text) RETURNS void
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


--
-- Name: maintain_dataset_manifest_object_count(); Type: FUNCTION; Schema: market_data; Owner: -
--

CREATE FUNCTION market_data.maintain_dataset_manifest_object_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE market_data.dataset_manifests
           SET object_count = object_count - 1
         WHERE id = OLD.dataset_manifest_id;
        RETURN OLD;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.dataset_manifest_id <> NEW.dataset_manifest_id THEN
        UPDATE market_data.dataset_manifests
           SET object_count = object_count - 1
         WHERE id = OLD.dataset_manifest_id;
    END IF;
    IF TG_OP = 'INSERT' OR OLD.dataset_manifest_id <> NEW.dataset_manifest_id THEN
        UPDATE market_data.dataset_manifests
           SET object_count = object_count + 1
         WHERE id = NEW.dataset_manifest_id;
    END IF;
    RETURN NEW;
END
$$;


--
-- Name: guard_operator_bootstrap_audit_immutable(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.guard_operator_bootstrap_audit_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.target_domain = 'OPERATOR_BOOTSTRAP' THEN
        RAISE EXCEPTION 'operator bootstrap audit evidence is immutable';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;


--
-- Name: guard_operator_bootstrap_receipt_immutable(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.guard_operator_bootstrap_receipt_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'operator bootstrap receipts are immutable';
END $$;


--
-- Name: guard_operator_rbac_audit_immutable(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.guard_operator_rbac_audit_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.target_domain = 'OPERATOR_RBAC' THEN
        RAISE EXCEPTION 'operator RBAC audit evidence is immutable';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;


--
-- Name: guard_outbox_immutable_envelope(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.guard_outbox_immutable_envelope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (NEW.owner_domain, NEW.aggregate_id, NEW.aggregate_sequence,
        NEW.event_type, NEW.event_schema_version, NEW.payload_document,
        NEW.payload_hash, NEW.producer_idempotency_key, NEW.idempotency_key,
        NEW.original_message_id, NEW.replayed_from_message_id,
        NEW.replay_sequence, NEW.replay_audit_event_id, NEW.created_at)
        IS DISTINCT FROM
       (OLD.owner_domain, OLD.aggregate_id, OLD.aggregate_sequence,
        OLD.event_type, OLD.event_schema_version, OLD.payload_document,
        OLD.payload_hash, OLD.producer_idempotency_key, OLD.idempotency_key,
        OLD.original_message_id, OLD.replayed_from_message_id,
        OLD.replay_sequence, OLD.replay_audit_event_id, OLD.created_at) THEN
        RAISE EXCEPTION 'outbox envelope is immutable' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: guard_rbac_catalog_immutable(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.guard_rbac_catalog_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'RBAC catalog rows are append-only'; END IF;
    IF OLD.status = 'RETIRED' OR
       (OLD.status = 'ACTIVE' AND NOT (NEW.status = 'RETIRED'
            AND NEW.catalog_version = OLD.catalog_version
            AND NEW.content_hash = OLD.content_hash
            AND NEW.activated_at = OLD.activated_at
            AND NEW.created_at = OLD.created_at)) THEN
        RAISE EXCEPTION 'active or retired RBAC catalog is immutable';
    END IF;
    RETURN NEW;
END $$;


--
-- Name: guard_rbac_catalog_snapshot(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.guard_rbac_catalog_snapshot() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE snapshot_status varchar(30);
DECLARE snapshot_version varchar(80);
BEGIN
    snapshot_version := CASE WHEN TG_OP = 'DELETE' THEN OLD.catalog_version ELSE NEW.catalog_version END;
    SELECT status INTO snapshot_status FROM operations.rbac_catalog_versions
    WHERE catalog_version = snapshot_version;
    IF snapshot_status IN ('ACTIVE', 'RETIRED') THEN
        RAISE EXCEPTION 'active or retired RBAC catalog snapshot is immutable';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;


--
-- Name: prepare_outbox_envelope(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.prepare_outbox_envelope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.payload_hash IS NULL THEN
        NEW.payload_hash := encode(sha256(convert_to(NEW.payload_document::text, 'UTF8')), 'hex');
    END IF;
    IF NEW.producer_idempotency_key IS NULL THEN
        NEW.producer_idempotency_key := NEW.idempotency_key;
    END IF;
    IF NEW.published_at IS NOT NULL AND NEW.delivery_status = 'PENDING' THEN
        NEW.delivery_status := 'PUBLISHED';
        NEW.next_attempt_at := NULL;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: reject_case_append_only_mutation(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.reject_case_append_only_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'case history, receipt, and evidence proof are append-only'
        USING ERRCODE = '23514';
END;
$$;


--
-- Name: require_active_assignment_catalog(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.require_active_assignment_catalog() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.catalog_version IS NULL OR NOT EXISTS (
        SELECT 1 FROM operations.rbac_catalog_versions
        WHERE catalog_version = NEW.catalog_version AND status = 'ACTIVE') THEN
        RAISE EXCEPTION 'new operator assignment requires the active RBAC catalog';
    END IF;
    RETURN NEW;
END $$;


--
-- Name: require_coherent_operator_bootstrap_receipt(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.require_coherent_operator_bootstrap_receipt() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM operations.operator_accounts account
        JOIN operations.operator_login_credentials credential
          ON credential.operator_account_id = account.id
        JOIN operations.operator_role_assignments assignment
          ON assignment.id = NEW.operator_role_assignment_id
         AND assignment.operator_account_id = account.id
        WHERE account.id = NEW.operator_account_id
          AND credential.credential_version = NEW.credential_version
    ) THEN
        RAISE EXCEPTION 'operator bootstrap receipt references incoherent identity evidence';
    END IF;
    RETURN NEW;
END $$;


--
-- Name: require_complete_operator_bootstrap_evidence(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.require_complete_operator_bootstrap_evidence() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM operations.operator_accounts account
        JOIN operations.operator_login_credentials credential
          ON credential.operator_account_id = account.id
        JOIN operations.operator_role_assignments assignment
          ON assignment.id = NEW.operator_role_assignment_id
         AND assignment.operator_account_id = account.id
        JOIN operations.rbac_catalog_versions catalog
          ON catalog.catalog_version = assignment.catalog_version
        JOIN operations.audit_events audit
          ON audit.id = NEW.audit_event_id
        WHERE account.id = NEW.operator_account_id
          AND credential.credential_version = NEW.credential_version
          AND account.created_at = NEW.applied_at
          AND credential.created_at = NEW.applied_at
          AND credential.totp_enrolled_at = NEW.applied_at
          AND assignment.catalog_version = NEW.catalog_version
          AND assignment.granted_by_operator_id = NEW.operator_account_id
          AND assignment.granted_at = NEW.applied_at
          AND catalog.status = 'ACTIVE'
          AND catalog.activated_at = NEW.applied_at
          AND audit.action_type = 'OPERATOR_BOOTSTRAP'
          AND audit.actor_type = 'DEPLOYMENT'
          AND audit.reason_code = 'BOOTSTRAP_DEPLOYMENT'
          AND audit.target_domain = 'OPERATOR_BOOTSTRAP'
          AND audit.target_id = NEW.operator_account_id
          AND audit.correlation_id = NEW.correlation_id
          AND audit.occurred_at = NEW.applied_at
          AND audit.idempotency_key = 'operator-bootstrap:' || NEW.bootstrap_key
          AND audit.decision_status = 'SUCCEEDED'
          AND audit.response_status = 200
          AND audit.response_code = 'OPERATOR_BOOTSTRAP_APPLIED'
          AND audit.request_document ->> 'bootstrapKey' = NEW.bootstrap_key
          AND audit.request_document ->> 'manifestHash' = NEW.manifest_hash
          AND audit.request_document ->> 'catalogVersion' = NEW.catalog_version
          AND audit.request_document ->> 'catalogContentHash' = catalog.content_hash
          AND audit.evidence_document ->> 'databaseRole' = audit.request_document ->> 'expectedDatabaseRole'
          AND audit.evidence_document ->> 'grantProvenance' = audit.request_document ->> 'grantProvenance'
          AND audit.response_document ->> 'operatorAccountId' = NEW.operator_account_id::text
          AND audit.response_document ->> 'operatorRoleAssignmentId' = NEW.operator_role_assignment_id::text
          AND audit.response_document ->> 'catalogVersion' = NEW.catalog_version
          AND (audit.response_document ->> 'credentialVersion')::bigint = NEW.credential_version
          AND audit.response_document ->> 'status' = 'ACTIVE'
          AND audit.evidence_document ->> 'deploymentActorId' = audit.actor_id::text
          AND audit.evidence_document ->> 'technicalGrantorOperatorId' = NEW.operator_account_id::text
          AND audit.evidence_document ->> 'grantMode' = 'BOOTSTRAP_DEPLOYMENT'
          AND length(audit.evidence_document ->> 'databaseRole') > 0
          AND length(audit.evidence_document ->> 'grantProvenance') > 0
          AND audit.request_hash = encode(digest(audit.request_document::text, 'sha256'), 'hex')
          AND audit.before_hash = encode(digest(audit.before_document::text, 'sha256'), 'hex')
          AND audit.after_hash = encode(digest(audit.after_document::text, 'sha256'), 'hex')
          AND audit.evidence_hash = encode(digest(audit.evidence_document::text, 'sha256'), 'hex')
    ) THEN
        RAISE EXCEPTION 'operator bootstrap receipt requires complete deployment evidence';
    END IF;
    RETURN NEW;
END $$;


--
-- Name: FUNCTION require_complete_operator_bootstrap_evidence(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.require_complete_operator_bootstrap_evidence() IS 'Binds the immutable receipt to its catalog, self-granted technical assignment, deployment actor, dedicated database role, correlation, and DB-time audit evidence.';


--
-- Name: verify_case_head_and_chain(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.verify_case_head_and_chain() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    head operations.case_events%ROWTYPE;
    previous_sequence integer;
BEGIN
    IF TG_TABLE_NAME = 'cases' THEN
        SELECT * INTO head FROM operations.case_events WHERE id = NEW.last_case_event_id;
        IF head.case_id IS DISTINCT FROM NEW.id
           OR head.account_id IS DISTINCT FROM NEW.account_id
           OR head.event_sequence IS DISTINCT FROM NEW.current_event_sequence
           OR head.resulting_status IS DISTINCT FROM NEW.status
           OR NEW.case_version IS DISTINCT FROM NEW.current_event_sequence THEN
            RAISE EXCEPTION 'case projection does not match its event head' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    END IF;
    IF NEW.previous_event_id IS NOT NULL THEN
        SELECT event_sequence INTO previous_sequence
        FROM operations.case_events
        WHERE case_id = NEW.case_id AND id = NEW.previous_event_id;
        IF previous_sequence IS DISTINCT FROM NEW.event_sequence - 1 THEN
            RAISE EXCEPTION 'case event does not extend the immediate previous head' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: assert_borrow_fee_period_isolation(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_borrow_fee_period_isolation(target_accrual_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    accrual_row "trading"."short_borrow_fee_accruals"%rowtype;
    conflicting_id uuid;
BEGIN
    SELECT * INTO accrual_row
      FROM "trading"."short_borrow_fee_accruals"
     WHERE "id" = target_accrual_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Serialise every isolation check for one lot, so a concurrent overlapping insert cannot slip
    -- past both checks. The lock is transaction scoped and released at commit.
    PERFORM pg_advisory_xact_lock(hashtextextended(accrual_row."position_lot_id"::text, 0));

    SELECT other."id" INTO conflicting_id
      FROM "trading"."short_borrow_fee_accruals" AS other
     WHERE other."position_lot_id" = accrual_row."position_lot_id"
       AND other."id" <> accrual_row."id"
       AND tstzrange(other."period_start", other."period_end", '[)')
           && tstzrange(accrual_row."period_start", accrual_row."period_end", '[)')
     LIMIT 1;

    IF conflicting_id IS NOT NULL THEN
        RAISE EXCEPTION
            'short borrow fee accrual % overlaps accrual % on lot % for period [%, %)',
            target_accrual_id, conflicting_id, accrual_row."position_lot_id",
            accrual_row."period_start", accrual_row."period_end";
    END IF;
END;
$$;


--
-- Name: assert_close_allocation_capacity(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_close_allocation_capacity(target_allocation_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    allocation_capacity numeric(28,8);
    moved_quantity numeric(28,8);
BEGIN
    SELECT fill_allocation.allocated_quantity INTO allocation_capacity
      FROM "trading"."fill_component_allocations" fill_allocation
     WHERE fill_allocation.id = target_allocation_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;
    SELECT COALESCE(sum(abs(quantity_delta)), 0) INTO moved_quantity
      FROM "trading"."lot_movements"
     WHERE source_fill_allocation_id = target_allocation_id
       AND movement_type = 'CLOSE';
    IF moved_quantity > allocation_capacity THEN
        RAISE EXCEPTION 'closing allocation % movement quantity % exceeds allocation quantity %',
            target_allocation_id, moved_quantity, allocation_capacity;
    END IF;
END $$;


--
-- Name: assert_component_allocation_capacity(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_component_allocation_capacity(target_component_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    requested numeric(28,8);
    allocated numeric(28,8);
BEGIN
    SELECT component_quantity INTO requested
      FROM "trading"."order_components" WHERE id = target_component_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(sum(allocation.allocated_quantity), 0)
      INTO allocated
      FROM "trading"."fill_component_allocations" allocation
     WHERE allocation.order_component_id = target_component_id
       AND NOT EXISTS (
           SELECT 1 FROM "trading"."fill_adjustments" adjustment
            WHERE adjustment.fill_id = allocation.fill_id
              AND adjustment.adjustment_type = 'REVERSAL'
       );
    IF allocated > requested THEN
        RAISE EXCEPTION 'component % effective allocation % exceeds component quantity %',
            target_component_id, allocated, requested;
    END IF;
END $$;


--
-- Name: assert_fill_adjustment(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_fill_adjustment(target_adjustment_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    adjustment "trading"."fill_adjustments"%ROWTYPE;
    original "trading"."fills"%ROWTYPE;
BEGIN
    SELECT * INTO adjustment FROM "trading"."fill_adjustments" WHERE id = target_adjustment_id;
    IF NOT FOUND OR adjustment.adjustment_type <> 'REVERSAL' THEN
        RETURN;
    END IF;
    SELECT * INTO original FROM "trading"."fills" WHERE id = adjustment.fill_id;
    IF adjustment.quantity_delta <> -original.quantity
       OR adjustment.gross_amount_delta <> -original.gross_amount
       OR adjustment.fee_amount_delta <> -original.fee_amount
       OR adjustment.settlement_cash_delta <> -original.settlement_cash_delta THEN
        RAISE EXCEPTION 'fill reversal % must exactly negate fill %', adjustment.id, original.id;
    END IF;
END $$;


--
-- Name: assert_fill_allocation_totals(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_fill_allocation_totals(target_fill_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    fill_row "trading"."fills"%ROWTYPE;
    quantity_total numeric(28,8);
    gross_total numeric(24,8);
    fee_total numeric(24,8);
    cash_total numeric(24,8);
BEGIN
    SELECT * INTO fill_row FROM "trading"."fills" WHERE id = target_fill_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(sum(allocated_quantity), 0),
           COALESCE(sum(allocated_gross_amount), 0),
           COALESCE(sum(allocated_fee_amount), 0),
           COALESCE(sum(allocated_settlement_cash_delta), 0)
      INTO quantity_total, gross_total, fee_total, cash_total
      FROM "trading"."fill_component_allocations"
     WHERE fill_id = target_fill_id;

    IF quantity_total <> fill_row.quantity
       OR gross_total <> fill_row.gross_amount
       OR fee_total <> fill_row.fee_amount
       OR cash_total <> fill_row.settlement_cash_delta THEN
        RAISE EXCEPTION 'fill % allocation totals do not match fill economics', target_fill_id;
    END IF;
END $$;


--
-- Name: assert_fill_reservation_consumption(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_fill_reservation_consumption(target_event_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    reservation_event "trading"."reservation_events"%ROWTYPE;
    reservation "trading"."resource_reservations"%ROWTYPE;
    allocation_record "trading"."fill_component_allocations"%ROWTYPE;
BEGIN
    SELECT * INTO reservation_event FROM "trading"."reservation_events" WHERE id = target_event_id;
    IF NOT FOUND OR reservation_event.event_type NOT IN ('CONSUMED_BY_FILL', 'SETTLED_BY_FILL') THEN
        RETURN;
    END IF;
    SELECT * INTO reservation FROM "trading"."resource_reservations"
     WHERE id = reservation_event.reservation_id;
    SELECT fill_allocation.* INTO allocation_record
      FROM "trading"."order_component_reservations" link
      JOIN "trading"."fill_component_allocations" fill_allocation
        ON fill_allocation.order_component_id = link.order_component_id
       AND fill_allocation.fill_id = reservation_event.source_fill_id
     WHERE link.reservation_id = reservation_event.reservation_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'reservation fill event % has no matching component allocation', target_event_id;
    END IF;

    IF reservation.resource_type = 'CASH_BUYING_POWER'
       AND COALESCE(reservation_event.consumed_amount_delta, 0)
           <> abs(allocation_record.allocated_settlement_cash_delta) THEN
        RAISE EXCEPTION 'cash reservation event % consumption does not match fill allocation', target_event_id;
    END IF;
    IF reservation.resource_type = 'POSITION_QUANTITY'
       AND COALESCE(reservation_event.consumed_quantity_delta, 0) <> allocation_record.allocated_quantity THEN
        RAISE EXCEPTION 'position reservation event % consumption does not match fill allocation', target_event_id;
    END IF;
END $$;


--
-- Name: assert_ledger_transaction_balanced(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_ledger_transaction_balanced(target_transaction_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    entry_count integer;
    signed_total numeric(24,8);
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "trading"."ledger_transactions" WHERE "id" = target_transaction_id
    ) THEN
        RETURN;
    END IF;

    SELECT count(*),
           COALESCE(sum(CASE WHEN "direction" = 'DEBIT' THEN "amount" ELSE -"amount" END), 0)
      INTO entry_count, signed_total
      FROM "trading"."ledger_entries"
     WHERE "transaction_id" = target_transaction_id;

    -- A single-sided posting is not double-entry bookkeeping.
    IF entry_count < 2 THEN
        RAISE EXCEPTION 'ledger transaction % has % entries; double-entry requires at least two',
            target_transaction_id, entry_count;
    END IF;

    -- ledger_transactions.currency_code is a single header currency and ledger_entries carries no
    -- currency of its own, so one signed total over the transaction is the complete balance test.
    IF signed_total <> 0 THEN
        RAISE EXCEPTION 'ledger transaction % is unbalanced by %', target_transaction_id, signed_total;
    END IF;
END;
$$;


--
-- Name: assert_ledger_transaction_source(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_ledger_transaction_source(target_transaction_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    transaction_row "trading"."ledger_transactions"%rowtype;
BEGIN
    SELECT * INTO transaction_row
      FROM "trading"."ledger_transactions"
     WHERE "id" = target_transaction_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- 'Fill 없는 체결 분개' blocked. Only the two source types the canonical note names verbatim
    -- are checked; this is a safety net over the documented vocabulary, not a new constraint on it,
    -- so an unrecognised source_type is left alone rather than rejected.
    IF transaction_row."source_type" = 'FILL'
       AND NOT EXISTS (
           SELECT 1 FROM "trading"."fills"
            WHERE "id" = transaction_row."source_id"
              AND "bot_id" = transaction_row."bot_id") THEN
        RAISE EXCEPTION 'ledger transaction % claims fill % which does not exist for this bot',
            target_transaction_id, transaction_row."source_id";
    END IF;

    IF transaction_row."source_type" = 'FILL_ADJUSTMENT'
       AND NOT EXISTS (
           SELECT 1 FROM "trading"."fill_adjustments"
            WHERE "id" = transaction_row."source_id"
              AND "bot_id" = transaction_row."bot_id") THEN
        RAISE EXCEPTION 'ledger transaction % claims fill adjustment % which does not exist for this bot',
            target_transaction_id, transaction_row."source_id";
    END IF;
END;
$$;


--
-- Name: assert_lot_movement_provenance(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_lot_movement_provenance(target_movement_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    movement "trading"."lot_movements"%ROWTYPE;
    lot "trading"."position_lots"%ROWTYPE;
    allocation "trading"."fill_component_allocations"%ROWTYPE;
    intent "trading"."order_intents"%ROWTYPE;
BEGIN
    SELECT * INTO movement FROM "trading"."lot_movements" WHERE id = target_movement_id;
    IF NOT FOUND OR movement.movement_type NOT IN ('OPEN', 'CLOSE') THEN
        RETURN;
    END IF;
    SELECT * INTO lot FROM "trading"."position_lots" WHERE id = movement.position_lot_id;
    SELECT * INTO allocation FROM "trading"."fill_component_allocations"
     WHERE id = movement.source_fill_allocation_id;
    SELECT intent_row.* INTO intent
      FROM "trading"."order_components" component
      JOIN "trading"."order_intents" intent_row ON intent_row.id = component.intent_id
     WHERE component.id = allocation.order_component_id;

    IF allocation.bot_id <> lot.bot_id OR allocation.partition_id <> lot.partition_id
       OR intent.flow_id <> lot.flow_id OR intent.instrument_id <> lot.instrument_id THEN
        RAISE EXCEPTION 'lot movement % allocation is outside the lot scope', target_movement_id;
    END IF;
    IF movement.movement_type = 'OPEN'
       AND (movement.source_fill_allocation_id <> lot.opening_fill_allocation_id
            OR movement.quantity_delta <> lot.opened_quantity
            OR movement.quantity_delta <> allocation.allocated_quantity) THEN
        RAISE EXCEPTION 'opening movement % must use the lot opening allocation', target_movement_id;
    END IF;
    IF movement.movement_type = 'CLOSE'
       AND (movement.quantity_delta >= 0
            OR (lot.lot_side = 'LONG' AND intent.position_effect <> 'CLOSE_LONG')
            OR (lot.lot_side = 'SHORT' AND intent.position_effect <> 'CLOSE_SHORT')) THEN
        RAISE EXCEPTION 'closing movement % has incompatible fill allocation', target_movement_id;
    END IF;
END $$;


--
-- Name: assert_order_fill_state(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_order_fill_state(target_order_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    requested numeric(28,8);
    effective_filled numeric(28,8);
    projection "trading"."order_state_projections"%ROWTYPE;
BEGIN
    SELECT requested_quantity INTO requested FROM "trading"."orders" WHERE id = target_order_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(sum(fill.quantity), 0)
           + COALESCE((
               SELECT sum(adjustment.quantity_delta)
                 FROM "trading"."fill_adjustments" adjustment
                 JOIN "trading"."fills" adjusted_fill ON adjusted_fill.id = adjustment.fill_id
                WHERE adjusted_fill.order_id = target_order_id
           ), 0)
      INTO effective_filled
      FROM "trading"."fills" fill
     WHERE fill.order_id = target_order_id;

    IF effective_filled < 0 OR effective_filled > requested THEN
        RAISE EXCEPTION 'order % effective fill quantity % is outside [0,%]',
            target_order_id, effective_filled, requested;
    END IF;

    SELECT * INTO projection
      FROM "trading"."order_state_projections" WHERE order_id = target_order_id;
    IF FOUND THEN
        IF projection.filled_quantity <> effective_filled THEN
            RAISE EXCEPTION 'order % projection filled quantity does not match effective fills', target_order_id;
        END IF;
        IF projection.status IN ('PENDING', 'OPEN')
           AND projection.remaining_quantity <> requested - effective_filled THEN
            RAISE EXCEPTION 'order % active remaining quantity does not match effective fills', target_order_id;
        END IF;
        IF projection.status = 'FILLED' AND effective_filled <> requested THEN
            RAISE EXCEPTION 'order % is FILLED before requested quantity is reached', target_order_id;
        END IF;
    END IF;
END $$;


--
-- Name: assert_position_lot_provenance(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_position_lot_provenance(target_lot_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    lot "trading"."position_lots"%ROWTYPE;
    allocation "trading"."fill_component_allocations"%ROWTYPE;
    intent "trading"."order_intents"%ROWTYPE;
BEGIN
    SELECT * INTO lot FROM "trading"."position_lots" WHERE id = target_lot_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;
    SELECT * INTO allocation FROM "trading"."fill_component_allocations"
     WHERE id = lot.opening_fill_allocation_id;
    SELECT intent_row.* INTO intent
      FROM "trading"."order_components" component
      JOIN "trading"."order_intents" intent_row ON intent_row.id = component.intent_id
     WHERE component.id = lot.opening_order_component_id;

    IF allocation.order_component_id <> lot.opening_order_component_id
       OR allocation.allocated_quantity <> lot.opened_quantity
       OR intent.bot_id <> lot.bot_id
       OR intent.partition_id <> lot.partition_id
       OR intent.flow_id <> lot.flow_id
       OR intent.instrument_id <> lot.instrument_id
       OR (lot.lot_side = 'LONG' AND intent.position_effect <> 'OPEN_LONG')
       OR (lot.lot_side = 'SHORT' AND intent.position_effect <> 'OPEN_SHORT') THEN
        RAISE EXCEPTION 'position lot % provenance does not match its fill allocation', target_lot_id;
    END IF;
END $$;


--
-- Name: assert_reservation_event_totals(uuid); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.assert_reservation_event_totals(target_reservation_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    reservation "trading"."resource_reservations"%ROWTYPE;
    event_count bigint;
    max_sequence bigint;
    consumed_amount_total numeric(24,8);
    released_amount_total numeric(24,8);
    consumed_quantity_total numeric(28,8);
    released_quantity_total numeric(28,8);
    latest_status "trading"."reservation_status";
BEGIN
    SELECT * INTO reservation
      FROM "trading"."resource_reservations" WHERE id = target_reservation_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT count(*), COALESCE(max(reservation_sequence), 0),
           COALESCE(sum(consumed_amount_delta), 0), COALESCE(sum(released_amount_delta), 0),
           COALESCE(sum(consumed_quantity_delta), 0), COALESCE(sum(released_quantity_delta), 0)
      INTO event_count, max_sequence, consumed_amount_total, released_amount_total,
           consumed_quantity_total, released_quantity_total
      FROM "trading"."reservation_events" WHERE reservation_id = target_reservation_id;

    IF event_count = 0 OR event_count <> max_sequence OR reservation.last_event_sequence <> max_sequence THEN
        RAISE EXCEPTION 'reservation % event sequence is incomplete', target_reservation_id;
    END IF;
    IF consumed_amount_total <> reservation.consumed_amount
       OR released_amount_total <> reservation.released_amount
       OR consumed_quantity_total <> reservation.consumed_quantity
       OR released_quantity_total <> reservation.released_quantity THEN
        RAISE EXCEPTION 'reservation % event totals do not match projection', target_reservation_id;
    END IF;
    SELECT status_after INTO latest_status
      FROM "trading"."reservation_events"
     WHERE reservation_id = target_reservation_id
     ORDER BY reservation_sequence DESC
     LIMIT 1;
    IF latest_status <> reservation.status THEN
        RAISE EXCEPTION 'reservation % status does not match its latest event', target_reservation_id;
    END IF;
END $$;


--
-- Name: check_borrow_fee_accrual_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_borrow_fee_accrual_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    PERFORM "trading"."assert_borrow_fee_period_isolation"(NEW."id");
    RETURN NEW;
END;
$$;


--
-- Name: check_fill_adjustment_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_fill_adjustment_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    target_fill uuid;
    target_order uuid;
    target_component uuid;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        target_fill := OLD.fill_id;
        SELECT order_id INTO target_order FROM "trading"."fills" WHERE id = target_fill;
        PERFORM "trading"."assert_order_fill_state"(target_order);
        FOR target_component IN
            SELECT DISTINCT order_component_id
              FROM "trading"."fill_component_allocations" WHERE fill_id = target_fill
        LOOP
            PERFORM "trading"."assert_component_allocation_capacity"(target_component);
        END LOOP;
    END IF;
    IF TG_OP <> 'DELETE' THEN
        target_fill := NEW.fill_id;
        PERFORM "trading"."assert_fill_adjustment"(NEW.id);
        SELECT order_id INTO target_order FROM "trading"."fills" WHERE id = target_fill;
        PERFORM "trading"."assert_order_fill_state"(target_order);
        FOR target_component IN
            SELECT DISTINCT order_component_id
              FROM "trading"."fill_component_allocations" WHERE fill_id = target_fill
        LOOP
            PERFORM "trading"."assert_component_allocation_capacity"(target_component);
        END LOOP;
    END IF;
    RETURN NULL;
END $$;


--
-- Name: check_fill_allocation_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_fill_allocation_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_fill_allocation_totals"(OLD.fill_id);
        PERFORM "trading"."assert_component_allocation_capacity"(OLD.order_component_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_fill_allocation_totals"(NEW.fill_id);
        PERFORM "trading"."assert_component_allocation_capacity"(NEW.order_component_id);
    END IF;
    RETURN NULL;
END $$;


--
-- Name: check_fill_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_fill_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_fill_allocation_totals"(OLD.id);
        PERFORM "trading"."assert_order_fill_state"(OLD.order_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_fill_allocation_totals"(NEW.id);
        PERFORM "trading"."assert_order_fill_state"(NEW.order_id);
    END IF;
    RETURN NULL;
END $$;


--
-- Name: check_ledger_entry_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_ledger_entry_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM "trading"."assert_ledger_transaction_balanced"(OLD."transaction_id");
        RETURN OLD;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD."transaction_id" <> NEW."transaction_id" THEN
        PERFORM "trading"."assert_ledger_transaction_balanced"(OLD."transaction_id");
    END IF;
    PERFORM "trading"."assert_ledger_transaction_balanced"(NEW."transaction_id");
    RETURN NEW;
END;
$$;


--
-- Name: check_ledger_transaction_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_ledger_transaction_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM "trading"."assert_ledger_transaction_balanced"(OLD."id");
        RETURN OLD;
    END IF;
    PERFORM "trading"."assert_ledger_transaction_balanced"(NEW."id");
    PERFORM "trading"."assert_ledger_transaction_source"(NEW."id");
    RETURN NEW;
END;
$$;


--
-- Name: check_lot_movement_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_lot_movement_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP <> 'INSERT' AND OLD.source_fill_allocation_id IS NOT NULL THEN
        PERFORM "trading"."assert_close_allocation_capacity"(OLD.source_fill_allocation_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_lot_movement_provenance"(NEW.id);
        IF NEW.source_fill_allocation_id IS NOT NULL THEN
            PERFORM "trading"."assert_close_allocation_capacity"(NEW.source_fill_allocation_id);
        END IF;
    END IF;
    RETURN NULL;
END $$;


--
-- Name: check_order_projection_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_order_projection_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_order_fill_state"(OLD.order_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_order_fill_state"(NEW.order_id);
    END IF;
    RETURN NULL;
END $$;


--
-- Name: check_position_lot_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_position_lot_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_position_lot_provenance"(NEW.id);
    END IF;
    RETURN NULL;
END $$;


--
-- Name: check_reservation_event_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_reservation_event_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_reservation_event_totals"(OLD.reservation_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_fill_reservation_consumption"(NEW.id);
        PERFORM "trading"."assert_reservation_event_totals"(NEW.reservation_id);
    END IF;
    RETURN NULL;
END $$;


--
-- Name: check_reservation_trigger(); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.check_reservation_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN
        PERFORM "trading"."assert_reservation_event_totals"(OLD.id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        PERFORM "trading"."assert_reservation_event_totals"(NEW.id);
    END IF;
    RETURN NULL;
END $$;


--
-- Name: delete_private_bot_runtime(uuid[], boolean); Type: FUNCTION; Schema: trading; Owner: -
--

CREATE FUNCTION trading.delete_private_bot_runtime(candidate_ids uuid[], delete_events boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF delete_events THEN
        DELETE FROM bot.bot_events WHERE bot_id = ANY(candidate_ids);
    ELSE
        DELETE FROM bot.runtime_state_changes WHERE bot_id = ANY(candidate_ids);
        DELETE FROM bot.evaluation_runs WHERE bot_id = ANY(candidate_ids);
        DELETE FROM bot.runtime_state_values WHERE bot_id = ANY(candidate_ids);
    END IF;
END;
$$;


--
-- Name: FUNCTION delete_private_bot_runtime(candidate_ids uuid[], delete_events boolean); Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON FUNCTION trading.delete_private_bot_runtime(candidate_ids uuid[], delete_events boolean) IS 'Trading-owned half of FK-safe private Bot deletion; the backend owner coordinates it in the same database transaction.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: detail_manifests; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.detail_manifests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    run_id uuid NOT NULL,
    object_id uuid NOT NULL,
    record_type character varying(50) NOT NULL,
    week_start_date date NOT NULL,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone NOT NULL,
    part_number integer NOT NULL,
    row_count bigint NOT NULL,
    schema_version character varying(40) NOT NULL,
    source_set_hash character varying(128) NOT NULL,
    supersedes_manifest_id uuid,
    detail_hash character varying(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE detail_manifests; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.detail_manifests IS '백테스트 상세 Parquet 오브젝트는 명시적 UNCOMPRESSED이며 ET 월요일 주 경계를 넘지 않는다.';


--
-- Name: execution_policy_versions; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.execution_policy_versions (
    version character varying(80) NOT NULL,
    policy_artifact_hash character varying(128) NOT NULL,
    policy_document jsonb NOT NULL,
    locked_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone,
    CONSTRAINT backtest_execution_policy_retirement_after_lock CHECK (((retired_at IS NULL) OR (retired_at >= locked_at)))
);


--
-- Name: failure_condition_counts; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.failure_condition_counts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    monthly_summary_id uuid NOT NULL,
    flow_or_branch_key character varying(160) NOT NULL,
    first_failure_condition_key character varying(160) NOT NULL,
    occurrence_count bigint NOT NULL
);


--
-- Name: TABLE failure_condition_counts; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.failure_condition_counts IS '실패 조건 집계 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: input_bundles; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.input_bundles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    run_id uuid NOT NULL,
    bundle_hash character varying(128) NOT NULL,
    as_of_at timestamp with time zone NOT NULL,
    locked_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE input_bundles; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.input_bundles IS '공식 전체 봇 실행 1건의 완전한 재현성 경계를 고정.';


--
-- Name: input_datasets; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.input_datasets (
    input_bundle_id uuid NOT NULL,
    dataset_manifest_id uuid NOT NULL,
    purpose_code character varying(80) NOT NULL,
    locked_dataset_hash character varying(128) NOT NULL
);


--
-- Name: TABLE input_datasets; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.input_datasets IS '백테스트 입력 데이터셋 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: input_feature_materializations; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.input_feature_materializations (
    input_bundle_id uuid NOT NULL,
    feature_materialization_id uuid NOT NULL,
    locked_result_hash character varying(128) NOT NULL
);


--
-- Name: TABLE input_feature_materializations; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.input_feature_materializations IS '공식 백테스트가 재사용하는 공유 과거 피처 결과를 고정. 잠금 해시는 AVAILABLE 구체화 결과 해시와 일치해야 하며, 누락·불일치 피처는 숨은 봇별 재계산 대신 입력 잠금 실패로 처리.';


--
-- Name: legacy_execution_policy_mappings; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.legacy_execution_policy_mappings (
    run_id uuid NOT NULL,
    lane backtest.run_lane NOT NULL,
    message_id uuid NOT NULL,
    canonical_payload_hash character varying(128) NOT NULL,
    aggregate_sequence bigint NOT NULL,
    execution_policy_version character varying(80) NOT NULL,
    idempotency_scope character varying(160) NOT NULL,
    pinned_policy_artifact_hash character varying(128) NOT NULL,
    reviewed_by character varying(160) NOT NULL,
    reviewed_at timestamp with time zone NOT NULL,
    CONSTRAINT legacy_execution_policy_mappings_aggregate_sequence_check CHECK ((aggregate_sequence >= 1))
);


--
-- Name: monthly_judgment_summaries; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.monthly_judgment_summaries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    run_id uuid NOT NULL,
    et_year_month character(7) NOT NULL,
    evaluation_count bigint NOT NULL,
    active_branch_count bigint NOT NULL,
    trade_event_count bigint NOT NULL,
    data_gap_count bigint NOT NULL,
    triggered_count bigint NOT NULL,
    rejected_count bigint NOT NULL,
    summary_document jsonb NOT NULL,
    summary_hash character varying(128) NOT NULL
);


--
-- Name: TABLE monthly_judgment_summaries; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.monthly_judgment_summaries IS '월별 판정 요약 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: performance_summaries; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.performance_summaries (
    run_id uuid NOT NULL,
    metric_catalog_version character varying(80) NOT NULL,
    metrics_document jsonb NOT NULL,
    calculation_rules_version character varying(80) NOT NULL,
    source_set_hash character varying(128) NOT NULL,
    input_hash character varying(128) NOT NULL,
    result_hash character varying(128) NOT NULL,
    calculated_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE performance_summaries; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.performance_summaries IS '백테스트 성과 요약 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: run_attempts; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.run_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    run_id uuid NOT NULL,
    attempt_number integer NOT NULL,
    worker_execution_key character varying(160) NOT NULL,
    status operations.work_status NOT NULL,
    started_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    failure_code character varying(80),
    claim_token uuid,
    worker_id character varying(160),
    claimed_at timestamp with time zone,
    claim_expires_at timestamp with time zone,
    last_heartbeat_at timestamp with time zone,
    previous_attempt_id uuid,
    terminal_reason_code character varying(80),
    CONSTRAINT backtest_attempt_claim_fields_together CHECK ((((claim_token IS NULL) AND (worker_id IS NULL) AND (claimed_at IS NULL) AND (claim_expires_at IS NULL) AND (last_heartbeat_at IS NULL)) OR ((claim_token IS NOT NULL) AND (worker_id IS NOT NULL) AND (claimed_at IS NOT NULL) AND (claim_expires_at IS NOT NULL) AND (last_heartbeat_at IS NOT NULL)))),
    CONSTRAINT backtest_attempt_terminal_reason_only_terminal CHECK (((terminal_reason_code IS NULL) OR (status = ANY (ARRAY['SUCCEEDED'::operations.work_status, 'FAILED'::operations.work_status, 'CANCELLED'::operations.work_status, 'SKIPPED'::operations.work_status])))),
    CONSTRAINT backtest_running_attempt_claim_expiry_after_activity CHECK (((status <> 'RUNNING'::operations.work_status) OR (claim_expires_at > GREATEST(claimed_at, last_heartbeat_at)))),
    CONSTRAINT backtest_terminal_attempt_has_completion CHECK (((status <> ALL (ARRAY['SUCCEEDED'::operations.work_status, 'FAILED'::operations.work_status, 'CANCELLED'::operations.work_status, 'SKIPPED'::operations.work_status])) OR ((completed_at IS NOT NULL) AND (terminal_reason_code IS NOT NULL))))
);


--
-- Name: TABLE run_attempts; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.run_attempts IS '백테스트 실행 시도 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: run_input_pins; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.run_input_pins (
    run_id uuid NOT NULL,
    input_bundle_id uuid NOT NULL,
    input_bundle_fingerprint character varying(128) NOT NULL,
    input_contract_version character varying(80) NOT NULL,
    compiled_plan_checksum character varying(128) NOT NULL,
    strategy_snapshot_hash character varying(128) NOT NULL,
    execution_policy_version character varying(80) NOT NULL,
    pinned_at timestamp with time zone NOT NULL,
    CONSTRAINT backtest_run_input_bundle_fingerprint_sha256 CHECK (((input_bundle_fingerprint)::text ~ '^sha256:[0-9a-f]{64}$'::text)),
    CONSTRAINT backtest_run_input_plan_checksum_sha256 CHECK (((compiled_plan_checksum)::text ~ '^sha256:[0-9a-f]{64}$'::text)),
    CONSTRAINT backtest_run_input_snapshot_hash_sha256 CHECK (((strategy_snapshot_hash)::text ~ '^sha256:[0-9a-f]{64}$'::text))
);


--
-- Name: TABLE run_input_pins; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.run_input_pins IS 'Producer-owned immutable join from an official run to its complete dataset/feature input bundle and execution semantics.';


--
-- Name: runs; Type: TABLE; Schema: backtest; Owner: -
--

CREATE TABLE backtest.runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    owner_account_id uuid,
    configuration_hash character varying(128) NOT NULL,
    status backtest.run_status NOT NULL,
    evaluation_start date NOT NULL,
    evaluation_end date NOT NULL,
    initial_cash_amount numeric(24,8) NOT NULL,
    market_rules_version character varying(80) NOT NULL,
    accounting_rules_version character varying(80) NOT NULL,
    precision_rules_version character varying(80) NOT NULL,
    fee_policy_id uuid NOT NULL,
    slippage_rate_bps integer NOT NULL,
    buying_power_buffer_policy_id uuid NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    queued_at timestamp with time zone NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    failure_code character varying(80),
    result_hash character varying(128),
    owner_anonymized_at timestamp with time zone,
    lane backtest.run_lane NOT NULL,
    message_id uuid NOT NULL,
    canonical_payload_hash character varying(128) NOT NULL,
    aggregate_sequence bigint NOT NULL,
    execution_policy_version character varying(80) NOT NULL,
    idempotency_scope character varying(160) NOT NULL,
    cancellation_requested_at timestamp with time zone,
    cancellation_reason_code character varying(80),
    cancelled_at timestamp with time zone,
    result_manifest_id uuid,
    retryable boolean,
    missing_requirements jsonb,
    CONSTRAINT backtest_aggregate_sequence_positive CHECK ((aggregate_sequence >= 1)),
    CONSTRAINT backtest_cancellation_state_consistent CHECK ((((cancellation_requested_at IS NULL) AND (cancellation_reason_code IS NULL) AND (cancelled_at IS NULL)) OR ((cancellation_requested_at IS NOT NULL) AND (cancellation_reason_code IS NOT NULL) AND ((cancelled_at IS NULL) OR (cancelled_at >= cancellation_requested_at))))),
    CONSTRAINT backtest_cancelled_run_has_time CHECK (((status <> 'CANCELLED'::backtest.run_status) OR (cancelled_at IS NOT NULL))),
    CONSTRAINT backtest_run_owner_state CHECK ((((owner_account_id IS NOT NULL) AND (owner_anonymized_at IS NULL)) OR ((owner_account_id IS NULL) AND (owner_anonymized_at IS NOT NULL)))),
    CONSTRAINT backtest_success_not_cancelled CHECK (((status <> 'COMPLETED'::backtest.run_status) OR ((cancelled_at IS NULL) AND (cancellation_requested_at IS NULL)))),
    CONSTRAINT runs_missing_requirements_is_a_non_empty_string_array CHECK (((missing_requirements IS NULL) OR ((jsonb_typeof(missing_requirements) = 'array'::text) AND (jsonb_array_length(missing_requirements) > 0) AND (NOT jsonb_path_exists(missing_requirements, '$[*]?(@.type() != "string")'::jsonpath)))))
);


--
-- Name: TABLE runs; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON TABLE backtest.runs IS '봇 생성 트랜잭션에서 최초 자동 백테스트 한 건을 원자적으로 생성하고, 이후 같은 봇에 사용자가 선택한 기간 또는 공식 BACKTEST 대회의 잠긴 기간마다 실행을 추가할 수 있다. 대회 실행 소유권은 backtest.runs에 nullable competition 컬럼을 섞지 않고 competition.backtest_period_runs가 관리한다. 각 실행은 configuration_hash, 평가 기간, 초기 자금과 정책 버전을 독립적으로 고정하며 idempotency_key는 동일 요청의 중복 생성만 막는다. 백테스트 지연·실패는 라이브 봇 생명주기와 원장을 절대 바꾸지 않는다.';


--
-- Name: COLUMN runs.result_manifest_id; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON COLUMN backtest.runs.result_manifest_id IS 'COMPLETED resultManifestId linking the run to its immutable result manifest; NULL for other states.';


--
-- Name: COLUMN runs.retryable; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON COLUMN backtest.runs.retryable IS 'FAILED retryable decision; NULL when the run has not failed.';


--
-- Name: COLUMN runs.missing_requirements; Type: COMMENT; Schema: backtest; Owner: -
--

COMMENT ON COLUMN backtest.runs.missing_requirements IS 'UNAVAILABLE missingRequirements as the non-empty ordered string array received from the worker; NULL for other states.';


--
-- Name: bot_events; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.bot_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    event_sequence bigint NOT NULL,
    event_type character varying(80) NOT NULL,
    event_schema_version character varying(40) NOT NULL,
    causation_event_id uuid,
    correlation_id uuid NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone NOT NULL,
    committed_at timestamp with time zone DEFAULT now() NOT NULL,
    summary_document jsonb NOT NULL,
    market_dataset_manifest_id uuid,
    evidence_object_id uuid
);


--
-- Name: TABLE bot_events; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.bot_events IS '봇별 추가 전용 순서 보장 공식 스트림이자 라우팅된 트리거 이벤트의 유일한 봇별 구체화. Trigger Router가 전역 이벤트 식별자를 담은 결정적 idempotency_key(예: PRICE:AAPL:bar-close-timestamp, SCHEDULE:ONE_MINUTE:minute)로 라우팅 이벤트당 1행을 적재하므로 (bot_id, idempotency_key)가 별도 전역 트리거 테이블 없이 at-least-once 재전달을 흡수. event_sequence는 런타임 감사 순서이지 봇 버전이 아니며 갭 허용. 실행 차단 생명주기는 문서화된 이벤트 타입 BOT_EXECUTION_BLOCKED, BOT_EXECUTION_UNBLOCKED, SETTLEMENT_FAILED, LEDGER_INVARIANT_VIOLATED, STATE_REBUILD_COMPLETED 사용. 의사결정에 쓴 정확한 시장 관측치는 값/버전/해시로 고정.';


--
-- Name: bot_partitions; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.bot_partitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    name character varying(120) NOT NULL,
    description text,
    budget_cap_bps integer NOT NULL,
    position_x numeric(14,4) NOT NULL,
    position_y numeric(14,4) NOT NULL,
    configuration_hash character varying(128) NOT NULL,
    edit_sequence bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT partition_budget_cap_range CHECK (((budget_cap_bps > 0) AND (budget_cap_bps <= 10000)))
);


--
-- Name: TABLE bot_partitions; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.bot_partitions IS '완성된 파티션은 최대 100%의 불변 양수 예산 상한과 1개 이상의 Flow를 소유하며, 형제 상한 합은 지연 집계 제약으로 100% 이하 검증. 종목이나 별도 위험 정책 문서는 소유하지 않는다. 파티션이 최하위 예산 경계라 자식 Flow들은 이 상한을 공유하고 개별 할당은 없다. 위험 통제는 각 Flow semantic_document의 RISK_POLICY Element. 형제 파티션 간 차입 금지. name, description, position_x, position_y는 configuration_hash에서 제외되는 편집 필드이고 좌표 겹침 허용, id는 결정적 조회 타이브레이커. edit_sequence는 0에서 시작해 편집 필드 갱신 성공마다 정확히 1 증가(낙관적 동시성), updated_at은 그 커밋 시각. (bot_id, id)는 복합 PK나 버전이 아닌 대체 소유 키. 복사/붙여넣기는 원본 참조 없는 독립 새 행과 자식을 생성.';


--
-- Name: COLUMN bot_partitions.budget_cap_bps; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.bot_partitions.budget_cap_bps IS '봇 초기 자본의 0..10000 bps. 형제 합은 10000 이하.';


--
-- Name: bots; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.bots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_account_id uuid,
    mode strategy.strategy_mode NOT NULL,
    name character varying(120) NOT NULL,
    lifecycle_status bot.lifecycle_status NOT NULL,
    lifecycle_changed_at timestamp with time zone NOT NULL,
    execution_blocked_at timestamp with time zone,
    execution_block_reason_code character varying(80),
    execution_block_event_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    execution_eligible_from timestamp with time zone NOT NULL,
    started_at timestamp with time zone,
    stop_requested_at timestamp with time zone,
    stopped_at timestamp with time zone,
    stop_reason_code character varying(80),
    archived_at timestamp with time zone,
    deleted_at timestamp with time zone,
    edit_sequence bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    owner_anonymized_at timestamp with time zone,
    CONSTRAINT bot_actual_start_after_eligibility CHECK (((started_at IS NULL) OR (started_at >= execution_eligible_from))),
    CONSTRAINT bot_block_fields_together CHECK (((execution_blocked_at IS NOT NULL) OR ((execution_block_reason_code IS NULL) AND (execution_block_event_id IS NULL)))),
    CONSTRAINT bot_owner_state CHECK ((((owner_account_id IS NOT NULL) AND (owner_anonymized_at IS NULL)) OR ((owner_account_id IS NULL) AND (owner_anonymized_at IS NOT NULL))))
);


--
-- Name: TABLE bots; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.bots IS '검증된 Strategy 당시 상태를 복사해 생성한 완전 독립 실행 Bot. 원본 Strategy 식별자·출처·계보·버전 관계를 저장하지 않아 어느 Strategy에서 출시됐는지 조회할 수 없다. 출시된 실행 의미와 mode는 불변이고 Bot 이름, 파티션·Flow 설명과 좌표 및 Flow 내부 layout 같은 presentation만 수정 가능하다. RUNNING이어도 now()가 execution_eligible_from보다 이르면 평가하지 않으며 별도 waiting·scheduled 상태는 만들지 않는다. 개인 Bot은 즉시, 평가 전에 생성된 대회 Bot은 대회 평가 시작부터 실행 가능하고, 이미 진행 중인 공식 BACKTEST 대회 Bot은 입력 잠금 완료 뒤 Competition 백테스트 실행기로만 보낸다. Competition 관계가 BACKTEST인 Bot은 라이브 Trigger Router가 절대 평가하지 않는다. started_at은 실제 첫 실행이 시작될 때만 설정한다. STOPPING은 신규 평가·신규 주문 등록만 막고 기존 미체결 주문을 취소하지 않은 채 결과·예약 해제·정산을 마무리하며 STOPPED는 영구다. 파티션 1개 이상과 각 파티션의 완성 Flow 1개 이상을 검증한 뒤 Bot 스냅샷 계층을 원자적으로 생성한다. archived_at은 STOPPED Bot의 가역 숨김이고 deleted_at은 정산 완료 뒤의 논리 삭제다.';


--
-- Name: COLUMN bots.execution_blocked_at; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.bots.execution_blocked_at IS 'nullable 실행 차단 Projection. NULL이면 정상. 이 봇에만 국한된 손상(런타임 상태 손상, 이벤트 시퀀스 갭, 예약·원장 불일치, 정산 실패, 복구 불가 Element 평가 오류)에서만 설정.';


--
-- Name: continuation_deadlines; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.continuation_deadlines (
    bot_id uuid NOT NULL,
    due_at timestamp with time zone NOT NULL,
    last_renewed_at timestamp with time zone,
    renewal_sequence bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT bot_continuation_due_after_renewal CHECK (((last_renewed_at IS NULL) OR (due_at > last_renewed_at))),
    CONSTRAINT bot_continuation_sequence_nonnegative CHECK ((renewal_sequence >= 0))
);


--
-- Name: TABLE continuation_deadlines; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.continuation_deadlines IS '무소속 실행 봇의 명시적 계속 실행 확인 기한. 조회와 로그인은 이 행을 변경하지 않는다.';


--
-- Name: evaluation_runs; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.evaluation_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    flow_id uuid NOT NULL,
    trigger_event_id uuid NOT NULL,
    result_event_id uuid,
    feature_snapshot_batch_id uuid,
    feature_snapshot_key character varying(200),
    feature_snapshot_hash character varying(128),
    status operations.work_status NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    lease_expires_at timestamp with time zone,
    input_state_hash character varying(128),
    input_market_hash character varying(128),
    candidate_set_hash character varying(128),
    candidate_count integer,
    state_change_count integer,
    result_hash character varying(128),
    summary_document jsonb,
    queued_at timestamp with time zone NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    failure_code character varying(80),
    CONSTRAINT evaluation_attempt_count_nonnegative CHECK ((attempt_count >= 0)),
    CONSTRAINT evaluation_success_complete CHECK (((status <> 'SUCCEEDED'::operations.work_status) OR ((completed_at IS NOT NULL) AND (result_hash IS NOT NULL))))
);


--
-- Name: TABLE evaluation_runs; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.evaluation_runs IS '트리거 이벤트당 Flow당 1행: 평가 큐, 사용자 노출 판단 로그, idempotency의 단위. 유일한 (trigger_event_id, flow_id) 쌍이 상류 bot_events와 하류 파티션별 order_intent_batches를 이어 at-least-once 재전달을 안전하게 만든다. 같은 파티션 Flow 평가는 병렬 가능하지만 예산·보유수량·충돌·상계 적용은 (bot_id, partition_id) advisory transaction lock과 파티션 Projection 행 잠금 아래 직렬화한다. 시장 데이터 평가는 불변 공유 피처 스냅샷을 고정하고 공통 지표를 봇별 재계산하지 않는다.';


--
-- Name: COLUMN evaluation_runs.lease_expires_at; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.evaluation_runs.lease_expires_at IS 'at-least-once 인계용 워커 lease. 만료되면 다른 공용 워커가 이어서 수행.';


--
-- Name: COLUMN evaluation_runs.input_market_hash; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.evaluation_runs.input_market_hash IS '스냅샷이 고정된 경우 참조한 공유 피처 스냅샷 입력 해시와 같아야 한다.';


--
-- Name: flow_feature_requirements; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.flow_feature_requirements (
    flow_id uuid NOT NULL,
    instrument_id uuid NOT NULL,
    feature_definition_id uuid NOT NULL
);


--
-- Name: TABLE flow_feature_requirements; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.flow_feature_requirements IS '완성 시 Flow semantic_document에서 추출한 불변 의존성 집합. 사용자 작성 상태가 아니며 예산도 부여하지 않는다. 역방향 인덱스로 서버가 동일 피처·종목 기준으로 활성 Flow을 묶어 공통 계산을 한 번 수행하고 여러 봇 평가로 팬아웃.';


--
-- Name: flow_instruments; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.flow_instruments (
    flow_id uuid NOT NULL,
    instrument_id uuid NOT NULL
);


--
-- Name: TABLE flow_instruments; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.flow_instruments IS '완성된 Flow semantic_document가 요구하는 명시적 종목의 불변 집합. 종목의 매매/참조 역할은 그 문서의 타입 Element과 엣지로 한 번 정의되며 여기에 가변 역할로 중복 저장하지 않는다. Flow와 원자적으로 삽입. 시작 검증은 종목 1개 이상과 추출된 의존성-행의 정확한 일치를 요구. 향후 유니버스 선택은 현재 범위 밖이며 제품 지원 시 별도 검토된 모델·마이그레이션으로 도입해야 한다.';


--
-- Name: flow_time_triggers; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.flow_time_triggers (
    flow_id uuid NOT NULL,
    trigger_type bot.time_trigger_type NOT NULL,
    schedule_key character varying(40) NOT NULL
);


--
-- Name: TABLE flow_time_triggers; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.flow_time_triggers IS '완성된 Flow semantic_document에서 서버가 추출한 시간·세션 트리거 의존성 Projection. 사용자 작성이 아니고 제2의 정본도 아니다. 종목·피처 트리거 의존성은 flow_instruments와 flow_feature_requirements에 유지(중복 테이블 없음). 역방향 인덱스가 Trigger Router 조회에 답한다: MARKET_OPEN이나 ONE_MINUTE 이벤트는 구독한 Flow만 찾아 RUNNING 비차단 봇과 조인하며, 시장 전체 이벤트가 전체 봇을 스캔하지 않는다.';


--
-- Name: COLUMN flow_time_triggers.schedule_key; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.flow_time_triggers.schedule_key IS '값은 SCHEDULE이면 ONE_MINUTE 같은 Interval 키, 세션 트리거면 고정값 NONE.';


--
-- Name: flows; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.flows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partition_id uuid NOT NULL,
    name character varying(120) NOT NULL,
    description text,
    element_catalog_version_id uuid NOT NULL,
    compiled_flow_plan_id uuid NOT NULL,
    position_x numeric(14,4) NOT NULL,
    position_y numeric(14,4) NOT NULL,
    semantic_document jsonb NOT NULL,
    layout_document jsonb NOT NULL,
    layout_schema_version character varying(40) NOT NULL,
    semantic_hash character varying(128) NOT NULL,
    layout_hash character varying(128) NOT NULL,
    configuration_hash character varying(128) NOT NULL,
    edit_sequence bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE flows; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.flows IS 'Flow는 정확히 하나의 파티션이 소유하는 완결 Element 그래프이며 재사용 라이브러리 항목이나 버전 엔티티가 아니다. BASIC/PRO 모드는 봇에서 상속. 예산 할당 경계는 파티션뿐이고 런타임 행의 flow_id는 귀속 기록용. 매수·매도 Element의 주문 규모 단위는 퍼센트이며 semantic_document에 orderSizePercent(0 초과 100 이하)와 minReactivationIntervalSeconds(0 이상)를 고정한다. 매수는 실행 시점 Partition 가용 현금, 매도는 해당 Flow의 예약되지 않은 매도 가능 수량에 퍼센트를 적용한다. name, description, position_x, position_y, layout_document와 layout_schema_version은 semantic_hash·configuration_hash에서 제외되는 편집 필드, 좌표 겹침 허용, id는 결정적 조회 타이브레이커. edit_sequence는 0에서 시작해 이름·설명·좌표·레이아웃 같은 편집 필드 갱신 성공마다 정확히 1 증가, updated_at은 그 커밋 시각. Element·포트·안정 키를 가진 엣지·매개변수·의미 그룹·RISK_POLICY Element는 semantic_document 하나의 불변 실행 의미 JSONB 집합체다. layout_document는 같은 안정 Element·엣지 키를 참조하는 UI 전용 JSONB이며 layout_schema_version으로 해석 규칙을 선택하고 layout_hash로 무결성을 확인한다. 레이아웃 변경은 실행 계획, 의미 검증, 백테스트 또는 configuration_hash를 변경하지 않는다. configuration_hash는 Element 카탈로그 버전과 semantic_hash만 바인딩. (partition_id, id)는 복합 런타임 FK용 대체 소유 키. 복사/붙여넣기는 원본 참조 없는 독립 새 행 생성.';


--
-- Name: COLUMN flows.layout_document; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.flows.layout_document IS '요소별 좌표·크기, 그룹 배치·접힘, 선택 상태, edge routing hint, viewport와 zoom을 저장하는 UI 전용 문서. 요소 키와 엣지 키는 semantic_document의 안정 식별자를 참조해야 한다.';


--
-- Name: launch_configurations; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.launch_configurations (
    bot_id uuid NOT NULL,
    initial_cash_amount numeric(24,8) NOT NULL,
    currency_code character(3) DEFAULT 'USD'::bpchar NOT NULL,
    broker_rules_version character varying(80) NOT NULL,
    accounting_rules_version character varying(80) NOT NULL,
    precision_rules_version character varying(80) NOT NULL,
    fee_policy_id uuid NOT NULL,
    slippage_rate_bps integer NOT NULL,
    buying_power_buffer_policy_id uuid NOT NULL,
    candidate_conflict_policy jsonb NOT NULL,
    configuration_hash character varying(128) NOT NULL,
    CONSTRAINT launch_fixed_slippage_five_bps CHECK ((slippage_rate_bps = 5)),
    CONSTRAINT launch_initial_cash_positive CHECK ((initial_cash_amount > (0)::numeric))
);


--
-- Name: TABLE launch_configurations; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.launch_configurations IS 'bot.launch_snapshots·파티션·완성 Flow와 원자적으로 삽입. 초기 가상 자본은 양수 USD, 봇별 격리이며 입금·출금·증액 불가. 사용자 정의 위험 통제는 Flow의 RISK_POLICY Element에만 존재. 실행 설정은 생성 시점부터 불변이며 의미 변경·삭제는 항상 거부.';


--
-- Name: COLUMN launch_configurations.slippage_rate_bps; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.launch_configurations.slippage_rate_bps IS '고정 5 bps. 매수는 +, 매도는 -.';


--
-- Name: launch_contract_plans; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.launch_contract_plans (
    bot_id uuid NOT NULL,
    contract_version character varying(40) NOT NULL,
    plan_schema_version character varying(40) NOT NULL,
    plan_checksum character varying(128) NOT NULL,
    plan_document jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT launch_contract_plan_checksum_is_prefixed_digest CHECK (((plan_checksum)::text ~ '^sha256:[0-9a-f]{64}$'::text)),
    CONSTRAINT launch_contract_plan_document_is_object CHECK ((jsonb_typeof(plan_document) = 'object'::text))
);


--
-- Name: TABLE launch_contract_plans; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.launch_contract_plans IS 'The strategy-bot.v1 compiled plan published for one bot at release time, read by the evaluation runtime.';


--
-- Name: COLUMN launch_contract_plans.plan_checksum; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.launch_contract_plans.plan_checksum IS 'The contract''s own planChecksum, sha256-prefixed, recomputed by every consumer from the fields it decoded.';


--
-- Name: launch_snapshots; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.launch_snapshots (
    bot_id uuid NOT NULL,
    snapshot_schema_version character varying(40) NOT NULL,
    semantic_snapshot jsonb NOT NULL,
    presentation_snapshot jsonb NOT NULL,
    semantic_hash character varying(128) NOT NULL,
    presentation_hash character varying(128) NOT NULL,
    snapshot_hash character varying(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE launch_snapshots; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.launch_snapshots IS 'Bot 출시 당시 상태의 불변 1:1 증적. 정규화된 bot_partitions·flows·의존성·launch_configurations와 같은 트랜잭션에서 생성하며 snapshot_hash는 의미 스냅샷과 launch configuration을 함께 바인딩한다. 동일 Strategy에서 여러 번 출시해도 각 Bot은 독립 스냅샷만 가지며 원본 Strategy를 역추적할 수 없다. 현재 좌표·레이아웃 수정은 presentation_snapshot을 덮어쓰지 않는다.';


--
-- Name: COLUMN launch_snapshots.semantic_snapshot; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.launch_snapshots.semantic_snapshot IS '출시 시점의 mode, 파티션 예산 상한, Flow, Element, edge, 매개변수, 선택 종목 및 실행 규칙을 포함한다. Strategy 식별자나 출처 정보는 포함할 수 없다.';


--
-- Name: COLUMN launch_snapshots.presentation_snapshot; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.launch_snapshots.presentation_snapshot IS '출시 시점의 이름·설명·파티션·Flow·Element 배치를 보존한다. 출시 후 현재 presentation은 수정될 수 있지만 이 증적은 불변이다.';


--
-- Name: runtime_state_changes; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.runtime_state_changes (
    bot_id uuid NOT NULL,
    bot_event_id uuid NOT NULL,
    runtime_state_value_id uuid NOT NULL,
    previous_value_hash character varying(128),
    new_value jsonb NOT NULL,
    new_value_hash character varying(128) NOT NULL,
    change_reason_code character varying(80) NOT NULL
);


--
-- Name: TABLE runtime_state_changes; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.runtime_state_changes IS '봇 전용 상태 변경의 추가 전용 before/after 증적. bot_id가 두 복합 참조에 모두 포함되어 이벤트가 다른 봇 소유 상태 행을 변경할 수 없다.';


--
-- Name: COLUMN runtime_state_changes.previous_value_hash; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON COLUMN bot.runtime_state_changes.previous_value_hash IS '상태 키 최초 생성 시에만 null.';


--
-- Name: runtime_state_values; Type: TABLE; Schema: bot; Owner: -
--

CREATE TABLE bot.runtime_state_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    flow_id uuid NOT NULL,
    instrument_id uuid,
    element_instance_key character varying(160) NOT NULL,
    state_definition_key character varying(160) NOT NULL,
    value_type bot.runtime_value_type NOT NULL,
    current_value jsonb NOT NULL,
    last_event_sequence bigint NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE runtime_state_values; Type: COMMENT; Schema: bot; Owner: -
--

COMMENT ON TABLE bot.runtime_state_values IS '평가 간 유지가 필요한 공식 봇 전용 Flow 상태만 PostgreSQL이 소유. 주문 Element의 LAST_SUCCESSFUL_FILL_AT 상태는 마지막 정상 전량 Fill 시각을 저장하며, 현재 시각이 이 값과 minReactivationIntervalSeconds를 지난 경우에만 같은 Element가 새 Intent를 만들 수 있다. 거절·만료와 미체결 Order 생성은 이 값을 갱신하지 않는다. 명시적 봇/파티션/Flow 소유가 봇 간 누출을 방지하고, instrument_id는 Flow 전역 상태에서만 null. 공유 가격·캔들·지표·캘린더·피처 값은 여기 금지이며 market_data 공유 계산이나 일회성 캐시 소관. instrument_id의 null-safe 유일성은 마이그레이션에서 강제.';


--
-- Name: backtest_aggregate_results; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.backtest_aggregate_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    participation_id uuid NOT NULL,
    evaluation_plan_room_id uuid NOT NULL,
    scoring_template_version_id uuid NOT NULL,
    weighted_return_pct numeric(18,8) NOT NULL,
    weighted_sharpe_ratio numeric(18,8),
    weighted_max_drawdown_pct numeric(18,8) NOT NULL,
    worst_period_max_drawdown_pct numeric(18,8) NOT NULL,
    final_score numeric(24,10) NOT NULL,
    metrics_document jsonb NOT NULL,
    period_result_set_hash character varying(128) NOT NULL,
    calculation_rules_version character varying(80) NOT NULL,
    aggregate_hash character varying(128) NOT NULL,
    calculated_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone NOT NULL,
    published_at timestamp with time zone NOT NULL,
    CONSTRAINT competition_backtest_aggregate_publication_order CHECK ((published_at >= verified_at)),
    CONSTRAINT competition_backtest_aggregate_verification_order CHECK ((verified_at >= calculated_at))
);


--
-- Name: TABLE backtest_aggregate_results; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.backtest_aggregate_results IS '모든 필수 기간 Run이 성공·검증된 Participation에만 생성되는 불변 최종 집계. 기간별 0~100 점수는 만들지 않고 원래 지표에 importance_weight를 적용하며 weighted와 worst-period 위험을 함께 보존한다. published_at부터 최종 점수와 현재 순위를 즉시 공개하지만 기간별 결과는 ENDED 전까지 숨긴다. 한 기간이라도 최종 실패하면 이 행을 만들지 않고 Participation을 EVALUATION_FAILED로 종료한다.';


--
-- Name: backtest_evaluation_periods; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.backtest_evaluation_periods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    evaluation_plan_room_id uuid NOT NULL,
    period_sequence integer NOT NULL,
    evaluation_start date NOT NULL,
    evaluation_end date NOT NULL,
    importance_weight numeric(18,12) NOT NULL,
    input_set_hash character varying(128) NOT NULL,
    CONSTRAINT competition_backtest_period_order CHECK ((evaluation_end >= evaluation_start)),
    CONSTRAINT competition_backtest_period_sequence_positive CHECK ((period_sequence >= 1)),
    CONSTRAINT competition_backtest_period_weight_range CHECK (((importance_weight > (0)::numeric) AND (importance_weight <= (1)::numeric)))
);


--
-- Name: TABLE backtest_evaluation_periods; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.backtest_evaluation_periods IS '서로 독립 초기 상태로 실행하는 숨은 기간. 같은 계획의 기간 범위 비중복, 행 수 = period_count, importance_weight 합계 = 1은 잠금 시 PostgreSQL deferred trigger와 daterange exclusion constraint로 강제한다. 기간 길이로 자동 가중하지 않고 플랫폼이 시장 중요도를 직접 설정한다.';


--
-- Name: backtest_evaluation_plans; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.backtest_evaluation_plans (
    room_id uuid NOT NULL,
    plan_version character varying(40) NOT NULL,
    period_count integer NOT NULL,
    plan_hash character varying(128) NOT NULL,
    commitment_hash character varying(128) NOT NULL,
    commitment_nonce_ciphertext text NOT NULL,
    nonce_key_version smallint NOT NULL,
    locked_at timestamp with time zone NOT NULL,
    disclosed_at timestamp with time zone,
    CONSTRAINT competition_backtest_nonce_key_version_positive CHECK ((nonce_key_version > 0)),
    CONSTRAINT competition_backtest_period_count_minimum CHECK ((period_count >= 2)),
    CONSTRAINT competition_backtest_plan_disclosure_order CHECK (((disclosed_at IS NULL) OR (disclosed_at >= locked_at)))
);


--
-- Name: TABLE backtest_evaluation_plans; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.backtest_evaluation_plans IS '플랫폼 공식 BACKTEST Room의 1:1 불변 비공개 평가 계획. 초기 자금·수수료·슬리피지·채점 공식은 room_rules로 항상 공개하고, 실제 기간·가중치·Dataset Manifest는 ENDED 전까지 권한 분리한다. 잠금 시 비밀 nonce를 포함한 commitment_hash만 공개하고 ENDED 뒤 계획과 nonce를 공개해 중간 변경이 없었음을 검증한다. nonce 평문은 저장하지 않는다.';


--
-- Name: backtest_period_datasets; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.backtest_period_datasets (
    evaluation_period_id uuid NOT NULL,
    dataset_manifest_id uuid NOT NULL,
    purpose_code character varying(80) NOT NULL,
    locked_dataset_hash character varying(128) NOT NULL
);


--
-- Name: TABLE backtest_period_datasets; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.backtest_period_datasets IS '모든 참가 Bot의 동일 기간 Run이 재사용하는 잠긴 시장 데이터 입력. 원본 S3 객체는 공개하지 않고 ENDED 뒤 Manifest 식별자·버전·해시만 공개한다.';


--
-- Name: backtest_period_feature_materializations; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.backtest_period_feature_materializations (
    evaluation_period_id uuid NOT NULL,
    feature_materialization_id uuid NOT NULL,
    locked_result_hash character varying(128) NOT NULL
);


--
-- Name: TABLE backtest_period_feature_materializations; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.backtest_period_feature_materializations IS '공통 서버 계산 결과를 참가 Bot마다 다시 계산하지 않도록 평가 기간이 잠근 공유 Feature Materialization 입력.';


--
-- Name: backtest_period_runs; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.backtest_period_runs (
    participation_id uuid NOT NULL,
    evaluation_period_id uuid NOT NULL,
    run_id uuid NOT NULL,
    verified_at timestamp with time zone,
    verification_failure_code character varying(80),
    locked_result_hash character varying(128),
    CONSTRAINT competition_backtest_failed_verification_not_verified CHECK (((verification_failure_code IS NULL) OR (verified_at IS NULL))),
    CONSTRAINT competition_backtest_verified_run_has_hash CHECK (((verified_at IS NULL) OR ((verification_failure_code IS NULL) AND (locked_result_hash IS NOT NULL))))
);


--
-- Name: TABLE backtest_period_runs; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.backtest_period_runs IS '참가 Bot·숨은 기간 하나와 기존 backtest.runs 하나를 정확히 연결한다. 각 Run은 동일 Bot 구성에서 동일 초기 자금, 빈 포지션·주문·예약·원장 변동·Flow 상태로 독립 시작한다. 실패 기간만 같은 Run의 run_attempts로 재시도하고 성공 기간은 다시 계산하지 않는다.';


--
-- Name: leaderboard_entries; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.leaderboard_entries (
    snapshot_id uuid NOT NULL,
    participation_id uuid NOT NULL,
    performance_snapshot_id uuid,
    backtest_aggregate_result_id uuid,
    rank integer,
    is_joint_rank boolean DEFAULT false NOT NULL,
    eligibility_status character varying(30) NOT NULL,
    eligibility_reason_code character varying(80),
    score numeric(24,10),
    tie_break_document jsonb NOT NULL,
    calculation_document jsonb NOT NULL,
    CONSTRAINT competition_leaderboard_exactly_one_result_source CHECK ((((performance_snapshot_id IS NOT NULL) AND (backtest_aggregate_result_id IS NULL)) OR ((performance_snapshot_id IS NULL) AND (backtest_aggregate_result_id IS NOT NULL)))),
    CONSTRAINT competition_leaderboard_rank_positive CHECK ((rank > 0))
);


--
-- Name: TABLE leaderboard_entries; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.leaderboard_entries IS 'LIVE_PAPER는 불변 performance_snapshot_id, BACKTEST는 검증된 backtest_aggregate_result_id 중 정확히 하나를 공식 점수 근거로 사용한다. Snapshot Room 유형, Participation Room과 결과 소유권 일치는 deferred trigger가 검증한다.';


--
-- Name: leaderboard_snapshots; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.leaderboard_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    scoring_template_version_id uuid NOT NULL,
    cutoff_at timestamp with time zone NOT NULL,
    status competition.leaderboard_status NOT NULL,
    result_hash character varying(128) NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE leaderboard_snapshots; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.leaderboard_snapshots IS '불변 공개 리더보드 스냅샷. 공식 BACKTEST는 새 aggregate result가 published_at에 공개될 때마다 현재 완료 Bot만 포함한 PUBLISHED 스냅샷을 만들고 별도 임시 표시는 하지 않는다. 모든 Participation terminal 뒤 FINAL 스냅샷을 만든다.';


--
-- Name: live_evaluation_segments; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.live_evaluation_segments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    participation_id uuid NOT NULL,
    segment_type character varying(40) NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    start_event_sequence bigint,
    end_event_sequence bigint,
    initial_state_hash character varying(128),
    final_state_hash character varying(128),
    source_set_hash character varying(128),
    virtual_liquidation_document jsonb,
    finalized_at timestamp with time zone
);


--
-- Name: TABLE live_evaluation_segments; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.live_evaluation_segments IS 'LIVE_PAPER Participation에만 존재하는 공식 평가 구간. 가상 청산은 채점 전용 증거이며 라이브 체결·예약·원장 분개를 생성하지 않는다. Participation의 Room 유형은 deferred trigger가 검증한다.';


--
-- Name: live_room_rules; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.live_room_rules (
    room_id uuid NOT NULL,
    stopped_bot_slot_policy character varying(30) NOT NULL,
    minimum_operation_seconds bigint NOT NULL,
    minimum_fill_count integer NOT NULL,
    CONSTRAINT competition_live_minimum_fill_nonnegative CHECK ((minimum_fill_count >= 0)),
    CONSTRAINT competition_live_minimum_operation_nonnegative CHECK ((minimum_operation_seconds >= 0))
);


--
-- Name: TABLE live_room_rules; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.live_room_rules IS 'LIVE_PAPER 대회에만 존재하는 운영·채점 자격 규칙. room_id가 LIVE_PAPER인지 PostgreSQL deferred constraint trigger가 검증한다.';


--
-- Name: participation_events; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.participation_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    participation_id uuid NOT NULL,
    event_sequence integer NOT NULL,
    event_type character varying(50) NOT NULL,
    reason_code character varying(80),
    occurred_at timestamp with time zone NOT NULL,
    payload_document jsonb NOT NULL
);


--
-- Name: TABLE participation_events; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.participation_events IS '참가 이벤트 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: participations; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.participations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    bot_id uuid NOT NULL,
    owner_account_id uuid,
    anonymous_alias character varying(80) NOT NULL,
    status competition.participation_status NOT NULL,
    joined_at timestamp with time zone NOT NULL,
    evaluation_started_at timestamp with time zone,
    evaluation_finished_at timestamp with time zone,
    evaluation_failure_code character varying(80),
    withdrawn_at timestamp with time zone,
    withdrawal_reason_code character varying(80),
    expelled_at timestamp with time zone,
    expulsion_reason_code character varying(80),
    post_room_action competition.post_room_action,
    action_recorded_at timestamp with time zone,
    action_locked_at timestamp with time zone,
    owner_anonymized_at timestamp with time zone,
    CONSTRAINT competition_completed_participation_has_result CHECK (((status <> 'COMPLETED'::competition.participation_status) OR ((evaluation_finished_at IS NOT NULL) AND (evaluation_failure_code IS NULL)))),
    CONSTRAINT competition_expelled_has_time CHECK (((status <> 'EXPELLED'::competition.participation_status) OR (expelled_at IS NOT NULL))),
    CONSTRAINT competition_failed_participation_has_reason CHECK (((status <> 'EVALUATION_FAILED'::competition.participation_status) OR ((evaluation_finished_at IS NOT NULL) AND (evaluation_failure_code IS NOT NULL)))),
    CONSTRAINT competition_participation_evaluation_order CHECK (((evaluation_finished_at IS NULL) OR (evaluation_started_at IS NOT NULL))),
    CONSTRAINT competition_participation_owner_state CHECK ((((owner_account_id IS NOT NULL) AND (owner_anonymized_at IS NULL)) OR ((owner_account_id IS NULL) AND (owner_anonymized_at IS NOT NULL)))),
    CONSTRAINT competition_withdrawn_has_time CHECK (((status <> 'WITHDRAWN'::competition.participation_status) OR (withdrawn_at IS NOT NULL)))
);


--
-- Name: TABLE participations; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.participations IS '사용자가 기존 Bot을 제출하는 행이 아니다. Strategy 선택 요청이 성공하면 출처 관계 없는 독립 새 Bot, Bot 스냅샷 계층, Participation, 최초 사건과 Outbox를 한 트랜잭션으로 생성한다. 같은 계정은 per_account_bot_limit까지 여러 행을 가질 수 있다. LIVE_PAPER는 Room 평가 시작 뒤 신규 참가 금지. 공식 BACKTEST는 participation_closes_at 전까지 진행 중 참가 가능하지만 EVALUATING 중 승인된 행은 사용자 취소·교체 불가하고 성공·실패와 관계없이 슬롯을 계속 점유한다.';


--
-- Name: COLUMN participations.post_room_action; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON COLUMN competition.participations.post_room_action IS 'null이면 결정 마감 시 STOP 처리.';


--
-- Name: room_evaluation_account_results; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.room_evaluation_account_results (
    request_message_id uuid NOT NULL,
    result_message_id uuid NOT NULL,
    participation_id uuid NOT NULL,
    bot_id uuid NOT NULL,
    evaluation_segment_id uuid NOT NULL,
    result_type character varying(20) NOT NULL,
    producer_idempotency_key character varying(160) NOT NULL,
    request_payload_hash character varying(128) NOT NULL,
    result_payload_hash character varying(128) NOT NULL,
    payload_document jsonb NOT NULL,
    received_at timestamp with time zone NOT NULL,
    applied_at timestamp with time zone,
    failure_code character varying(80),
    CONSTRAINT room_evaluation_account_result_application_check CHECK (((((result_type)::text = 'OPENED'::text) AND (failure_code IS NULL)) OR (((result_type)::text = 'REJECTED'::text) AND (failure_code IS NOT NULL)))),
    CONSTRAINT room_evaluation_account_result_type_check CHECK (((result_type)::text = ANY ((ARRAY['OPENED'::character varying, 'REJECTED'::character varying])::text[])))
);


--
-- Name: room_events; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.room_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    event_sequence integer NOT NULL,
    event_type character varying(60) NOT NULL,
    resulting_status competition.room_status NOT NULL,
    reason_code character varying(80),
    occurred_at timestamp with time zone NOT NULL,
    payload_document jsonb NOT NULL
);


--
-- Name: TABLE room_events; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.room_events IS '추가 전용 생명주기 증적. rooms.status는 가드된 현재 Projection일 뿐이다.';


--
-- Name: room_final_access_grants; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.room_final_access_grants (
    room_id uuid NOT NULL,
    account_id uuid NOT NULL,
    snapshot_id uuid NOT NULL,
    eligibility_basis character varying(40) NOT NULL,
    granted_at timestamp with time zone NOT NULL,
    CONSTRAINT competition_final_access_basis_valid CHECK (((eligibility_basis)::text = ANY ((ARRAY['CREATOR'::character varying, 'ACTIVE_PARTICIPANT'::character varying])::text[])))
);


--
-- Name: TABLE room_final_access_grants; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.room_final_access_grants IS 'Immutable SECRET-room FINAL leaderboard access frozen at room finalization; query expiry does not delete evidence.';


--
-- Name: room_invitations; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.room_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    issued_by_account_id uuid NOT NULL,
    credential_type competition.invitation_credential_type NOT NULL,
    credential_digest character varying(128) NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    revocation_reason_code character varying(80)
);


--
-- Name: TABLE room_invitations; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.room_invitations IS '평문 초대 비밀값은 저장하지 않는다. 활성 초대는 participation_closes_at 또는 더 이른 방 종료 시점에 만료. PLATFORM 공식 대회에서 초대를 사용할 수 있는지는 Room access policy가 결정한다.';


--
-- Name: room_rules; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.room_rules (
    room_id uuid NOT NULL,
    scoring_template_version_id uuid NOT NULL,
    initial_cash_amount numeric(24,8) NOT NULL,
    currency_code character(3) DEFAULT 'USD'::bpchar NOT NULL,
    bot_participation_limit integer NOT NULL,
    per_account_bot_limit integer NOT NULL,
    eligibility_document jsonb NOT NULL,
    market_scope_document jsonb NOT NULL,
    scoring_parameters jsonb NOT NULL,
    fee_policy_id uuid NOT NULL,
    slippage_rate_bps integer NOT NULL,
    buying_power_buffer_policy_id uuid NOT NULL,
    precision_rules_version character varying(80) NOT NULL,
    rules_hash character varying(128) NOT NULL,
    locked_at timestamp with time zone NOT NULL,
    CONSTRAINT competition_account_bot_limit_valid CHECK (((per_account_bot_limit > 0) AND (per_account_bot_limit <= bot_participation_limit))),
    CONSTRAINT competition_bot_participation_limit_positive CHECK ((bot_participation_limit > 0)),
    CONSTRAINT competition_fixed_slippage_five_bps CHECK ((slippage_rate_bps = 5)),
    CONSTRAINT competition_initial_cash_positive CHECK ((initial_cash_amount > (0)::numeric))
);


--
-- Name: TABLE room_rules; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.room_rules IS '모든 대회가 공유하는 잠긴 공개 규칙. 초기 자금, 수수료·고정 슬리피지 정책 버전, 채점 공식과 계산 규칙은 모집·평가·종료 상태와 관계없이 공개한다. 진행 중 참가 허용은 late_submission 문자열이 아니라 Room 유형과 잠긴 일정으로 결정한다.';


--
-- Name: COLUMN room_rules.slippage_rate_bps; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON COLUMN competition.room_rules.slippage_rate_bps IS '고정 5 bps.';


--
-- Name: room_schedules; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.room_schedules (
    room_id uuid NOT NULL,
    recruitment_opens_at timestamp with time zone NOT NULL,
    participation_opens_at timestamp with time zone NOT NULL,
    evaluation_starts_at timestamp with time zone NOT NULL,
    participation_closes_at timestamp with time zone NOT NULL,
    evaluation_ends_at timestamp with time zone NOT NULL,
    finalization_deadline_at timestamp with time zone NOT NULL,
    timezone_name character varying(80) NOT NULL,
    CONSTRAINT competition_evaluation_window_order CHECK ((evaluation_starts_at <= evaluation_ends_at)),
    CONSTRAINT competition_finalization_after_evaluation CHECK ((evaluation_ends_at <= finalization_deadline_at)),
    CONSTRAINT competition_participation_before_evaluation_end CHECK ((participation_closes_at <= evaluation_ends_at)),
    CONSTRAINT competition_participation_window_order CHECK ((participation_opens_at <= participation_closes_at)),
    CONSTRAINT competition_recruitment_before_participation CHECK ((recruitment_opens_at <= participation_opens_at))
);


--
-- Name: TABLE room_schedules; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.room_schedules IS '잠긴 공통 일정. participation_closes_at 미입력의 논리적 기본값은 evaluation_ends_at이며 PostgreSQL DEFAULT가 형제 컬럼을 참조할 수 없으므로 생성 함수가 복사한다. LIVE_PAPER는 participation_closes_at <= evaluation_starts_at, 공식 BACKTEST는 participation_closes_at <= evaluation_ends_at을 유형별 deferred trigger가 강제한다. 마감 전에 승인된 BACKTEST Participation은 evaluation_ends_at 뒤에도 finalization_deadline_at까지 완료한다.';


--
-- Name: rooms; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.rooms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    competition_type competition.competition_type NOT NULL,
    organizer_type competition.organizer_type NOT NULL,
    creator_account_id uuid,
    created_by_operator_id uuid,
    name character varying(120) NOT NULL,
    access_type competition.room_access_type NOT NULL,
    status competition.room_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    ended_at timestamp with time zone,
    invalidated_at timestamp with time zone,
    invalidation_reason_code character varying(80),
    creator_anonymized_at timestamp with time zone,
    CONSTRAINT competition_backtest_platform_only CHECK (((competition_type <> 'BACKTEST'::competition.competition_type) OR (organizer_type = 'PLATFORM'::competition.organizer_type))),
    CONSTRAINT competition_room_organizer_actor CHECK ((((organizer_type = 'USER'::competition.organizer_type) AND (((creator_account_id IS NOT NULL) AND (creator_anonymized_at IS NULL)) OR ((creator_account_id IS NULL) AND (creator_anonymized_at IS NOT NULL))) AND (created_by_operator_id IS NULL)) OR ((organizer_type = 'PLATFORM'::competition.organizer_type) AND (creator_account_id IS NULL) AND (creator_anonymized_at IS NULL) AND (created_by_operator_id IS NOT NULL))))
);


--
-- Name: TABLE rooms; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.rooms IS '라이브와 백테스트 대회의 공통 루트. BACKTEST는 플랫폼 공식 대회만 허용한다. 플랫폼 대회는 고객 계정을 소유자로 가장하지 않고 실제 개설 운영자를 감사 FK로 남긴다. status는 append-only room_events에서 재구축 가능한 현재 Projection이다.';


--
-- Name: scoring_template_versions; Type: TABLE; Schema: competition; Owner: -
--

CREATE TABLE competition.scoring_template_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_code character varying(80) NOT NULL,
    version character varying(40) NOT NULL,
    rules_document jsonb NOT NULL,
    rules_hash character varying(128) NOT NULL,
    published_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone
);


--
-- Name: TABLE scoring_template_versions; Type: COMMENT; Schema: competition; Owner: -
--

COMMENT ON TABLE competition.scoring_template_versions IS '채점 템플릿 버전 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: account_closure_readiness; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_closure_readiness (
    correlation_id uuid NOT NULL,
    generation bigint NOT NULL,
    account_id uuid NOT NULL,
    domain identity.account_closure_domain NOT NULL,
    status identity.account_closure_readiness_status NOT NULL,
    reason_code character varying(80) NOT NULL,
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    observed_at timestamp with time zone NOT NULL,
    CONSTRAINT account_closure_readiness_evidence_object CHECK ((jsonb_typeof(evidence) = 'object'::text)),
    CONSTRAINT account_closure_readiness_generation_positive CHECK ((generation > 0))
);


--
-- Name: TABLE account_closure_readiness; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_closure_readiness IS 'Generation-scoped fail-closed evidence. CLOSED requires TRADING=SETTLED and every other domain=FROZEN.';


--
-- Name: account_closure_runs; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_closure_runs (
    correlation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    lifecycle_version bigint NOT NULL,
    cancellation_deadline_at timestamp with time zone NOT NULL,
    generation bigint DEFAULT 0 NOT NULL,
    started_at timestamp with time zone NOT NULL,
    last_checked_at timestamp with time zone NOT NULL,
    closed_at timestamp with time zone
);


--
-- Name: account_consents; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_consents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    policy_document_id uuid NOT NULL,
    decision identity.consent_decision NOT NULL,
    supersedes_consent_id uuid,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE account_consents; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_consents IS '추가 전용 동의 결정 이력. 철회·재동의는 기존 법적 증적을 수정하지 않고 새 행을 생성.';


--
-- Name: account_emails; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_emails (
    account_id uuid NOT NULL,
    email_ciphertext text NOT NULL,
    email_lookup_hmac character varying(128) NOT NULL,
    email_lookup_key_version smallint NOT NULL,
    encryption_key_version smallint NOT NULL,
    status identity.email_status NOT NULL,
    verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT account_email_status_timestamps_consistent CHECK ((((status = 'PENDING_VERIFICATION'::identity.email_status) AND (verified_at IS NULL) AND (revoked_at IS NULL)) OR ((status = 'VERIFIED'::identity.email_status) AND (verified_at IS NOT NULL) AND (revoked_at IS NULL)) OR ((status = 'REVOKED'::identity.email_status) AND (revoked_at IS NOT NULL))))
);


--
-- Name: TABLE account_emails; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_emails IS '공유 PK로 계정당 이메일 최대 1행. 지연 생명주기 가드가 활성화 가능한 계정에 이 행 소유와 활성화 전 VERIFIED를 요구. 애플리케이션은 정규화 후 키 기반 조회하고 평문 인덱스를 두지 않으며, 회수된 이메일의 재사용 허용 여부를 정의해야 한다.';


--
-- Name: account_identifier_quarantines; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_identifier_quarantines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    lifecycle_event_id uuid NOT NULL,
    identifier_kind character varying(20) NOT NULL,
    provider_code character varying(40) NOT NULL,
    identifier_fingerprint character varying(128) NOT NULL,
    fingerprint_key_version smallint NOT NULL,
    quarantined_at timestamp with time zone NOT NULL,
    reuse_eligible_at timestamp with time zone NOT NULL,
    released_at timestamp with time zone,
    release_reason_code character varying(80),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_identifier_quarantine_exact_period CHECK ((reuse_eligible_at = (quarantined_at + '30 days'::interval))),
    CONSTRAINT account_identifier_quarantine_kind_supported CHECK (((identifier_kind)::text = ANY ((ARRAY['EMAIL'::character varying, 'OIDC_SUBJECT'::character varying])::text[]))),
    CONSTRAINT account_identifier_quarantine_release_complete CHECK (((released_at IS NULL) OR ((released_at >= reuse_eligible_at) AND (release_reason_code IS NOT NULL))))
);


--
-- Name: TABLE account_identifier_quarantines; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_identifier_quarantines IS 'Keyed HMAC tombstones block email or OIDC subject reuse for exactly 30x24 hours after CLOSED; plaintext identifiers are forbidden.';


--
-- Name: account_legal_holds; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_legal_holds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    data_category identity.account_data_category NOT NULL,
    status identity.legal_hold_status DEFAULT 'ACTIVE'::identity.legal_hold_status NOT NULL,
    blocks_identifier_reuse boolean DEFAULT false NOT NULL,
    basis_reference character varying(160) NOT NULL,
    applied_by character varying(120) NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL,
    released_by character varying(120),
    released_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_legal_hold_identifier_scope CHECK (((NOT blocks_identifier_reuse) OR (data_category = 'CONTACT_IDENTIFIER'::identity.account_data_category))),
    CONSTRAINT account_legal_hold_release_after_apply CHECK (((released_at IS NULL) OR (released_at >= applied_at))),
    CONSTRAINT account_legal_hold_release_complete CHECK (((status <> 'RELEASED'::identity.legal_hold_status) OR ((released_at IS NOT NULL) AND (released_by IS NOT NULL))))
);


--
-- Name: account_lifecycle_command_receipts; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_lifecycle_command_receipts (
    account_id uuid NOT NULL,
    command_type character varying(60) NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    request_hash character varying(128) NOT NULL,
    response_status smallint NOT NULL,
    response_code character varying(80),
    response_document jsonb NOT NULL,
    lifecycle_event_id uuid,
    completed_at timestamp with time zone NOT NULL,
    CONSTRAINT account_lifecycle_receipt_command_nonblank CHECK ((length(btrim((command_type)::text)) > 0)),
    CONSTRAINT account_lifecycle_receipt_idempotency_key_nonblank CHECK ((length(btrim((idempotency_key)::text)) > 0)),
    CONSTRAINT account_lifecycle_receipt_request_hash_nonblank CHECK ((length(btrim((request_hash)::text)) > 0)),
    CONSTRAINT account_lifecycle_receipt_response_status_range CHECK (((response_status >= 100) AND (response_status <= 599)))
);


--
-- Name: TABLE account_lifecycle_command_receipts; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_lifecycle_command_receipts IS 'Immutable completed-command receipts keyed by account, command type, and idempotency key; request hash rejects key reuse with a different request and response_document reproduces the original response.';


--
-- Name: account_lifecycle_events; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_lifecycle_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    event_sequence bigint NOT NULL,
    previous_status identity.account_lifecycle_status,
    new_status identity.account_lifecycle_status NOT NULL,
    reason_code character varying(80),
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    previous_event_id uuid,
    lifecycle_version bigint NOT NULL,
    command_type character varying(60) NOT NULL,
    actor_type character varying(40) NOT NULL,
    actor_id character varying(160),
    correlation_id uuid NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    request_hash character varying(128) NOT NULL,
    retention_policy_version character varying(80),
    cancellation_deadline_at timestamp with time zone,
    dormancy_basis_at timestamp with time zone,
    CONSTRAINT account_lifecycle_event_dormancy_basis_required CHECK ((((command_type)::text <> 'ACCOUNT_DORMANT'::text) OR ((dormancy_basis_at IS NOT NULL) AND (occurred_at >= (dormancy_basis_at + '1 year'::interval))))),
    CONSTRAINT account_lifecycle_event_idempotency_complete CHECK (((length(btrim((idempotency_key)::text)) > 0) AND (length(btrim((request_hash)::text)) > 0))),
    CONSTRAINT account_lifecycle_event_previous_link_complete CHECK ((((event_sequence = 1) AND (previous_event_id IS NULL)) OR ((event_sequence > 1) AND (previous_event_id IS NOT NULL)))),
    CONSTRAINT account_lifecycle_event_sequence_positive CHECK ((event_sequence > 0)),
    CONSTRAINT account_lifecycle_event_status_chain_complete CHECK ((((event_sequence = 1) AND (previous_status IS NULL)) OR ((event_sequence > 1) AND (previous_status IS NOT NULL) AND (previous_status <> new_status)))),
    CONSTRAINT account_lifecycle_event_version_matches_sequence CHECK ((lifecycle_version = event_sequence)),
    CONSTRAINT account_lifecycle_event_withdrawal_deadline_required CHECK ((((command_type)::text <> 'WITHDRAWAL_REQUESTED'::text) OR (cancellation_deadline_at = (occurred_at + '30 days'::interval))))
);


--
-- Name: TABLE account_lifecycle_events; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_lifecycle_events IS 'Append-only A12 lifecycle evidence; every predecessor has the same account, adjacent sequence, and matching status, and the account projection must point at its head.';


--
-- Name: account_preferences; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_preferences (
    account_id uuid NOT NULL,
    language_code character varying(12) NOT NULL,
    timezone_name character varying(80) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    theme_preference identity.theme_preference DEFAULT 'SYSTEM'::identity.theme_preference NOT NULL
);


--
-- Name: TABLE account_preferences; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_preferences IS '계정과 원자적으로 생성. 알림 수신 설정은 operations.notification_preferences, 마케팅 법적 동의는 account_consents에 유지.';


--
-- Name: COLUMN account_preferences.language_code; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.account_preferences.language_code IS '현재 지원 값은 ko와 en.';


--
-- Name: COLUMN account_preferences.timezone_name; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.account_preferences.timezone_name IS '표시 전용 IANA 시간대 이름. 시장 계산은 거래소 캘린더 사용.';


--
-- Name: COLUMN account_preferences.theme_preference; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.account_preferences.theme_preference IS 'LIGHT, DARK, or SYSTEM. Existing and repaired accounts default to SYSTEM.';


--
-- Name: account_retention_execution_attempts; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_retention_execution_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    obligation_id uuid NOT NULL,
    account_id uuid NOT NULL,
    data_category identity.account_data_category NOT NULL,
    correlation_id uuid NOT NULL,
    legal_hold_id uuid,
    outcome character varying(20) NOT NULL,
    failure_code character varying(80),
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    CONSTRAINT account_retention_attempt_failure_shape CHECK (((((outcome)::text = 'FAILED'::text) AND (failure_code IS NOT NULL)) OR (((outcome)::text <> 'FAILED'::text) AND (failure_code IS NULL)))),
    CONSTRAINT account_retention_attempt_outcome CHECK (((outcome)::text = ANY ((ARRAY['COMPLETED'::character varying, 'HELD'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: TABLE account_retention_execution_attempts; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_retention_execution_attempts IS 'Append-only per-account retention worker outcomes. Each destructive action and legal-hold skip is independently auditable.';


--
-- Name: account_retention_obligations; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_retention_obligations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    lifecycle_event_id uuid NOT NULL,
    retention_policy_version character varying(80),
    data_category identity.account_data_category NOT NULL,
    disposition identity.retention_disposition,
    retention_days integer,
    retain_until timestamp with time zone,
    status identity.retention_obligation_status DEFAULT 'PENDING'::identity.retention_obligation_status NOT NULL,
    failure_code character varying(80),
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_retention_completion_timestamp_required CHECK (((status <> 'COMPLETED'::identity.retention_obligation_status) OR (completed_at IS NOT NULL))),
    CONSTRAINT account_retention_days_nonnegative CHECK (((retention_days IS NULL) OR (retention_days >= 0))),
    CONSTRAINT account_retention_destructive_obligation_has_period CHECK (((disposition IS NULL) OR (disposition = 'RETAIN'::identity.retention_disposition) OR (retention_days IS NOT NULL))),
    CONSTRAINT account_retention_period_complete_or_unapproved CHECK ((((retention_days IS NULL) AND (retain_until IS NULL)) OR ((retention_days IS NOT NULL) AND (retain_until IS NOT NULL)))),
    CONSTRAINT account_retention_policy_snapshot_or_fail_closed CHECK ((((retention_policy_version IS NOT NULL) AND (disposition IS NOT NULL) AND (failure_code IS NULL)) OR ((retention_policy_version IS NULL) AND (disposition IS NULL) AND (retention_days IS NULL) AND (retain_until IS NULL) AND (status = 'FAILED'::identity.retention_obligation_status) AND ((failure_code)::text = 'RETENTION_POLICY_MISSING'::text))))
);


--
-- Name: TABLE account_retention_obligations; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_retention_obligations IS 'Policy snapshot projection. A missing approved policy is represented only by RETENTION_POLICY_MISSING and denies physical deletion.';


--
-- Name: account_retention_policy_proposals; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_retention_policy_proposals (
    proposal_key character varying(80) NOT NULL,
    canonical_status character varying(20) DEFAULT 'PROPOSED'::character varying NOT NULL,
    proposal_document jsonb NOT NULL,
    product_approver_subject character varying(160) NOT NULL,
    product_approval_evidence text NOT NULL,
    product_approved_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_retention_policy_proposal_document_object CHECK ((jsonb_typeof(proposal_document) = 'object'::text)),
    CONSTRAINT account_retention_policy_proposal_status CHECK (((canonical_status)::text = 'PROPOSED'::text))
);


--
-- Name: TABLE account_retention_policy_proposals; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_retention_policy_proposals IS 'Product-approved recommendation only. It is excluded from canonical policy selection until a canonical policy PR is approved.';


--
-- Name: account_retention_policy_rules; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_retention_policy_rules (
    policy_version character varying(80) NOT NULL,
    data_category identity.account_data_category NOT NULL,
    disposition identity.retention_disposition NOT NULL,
    retention_days integer,
    legal_basis_code character varying(160) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_retention_legacy_combined_retain_only CHECK (((data_category <> 'BOT_STRATEGY_EVALUATION'::identity.account_data_category) OR ((disposition = 'RETAIN'::identity.retention_disposition) AND (retention_days IS NULL)))),
    CONSTRAINT account_retention_policy_destructive_rule_has_period CHECK (((disposition = 'RETAIN'::identity.retention_disposition) OR (retention_days IS NOT NULL))),
    CONSTRAINT account_retention_policy_rule_days_nonnegative CHECK (((retention_days IS NULL) OR (retention_days >= 0)))
);


--
-- Name: account_retention_policy_versions; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_retention_policy_versions (
    version character varying(80) NOT NULL,
    effective_from timestamp with time zone NOT NULL,
    approved_at timestamp with time zone NOT NULL,
    approved_by character varying(120) NOT NULL,
    basis_reference character varying(160) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_retention_policy_approved_before_effective CHECK ((approved_at <= effective_from))
);


--
-- Name: account_sanction_command_receipts; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_sanction_command_receipts (
    account_id uuid NOT NULL,
    command_type character varying(20) NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    request_hash character varying(128) NOT NULL,
    sanction_id uuid NOT NULL,
    correlation_id uuid NOT NULL,
    response_document jsonb NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_sanction_command_receipts_command_type_check CHECK (((command_type)::text = ANY ((ARRAY['APPLY'::character varying, 'LIFT'::character varying, 'EXPIRE'::character varying])::text[])))
);


--
-- Name: TABLE account_sanction_command_receipts; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_sanction_command_receipts IS 'Immutable account-scoped idempotency receipts for sanction commands.';


--
-- Name: account_sanction_events; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_sanction_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sanction_id uuid NOT NULL,
    event_sequence bigint NOT NULL,
    event_type character varying(40) NOT NULL,
    actor_operator_id uuid,
    reason_code character varying(80) NOT NULL,
    evidence_object_id uuid,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    account_id uuid NOT NULL,
    correlation_id uuid NOT NULL,
    previous_status identity.sanction_status,
    resulting_status identity.sanction_status NOT NULL,
    CONSTRAINT account_sanction_event_sequence_positive CHECK ((event_sequence > 0)),
    CONSTRAINT account_sanction_event_type_valid CHECK (((event_type)::text = ANY ((ARRAY['APPLIED'::character varying, 'LIFTED'::character varying, 'EXPIRED'::character varying])::text[])))
);


--
-- Name: TABLE account_sanction_events; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_sanction_events IS '추가 전용 공식 제재 이력. actor null은 시스템 생성 만료 이벤트에서만 허용.';


--
-- Name: COLUMN account_sanction_events.event_type; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.account_sanction_events.event_type IS '값은 APPLIED, LIFTED, EXPIRED.';


--
-- Name: account_sanction_heads; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_sanction_heads (
    account_id uuid NOT NULL,
    aggregate_version bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_sanction_heads_aggregate_version_check CHECK ((aggregate_version >= 0))
);


--
-- Name: TABLE account_sanction_heads; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_sanction_heads IS 'Per-account sanction aggregate version serialized across apply, lift, and expiry commands.';


--
-- Name: account_sanctions; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_sanctions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    sanction_type character varying(40) NOT NULL,
    status identity.sanction_status NOT NULL,
    reason_code character varying(80) NOT NULL,
    applied_by_operator_id uuid NOT NULL,
    applied_at timestamp with time zone NOT NULL,
    effective_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone,
    source_case_id uuid,
    status_changed_at timestamp with time zone NOT NULL,
    public_reference uuid DEFAULT gen_random_uuid() NOT NULL,
    CONSTRAINT account_sanction_expiry_valid CHECK (((((sanction_type)::text = 'SUSPENSION'::text) AND (expires_at IS NOT NULL) AND (expires_at > effective_at)) OR (((sanction_type)::text = 'PERMANENT'::text) AND (expires_at IS NULL)))),
    CONSTRAINT account_sanction_type_valid CHECK (((sanction_type)::text = ANY ((ARRAY['SUSPENSION'::character varying, 'PERMANENT'::character varying])::text[])))
);


--
-- Name: TABLE account_sanctions; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_sanctions IS '현재 제재 집합체. status는 불변 제재 이벤트의 트랜잭션 유지 Projection.';


--
-- Name: COLUMN account_sanctions.sanction_type; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.account_sanctions.sanction_type IS '값은 SUSPENSION 또는 PERMANENT.';


--
-- Name: COLUMN account_sanctions.public_reference; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.account_sanctions.public_reference IS 'Stable non-secret sanction reference exposed to an A19 appeal without copying sanction evidence.';


--
-- Name: account_security_states; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.account_security_states (
    account_id uuid NOT NULL,
    auth_epoch bigint DEFAULT 1 NOT NULL,
    credentials_revoked_before timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_security_auth_epoch_positive CHECK ((auth_epoch > 0))
);


--
-- Name: TABLE account_security_states; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.account_security_states IS '계정당 정확히 하나인 인증 보안 현재 상태. 비밀번호 변경, 로그인 수단 교체, 계정 복구 또는 전체 로그아웃 시 auth_epoch를 증가시켜 이전 세션과 캐시를 일괄 무효화한다.';


--
-- Name: accounts; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lifecycle_status identity.account_lifecycle_status NOT NULL,
    status_changed_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    lifecycle_version bigint DEFAULT 1 NOT NULL,
    last_lifecycle_event_id uuid,
    last_successful_auth_at timestamp with time zone,
    dormant_at timestamp with time zone,
    withdrawal_requested_at timestamp with time zone,
    cancellation_deadline_at timestamp with time zone,
    closing_previous_status identity.account_lifecycle_status,
    closed_at timestamp with time zone,
    anonymized_at timestamp with time zone,
    CONSTRAINT account_anonymized_after_close CHECK (((anonymized_at IS NULL) OR ((closed_at IS NOT NULL) AND (anonymized_at >= closed_at)))),
    CONSTRAINT account_closed_timestamp_required CHECK (((lifecycle_status <> 'CLOSED'::identity.account_lifecycle_status) OR (closed_at IS NOT NULL))),
    CONSTRAINT account_closing_projection_complete CHECK (((lifecycle_status <> 'CLOSING'::identity.account_lifecycle_status) OR ((withdrawal_requested_at IS NOT NULL) AND (cancellation_deadline_at = (withdrawal_requested_at + '30 days'::interval)) AND (closing_previous_status = ANY (ARRAY['ACTIVE'::identity.account_lifecycle_status, 'DORMANT'::identity.account_lifecycle_status]))))),
    CONSTRAINT account_dormant_timestamp_required CHECK (((lifecycle_status <> 'DORMANT'::identity.account_lifecycle_status) OR (dormant_at IS NOT NULL))),
    CONSTRAINT account_lifecycle_version_positive CHECK ((lifecycle_version > 0))
);


--
-- Name: TABLE accounts; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.accounts IS '최소 계정 루트. 환경설정·이메일·인증·동의·제재는 별도 집합체. 계정 생성은 이메일·환경설정을 같은 트랜잭션으로 삽입하고, 활성화에는 단일 이메일의 VERIFIED가 필요. 제재를 lifecycle_status에 겹쳐 싣지 않는다.';


--
-- Name: auth_providers; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.auth_providers (
    id smallint NOT NULL,
    code character varying(40) NOT NULL,
    display_name character varying(80) NOT NULL,
    provider_type identity.auth_provider_type NOT NULL,
    issuer text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE auth_providers; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.auth_providers IS '시드되는 인증 제공자 카탈로그. PASSWORD는 issuer가 없고, OIDC는 정확한 issuer와 불변 subject 검증을 요구.';


--
-- Name: authentication_events; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.authentication_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    event_sequence bigint NOT NULL,
    event_type character varying(60) NOT NULL,
    subject_login_identity_id uuid,
    previous_login_identity_id uuid,
    new_login_identity_id uuid,
    actor_type character varying(30) NOT NULL,
    actor_id uuid,
    reason_code character varying(80),
    correlation_id uuid NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE authentication_events; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.authentication_events IS '계정 인증 보안의 추가 전용 감사 스트림. 로그인 수단 전환 시 이전·새 ID를 함께 기록하며 모든 참조 로그인 ID가 같은 account_id에 속하는지는 지연 제약으로 검증한다. 비밀번호·토큰·복구 코드·OIDC 원문 subject는 기록하지 않는다.';


--
-- Name: COLUMN authentication_events.event_type; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.authentication_events.event_type IS 'LOGIN_IDENTITY_CREATED, VERIFIED, ACTIVATED, REPLACED, DISABLED, PASSWORD_CHANGED, SESSIONS_REVOKED 등.';


--
-- Name: COLUMN authentication_events.actor_type; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.authentication_events.actor_type IS 'ACCOUNT, OPERATOR 또는 SYSTEM.';


--
-- Name: delegated_authorization_events; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.delegated_authorization_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    authorization_id uuid NOT NULL,
    event_sequence bigint NOT NULL,
    event_type character varying(50) NOT NULL,
    actor_type character varying(30) NOT NULL,
    actor_id uuid,
    reason_code character varying(80),
    correlation_id uuid NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    payload_document jsonb NOT NULL
);


--
-- Name: TABLE delegated_authorization_events; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.delegated_authorization_events IS 'Append-only delegation lifecycle evidence. Payloads may identify policy and scopes but never contain tokens, private strategy source, holdings, or result data.';


--
-- Name: COLUMN delegated_authorization_events.event_type; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.delegated_authorization_events.event_type IS 'AUTHORIZED, CREDENTIAL_ISSUED, CREDENTIAL_REVOKED, EXPIRED, or REVOKED.';


--
-- Name: COLUMN delegated_authorization_events.actor_type; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.delegated_authorization_events.actor_type IS 'ACCOUNT or SYSTEM.';


--
-- Name: delegated_authorization_scopes; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.delegated_authorization_scopes (
    authorization_id uuid NOT NULL,
    scope_code identity.delegated_scope NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE delegated_authorization_scopes; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.delegated_authorization_scopes IS 'Immutable after authorization activation. Release, bot lifecycle, room final actions, continuation renewal, and order mutation scopes intentionally do not exist; changing permissions requires a new explicit user grant.';


--
-- Name: delegated_authorization_strategy_targets; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.delegated_authorization_strategy_targets (
    authorization_id uuid NOT NULL,
    strategy_id uuid NOT NULL,
    owner_account_id_at_grant uuid NOT NULL,
    strategy_access_epoch_at_grant bigint NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT delegated_strategy_target_epoch_positive CHECK ((strategy_access_epoch_at_grant > 0))
);


--
-- Name: TABLE delegated_authorization_strategy_targets; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.delegated_authorization_strategy_targets IS 'Immutable explicit Strategy allowlist. Existing authorizations are intentionally not backfilled and therefore fail closed.';


--
-- Name: delegated_authorizations; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.delegated_authorizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    client_label character varying(120) NOT NULL,
    external_provider_code character varying(80),
    status identity.delegated_authorization_status NOT NULL,
    expiry_mode identity.delegated_expiry_mode NOT NULL,
    auth_epoch_at_grant bigint NOT NULL,
    disclosure_policy_document_id uuid NOT NULL,
    scope_set_hash character varying(128) NOT NULL,
    authorized_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    revoked_at timestamp with time zone,
    revoke_reason_code character varying(80),
    authorization_version bigint DEFAULT 1 NOT NULL,
    replaces_authorization_id uuid,
    strategy_target_set_hash character varying(128),
    CONSTRAINT delegated_authorization_auth_epoch_positive CHECK ((auth_epoch_at_grant > 0)),
    CONSTRAINT delegated_authorization_expiry_mode_valid CHECK ((((expiry_mode = 'AT_TIME'::identity.delegated_expiry_mode) AND (expires_at IS NOT NULL)) OR ((expiry_mode <> 'AT_TIME'::identity.delegated_expiry_mode) AND (expires_at IS NULL)))),
    CONSTRAINT delegated_authorization_revocation_state_valid CHECK ((((status = 'REVOKED'::identity.delegated_authorization_status) AND (revoked_at IS NOT NULL)) OR ((status <> 'REVOKED'::identity.delegated_authorization_status) AND (revoked_at IS NULL)))),
    CONSTRAINT delegated_authorization_strategy_target_hash_format CHECK (((strategy_target_set_hash IS NULL) OR ((strategy_target_set_hash)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT delegated_authorization_version_positive CHECK ((authorization_version > 0))
);


--
-- Name: TABLE delegated_authorizations; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.delegated_authorizations IS 'User-approved external AI/tool delegation. The delegate is never the account owner or final approver. A mismatched account auth epoch, sanction, expiry, or revocation blocks every new call without affecting committed server work or running bots.';


--
-- Name: delegated_credentials; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.delegated_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    authorization_id uuid NOT NULL,
    credential_type identity.delegated_credential_type NOT NULL,
    token_digest character varying(128) NOT NULL,
    digest_key_version smallint NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    last_seen_at timestamp with time zone,
    revoked_at timestamp with time zone,
    revoke_reason_code character varying(80),
    superseded_by_credential_id uuid,
    CONSTRAINT delegated_credential_digest_key_version_positive CHECK ((digest_key_version > 0)),
    CONSTRAINT delegated_credential_expiry_after_issue CHECK ((expires_at > issued_at))
);


--
-- Name: TABLE delegated_credentials; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.delegated_credentials IS 'Opaque CLI/MCP credential metadata. Only a keyed digest is stored. A credential can exercise only the current scopes of its active authorization and can never elevate itself.';


--
-- Name: delegated_strategy_derivations; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.delegated_strategy_derivations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    authorization_id uuid NOT NULL,
    credential_id uuid NOT NULL,
    derivation_type character varying(16) NOT NULL,
    source_strategy_id uuid,
    result_strategy_id uuid NOT NULL,
    owner_account_id_at_creation uuid NOT NULL,
    strategy_access_epoch_at_creation bigint NOT NULL,
    correlation_id uuid NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    request_hash character varying(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT delegated_strategy_derivation_epoch_positive CHECK ((strategy_access_epoch_at_creation > 0)),
    CONSTRAINT delegated_strategy_derivation_request_hash_format CHECK (((request_hash)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT delegated_strategy_derivation_type_valid CHECK (((((derivation_type)::text = 'CREATE'::text) AND (source_strategy_id IS NULL)) OR (((derivation_type)::text = 'COPY'::text) AND (source_strategy_id IS NOT NULL) AND (source_strategy_id <> result_strategy_id))))
);


--
-- Name: TABLE delegated_strategy_derivations; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.delegated_strategy_derivations IS 'Append-only CREATE/COPY result provenance. COPY sources must be explicit targets; derived results never become COPY sources.';


--
-- Name: device_authorization_requests; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.device_authorization_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_code_digest character varying(128) NOT NULL,
    user_code_digest character varying(128) NOT NULL,
    digest_key_version smallint NOT NULL,
    client_label character varying(80) NOT NULL,
    status identity.device_authorization_status NOT NULL,
    approved_account_id uuid,
    approved_login_identity_id uuid,
    poll_interval_seconds smallint DEFAULT 5 NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    approved_at timestamp with time zone,
    consumed_at timestamp with time zone,
    denied_at timestamp with time zone,
    failed_attempt_count integer DEFAULT 0 NOT NULL,
    last_polled_at timestamp with time zone,
    CONSTRAINT device_authorization_requests_approval_is_complete CHECK (((status = ANY (ARRAY['APPROVED'::identity.device_authorization_status, 'CONSUMED'::identity.device_authorization_status])) = ((approved_account_id IS NOT NULL) AND (approved_at IS NOT NULL)))),
    CONSTRAINT device_authorization_requests_consumed_is_approved CHECK (((status = 'CONSUMED'::identity.device_authorization_status) = (consumed_at IS NOT NULL))),
    CONSTRAINT device_authorization_requests_denied_is_marked CHECK (((status = 'DENIED'::identity.device_authorization_status) = (denied_at IS NOT NULL)))
);


--
-- Name: TABLE device_authorization_requests; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.device_authorization_requests IS '브라우저 승인으로 CLI 를 인증시키는 기기 인증 요청. 사용자가 보는 짧은 user_code 와 CLI 가 폴링하는 device_code 는 서로 다른 비밀이며 둘 다 다이제스트로만 저장한다. 승인은 브라우저 세션이, 토큰 수령은 device_code 소지자가 한다. 소진은 1회 한정.';


--
-- Name: email_verification_requests; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.email_verification_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    token_digest character varying(128) NOT NULL,
    digest_key_version smallint NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    revoked_at timestamp with time zone,
    failed_attempt_count integer DEFAULT 0 NOT NULL,
    request_ip_prefix inet
);


--
-- Name: TABLE email_verification_requests; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.email_verification_requests IS '추가 전용 인증 시도. 새 요청 발급이 이전 활성 요청을 회수할 수 있으며, 검증과 소진은 원자적.';


--
-- Name: login_identities; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.login_identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    provider_id smallint NOT NULL,
    provider_subject_hmac character varying(128),
    subject_key_version smallint,
    status identity.login_identity_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    linked_at timestamp with time zone,
    activated_at timestamp with time zone,
    last_authenticated_at timestamp with time zone,
    replaced_at timestamp with time zone,
    disabled_at timestamp with time zone,
    disabled_reason_code character varying(80),
    failed_attempt_count integer DEFAULT 0 NOT NULL,
    last_failed_at timestamp with time zone,
    CONSTRAINT login_identity_active_state_complete CHECK (((status <> 'ACTIVE'::identity.login_identity_status) OR ((activated_at IS NOT NULL) AND (replaced_at IS NULL) AND (disabled_at IS NULL)))),
    CONSTRAINT login_identity_disabled_at_required CHECK (((status <> 'DISABLED'::identity.login_identity_status) OR (disabled_at IS NOT NULL))),
    CONSTRAINT login_identity_failed_attempt_count_nonnegative CHECK ((failed_attempt_count >= 0)),
    CONSTRAINT login_identity_replaced_at_required CHECK (((status <> 'REPLACED'::identity.login_identity_status) OR (replaced_at IS NOT NULL)))
);


--
-- Name: TABLE login_identities; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.login_identities IS '계정에는 로그인 가능한 ACTIVE 행을 최대 1개만 허용하며 PostgreSQL 마이그레이션에서 WHERE status = ACTIVE partial unique index로 강제한다. PENDING도 계정당 최대 1개로 제한한다. PENDING은 아직 연결된 로그인 수단이 아니고, 과거 REPLACED/DISABLED 행은 발급 세션과 보안 감사를 위해 보존한다. PASSWORD는 provider subject와 subject_key_version이 null이어야 하고 OIDC는 둘 다 필요하다. 제공자 이메일로 계정을 자동 연결하지 않는다. 로그인 수단 교체는 기존 ACTIVE를 REPLACED로, 검증된 PENDING을 ACTIVE로 바꾸고 auth_epoch 증가와 기존 세션·재설정 요청 회수를 같은 트랜잭션에서 수행한다.';


--
-- Name: oidc_step_up_nonces; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.oidc_step_up_nonces (
    id uuid NOT NULL,
    provider_id smallint NOT NULL,
    nonce_digest character varying(128) NOT NULL,
    digest_key_version smallint NOT NULL,
    requested_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    verification_attempt_count integer DEFAULT 0 NOT NULL,
    last_verification_attempt_at timestamp with time zone,
    consumed_at timestamp with time zone,
    consumed_by_account_id uuid,
    CONSTRAINT oidc_step_up_nonce_attempts_bounded CHECK ((((verification_attempt_count >= 0) AND (verification_attempt_count <= 5)) AND (((verification_attempt_count = 0) AND (last_verification_attempt_at IS NULL)) OR ((verification_attempt_count > 0) AND (last_verification_attempt_at IS NOT NULL))))),
    CONSTRAINT oidc_step_up_nonce_consumption_complete CHECK ((((consumed_at IS NULL) AND (consumed_by_account_id IS NULL)) OR ((consumed_at IS NOT NULL) AND (consumed_by_account_id IS NOT NULL) AND (consumed_at >= requested_at) AND (consumed_at <= expires_at)))),
    CONSTRAINT oidc_step_up_nonce_digest_key_positive CHECK ((digest_key_version > 0)),
    CONSTRAINT oidc_step_up_nonce_window_valid CHECK ((expires_at > requested_at))
);


--
-- Name: TABLE oidc_step_up_nonces; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.oidc_step_up_nonces IS 'Server-issued, single-use OIDC lifecycle step-up challenges. Only an HMAC digest is stored; plaintext nonce and ID token are forbidden.';


--
-- Name: password_credentials; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.password_credentials (
    login_identity_id uuid NOT NULL,
    password_hash text NOT NULL,
    hash_scheme character varying(40) NOT NULL,
    hash_parameters jsonb NOT NULL,
    credential_version bigint DEFAULT 1 NOT NULL,
    password_changed_at timestamp with time zone NOT NULL,
    compromised_at timestamp with time zone
);


--
-- Name: TABLE password_credentials; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.password_credentials IS '오직 PASSWORD 로그인 ID에만 허용. 비밀번호 변경은 credential_version을 증가시키고 같은 워크플로에서 관련 세션을 회수.';


--
-- Name: password_reset_requests; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.password_reset_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    login_identity_id uuid NOT NULL,
    auth_epoch_at_issue bigint NOT NULL,
    credential_version_at_issue bigint NOT NULL,
    token_digest character varying(128) NOT NULL,
    digest_key_version smallint NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    revoked_at timestamp with time zone,
    failed_attempt_count integer DEFAULT 0 NOT NULL,
    request_ip_prefix inet,
    CONSTRAINT password_reset_auth_epoch_positive CHECK ((auth_epoch_at_issue > 0)),
    CONSTRAINT password_reset_credential_version_positive CHECK ((credential_version_at_issue > 0))
);


--
-- Name: TABLE password_reset_requests; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.password_reset_requests IS '계정 이메일이 하나이므로 요청은 발급 당시 ACTIVE PASSWORD 로그인 ID, auth_epoch, credential_version에 바인딩한다. 어느 값이든 바뀌면 이전 요청은 무효다. 토큰 검증, 비밀번호 교체, credential_version·auth_epoch 증가, 요청 소진, 기존 세션과 다른 활성 요청 회수는 원자적이다.';


--
-- Name: policy_documents; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.policy_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    policy_code character varying(80) NOT NULL,
    version character varying(40) NOT NULL,
    language_code character varying(12) NOT NULL,
    title character varying(160) NOT NULL,
    content_format character varying(20) NOT NULL,
    content_text text NOT NULL,
    content_hash character varying(128) NOT NULL,
    is_required boolean DEFAULT true NOT NULL,
    published_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone
);


--
-- Name: TABLE policy_documents; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.policy_documents IS '정책 본문은 작은 불변 관계형 콘텐츠. 대용량 증적 첨부가 도입되면 이 정본 텍스트를 대체하지 않고 storage.objects를 사용.';


--
-- Name: recovery_code_sets; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.recovery_code_sets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    purpose character varying(40) NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    revoke_reason_code character varying(80)
);


--
-- Name: TABLE recovery_code_sets; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.recovery_code_sets IS '계정·용도별 활성 세트는 1개만 허용(마이그레이션의 partial unique index).';


--
-- Name: COLUMN recovery_code_sets.purpose; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON COLUMN identity.recovery_code_sets.purpose IS '현재 제품에서는 ACCOUNT_RECOVERY.';


--
-- Name: recovery_codes; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.recovery_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recovery_code_set_id uuid NOT NULL,
    code_digest character varying(128) NOT NULL,
    digest_key_version smallint NOT NULL,
    used_at timestamp with time zone
);


--
-- Name: TABLE recovery_codes; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.recovery_codes IS '복구 코드 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: refresh_token_families; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.refresh_token_families (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    authenticated_by_login_identity_id uuid NOT NULL,
    auth_epoch_at_issue bigint NOT NULL,
    credential_version_at_issue bigint,
    current_token_digest character varying(128) NOT NULL,
    digest_key_version smallint NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    last_rotated_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    revoke_reason_code character varying(80),
    CONSTRAINT refresh_token_family_auth_epoch_positive CHECK ((auth_epoch_at_issue > 0)),
    CONSTRAINT refresh_token_family_credential_version_positive CHECK (((credential_version_at_issue IS NULL) OR (credential_version_at_issue > 0))),
    CONSTRAINT refresh_token_family_digest_key_version_positive CHECK ((digest_key_version > 0)),
    CONSTRAINT refresh_token_family_time_order_valid CHECK (((last_rotated_at >= issued_at) AND (expires_at > last_rotated_at)))
);


--
-- Name: TABLE refresh_token_families; Type: COMMENT; Schema: identity; Owner: -
--

COMMENT ON TABLE identity.refresh_token_families IS 'Minimal server state for rotating refresh JWT reuse detection. It is not a device session registry and has no concurrent-login policy.';


--
-- Name: corporate_actions; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.corporate_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    instrument_id uuid NOT NULL,
    source_manifest_id uuid NOT NULL,
    provider_event_key character varying(160) NOT NULL,
    action_type character varying(60) NOT NULL,
    effective_at timestamp with time zone NOT NULL,
    terms_document jsonb NOT NULL,
    terms_hash character varying(128) NOT NULL,
    supersedes_action_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE corporate_actions; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.corporate_actions IS '기업행사 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: dataset_lineage; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.dataset_lineage (
    derived_manifest_id uuid NOT NULL,
    source_manifest_id uuid NOT NULL,
    relation_type character varying(40) NOT NULL
);


--
-- Name: TABLE dataset_lineage; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.dataset_lineage IS '데이터셋 계보 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: dataset_manifests; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.dataset_manifests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    feed_id uuid NOT NULL,
    instrument_id uuid,
    data_layer character varying(40) NOT NULL,
    resolution character varying(30) NOT NULL,
    revision_number integer NOT NULL,
    status market_data.dataset_status NOT NULL,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone NOT NULL,
    schema_version character varying(40) NOT NULL,
    dataset_hash character varying(128) NOT NULL,
    supersedes_manifest_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    available_at timestamp with time zone,
    object_count bigint DEFAULT 0 NOT NULL,
    CONSTRAINT dataset_manifest_object_count_nonnegative CHECK ((object_count >= 0))
);


--
-- Name: TABLE dataset_manifests; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.dataset_manifests IS '다중 종목 데이터셋의 null-safe 유일성은 마이그레이션에서 강제해야 한다.';


--
-- Name: COLUMN dataset_manifests.data_layer; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON COLUMN market_data.dataset_manifests.data_layer IS '값은 RAW, NORMALIZED, ADJUSTED, DERIVED.';


--
-- Name: COLUMN dataset_manifests.dataset_hash; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON COLUMN market_data.dataset_manifests.dataset_hash IS 'Hash of the manifest content object set; zero-object manifests share the empty-set hash.';


--
-- Name: COLUMN dataset_manifests.object_count; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON COLUMN market_data.dataset_manifests.object_count IS 'Transactionally maintained object count used to exclude zero-object manifests from content uniqueness.';


--
-- Name: dataset_object_lineage; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.dataset_object_lineage (
    derived_dataset_object_id uuid NOT NULL,
    source_dataset_object_id uuid NOT NULL,
    pipeline_run_id uuid NOT NULL,
    relation_type character varying(40) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT dataset_object_lineage_no_self_reference CHECK ((derived_dataset_object_id <> source_dataset_object_id))
);


--
-- Name: TABLE dataset_object_lineage; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.dataset_object_lineage IS '일·주·월 파티션에서 주·월·연 파티션을 생성한 정확한 파일 단위 계보를 보존한다. 컴팩션 결과는 불변 새 오브젝트이며 이미 잠긴 백테스트 Manifest의 기존 오브젝트 선택을 바꾸지 않는다.';


--
-- Name: COLUMN dataset_object_lineage.relation_type; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON COLUMN market_data.dataset_object_lineage.relation_type IS '컴팩션은 COMPACTED_FROM.';


--
-- Name: dataset_objects; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.dataset_objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dataset_manifest_id uuid NOT NULL,
    object_id uuid NOT NULL,
    object_kind character varying(40) NOT NULL,
    partition_granularity market_data.partition_granularity NOT NULL,
    partition_start date NOT NULL,
    partition_end date NOT NULL,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone NOT NULL,
    shard_key character varying(120) NOT NULL,
    part_number integer NOT NULL,
    row_count bigint NOT NULL,
    min_instrument_id uuid,
    max_instrument_id uuid,
    CONSTRAINT dataset_object_partition_order CHECK ((partition_end > partition_start)),
    CONSTRAINT dataset_object_period_order CHECK ((period_end > period_start))
);


--
-- Name: TABLE dataset_objects; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.dataset_objects IS '오브젝트는 ET 기준 일·주·월·연 파티션을 지원한다. 주 경계는 월요일, 월 경계는 매월 1일, 연 경계는 1월 1일이며 partition_end는 미포함이다. 마이크로배치나 작은 파티션을 더 큰 파티션으로 컴팩션할 때 원본을 덮어쓰지 않고 새 오브젝트·새 데이터셋 리비전·명시적 오브젝트 계보를 만든다. 하나의 공개 Manifest는 같은 shard와 시간 범위에 겹치는 표현을 동시에 포함하지 않는다.';


--
-- Name: COLUMN dataset_objects.partition_start; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON COLUMN market_data.dataset_objects.partition_start IS 'ET 달력 기준 포함 시작일.';


--
-- Name: COLUMN dataset_objects.partition_end; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON COLUMN market_data.dataset_objects.partition_end IS 'ET 달력 기준 미포함 종료일.';


--
-- Name: feature_definitions; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.feature_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    element_catalog_version_id uuid NOT NULL,
    feature_code character varying(120) NOT NULL,
    calculator_version character varying(80) NOT NULL,
    resolution character varying(30) NOT NULL,
    normalized_parameters jsonb NOT NULL,
    output_value_type character varying(40) NOT NULL,
    required_history_points integer NOT NULL,
    definition_hash character varying(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT feature_required_history_nonnegative CHECK ((required_history_points >= 0))
);


--
-- Name: TABLE feature_definitions; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.feature_definitions IS '봇과 무관한 결정적 시장 계산(예: SMA(20))의 불변 정본 정의. definition_hash는 계산기 코드 버전, 정규화 매개변수, resolution, 출력 타입, 히스토리 요구량, 캘린더·정밀도 의미를 포함. 사용자 예산·포지션·런타임 상태·비공개 전략 식별자는 이 해시와 공유 계산 경계에 절대 들어가지 않는다.';


--
-- Name: feature_materializations; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.feature_materializations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    feature_definition_id uuid NOT NULL,
    instrument_id uuid NOT NULL,
    pipeline_run_id uuid NOT NULL,
    input_dataset_set_hash character varying(128) NOT NULL,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone NOT NULL,
    source_watermark character varying(300) NOT NULL,
    output_dataset_manifest_id uuid,
    result_hash character varying(128),
    status operations.work_status NOT NULL,
    available_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT feature_materialization_period_order CHECK ((period_end > period_start)),
    CONSTRAINT feature_materialization_success_complete CHECK (((status <> 'SUCCEEDED'::operations.work_status) OR ((output_dataset_manifest_id IS NOT NULL) AND (result_hash IS NOT NULL) AND (available_at IS NOT NULL))))
);


--
-- Name: TABLE feature_materializations; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.feature_materializations IS '정본 정의·종목·정확한 입력 집합·기간당 과거 공유 계산 결과 1건. 대용량 시계열 값은 S3 호환 스토리지의 DERIVED 데이터셋 오브젝트에 남고, PostgreSQL은 식별자·상태·해시·watermark·출력 매니페스트만 저장. 유일 계산 키와 파이프라인 idempotency가 중복 서버 작업을 방지.';


--
-- Name: feature_snapshot_batches; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.feature_snapshot_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    feature_set_hash character varying(128) NOT NULL,
    input_market_set_hash character varying(128) NOT NULL,
    source_start_watermark character varying(300) NOT NULL,
    source_end_watermark character varying(300) NOT NULL,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone NOT NULL,
    snapshot_object_id uuid,
    batch_hash character varying(128),
    row_count bigint,
    status operations.work_status NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    available_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT feature_snapshot_batch_period_order CHECK ((period_end > period_start)),
    CONSTRAINT feature_snapshot_batch_row_count_positive CHECK (((row_count IS NULL) OR (row_count > 0))),
    CONSTRAINT feature_snapshot_batch_success_complete CHECK (((status <> 'SUCCEEDED'::operations.work_status) OR ((snapshot_object_id IS NOT NULL) AND (batch_hash IS NOT NULL) AND (row_count IS NOT NULL) AND (available_at IS NOT NULL))))
);


--
-- Name: TABLE feature_snapshot_batches; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.feature_snapshot_batches IS '한 번 계산되어 대상 봇 전체로 팬아웃되는 공유 실시간 피처 스냅샷 불변 마이크로배치의 메타데이터. 스냅샷 본문은 스트림/캐시에 버퍼링 후 하나의 오브젝트로 봉인해 틱당 PostgreSQL 행이나 S3 오브젝트 생성을 피한다. 본문 각 행은 배치 로컬 스냅샷 키와 해시를 가지며 평가는 그 키와 정확한 해시를 저장. SUCCEEDED는 오브젝트, batch_hash, row_count, available_at을 요구. 캐시 만료가 정본 증적을 지우지 않는다.';


--
-- Name: feeds; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.feeds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_id uuid NOT NULL,
    code character varying(80) NOT NULL,
    data_kind character varying(40) NOT NULL,
    resolution character varying(30) NOT NULL,
    timezone_name character varying(80) NOT NULL,
    feed_version character varying(40) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone
);


--
-- Name: TABLE feeds; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.feeds IS '시장 데이터 피드 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: instrument_symbols; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.instrument_symbols (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    instrument_id uuid NOT NULL,
    exchange_mic character(4) NOT NULL,
    symbol character varying(32) NOT NULL,
    effective_from timestamp with time zone NOT NULL,
    effective_to timestamp with time zone
);


--
-- Name: TABLE instrument_symbols; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.instrument_symbols IS '마이그레이션은 심볼 유효기간 겹침을 방지해야 한다.';


--
-- Name: instruments; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.instruments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asset_type market_data.asset_type NOT NULL,
    primary_exchange_mic character(4) NOT NULL,
    currency_code character(3) DEFAULT 'USD'::bpchar NOT NULL,
    provider_reference character varying(160),
    listed_at date,
    delisted_at date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE instruments; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.instruments IS '종목 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: pipeline_runs; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.pipeline_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pipeline_code character varying(80) NOT NULL,
    pipeline_version character varying(40) NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    status operations.work_status NOT NULL,
    input_hash character varying(128) NOT NULL,
    output_hash character varying(128),
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    failure_code character varying(80)
);


--
-- Name: TABLE pipeline_runs; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.pipeline_runs IS '파이프라인 실행 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: providers; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(80) NOT NULL,
    display_name character varying(160) NOT NULL,
    rights_version character varying(80) NOT NULL,
    status character varying(30) NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE providers; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.providers IS '시장 데이터 제공자 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: COLUMN providers.rights_version; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON COLUMN market_data.providers.rights_version IS '정확한 제공자와 라이선스 권리는 외부 승인 증적 필요.';


--
-- Name: quality_incidents; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.quality_incidents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dataset_manifest_id uuid,
    instrument_id uuid,
    severity character varying(20) NOT NULL,
    incident_code character varying(80) NOT NULL,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone,
    status character varying(30) NOT NULL,
    evidence_object_id uuid,
    detected_at timestamp with time zone NOT NULL,
    resolved_at timestamp with time zone
);


--
-- Name: TABLE quality_incidents; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.quality_incidents IS '데이터 품질 인시던트 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: stream_watermarks; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.stream_watermarks (
    feed_id uuid NOT NULL,
    last_source_event_at timestamp with time zone NOT NULL,
    last_ingested_at timestamp with time zone NOT NULL,
    last_sequence bigint,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE stream_watermarks; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.stream_watermarks IS '재구축 가능한 시장 데이터 신선도 Projection(market_data 소유, 실시간 피드당 1행). 평가 전 실행 게이트가 quality_incidents와 함께 읽어 시장 데이터 평가 진행 여부를 결정. 전역 지연·장애는 여기와 operations 관측성에만 존재하며 봇 행을 대량 갱신하지 않는다. 컨슈머 lag, 유실 이벤트, outbox 적체는 같은 파이프라인 범위 문제이고 봇은 자신의 execution_blocked_at만 가진다.';


--
-- Name: trading_sessions; Type: TABLE; Schema: market_data; Owner: -
--

CREATE TABLE market_data.trading_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    exchange_mic character(4) NOT NULL,
    session_date date NOT NULL,
    opens_at timestamp with time zone,
    closes_at timestamp with time zone,
    session_type character varying(30) NOT NULL,
    calendar_version character varying(40) NOT NULL
);


--
-- Name: TABLE trading_sessions; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON TABLE market_data.trading_sessions IS '캘린더 버전이 백테스트, 실시간 평가, ET 마감 스냅샷, 주간 오브젝트 검증에 쓰는 세션 경계를 고정.';


--
-- Name: COLUMN trading_sessions.session_type; Type: COMMENT; Schema: market_data; Owner: -
--

COMMENT ON COLUMN market_data.trading_sessions.session_type IS '값은 REGULAR, EARLY_CLOSE, CLOSED.';


--
-- Name: account_email_notification_preferences; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.account_email_notification_preferences (
    account_id uuid NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: TABLE account_email_notification_preferences; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.account_email_notification_preferences IS 'Account-wide opt-in for optional notification emails. Missing rows mean disabled; mandatory delivery is policy-controlled.';


--
-- Name: account_integrations; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.account_integrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    integration_code character varying(80) NOT NULL,
    status character varying(20) NOT NULL,
    freeze_requested_at timestamp with time zone,
    closed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_integration_closed_timestamp CHECK ((((status)::text <> 'CLOSED'::text) OR (closed_at IS NOT NULL))),
    CONSTRAINT account_integration_closing_timestamp CHECK ((((status)::text <> 'CLOSING'::text) OR (freeze_requested_at IS NOT NULL))),
    CONSTRAINT account_integration_status_supported CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'CLOSING'::character varying, 'CLOSED'::character varying])::text[])))
);


--
-- Name: TABLE account_integrations; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.account_integrations IS 'Concrete shared-database boundary for external integrations; missing rows mean no integration, never an assumed remote success.';


--
-- Name: audit_events; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.audit_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_type character varying(30) NOT NULL,
    actor_id uuid NOT NULL,
    delegated_authorization_id uuid,
    action_type character varying(100) NOT NULL,
    target_domain character varying(40) NOT NULL,
    target_id uuid NOT NULL,
    reason_code character varying(80) NOT NULL,
    correlation_id uuid NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    before_hash character varying(128),
    after_hash character varying(128),
    evidence_object_id uuid,
    occurred_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    rbac_catalog_version character varying(80),
    resolved_rbac_catalog_version character varying(80),
    request_hash character varying(128),
    decision_status character varying(30),
    response_status integer,
    response_code character varying(80),
    evidence_hash character varying(128),
    request_document jsonb,
    response_document jsonb,
    before_document jsonb,
    after_document jsonb,
    evidence_document jsonb,
    CONSTRAINT audit_delegated_actor_reference_valid CHECK (((((actor_type)::text = 'DELEGATED_AUTHORIZATION'::text) AND (delegated_authorization_id IS NOT NULL) AND (actor_id = delegated_authorization_id)) OR (((actor_type)::text <> 'DELEGATED_AUTHORIZATION'::text) AND (delegated_authorization_id IS NULL)))),
    CONSTRAINT audit_operator_rbac_evidence_complete CHECK ((((target_domain)::text <> 'OPERATOR_RBAC'::text) OR ((rbac_catalog_version IS NOT NULL) AND ((request_hash)::text ~ '^[0-9a-f]{64}$'::text) AND ((decision_status)::text = ANY ((ARRAY['SUCCEEDED'::character varying, 'REJECTED'::character varying])::text[])) AND ((response_status >= 200) AND (response_status <= 499)) AND (response_code IS NOT NULL) AND ((before_hash)::text ~ '^[0-9a-f]{64}$'::text) AND ((after_hash)::text ~ '^[0-9a-f]{64}$'::text) AND ((evidence_hash)::text ~ '^[0-9a-f]{64}$'::text) AND (jsonb_typeof(request_document) = 'object'::text) AND (jsonb_typeof(response_document) = 'object'::text) AND (jsonb_typeof(before_document) = 'object'::text) AND (jsonb_typeof(after_document) = 'object'::text) AND (jsonb_typeof(evidence_document) = 'object'::text) AND ((request_hash)::text = encode(public.digest((request_document)::text, 'sha256'::text), 'hex'::text)) AND ((before_hash)::text = encode(public.digest((before_document)::text, 'sha256'::text), 'hex'::text)) AND ((after_hash)::text = encode(public.digest((after_document)::text, 'sha256'::text), 'hex'::text)) AND ((evidence_hash)::text = encode(public.digest((evidence_document)::text, 'sha256'::text), 'hex'::text)) AND ((((decision_status)::text = 'SUCCEEDED'::text) AND ((response_status >= 200) AND (response_status <= 299)) AND ((resolved_rbac_catalog_version)::text = (rbac_catalog_version)::text)) OR (((decision_status)::text = 'REJECTED'::text) AND ((response_status >= 400) AND (response_status <= 499)) AND ((before_hash)::text = (after_hash)::text) AND ((resolved_rbac_catalog_version IS NULL) OR ((resolved_rbac_catalog_version)::text = (rbac_catalog_version)::text)))))))
);


--
-- Name: TABLE audit_events; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.audit_events IS '추가 전용 보안 증적. 외부 AI 호출은 actor_type DELEGATED_AUTHORIZATION과 delegated_authorization_id로 위임 승인을 명시한다. 페이로드·오브젝트 증거에 자격증명, 비공개 전략 소스, 불필요한 보유 정보를 중복 저장하지 않는다.';


--
-- Name: batch_item_attempts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.batch_item_attempts (
    batch_item_id uuid NOT NULL,
    attempt_number integer NOT NULL,
    claim_token uuid NOT NULL,
    worker_id character varying(160) NOT NULL,
    runtime_policy_version character varying(80) NOT NULL,
    correlation_id uuid NOT NULL,
    claimed_at timestamp with time zone NOT NULL,
    claim_expires_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    outcome operations.batch_attempt_outcome,
    domain_result_code character varying(80),
    failure_code character varying(80),
    next_attempt_at timestamp with time zone,
    CONSTRAINT batch_attempt_completion_consistent CHECK ((((completed_at IS NULL) AND (outcome IS NULL) AND (domain_result_code IS NULL) AND (failure_code IS NULL) AND (next_attempt_at IS NULL)) OR ((completed_at IS NOT NULL) AND (outcome IS NOT NULL)))),
    CONSTRAINT batch_attempt_failure_consistent CHECK ((((outcome = ANY (ARRAY['QUARANTINED'::operations.batch_attempt_outcome, 'LEASE_EXPIRED'::operations.batch_attempt_outcome])) AND (failure_code IS NOT NULL)) OR (outcome <> ALL (ARRAY['QUARANTINED'::operations.batch_attempt_outcome, 'LEASE_EXPIRED'::operations.batch_attempt_outcome])) OR (outcome IS NULL))),
    CONSTRAINT batch_attempt_lease_positive CHECK ((claim_expires_at > claimed_at)),
    CONSTRAINT batch_attempt_number_positive CHECK ((attempt_number > 0)),
    CONSTRAINT batch_attempt_retry_consistent CHECK ((((outcome = 'RETRY_SCHEDULED'::operations.batch_attempt_outcome) AND (failure_code IS NOT NULL) AND (next_attempt_at IS NOT NULL)) OR ((outcome <> 'RETRY_SCHEDULED'::operations.batch_attempt_outcome) AND (next_attempt_at IS NULL)) OR (outcome IS NULL)))
);


--
-- Name: batch_items; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.batch_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    discovered_by_run_id uuid NOT NULL,
    category_code character varying(80) NOT NULL,
    source_key character varying(200) NOT NULL,
    source_version character varying(160) NOT NULL,
    due_at timestamp with time zone NOT NULL,
    replay_sequence integer DEFAULT 0 NOT NULL,
    original_item_id uuid,
    replayed_from_item_id uuid,
    replay_audit_event_id uuid,
    status operations.batch_item_status DEFAULT 'PENDING'::operations.batch_item_status NOT NULL,
    claim_token uuid,
    claimed_by character varying(160),
    claimed_at timestamp with time zone,
    claim_expires_at timestamp with time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp with time zone NOT NULL,
    correlation_id uuid NOT NULL,
    first_discovered_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    completed_at timestamp with time zone,
    domain_result_code character varying(80),
    terminal_failure_code character varying(80),
    CONSTRAINT batch_item_attempt_count_nonnegative CHECK ((attempt_count >= 0)),
    CONSTRAINT batch_item_claim_consistent CHECK ((((status = 'CLAIMED'::operations.batch_item_status) AND (claim_token IS NOT NULL) AND (claimed_by IS NOT NULL) AND (claimed_at IS NOT NULL) AND (claim_expires_at > claimed_at)) OR ((status <> 'CLAIMED'::operations.batch_item_status) AND (claim_token IS NULL) AND (claimed_by IS NULL) AND (claimed_at IS NULL) AND (claim_expires_at IS NULL)))),
    CONSTRAINT batch_item_completion_consistent CHECK ((((status = ANY (ARRAY['SUCCEEDED'::operations.batch_item_status, 'QUARANTINED'::operations.batch_item_status, 'SKIPPED'::operations.batch_item_status])) AND (completed_at IS NOT NULL)) OR ((status = ANY (ARRAY['PENDING'::operations.batch_item_status, 'CLAIMED'::operations.batch_item_status])) AND (completed_at IS NULL)))),
    CONSTRAINT batch_item_quarantine_consistent CHECK ((((status = 'QUARANTINED'::operations.batch_item_status) AND (terminal_failure_code IS NOT NULL)) OR ((status <> 'QUARANTINED'::operations.batch_item_status) AND (terminal_failure_code IS NULL)))),
    CONSTRAINT batch_item_replay_lineage_consistent CHECK ((((replay_sequence = 0) AND (original_item_id IS NULL) AND (replayed_from_item_id IS NULL) AND (replay_audit_event_id IS NULL)) OR ((replay_sequence > 0) AND (original_item_id IS NOT NULL) AND (replayed_from_item_id IS NOT NULL) AND (replay_audit_event_id IS NOT NULL)))),
    CONSTRAINT batch_item_replay_sequence_nonnegative CHECK ((replay_sequence >= 0))
);


--
-- Name: TABLE batch_items; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.batch_items IS 'Durable non-sensitive batch work identity and current lease head; domain receipts remain authoritative.';


--
-- Name: batch_job_versions; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.batch_job_versions (
    job_code character varying(80) NOT NULL,
    job_version character varying(40) NOT NULL,
    status operations.batch_job_version_status NOT NULL,
    category_set_document jsonb NOT NULL,
    content_hash character varying(128) NOT NULL,
    published_at timestamp with time zone,
    retired_at timestamp with time zone,
    CONSTRAINT batch_job_version_categories_array CHECK ((jsonb_typeof(category_set_document) = 'array'::text)),
    CONSTRAINT batch_job_version_lifecycle_consistent CHECK ((((status = 'DRAFT'::operations.batch_job_version_status) AND (published_at IS NULL) AND (retired_at IS NULL)) OR ((status = 'ACTIVE'::operations.batch_job_version_status) AND (published_at IS NOT NULL) AND (retired_at IS NULL)) OR ((status = 'RETIRED'::operations.batch_job_version_status) AND (published_at IS NOT NULL) AND (retired_at IS NOT NULL) AND (retired_at >= published_at))))
);


--
-- Name: batch_run_checkpoints; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.batch_run_checkpoints (
    job_code character varying(80) NOT NULL,
    job_version character varying(40) NOT NULL,
    category_code character varying(80) NOT NULL,
    shard_key character varying(160) NOT NULL,
    cursor_due_at timestamp with time zone,
    cursor_source_key character varying(200),
    last_run_id uuid NOT NULL,
    scanned_count bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT batch_checkpoint_cursor_pair CHECK ((((cursor_due_at IS NULL) AND (cursor_source_key IS NULL)) OR ((cursor_due_at IS NOT NULL) AND (cursor_source_key IS NOT NULL)))),
    CONSTRAINT batch_checkpoint_scanned_count_nonnegative CHECK ((scanned_count >= 0))
);


--
-- Name: TABLE batch_run_checkpoints; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.batch_run_checkpoints IS 'Discovery optimization only; consumers must overlap-rescan and cannot treat a checkpoint as completion evidence.';


--
-- Name: batch_runs; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.batch_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_code character varying(80) NOT NULL,
    job_version character varying(40) NOT NULL,
    runtime_policy_version character varying(80) NOT NULL,
    trigger_id character varying(160) NOT NULL,
    window_start timestamp with time zone NOT NULL,
    window_end timestamp with time zone NOT NULL,
    status operations.batch_run_status DEFAULT 'RUNNING'::operations.batch_run_status NOT NULL,
    started_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    completed_at timestamp with time zone,
    discovered_count bigint DEFAULT 0 NOT NULL,
    succeeded_count bigint DEFAULT 0 NOT NULL,
    quarantined_count bigint DEFAULT 0 NOT NULL,
    CONSTRAINT batch_run_completion_consistent CHECK ((((status = 'RUNNING'::operations.batch_run_status) AND (completed_at IS NULL)) OR ((status <> 'RUNNING'::operations.batch_run_status) AND (completed_at IS NOT NULL) AND (completed_at >= started_at)))),
    CONSTRAINT batch_run_counts_nonnegative CHECK (((discovered_count >= 0) AND (succeeded_count >= 0) AND (quarantined_count >= 0))),
    CONSTRAINT batch_run_window_positive CHECK ((window_end > window_start))
);


--
-- Name: case_command_receipts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.case_command_receipts (
    account_id uuid NOT NULL,
    command_type operations.case_command_type NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    request_hash character varying(128) NOT NULL,
    case_id uuid NOT NULL,
    case_event_id uuid NOT NULL,
    response_status integer NOT NULL,
    response_code character varying(80) NOT NULL,
    response_document jsonb NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT case_command_receipt_success_status CHECK (((response_status >= 200) AND (response_status <= 299)))
);


--
-- Name: TABLE case_command_receipts; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.case_command_receipts IS 'Immutable successful command receipts for exact account-scoped idempotent replay.';


--
-- Name: case_deadline_receipts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.case_deadline_receipts (
    case_id uuid NOT NULL,
    expected_case_version bigint NOT NULL,
    response_deadline_at timestamp with time zone NOT NULL,
    decision_status character varying(32) NOT NULL,
    case_event_id uuid,
    correlation_id uuid NOT NULL,
    decided_at timestamp with time zone NOT NULL,
    CONSTRAINT case_deadline_receipt_decision_valid CHECK (((decision_status)::text = ANY ((ARRAY['APPLIED'::character varying, 'ALREADY_TRANSITIONED'::character varying])::text[]))),
    CONSTRAINT case_deadline_receipt_event_consistent CHECK (((((decision_status)::text = 'APPLIED'::text) AND (case_event_id IS NOT NULL)) OR (((decision_status)::text = 'ALREADY_TRANSITIONED'::text) AND (case_event_id IS NULL))))
);


--
-- Name: TABLE case_deadline_receipts; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.case_deadline_receipts IS 'Immutable A20 result for one case/version/deadline identity; retries never append another event.';


--
-- Name: case_events; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.case_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    case_id uuid NOT NULL,
    event_sequence integer NOT NULL,
    actor_type operations.case_actor_type NOT NULL,
    actor_id uuid NOT NULL,
    event_type operations.case_event_type NOT NULL,
    payload_document jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    account_id uuid NOT NULL,
    previous_event_id uuid,
    resulting_status operations.case_status NOT NULL,
    visibility operations.case_event_visibility NOT NULL,
    reason_code character varying(80),
    correlation_id uuid NOT NULL,
    CONSTRAINT case_event_chain_start_valid CHECK ((((event_sequence = 1) AND (previous_event_id IS NULL) AND (event_type = 'SUBMITTED'::operations.case_event_type) AND (resulting_status = 'OPEN'::operations.case_status)) OR ((event_sequence > 1) AND (previous_event_id IS NOT NULL)))),
    CONSTRAINT case_event_sequence_positive CHECK ((event_sequence > 0))
);


--
-- Name: TABLE case_events; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.case_events IS 'Append-only case history. User APIs expose USER_VISIBLE events only.';


--
-- Name: case_evidence_references; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.case_evidence_references (
    case_id uuid NOT NULL,
    account_id uuid NOT NULL,
    case_event_id uuid NOT NULL,
    storage_object_id uuid NOT NULL,
    source_domain character varying(40) NOT NULL,
    source_resource_id uuid NOT NULL,
    owner_account_id uuid NOT NULL,
    ownership_policy_version character varying(80) NOT NULL,
    ownership_verified_at timestamp with time zone NOT NULL,
    attached_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT case_evidence_owner_matches_case_account CHECK ((owner_account_id = account_id)),
    CONSTRAINT case_evidence_verification_time_order CHECK ((attached_at >= ownership_verified_at))
);


--
-- Name: TABLE case_evidence_references; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.case_evidence_references IS 'Immutable proof that an AVAILABLE object belonged to the case account through its source resource when linked.';


--
-- Name: cases; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.cases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    case_type operations.case_type NOT NULL,
    status operations.case_status NOT NULL,
    subject character varying(200) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    resolution_code character varying(80),
    case_version bigint DEFAULT 1 NOT NULL,
    current_event_sequence integer NOT NULL,
    last_case_event_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    assignee_operator_id uuid,
    response_deadline_at timestamp with time zone,
    deadline_policy_version character varying(80),
    CONSTRAINT case_current_sequence_positive CHECK ((current_event_sequence > 0)),
    CONSTRAINT case_head_required CHECK ((last_case_event_id IS NOT NULL)),
    CONSTRAINT case_response_deadline_pair CHECK ((((response_deadline_at IS NULL) AND (deadline_policy_version IS NULL)) OR ((response_deadline_at IS NOT NULL) AND (deadline_policy_version IS NOT NULL)))),
    CONSTRAINT case_terminal_state_consistent CHECK ((((status = ANY (ARRAY['RESOLVED'::operations.case_status, 'REJECTED'::operations.case_status])) AND (closed_at IS NOT NULL) AND (resolution_code IS NOT NULL)) OR ((status <> ALL (ARRAY['RESOLVED'::operations.case_status, 'REJECTED'::operations.case_status])) AND (closed_at IS NULL) AND (resolution_code IS NULL)))),
    CONSTRAINT case_update_time_order CHECK ((updated_at >= created_at)),
    CONSTRAINT case_version_positive CHECK ((case_version > 0))
);


--
-- Name: TABLE cases; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.cases IS 'Current user case head projection. A19 owns user submit/read/supplement only; operator workflow is A20.';


--
-- Name: COLUMN cases.assignee_operator_id; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations.cases.assignee_operator_id IS 'Current A20 operator assignment. Every change increments case_version and appends one case event.';


--
-- Name: COLUMN cases.response_deadline_at; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations.cases.response_deadline_at IS 'Exclusive end of the versioned information-response window, evaluated with database time.';


--
-- Name: delivery_attempts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.delivery_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    notification_id uuid NOT NULL,
    channel character varying(30) NOT NULL,
    attempt_number integer NOT NULL,
    status operations.work_status NOT NULL,
    attempted_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    provider_message_key character varying(200),
    failure_code character varying(80),
    next_attempt_at timestamp with time zone,
    outbox_message_id uuid,
    runtime_policy_version character varying(80)
);


--
-- Name: TABLE delivery_attempts; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.delivery_attempts IS '알림 발송 시도 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: notification_policies; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.notification_policies (
    type_code character varying(80) NOT NULL,
    policy_version character varying(80) NOT NULL,
    mandatory boolean NOT NULL,
    default_channels jsonb NOT NULL,
    active boolean DEFAULT false NOT NULL,
    activated_at timestamp with time zone,
    CONSTRAINT notification_policy_activation_consistent CHECK ((active = (activated_at IS NOT NULL))),
    CONSTRAINT notification_policy_channels_array CHECK ((jsonb_typeof(default_channels) = 'array'::text))
);


--
-- Name: TABLE notification_policies; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.notification_policies IS 'A18 notification policy versions; product-owned values are configured separately and are not seeded here.';


--
-- Name: notification_preferences; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.notification_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    bot_id uuid,
    event_type character varying(80) NOT NULL,
    channel character varying(20) NOT NULL,
    enabled boolean NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    policy_version character varying(80) DEFAULT 'legacy'::character varying NOT NULL
);


--
-- Name: TABLE notification_preferences; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.notification_preferences IS '필수 운영 공지는 수신 거부를 무시. 계정 전역 설정의 null-safe 유일성은 마이그레이션에서 강제.';


--
-- Name: notifications; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    bot_id uuid,
    notification_type character varying(80) NOT NULL,
    mandatory boolean NOT NULL,
    locale character varying(5) NOT NULL,
    template_version character varying(40) NOT NULL,
    payload_document jsonb NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    read_at timestamp with time zone,
    expires_at timestamp with time zone,
    source_event_id character varying(160),
    source_event_hash character varying(128),
    policy_version character varying(80),
    selected_channels jsonb,
    correlation_id uuid,
    CONSTRAINT notification_selected_channels_array CHECK (((selected_channels IS NULL) OR (jsonb_typeof(selected_channels) = 'array'::text))),
    CONSTRAINT notification_source_evidence_pair CHECK (((source_event_id IS NULL) = (source_event_hash IS NULL)))
);


--
-- Name: TABLE notifications; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.notifications IS '알림 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: COLUMN notifications.source_event_hash; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations.notifications.source_event_hash IS 'Immutable source-event evidence used to fail closed on an idempotency-key payload mismatch.';


--
-- Name: operator_accounts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.operator_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status character varying(30) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    disabled_at timestamp with time zone,
    CONSTRAINT operator_account_status_valid CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'DISABLED'::character varying])::text[]))),
    CONSTRAINT operator_account_status_coherent CHECK (((((status)::text = 'ACTIVE'::text) AND (disabled_at IS NULL)) OR (((status)::text = 'DISABLED'::text) AND (disabled_at IS NOT NULL))))
);


--
-- Name: TABLE operator_accounts; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.operator_accounts IS '운영자 계정 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: operator_login_credentials; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.operator_login_credentials (
    operator_account_id uuid PRIMARY KEY,
    login_name character varying(120) NOT NULL UNIQUE,
    password_hash character varying(512) NOT NULL,
    password_algorithm character varying(30) DEFAULT 'ARGON2ID'::character varying NOT NULL,
    password_parameters jsonb NOT NULL,
    password_version smallint NOT NULL,
    credential_version bigint DEFAULT 1 NOT NULL,
    totp_ciphertext bytea NOT NULL,
    totp_nonce bytea NOT NULL,
    totp_key_version smallint NOT NULL,
    totp_enrolled_at timestamp with time zone NOT NULL,
    last_accepted_totp_step bigint,
    failed_attempt_count integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    password_changed_at timestamp with time zone NOT NULL,
    compromised_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT operator_credential_versions_positive CHECK (((password_version > 0) AND (credential_version > 0) AND (totp_key_version > 0))),
    CONSTRAINT operator_failed_attempt_count_nonnegative CHECK ((failed_attempt_count >= 0)),
    CONSTRAINT operator_login_name_normalized CHECK ((((login_name)::text = lower((login_name)::text)) AND ((login_name)::text ~ '^[a-z0-9][a-z0-9._-]{2,119}$'::text))),
    CONSTRAINT operator_password_algorithm_valid CHECK (((password_algorithm)::text = 'ARGON2ID'::text)),
    CONSTRAINT operator_totp_nonce_valid CHECK ((octet_length(totp_nonce) = 12))
);

COMMENT ON TABLE operations.operator_login_credentials IS 'Dedicated operator password and encrypted TOTP credential. Raw passwords and TOTP seeds are never stored.';


--
-- Name: operator_sessions; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.operator_sessions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    operator_account_id uuid NOT NULL,
    credential_version bigint NOT NULL,
    session_token_hmac character varying(64) NOT NULL UNIQUE,
    session_hmac_key_version smallint NOT NULL,
    csrf_token_hmac character varying(64) NOT NULL,
    csrf_hmac_key_version smallint NOT NULL,
    csrf_generation bigint DEFAULT 1 NOT NULL,
    source_key_hmac character varying(64) NOT NULL,
    source_hmac_key_version smallint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_used_at timestamp with time zone NOT NULL,
    idle_expires_at timestamp with time zone NOT NULL,
    absolute_expires_at timestamp with time zone NOT NULL,
    mfa_verified_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    revocation_reason_code character varying(80),
    CONSTRAINT operator_session_expiry_coherent CHECK (((created_at <= last_used_at) AND (last_used_at < idle_expires_at) AND (idle_expires_at <= absolute_expires_at))),
    CONSTRAINT operator_session_hmacs_valid CHECK ((((session_token_hmac)::text ~ '^[0-9a-f]{64}$'::text) AND ((csrf_token_hmac)::text ~ '^[0-9a-f]{64}$'::text) AND ((source_key_hmac)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT operator_session_revocation_coherent CHECK ((((revoked_at IS NULL) AND (revocation_reason_code IS NULL)) OR ((revoked_at IS NOT NULL) AND (revocation_reason_code IS NOT NULL)))),
    CONSTRAINT operator_session_versions_positive CHECK (((credential_version > 0) AND (session_hmac_key_version > 0) AND (csrf_hmac_key_version > 0) AND (source_hmac_key_version > 0) AND (csrf_generation > 0)))
);

COMMENT ON TABLE operations.operator_sessions IS 'Opaque server-side operator session. Only versioned HMAC digests are stored.';

CREATE INDEX operator_login_credentials_locked_until_idx ON operations.operator_login_credentials USING btree (locked_until);
CREATE INDEX operator_sessions_operator_created_idx ON operations.operator_sessions USING btree (operator_account_id, created_at);
CREATE INDEX operator_sessions_idle_expiry_idx ON operations.operator_sessions USING btree (idle_expires_at);
CREATE INDEX operator_sessions_absolute_expiry_idx ON operations.operator_sessions USING btree (absolute_expires_at);


--
-- Name: operator_bootstrap_receipts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.operator_bootstrap_receipts (
    bootstrap_key character varying(160) NOT NULL,
    manifest_hash character varying(128) NOT NULL,
    catalog_version character varying(80) NOT NULL,
    operator_account_id uuid NOT NULL,
    operator_role_assignment_id uuid NOT NULL,
    credential_version bigint NOT NULL,
    correlation_id uuid NOT NULL,
    audit_event_id uuid NOT NULL,
    applied_at timestamp with time zone NOT NULL,
    CONSTRAINT operator_bootstrap_credential_version_positive CHECK ((credential_version > 0))
);


--
-- Name: TABLE operator_bootstrap_receipts; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.operator_bootstrap_receipts IS 'Immutable one-shot deployment bootstrap evidence. No HTTP or MCP bootstrap route is permitted.';


--
-- Name: operator_case_command_receipts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.operator_case_command_receipts (
    operator_id uuid NOT NULL,
    command_type character varying(40) NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    request_hash character varying(64) NOT NULL,
    case_id uuid NOT NULL,
    case_event_id uuid,
    decision_status character varying(20) NOT NULL,
    response_code character varying(80) NOT NULL,
    response_document jsonb NOT NULL,
    audit_document jsonb NOT NULL,
    completed_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT operator_case_receipt_audit_object CHECK ((jsonb_typeof(audit_document) = 'object'::text)),
    CONSTRAINT operator_case_receipt_decision_valid CHECK (((decision_status)::text = ANY ((ARRAY['APPLIED'::character varying, 'NO_OP'::character varying, 'REJECTED'::character varying])::text[]))),
    CONSTRAINT operator_case_receipt_event_consistent CHECK (((((decision_status)::text = 'APPLIED'::text) AND (case_event_id IS NOT NULL)) OR (((decision_status)::text <> 'APPLIED'::text) AND (case_event_id IS NULL)))),
    CONSTRAINT operator_case_receipt_hash_valid CHECK (((request_hash)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT operator_case_receipt_response_object CHECK ((jsonb_typeof(response_document) = 'object'::text))
);


--
-- Name: TABLE operator_case_command_receipts; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.operator_case_command_receipts IS 'Immutable A20 idempotency and redacted audit evidence; rejected/no-op decisions never advance the case head.';


--
-- Name: operator_role_assignments; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.operator_role_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    operator_account_id uuid NOT NULL,
    role_id uuid NOT NULL,
    granted_by_operator_id uuid NOT NULL,
    granted_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone,
    revoked_by_operator_id uuid,
    revoked_at timestamp with time zone,
    revocation_reason_code character varying(80),
    catalog_version character varying(80)
);


--
-- Name: TABLE operator_role_assignments; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.operator_role_assignments IS '운영자 역할 부여 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: outbox_consumer_receipts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.outbox_consumer_receipts (
    consumer_handler_id character varying(160) NOT NULL,
    outbox_message_id uuid NOT NULL,
    producer_idempotency_key character varying(160) NOT NULL,
    payload_hash character varying(128) NOT NULL,
    status operations.consumer_receipt_status NOT NULL,
    claim_token uuid,
    claimed_by character varying(160),
    claimed_at timestamp with time zone,
    claim_expires_at timestamp with time zone,
    receive_attempt_count integer DEFAULT 1 NOT NULL,
    first_received_at timestamp with time zone NOT NULL,
    last_received_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    result_hash character varying(128),
    failure_code character varying(80),
    CONSTRAINT consumer_receipt_attempt_count_positive CHECK ((receive_attempt_count > 0)),
    CONSTRAINT consumer_receipt_claim_state_consistent CHECK ((((status = 'PROCESSING'::operations.consumer_receipt_status) AND (claim_token IS NOT NULL) AND (claimed_by IS NOT NULL) AND (claimed_at IS NOT NULL) AND (claim_expires_at > claimed_at) AND (completed_at IS NULL)) OR ((status <> 'PROCESSING'::operations.consumer_receipt_status) AND (claim_token IS NULL) AND (claimed_by IS NULL) AND (claimed_at IS NULL) AND (claim_expires_at IS NULL)))),
    CONSTRAINT consumer_receipt_completion_consistent CHECK ((((status = 'COMPLETED'::operations.consumer_receipt_status) AND (completed_at IS NOT NULL) AND (failure_code IS NULL)) OR ((status <> 'COMPLETED'::operations.consumer_receipt_status) AND (completed_at IS NULL)))),
    CONSTRAINT consumer_receipt_failure_consistent CHECK ((((status = ANY (ARRAY['RETRYABLE_FAILURE'::operations.consumer_receipt_status, 'PERMANENT_FAILURE'::operations.consumer_receipt_status])) AND (failure_code IS NOT NULL)) OR ((status <> ALL (ARRAY['RETRYABLE_FAILURE'::operations.consumer_receipt_status, 'PERMANENT_FAILURE'::operations.consumer_receipt_status])) AND (failure_code IS NULL)))),
    CONSTRAINT consumer_receipt_receive_time_order CHECK ((last_received_at >= first_received_at))
);


--
-- Name: TABLE outbox_consumer_receipts; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.outbox_consumer_receipts IS 'A17 proposal 52870121: handler/message idempotency receipt; business effect and completion share a local transaction.';


--
-- Name: outbox_delivery_attempts; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.outbox_delivery_attempts (
    outbox_message_id uuid NOT NULL,
    attempt_number integer NOT NULL,
    claim_token uuid NOT NULL,
    worker_id character varying(160) NOT NULL,
    runtime_policy_version character varying(80) NOT NULL,
    claimed_at timestamp with time zone NOT NULL,
    claim_expires_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    outcome operations.outbox_attempt_outcome,
    transport_message_key character varying(200),
    failure_code character varying(80),
    next_attempt_at timestamp with time zone,
    CONSTRAINT outbox_attempt_completion_consistent CHECK ((((completed_at IS NULL) AND (outcome IS NULL) AND (failure_code IS NULL) AND (next_attempt_at IS NULL)) OR ((completed_at IS NOT NULL) AND (outcome IS NOT NULL)))),
    CONSTRAINT outbox_attempt_failure_code_consistent CHECK ((((outcome = 'PUBLISHED'::operations.outbox_attempt_outcome) AND (failure_code IS NULL)) OR ((outcome <> 'PUBLISHED'::operations.outbox_attempt_outcome) AND (failure_code IS NOT NULL)) OR (outcome IS NULL))),
    CONSTRAINT outbox_attempt_lease_positive CHECK ((claim_expires_at > claimed_at)),
    CONSTRAINT outbox_attempt_number_positive CHECK ((attempt_number > 0)),
    CONSTRAINT outbox_attempt_retry_consistent CHECK ((((outcome = 'RETRY_SCHEDULED'::operations.outbox_attempt_outcome) AND (failure_code IS NOT NULL) AND (next_attempt_at IS NOT NULL)) OR ((outcome <> 'RETRY_SCHEDULED'::operations.outbox_attempt_outcome) AND (next_attempt_at IS NULL)) OR (outcome IS NULL)))
);


--
-- Name: TABLE outbox_delivery_attempts; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.outbox_delivery_attempts IS 'A17 proposal 52870121: durable publisher claim attempts; runtime numeric policy remains versioned configuration.';


--
-- Name: outbox_messages; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.outbox_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_domain character varying(40) NOT NULL,
    aggregate_id uuid NOT NULL,
    aggregate_sequence bigint,
    event_type character varying(100) NOT NULL,
    event_schema_version character varying(80) NOT NULL,
    payload_document jsonb NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    published_at timestamp with time zone,
    publish_attempt_count integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp with time zone,
    last_failure_code character varying(80),
    payload_hash character varying(128) NOT NULL,
    producer_idempotency_key character varying(160) NOT NULL,
    original_message_id uuid,
    replayed_from_message_id uuid,
    replay_sequence integer DEFAULT 0 NOT NULL,
    replay_audit_event_id uuid,
    delivery_status operations.outbox_delivery_status DEFAULT 'PENDING'::operations.outbox_delivery_status NOT NULL,
    claim_token uuid,
    claimed_by character varying(160),
    claimed_at timestamp with time zone,
    claim_expires_at timestamp with time zone,
    dead_lettered_at timestamp with time zone,
    dead_letter_reason_code character varying(80),
    CONSTRAINT outbox_claim_state_consistent CHECK ((((delivery_status = 'CLAIMED'::operations.outbox_delivery_status) AND (claim_token IS NOT NULL) AND (claimed_by IS NOT NULL) AND (claimed_at IS NOT NULL) AND (claim_expires_at > claimed_at)) OR ((delivery_status <> 'CLAIMED'::operations.outbox_delivery_status) AND (claim_token IS NULL) AND (claimed_by IS NULL) AND (claimed_at IS NULL) AND (claim_expires_at IS NULL)))),
    CONSTRAINT outbox_dead_letter_state_consistent CHECK ((((delivery_status = 'DEAD_LETTERED'::operations.outbox_delivery_status) AND (dead_lettered_at IS NOT NULL) AND (dead_letter_reason_code IS NOT NULL)) OR ((delivery_status <> 'DEAD_LETTERED'::operations.outbox_delivery_status) AND (dead_lettered_at IS NULL) AND (dead_letter_reason_code IS NULL)))),
    CONSTRAINT outbox_next_attempt_pending_only CHECK (((delivery_status = 'PENDING'::operations.outbox_delivery_status) OR (next_attempt_at IS NULL))),
    CONSTRAINT outbox_publish_attempt_count_nonnegative CHECK ((publish_attempt_count >= 0)),
    CONSTRAINT outbox_published_state_consistent CHECK ((((delivery_status = 'PUBLISHED'::operations.outbox_delivery_status) AND (published_at IS NOT NULL)) OR ((delivery_status <> 'PUBLISHED'::operations.outbox_delivery_status) AND (published_at IS NULL)))),
    CONSTRAINT outbox_replay_lineage_consistent CHECK ((((replay_sequence = 0) AND (original_message_id IS NULL) AND (replayed_from_message_id IS NULL) AND (replay_audit_event_id IS NULL)) OR ((replay_sequence > 0) AND (original_message_id IS NOT NULL) AND (replayed_from_message_id IS NOT NULL) AND (replay_audit_event_id IS NOT NULL)))),
    CONSTRAINT outbox_replay_sequence_nonnegative CHECK ((replay_sequence >= 0))
);


--
-- Name: TABLE outbox_messages; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.outbox_messages IS '도메인 변경과 원자적으로 삽입. 퍼블리셔는 at-least-once 전달일 수 있으므로 모든 컨슈머가 idempotency_key를 사용.';


--
-- Name: permissions; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(120) NOT NULL,
    description character varying(500) NOT NULL,
    sensitivity character varying(30) NOT NULL
);


--
-- Name: TABLE permissions; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.permissions IS '운영 권한 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: projection_checkpoints; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.projection_checkpoints (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    projection_name character varying(100) NOT NULL,
    target_store character varying(40) NOT NULL,
    shard_key character varying(160) NOT NULL,
    source_domain character varying(40) NOT NULL,
    last_source_sequence bigint,
    last_source_time timestamp with time zone,
    projection_version character varying(40) NOT NULL,
    status character varying(30) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    failure_code character varying(80)
);


--
-- Name: TABLE projection_checkpoints; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.projection_checkpoints IS '일회성인 NoSQL·검색·캐시 콘텐츠는 PostgreSQL과 검증된 S3 오브젝트로부터 재구축 가능해야 한다.';


--
-- Name: COLUMN projection_checkpoints.target_store; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations.projection_checkpoints.target_store IS '값은 NOSQL, SEARCH, CACHE, POSTGRES_READ_MODEL.';


--
-- Name: rbac_catalog_permissions; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.rbac_catalog_permissions (
    catalog_version character varying(80) NOT NULL,
    permission_id uuid NOT NULL,
    permission_status character varying(30) NOT NULL,
    CONSTRAINT rbac_catalog_permission_status_valid CHECK (((permission_status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'INACTIVE'::character varying])::text[])))
);


--
-- Name: rbac_catalog_role_permissions; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.rbac_catalog_role_permissions (
    catalog_version character varying(80) NOT NULL,
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL,
    delegable boolean DEFAULT false NOT NULL
);


--
-- Name: rbac_catalog_roles; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.rbac_catalog_roles (
    catalog_version character varying(80) NOT NULL,
    role_id uuid NOT NULL,
    hierarchy_rank integer NOT NULL,
    role_status character varying(30) NOT NULL,
    CONSTRAINT rbac_catalog_role_rank_nonnegative CHECK ((hierarchy_rank >= 0)),
    CONSTRAINT rbac_catalog_role_status_valid CHECK (((role_status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'INACTIVE'::character varying])::text[])))
);


--
-- Name: rbac_catalog_versions; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.rbac_catalog_versions (
    catalog_version character varying(80) NOT NULL,
    content_hash character varying(128) NOT NULL,
    status character varying(30) NOT NULL,
    activated_at timestamp with time zone,
    retired_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT rbac_catalog_content_hash_valid CHECK (((content_hash)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT rbac_catalog_lifecycle_valid CHECK (((((status)::text = 'DRAFT'::text) AND (activated_at IS NULL) AND (retired_at IS NULL)) OR (((status)::text = 'ACTIVE'::text) AND (activated_at IS NOT NULL) AND (retired_at IS NULL)) OR (((status)::text = 'RETIRED'::text) AND (activated_at IS NOT NULL) AND (retired_at IS NOT NULL) AND (retired_at >= activated_at)))),
    CONSTRAINT rbac_catalog_status_valid CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'ACTIVE'::character varying, 'RETIRED'::character varying])::text[])))
);


--
-- Name: TABLE rbac_catalog_versions; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.rbac_catalog_versions IS 'A13 additive version metadata only. Actual role, permission, hierarchy and delegability values are external reviewed seed/config and are not seeded here.';


--
-- Name: role_permissions; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.role_permissions (
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL
);


--
-- Name: TABLE role_permissions; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.role_permissions IS '역할-권한 매핑 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: roles; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(80) NOT NULL,
    hierarchy_rank integer NOT NULL,
    status character varying(30) NOT NULL
);


--
-- Name: TABLE roles; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations.roles IS '운영자 역할 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: bot_current_projections; Type: TABLE; Schema: performance; Owner: -
--

CREATE TABLE performance.bot_current_projections (
    bot_id uuid NOT NULL,
    equity_amount numeric(24,8) NOT NULL,
    total_return_pct numeric(18,8) NOT NULL,
    max_drawdown_pct numeric(18,8) NOT NULL,
    sharpe_ratio numeric(18,8),
    metrics_document jsonb NOT NULL,
    ledger_state_hash character varying(128) NOT NULL,
    position_state_hash character varying(128) NOT NULL,
    calculation_rules_version character varying(80) NOT NULL,
    last_event_sequence bigint NOT NULL,
    projection_hash character varying(128) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT performance_current_event_sequence_nonnegative CHECK ((last_event_sequence >= 0))
);


--
-- Name: TABLE bot_current_projections; Type: COMMENT; Schema: performance; Owner: -
--

COMMENT ON TABLE performance.bot_current_projections IS '봇별 최신 성과를 저장하는 mutable Projection. equity_amount, total_return_pct, max_drawdown_pct, sharpe_ratio는 정렬·필터용 핵심 지표이고 metrics_document는 중복되지 않는 확장 지표만 담는다. 갱신은 PostgreSQL 조건부 UPSERT 또는 전용 함수로 기존 last_event_sequence보다 큰 사건만 허용하여 늦게 끝난 과거 계산이 최신 상태를 덮지 못하게 한다. 직접 UPDATE 권한은 애플리케이션 역할에서 제거한다. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: bot_snapshots; Type: TABLE; Schema: performance; Owner: -
--

CREATE TABLE performance.bot_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    snapshot_type performance.snapshot_type NOT NULL,
    source_event_sequence bigint NOT NULL,
    evaluated_at timestamp with time zone NOT NULL,
    equity_amount numeric(24,8) NOT NULL,
    total_return_pct numeric(18,8) NOT NULL,
    max_drawdown_pct numeric(18,8) NOT NULL,
    sharpe_ratio numeric(18,8),
    metrics_document jsonb NOT NULL,
    input_hash character varying(128) NOT NULL,
    calculation_rules_version character varying(80) NOT NULL,
    snapshot_hash character varying(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT performance_snapshot_event_sequence_nonnegative CHECK ((source_event_sequence >= 0))
);


--
-- Name: TABLE bot_snapshots; Type: COMMENT; Schema: performance; Owner: -
--

COMMENT ON TABLE performance.bot_snapshots IS '불변 공식 경계 스냅샷. 핵심 지표는 타입 컬럼에 고정하고 metrics_document에는 중복되지 않는 확장 지표만 둔다. 생성 후 UPDATE·DELETE를 금지하고 정정은 새로운 스냅샷으로 남긴다. NoSQL 리더보드·대시보드 문서는 절대 채점 증거가 아니다.';


--
-- Name: series_manifests; Type: TABLE; Schema: performance; Owner: -
--

CREATE TABLE performance.series_manifests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    object_id uuid NOT NULL,
    series_type character varying(50) NOT NULL,
    week_start_date date NOT NULL,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone NOT NULL,
    part_number integer NOT NULL,
    revision_number integer DEFAULT 1 NOT NULL,
    row_count bigint NOT NULL,
    schema_version character varying(40) NOT NULL,
    calculation_rules_version character varying(80) NOT NULL,
    supersedes_manifest_id uuid,
    series_hash character varying(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    available_at timestamp with time zone NOT NULL,
    CONSTRAINT performance_series_availability_order CHECK ((available_at >= created_at)),
    CONSTRAINT performance_series_part_number_positive CHECK ((part_number >= 1)),
    CONSTRAINT performance_series_period_order CHECK ((period_end > period_start)),
    CONSTRAINT performance_series_revision_number_positive CHECK ((revision_number >= 1)),
    CONSTRAINT performance_series_row_count_nonnegative CHECK ((row_count >= 0)),
    CONSTRAINT performance_series_week_starts_monday CHECK ((EXTRACT(isodow FROM week_start_date) = (1)::numeric))
);


--
-- Name: TABLE series_manifests; Type: COMMENT; Schema: performance; Owner: -
--

COMMENT ON TABLE performance.series_manifests IS '주 단위 성과 시계열 Parquet 객체의 PostgreSQL 매니페스트. 실제 시계열은 S3 storage.objects가 소유하고 이 행은 기간, 행 수, 스키마·계산 버전, 해시와 교체 계보를 검증한다. 객체 업로드와 해시 검증이 모두 끝난 뒤 available_at을 포함한 완성 행을 한 번만 삽입한다. ET 월요일 주 경계를 넘지 않는지는 PostgreSQL migration trigger로 검증한다. 기존 행을 덮어쓰지 않고 수정 파일은 같은 논리 파트의 revision_number를 증가시킨 새 행으로 추가하며 supersedes_manifest_id로 직전 행을 가리킨다. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status storage.object_status NOT NULL,
    storage_provider character varying(40) NOT NULL,
    bucket_name character varying(160) NOT NULL,
    object_key character varying(900) NOT NULL,
    provider_version_id character varying(300) NOT NULL,
    content_hash character varying(128) NOT NULL,
    byte_size bigint NOT NULL,
    file_format character varying(40) NOT NULL,
    compression_codec character varying(40) NOT NULL,
    media_type character varying(120) NOT NULL,
    schema_version character varying(40) NOT NULL,
    row_count bigint,
    period_start timestamp with time zone,
    period_end timestamp with time zone,
    encryption_key_ref character varying(300),
    retention_policy_version character varying(80) NOT NULL,
    retention_until timestamp with time zone,
    legal_hold boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    verified_at timestamp with time zone,
    quarantined_at timestamp with time zone,
    superseded_at timestamp with time zone,
    deleted_at timestamp with time zone
);


--
-- Name: TABLE objects; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON TABLE storage.objects IS '크기·해시·스키마·Parquet footer·코덱 검증 후에만 AVAILABLE. 새 리비전은 정본 오브젝트 버전을 덮어쓰지 않으며, 삭제는 보존기간 경과와 legal hold 부재를 요구.';


--
-- Name: COLUMN objects.file_format; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.file_format IS '이 초안에서 대용량 표 데이터는 PARQUET.';


--
-- Name: COLUMN objects.compression_codec; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.compression_codec IS '현재 Parquet 오브젝트는 명시적 UNCOMPRESSED.';


--
-- Name: compiled_flow_plans; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.compiled_flow_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    element_catalog_version_id uuid NOT NULL,
    semantic_hash character varying(128) NOT NULL,
    compiler_version character varying(80) NOT NULL,
    required_feature_set_hash character varying(128) NOT NULL,
    plan_document jsonb NOT NULL,
    plan_hash character varying(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE compiled_flow_plans; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.compiled_flow_plans IS '의미상 동일한 Flow들이 공유하는 content-addressing 서버 실행 계획. 재사용 사용자 Flow·버전 계보·복사 관계가 아닌 인프라 캐시. 컴파일러는 타입이 지정된 Element를 검증해 봇별 최소 명령만 산출하고, 공통 시장 계산은 required_feature_set_hash로 표현되어 봇 Worker 밖에서 실행된다.';


--
-- Name: element_catalog_versions; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.element_catalog_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    language_version character varying(40) NOT NULL,
    schema_version character varying(40) NOT NULL,
    catalog_version character varying(40) NOT NULL,
    data_requirement_version character varying(40) NOT NULL,
    definition_hash character varying(128) NOT NULL,
    published_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone
);


--
-- Name: TABLE element_catalog_versions; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.element_catalog_versions IS 'Flow를 구성할 수 있는 Element 정의 집합의 불변 카탈로그 버전. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';


--
-- Name: element_definitions; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.element_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    element_catalog_version_id uuid NOT NULL,
    element_code character varying(120) NOT NULL,
    element_kind character varying(50) NOT NULL,
    parameter_schema jsonb NOT NULL,
    input_port_schema jsonb NOT NULL,
    output_port_schema jsonb NOT NULL,
    execution_contract jsonb NOT NULL,
    definition_hash character varying(128) NOT NULL
);


--
-- Name: TABLE element_definitions; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.element_definitions IS 'PRICE_DATA, RSI, CONDITION, ORDER, RISK_POLICY처럼 Flow에 배치할 수 있는 Element의 타입·포트·매개변수·실행 계약을 정의한다. 사용자 Flow 안의 Element 인스턴스와 분리된 플랫폼 정의다.';


--
-- Name: package_versions; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.package_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    package_id uuid NOT NULL,
    version character varying(40) NOT NULL,
    element_catalog_version_id uuid NOT NULL,
    name_i18n jsonb NOT NULL,
    description_i18n jsonb NOT NULL,
    flow_document jsonb NOT NULL,
    content_hash character varying(128) NOT NULL,
    published_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone
);


--
-- Name: TABLE package_versions; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.package_versions IS 'Basic Package의 불변 완성 Flow 문서 버전. Package를 선택하면 flow_document를 수정 가능한 strategy.strategy_documents 안의 새 독립 Flow로 복사하고 Package 출처나 계보 연결은 저장하지 않는다.';


--
-- Name: packages; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.packages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(80) NOT NULL,
    status character varying(30) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone
);


--
-- Name: TABLE packages; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.packages IS 'Basic 사용자에게 플랫폼이 완성된 형태로 제공하는 Flow Package의 식별자. 사용 시 독립 Flow로 복사되며 원본 Package FK를 남기지 않는다.';


--
-- Name: strategies; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.strategies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_account_id uuid NOT NULL,
    mode strategy.strategy_mode NOT NULL,
    name character varying(120) NOT NULL,
    description text,
    edit_sequence bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    archived_at timestamp with time zone,
    deleted_at timestamp with time zone,
    delegated_access_epoch bigint DEFAULT 1 NOT NULL,
    CONSTRAINT strategy_delegated_access_epoch_positive CHECK ((delegated_access_epoch > 0))
);


--
-- Name: TABLE strategies; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.strategies IS '사용자가 계속 수정할 수 있는 Strategy 설계 원본의 식별·표시·수명주기 메타데이터. 실행 Bot을 소유하거나 연결하지 않는다. 출시 시 strategy_documents의 검증된 당시 상태를 독립 Bot 스냅샷으로 복사하며 Bot에는 원본 Strategy 식별자·출처·계보를 남기지 않는다. 이후 Strategy 수정은 기존 Bot에 전파되지 않는다.';


--
-- Name: strategy_documents; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.strategy_documents (
    strategy_id uuid NOT NULL,
    semantic_document jsonb NOT NULL,
    presentation_document jsonb NOT NULL,
    semantic_schema_version character varying(40) NOT NULL,
    presentation_schema_version character varying(40) NOT NULL,
    semantic_hash character varying(128) NOT NULL,
    presentation_hash character varying(128) NOT NULL,
    edit_sequence bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE strategy_documents; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.strategy_documents IS 'Strategy 편집기의 현재 문서 1개를 저장하는 1:1 집합체. 버전 계보가 아니라 낙관적 동시성으로 갱신되는 현재 설계다. 출시 서비스는 완전성·포트 타입·DAG·예산 합·필수 주문 경로를 검증한 동일 트랜잭션에서 독립 bot.bots, bot.launch_snapshots, bot.launch_configurations, bot.bot_partitions, bot.flows 및 파생 의존성 행을 생성한다. 생성 후 Strategy와 Bot 사이에는 어떤 참조도 없다.';


--
-- Name: COLUMN strategy_documents.semantic_document; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON COLUMN strategy.strategy_documents.semantic_document IS '파티션 예산 상한, Flow, Element, edge, 매개변수, 선택 종목을 포함하는 수정 가능한 Strategy 설계 의미. 편집 중에는 미완성 구조를 허용하되 schema에 맞게 파싱 가능해야 한다.';


--
-- Name: COLUMN strategy_documents.presentation_document; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON COLUMN strategy.strategy_documents.presentation_document IS '파티션·Flow·Element 좌표, 크기, edge route, viewport 같은 UI 배치 정보. semantic_document와 동일한 안정 키를 참조한다.';


--
-- Name: strategy_edit_leases; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.strategy_edit_leases (
    strategy_id uuid NOT NULL,
    delegated_credential_id uuid,
    lease_token_digest character varying(128) NOT NULL,
    digest_key_version smallint NOT NULL,
    acquired_at timestamp with time zone NOT NULL,
    heartbeat_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    account_id uuid,
    CONSTRAINT strategy_edit_lease_digest_key_version_positive CHECK ((digest_key_version > 0)),
    CONSTRAINT strategy_edit_lease_exactly_one_editor CHECK ((((account_id IS NOT NULL) AND (delegated_credential_id IS NULL)) OR ((account_id IS NULL) AND (delegated_credential_id IS NOT NULL)))),
    CONSTRAINT strategy_edit_lease_time_order_valid CHECK (((heartbeat_at >= acquired_at) AND (expires_at > heartbeat_at)))
);


--
-- Name: TABLE strategy_edit_leases; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.strategy_edit_leases IS 'Allows exactly one active editor. Customer leases are account-owned and independently protected by the lease token; refresh token families are not editor identities.';


--
-- Name: template_versions; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.template_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_id uuid NOT NULL,
    version character varying(40) NOT NULL,
    element_catalog_version_id uuid NOT NULL,
    name_i18n jsonb NOT NULL,
    description_i18n jsonb NOT NULL,
    semantic_skeleton jsonb NOT NULL,
    content_hash character varying(128) NOT NULL,
    published_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone
);


--
-- Name: TABLE template_versions; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.template_versions IS 'Pro Template의 불변 시작 골격 버전. 사용하면 수정 가능한 strategy.strategy_documents 안의 새 독립 Flow 골격으로 복사되며 Template 버전이나 복사 출처를 참조하지 않는다. 이후 사용자가 완성한 Strategy를 출시해야 독립 Bot 스냅샷이 생성된다.';


--
-- Name: templates; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(80) NOT NULL,
    status character varying(30) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    retired_at timestamp with time zone
);


--
-- Name: TABLE templates; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.templates IS 'Pro 사용자에게 Pair Trading 같은 시작 구조로 제공하는 Flow Template의 식별자. 사용 후 만들어진 Flow는 Template과 연결되지 않는 독립 객체다.';


--
-- Name: validation_runs; Type: TABLE; Schema: strategy; Owner: -
--

CREATE TABLE strategy.validation_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    strategy_id uuid NOT NULL,
    requested_by_account_id uuid NOT NULL,
    delegated_authorization_id uuid,
    requested_edit_sequence bigint NOT NULL,
    semantic_hash character varying(128) NOT NULL,
    element_catalog_version_id uuid NOT NULL,
    status character varying(30) NOT NULL,
    issue_count integer DEFAULT 0 NOT NULL,
    result_document jsonb NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    CONSTRAINT strategy_validation_completion_state_valid CHECK (((((status)::text = 'RUNNING'::text) AND (completed_at IS NULL)) OR (((status)::text <> 'RUNNING'::text) AND (completed_at IS NOT NULL)))),
    CONSTRAINT strategy_validation_edit_sequence_nonnegative CHECK ((requested_edit_sequence >= 0)),
    CONSTRAINT strategy_validation_issue_count_nonnegative CHECK ((issue_count >= 0))
);


--
-- Name: TABLE validation_runs; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON TABLE strategy.validation_runs IS 'Deterministic validation of one exact mutable Strategy document state. delegated_authorization_id identifies an external AI request; null means the account acted directly. Validation never releases a Strategy, launches a Bot, or starts a backtest.';


--
-- Name: COLUMN validation_runs.status; Type: COMMENT; Schema: strategy; Owner: -
--

COMMENT ON COLUMN strategy.validation_runs.status IS 'RUNNING, VALID, INVALID, or FAILED.';


--
-- Name: bot_budget_projections; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.bot_budget_projections (
    bot_id uuid NOT NULL,
    currency_code character(3) NOT NULL,
    available_cash_amount numeric(24,8) NOT NULL,
    active_reservation_amount numeric(24,8) NOT NULL,
    invested_amount numeric(24,8) NOT NULL,
    segregated_short_proceeds_amount numeric(24,8) NOT NULL,
    short_collateral_amount numeric(24,8) NOT NULL,
    valuation_at timestamp with time zone NOT NULL,
    valuation_status character varying(30) NOT NULL,
    last_event_sequence bigint NOT NULL,
    projection_hash character varying(128) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT bot_budget_available_nonnegative CHECK ((available_cash_amount >= (0)::numeric)),
    CONSTRAINT bot_budget_invested_nonnegative CHECK ((invested_amount >= (0)::numeric)),
    CONSTRAINT bot_budget_reservation_nonnegative CHECK ((active_reservation_amount >= (0)::numeric)),
    CONSTRAINT bot_budget_short_collateral_nonnegative CHECK ((short_collateral_amount >= (0)::numeric)),
    CONSTRAINT bot_budget_short_proceeds_nonnegative CHECK ((segregated_short_proceeds_amount >= (0)::numeric))
);


--
-- Name: TABLE bot_budget_projections; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.bot_budget_projections IS '공식 원장·활성 resource_reservations·현재 청산가능 호가 평가에서 재구축하는 봇 예산 Projection. 가용현금은 격리 숏 매도대금과 담보를 제외하며 정본으로 사용하지 않는다.';


--
-- Name: buying_power_buffer_policy_versions; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.buying_power_buffer_policy_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    policy_code character varying(80) NOT NULL,
    version character varying(40) NOT NULL,
    buffer_bps integer NOT NULL,
    rounding_rules_version character varying(40) NOT NULL,
    rules_hash character varying(128) NOT NULL,
    effective_from timestamp with time zone NOT NULL,
    effective_to timestamp with time zone,
    published_at timestamp with time zone NOT NULL,
    CONSTRAINT buying_power_buffer_bps_nonnegative CHECK ((buffer_bps >= 0)),
    CONSTRAINT buying_power_buffer_effective_range CHECK (((effective_to IS NULL) OR (effective_to > effective_from)))
);


--
-- Name: TABLE buying_power_buffer_policy_versions; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.buying_power_buffer_policy_versions IS '플랫폼 관리 불변 정책. 정확한 buffer_bps는 운영 전 근거 필요.';


--
-- Name: candidate_batch_processing; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.candidate_batch_processing (
    batch_id uuid NOT NULL,
    evaluation_id uuid NOT NULL,
    source_created_at timestamp with time zone NOT NULL,
    status character varying(16) NOT NULL,
    claim_token uuid NOT NULL,
    lease_expires_at timestamp with time zone NOT NULL,
    failure_reason character varying(512),
    started_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT candidate_batch_processing_status_check CHECK (((status)::text = ANY ((ARRAY['PROCESSING'::character varying, 'COMPLETED'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: fee_policy_versions; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.fee_policy_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    policy_code character varying(80) NOT NULL,
    version character varying(40) NOT NULL,
    fee_rate_bps integer NOT NULL,
    calculation_rules_version character varying(40) NOT NULL,
    rules_hash character varying(128) NOT NULL,
    effective_from timestamp with time zone NOT NULL,
    effective_to timestamp with time zone,
    published_at timestamp with time zone NOT NULL,
    CONSTRAINT fee_policy_effective_range CHECK (((effective_to IS NULL) OR (effective_to > effective_from))),
    CONSTRAINT official_fee_twenty_bps CHECK ((fee_rate_bps = 20))
);


--
-- Name: TABLE fee_policy_versions; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.fee_policy_versions IS '모든 롱·숏 매수·매도의 정상 전량 Fill에 동일하게 한 번 적용하는 불변 플랫폼 정책. 사용자가 변경할 수 없고 과거 체결은 당시 policy id를 고정한다.';


--
-- Name: COLUMN fee_policy_versions.fee_rate_bps; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON COLUMN trading.fee_policy_versions.fee_rate_bps IS '공식 통합 가상 거래 수수료 0.2% = 20 bps.';


--
-- Name: fill_adjustments; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.fill_adjustments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    fill_id uuid NOT NULL,
    bot_event_id uuid NOT NULL,
    adjustment_key character varying(160) NOT NULL,
    adjustment_type trading.fill_adjustment_type NOT NULL,
    quantity_delta numeric(28,8) DEFAULT 0 NOT NULL,
    gross_amount_delta numeric(24,8) DEFAULT 0 NOT NULL,
    fee_amount_delta numeric(24,8) DEFAULT 0 NOT NULL,
    settlement_cash_delta numeric(24,8) DEFAULT 0 NOT NULL,
    reason_code character varying(80) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT fill_adjustment_has_effect CHECK (((quantity_delta <> (0)::numeric) OR (gross_amount_delta <> (0)::numeric) OR (fee_amount_delta <> (0)::numeric) OR (settlement_cash_delta <> (0)::numeric))),
    CONSTRAINT fill_correction_does_not_change_quantity CHECK (((adjustment_type <> 'CORRECTION'::trading.fill_adjustment_type) OR (quantity_delta = (0)::numeric)))
);


--
-- Name: TABLE fill_adjustments; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.fill_adjustments IS '정상 Fill을 복제하지 않고 사후 정정·반전을 명시적으로 남기는 추가 전용 사건. CORRECTION은 가격·금액·수수료만 조정하고, REVERSAL은 migration trigger가 원 Fill의 경제 효과와 정확히 반대인지 검증한다. 정상 Fill의 Order당 1건 불변식에는 포함되지 않는다.';


--
-- Name: fill_component_allocations; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.fill_component_allocations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    order_id uuid NOT NULL,
    fill_id uuid NOT NULL,
    order_component_id uuid NOT NULL,
    allocation_sequence integer NOT NULL,
    allocated_quantity numeric(28,8) NOT NULL,
    allocated_gross_amount numeric(24,8) NOT NULL,
    allocated_fee_amount numeric(24,8) NOT NULL,
    allocated_settlement_cash_delta numeric(24,8) NOT NULL,
    allocation_rules_version character varying(40) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT fill_allocation_cash_delta_nonzero CHECK ((allocated_settlement_cash_delta <> (0)::numeric)),
    CONSTRAINT fill_allocation_fee_nonnegative CHECK ((allocated_fee_amount >= (0)::numeric)),
    CONSTRAINT fill_allocation_gross_positive CHECK ((allocated_gross_amount > (0)::numeric)),
    CONSTRAINT fill_allocation_quantity_positive CHECK ((allocated_quantity > (0)::numeric)),
    CONSTRAINT fill_allocation_sequence_positive CHECK ((allocation_sequence > 0))
);


--
-- Name: TABLE fill_component_allocations; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.fill_component_allocations IS 'Append-only deterministic attribution of each individual fill to its order components. Deferred constraints enforce exact quantity, gross, fee and signed cash totals.';


--
-- Name: fills; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.fills (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    bot_event_id uuid NOT NULL,
    provider_fill_key character varying(160) NOT NULL,
    quantity numeric(28,8) NOT NULL,
    reference_price numeric(24,8) NOT NULL,
    reference_observed_at timestamp with time zone NOT NULL,
    reference_market_hash character varying(128) NOT NULL,
    slippage_rate_bps integer NOT NULL,
    slippage_amount numeric(24,8) NOT NULL,
    fill_price numeric(24,8) NOT NULL,
    gross_amount numeric(24,8) NOT NULL,
    fee_policy_id uuid NOT NULL,
    fee_rate_bps integer NOT NULL,
    precision_rules_version character varying(80) NOT NULL,
    fee_basis_amount numeric(24,8) NOT NULL,
    fee_amount numeric(24,8) NOT NULL,
    settlement_cash_delta numeric(24,8) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT fill_fee_basis_positive CHECK ((fee_basis_amount > (0)::numeric)),
    CONSTRAINT fill_fee_nonnegative CHECK ((fee_amount >= (0)::numeric)),
    CONSTRAINT fill_fee_twenty_bps CHECK ((fee_rate_bps = 20)),
    CONSTRAINT fill_fixed_slippage_five_bps CHECK ((slippage_rate_bps = 5)),
    CONSTRAINT fill_gross_amount_positive CHECK ((gross_amount > (0)::numeric)),
    CONSTRAINT fill_price_positive CHECK ((fill_price > (0)::numeric)),
    CONSTRAINT fill_quantity_positive CHECK ((quantity > (0)::numeric)),
    CONSTRAINT fill_reference_price_positive CHECK ((reference_price > (0)::numeric)),
    CONSTRAINT fill_slippage_amount_nonnegative CHECK ((slippage_amount >= (0)::numeric))
);


--
-- Name: TABLE fills; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.fills IS 'Append-only individual fills. Multiple partial fills are allowed per order and deferred constraints enforce effective cumulative quantity.';


--
-- Name: COLUMN fills.settlement_cash_delta; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON COLUMN trading.fills.settlement_cash_delta IS '매수는 음수, 매도는 양수인 공식 현금 변동.';


--
-- Name: flow_position_projections; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.flow_position_projections (
    flow_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    bot_id uuid NOT NULL,
    instrument_id uuid NOT NULL,
    long_quantity numeric(28,8) NOT NULL,
    short_quantity numeric(28,8) NOT NULL,
    cost_basis_amount numeric(24,8) NOT NULL,
    last_event_sequence bigint NOT NULL,
    projection_hash character varying(128) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT flow_position_basis_nonnegative CHECK ((cost_basis_amount >= (0)::numeric)),
    CONSTRAINT flow_position_long_nonnegative CHECK ((long_quantity >= (0)::numeric)),
    CONSTRAINT flow_position_short_nonnegative CHECK ((short_quantity >= (0)::numeric))
);


--
-- Name: TABLE flow_position_projections; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.flow_position_projections IS '재구축 가능한 PostgreSQL 현재 Projection. 공식 이력은 체결, 로트 변동, 원장 분개.';


--
-- Name: ledger_accounts; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.ledger_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    account_key character varying(240) NOT NULL,
    partition_id uuid,
    flow_id uuid,
    account_type character varying(50) NOT NULL,
    currency_code character(3),
    instrument_id uuid,
    created_at timestamp with time zone NOT NULL,
    closed_at timestamp with time zone,
    CONSTRAINT ledger_account_close_after_create CHECK (((closed_at IS NULL) OR (closed_at > created_at))),
    CONSTRAINT ledger_account_exactly_one_unit CHECK (((currency_code IS NOT NULL) <> (instrument_id IS NOT NULL))),
    CONSTRAINT ledger_flow_requires_partition CHECK (((flow_id IS NULL) OR (partition_id IS NOT NULL)))
);


--
-- Name: TABLE ledger_accounts; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.ledger_accounts IS '복식 원장의 계정 차원. 거래용 계정은 반드시 Partition에 속하고 Flow 귀속 자산 계정은 flow_id도 가진다. OPEN_SHORT Fill 매도대금은 일반 CASH가 아니라 SEGREGATED_SHORT_PROCEEDS 계정에 기록하며 CLOSE_SHORT 정산 전까지 새 주문의 Buying Power로 사용할 수 없다. Bot 전체 초기자본·미배정 현금 계정만 partition_id가 없을 수 있다. account_key와 제약 트리거가 scope 컬럼 일치를 검증한다.';


--
-- Name: COLUMN ledger_accounts.account_key; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON COLUMN trading.ledger_accounts.account_key IS '봇 안에서 범위·계정유형·통화·종목을 정규화한 null 없는 안정 키.';


--
-- Name: ledger_entries; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.ledger_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid,
    transaction_id uuid NOT NULL,
    ledger_account_id uuid NOT NULL,
    order_component_id uuid,
    entry_sequence integer NOT NULL,
    direction trading.ledger_direction NOT NULL,
    amount numeric(24,8) NOT NULL,
    quantity numeric(28,8),
    entry_hash character varying(128) NOT NULL,
    CONSTRAINT ledger_entry_amount_positive CHECK ((amount > (0)::numeric)),
    CONSTRAINT ledger_entry_quantity_nonzero CHECK (((quantity IS NULL) OR (quantity <> (0)::numeric))),
    CONSTRAINT ledger_entry_sequence_positive CHECK ((entry_sequence > 0)),
    CONSTRAINT order_component_ledger_entry_requires_partition CHECK (((order_component_id IS NULL) OR (partition_id IS NOT NULL)))
);


--
-- Name: TABLE ledger_entries; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.ledger_entries IS '추가 전용 차변·대변 분개. Fill 거래의 Flow별 귀속은 order_component_id로 직접 이어지고 Flow 자체는 component의 Intent에서 유도한다. 지연 트리거가 Fill 없는 체결 분개, 파티션 불일치, 구성별 금액·수수료 합계 불일치와 불균형 분개를 커밋 시 차단한다.';


--
-- Name: ledger_transactions; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.ledger_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid,
    bot_event_id uuid NOT NULL,
    transaction_type character varying(60) NOT NULL,
    transaction_key character varying(160) NOT NULL,
    source_type character varying(40) NOT NULL,
    source_id uuid NOT NULL,
    currency_code character(3) NOT NULL,
    reversal_of_transaction_id uuid,
    occurred_at timestamp with time zone NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    description_code character varying(80) NOT NULL
);


--
-- Name: TABLE ledger_transactions; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.ledger_transactions IS '추가 전용 회계 사건 헤더. FILL·FILL_ADJUSTMENT·차입비용·기업행사·초기자본을 멱등 source로 식별한다. FILL과 그 조정은 partition_id가 필수이며 같은 파티션 Ledger Account만 사용할 수 있다. 초기자본처럼 Bot 전체 사건만 partition_id가 없다.';


--
-- Name: lot_movements; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.lot_movements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    position_lot_id uuid NOT NULL,
    bot_event_id uuid NOT NULL,
    source_fill_allocation_id uuid,
    source_fill_adjustment_id uuid,
    corporate_action_id uuid,
    reverses_movement_id uuid,
    movement_type trading.lot_movement_type NOT NULL,
    quantity_delta numeric(28,8) NOT NULL,
    cost_basis_delta numeric(24,8) NOT NULL,
    remaining_after numeric(28,8) NOT NULL,
    cost_basis_after numeric(24,8) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    CONSTRAINT corporate_movement_source_required CHECK (((movement_type <> 'CORPORATE_ACTION_ADJUSTMENT'::trading.lot_movement_type) OR (corporate_action_id IS NOT NULL))),
    CONSTRAINT fill_movement_source_required CHECK (((movement_type <> ALL (ARRAY['OPEN'::trading.lot_movement_type, 'CLOSE'::trading.lot_movement_type])) OR (source_fill_allocation_id IS NOT NULL))),
    CONSTRAINT lot_movement_basis_nonnegative CHECK ((cost_basis_after >= (0)::numeric)),
    CONSTRAINT lot_movement_quantity_nonzero CHECK ((quantity_delta <> (0)::numeric)),
    CONSTRAINT lot_movement_remaining_nonnegative CHECK ((remaining_after >= (0)::numeric)),
    CONSTRAINT lot_movement_source_not_ambiguous CHECK ((((
CASE
    WHEN (source_fill_allocation_id IS NOT NULL) THEN 1
    ELSE 0
END +
CASE
    WHEN (source_fill_adjustment_id IS NOT NULL) THEN 1
    ELSE 0
END) +
CASE
    WHEN (corporate_action_id IS NOT NULL) THEN 1
    ELSE 0
END) <= 1)),
    CONSTRAINT reversal_movement_source_required CHECK (((movement_type <> 'REVERSAL'::trading.lot_movement_type) OR ((reverses_movement_id IS NOT NULL) AND (source_fill_adjustment_id IS NOT NULL))))
);


--
-- Name: TABLE lot_movements; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.lot_movements IS 'OPEN and CLOSE movements prove their scope through an exact fill-component allocation.';


--
-- Name: order_component_reservations; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_component_reservations (
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    reservation_id uuid NOT NULL,
    order_component_id uuid NOT NULL,
    reserved_amount numeric(24,8),
    reserved_quantity numeric(28,8),
    CONSTRAINT order_component_reservation_amount_positive CHECK (((reserved_amount IS NULL) OR (reserved_amount > (0)::numeric))),
    CONSTRAINT order_component_reservation_exactly_one_measure CHECK (((reserved_amount IS NOT NULL) <> (reserved_quantity IS NOT NULL))),
    CONSTRAINT order_component_reservation_quantity_positive CHECK (((reserved_quantity IS NULL) OR (reserved_quantity > (0)::numeric)))
);


--
-- Name: TABLE order_component_reservations; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_component_reservations IS '최종 Order의 각 구성 내역을 실제 현금·Position 수량 예약과 연결한다. 부분 체결과 예약 재사용을 지원하지 않으므로 하나의 resource reservation은 하나의 order component만 뒷받침하며 replacement Order는 새 예약을 만든다.';


--
-- Name: order_components; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_components (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    order_id uuid NOT NULL,
    intent_id uuid NOT NULL,
    component_quantity numeric(28,8) NOT NULL,
    component_notional numeric(24,8),
    component_sequence integer NOT NULL,
    composition_rules_version character varying(40) NOT NULL,
    CONSTRAINT order_component_notional_positive CHECK (((component_notional IS NULL) OR (component_notional > (0)::numeric))),
    CONSTRAINT order_component_quantity_positive CHECK ((component_quantity > (0)::numeric)),
    CONSTRAINT order_component_sequence_positive CHECK ((component_sequence > 0))
);


--
-- Name: TABLE order_components; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_components IS '하나의 파티션 전용 Order를 구성하는 Flow별 주문 의도 내역. 각 행은 어떤 Intent가 최종 Order 수량 중 얼마를 구성하는지 고정하며, Order의 component_quantity 합계는 requested_quantity와 같아야 한다. 정확한 Intent·position_effect·구성 규칙 버전을 보존하고 합계 불변식은 PostgreSQL 지연 제약 트리거로 강제한다.';


--
-- Name: order_events; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    order_id uuid NOT NULL,
    bot_event_id uuid NOT NULL,
    order_sequence bigint NOT NULL,
    event_type character varying(50) NOT NULL,
    previous_status trading.order_status,
    new_status trading.order_status NOT NULL,
    reason_code character varying(80),
    occurred_at timestamp with time zone NOT NULL,
    event_document jsonb NOT NULL,
    CONSTRAINT order_event_sequence_positive CHECK ((order_sequence > 0))
);


--
-- Name: TABLE order_events; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_events IS '주문 상태 전이의 추가 전용 정본. 정상 경로는 PENDING/OPEN에서 FILLED, CANCELLED, EXPIRED 또는 REJECTED 중 하나로만 끝난다. CANCELLED는 사용자·봇 중지·운영자 강제 취소가 아니라 자동 replacement에서 원본 주문을 철회할 때만 허용한다. 부분 체결 상태는 없고 replacement 전 원본은 CANCELLED 사건을 먼저 가져야 한다.';


--
-- Name: order_group_events; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_group_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    order_group_id uuid NOT NULL,
    bot_event_id uuid NOT NULL,
    group_sequence bigint NOT NULL,
    previous_status trading.order_group_status,
    new_status trading.order_group_status NOT NULL,
    event_type character varying(50) NOT NULL,
    reason_code character varying(80),
    occurred_at timestamp with time zone NOT NULL,
    event_document jsonb NOT NULL,
    CONSTRAINT order_group_event_sequence_positive CHECK ((group_sequence > 0))
);


--
-- Name: TABLE order_group_events; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_group_events IS '그룹의 활성화·상호 취소·완료·실패를 추가 전용으로 보존한다. order_groups.status는 이 이벤트의 현재 Projection이다.';


--
-- Name: order_group_members; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_group_members (
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    order_group_id uuid NOT NULL,
    order_id uuid NOT NULL,
    member_role trading.order_group_member_role NOT NULL,
    leg_sequence integer NOT NULL,
    quantity_ratio numeric(18,8) DEFAULT 1 NOT NULL,
    activation_condition jsonb NOT NULL,
    cancellation_condition jsonb NOT NULL,
    CONSTRAINT order_group_leg_sequence_positive CHECK ((leg_sequence > 0)),
    CONSTRAINT order_group_quantity_ratio_positive CHECK ((quantity_ratio > (0)::numeric))
);


--
-- Name: TABLE order_group_members; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_group_members IS 'OCO·브래킷·멀티레그에서 각 주문의 역할, 순서, 활성화와 상호 취소 조건을 고정한다. 주문 하나는 동시에 둘 이상의 그룹에 속하지 않는다.';


--
-- Name: order_groups; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    group_type trading.order_group_type NOT NULL,
    group_key character varying(160) NOT NULL,
    status trading.order_group_status NOT NULL,
    created_event_id uuid NOT NULL,
    closed_event_id uuid
);


--
-- Name: TABLE order_groups; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_groups IS 'OCO·브래킷·Pro 연계 주문의 관계만 표현하는 파티션 전용 그룹. 다른 파티션 주문은 멤버가 될 수 없고 전량 체결 또는 미체결 결과만 처리한다.';


--
-- Name: order_intent_batches; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_intent_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    source_event_id uuid NOT NULL,
    status character varying(30) NOT NULL,
    conflict_policy_hash character varying(128) NOT NULL,
    composition_rules_version character varying(40) NOT NULL,
    input_state_hash character varying(128) NOT NULL,
    result_hash character varying(128),
    finalized_at timestamp with time zone,
    CONSTRAINT intent_batch_finalized_complete CHECK ((((status)::text <> 'FINALIZED'::text) OR ((finalized_at IS NOT NULL) AND (result_hash IS NOT NULL)))),
    CONSTRAINT intent_batch_status_valid CHECK (((status)::text = ANY ((ARRAY['COLLECTING'::character varying, 'FINALIZED'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: TABLE order_intent_batches; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_intent_batches IS '한 Bot Event에서 정확히 한 파티션의 Flow 의도만 수집하는 거래 격리 경계. 충돌 처리·상계·통합과 자원 잠금은 (bot_id, partition_id) 안에서만 수행한다. 복합 멱등 키가 같은 이벤트의 파티션별 at-least-once 재전달을 안전하게 흡수한다.';


--
-- Name: order_intents; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_intents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    source_event_id uuid NOT NULL,
    origin_type trading.intent_origin_type NOT NULL,
    evaluation_run_id uuid,
    partition_id uuid NOT NULL,
    flow_id uuid NOT NULL,
    instrument_id uuid NOT NULL,
    intent_key character varying(160) NOT NULL,
    side trading.order_side NOT NULL,
    position_effect trading.position_effect NOT NULL,
    order_type trading.order_type NOT NULL,
    time_in_force trading.time_in_force NOT NULL,
    requested_quantity numeric(28,8),
    requested_notional numeric(24,8),
    approved_quantity numeric(28,8),
    approved_notional numeric(24,8),
    post_netting_quantity numeric(28,8) DEFAULT 0 NOT NULL,
    final_quantity numeric(28,8),
    final_notional numeric(24,8),
    limit_price numeric(24,8),
    stop_price numeric(24,8),
    trailing_offset_type trading.trailing_offset_type,
    trailing_offset_value numeric(24,8),
    requested_expires_at timestamp with time zone,
    decision trading.intent_decision NOT NULL,
    decision_reason_code character varying(80) NOT NULL,
    CONSTRAINT flow_intent_requires_evaluation CHECK (((origin_type <> 'FLOW_EVALUATION'::trading.intent_origin_type) OR (evaluation_run_id IS NOT NULL))),
    CONSTRAINT intent_approved_notional_nonnegative CHECK (((approved_notional IS NULL) OR (approved_notional >= (0)::numeric))),
    CONSTRAINT intent_approved_quantity_nonnegative CHECK (((approved_quantity IS NULL) OR (approved_quantity >= (0)::numeric))),
    CONSTRAINT intent_exactly_one_requested_measure CHECK (((requested_quantity IS NOT NULL) <> (requested_notional IS NOT NULL))),
    CONSTRAINT intent_final_notional_nonnegative CHECK (((final_notional IS NULL) OR (final_notional >= (0)::numeric))),
    CONSTRAINT intent_final_quantity_nonnegative CHECK (((final_quantity IS NULL) OR (final_quantity >= (0)::numeric))),
    CONSTRAINT intent_gtd_expiry_required CHECK (((time_in_force <> 'GTD'::trading.time_in_force) OR (requested_expires_at IS NOT NULL))),
    CONSTRAINT intent_limit_price_required CHECK (((order_type <> 'LIMIT'::trading.order_type) OR (limit_price IS NOT NULL))),
    CONSTRAINT intent_market_contract_valid CHECK (((order_type <> 'MARKET'::trading.order_type) OR ((limit_price IS NULL) AND (stop_price IS NULL) AND (trailing_offset_type IS NULL) AND (time_in_force = 'DAY'::trading.time_in_force)))),
    CONSTRAINT intent_non_trailing_has_no_offset CHECK (((order_type = 'TRAILING_STOP'::trading.order_type) OR ((trailing_offset_type IS NULL) AND (trailing_offset_value IS NULL)))),
    CONSTRAINT intent_nonexecuting_decision_has_no_final CHECK (((decision <> ALL (ARRAY['REJECTED'::trading.intent_decision, 'NETTED'::trading.intent_decision, 'CONFLICTED'::trading.intent_decision])) OR ((COALESCE(final_quantity, (0)::numeric) = (0)::numeric) AND (COALESCE(final_notional, (0)::numeric) = (0)::numeric)))),
    CONSTRAINT intent_post_netting_quantity_nonnegative CHECK ((post_netting_quantity >= (0)::numeric)),
    CONSTRAINT intent_requested_notional_positive CHECK (((requested_notional IS NULL) OR (requested_notional > (0)::numeric))),
    CONSTRAINT intent_requested_quantity_positive CHECK (((requested_quantity IS NULL) OR (requested_quantity > (0)::numeric))),
    CONSTRAINT intent_side_effect_compatible CHECK ((((side = 'BUY'::trading.order_side) AND (position_effect = ANY (ARRAY['OPEN_LONG'::trading.position_effect, 'CLOSE_SHORT'::trading.position_effect]))) OR ((side = 'SELL'::trading.order_side) AND (position_effect = ANY (ARRAY['CLOSE_LONG'::trading.position_effect, 'OPEN_SHORT'::trading.position_effect]))))),
    CONSTRAINT intent_stop_limit_prices_required CHECK (((order_type <> 'STOP_LIMIT'::trading.order_type) OR ((limit_price IS NOT NULL) AND (stop_price IS NOT NULL)))),
    CONSTRAINT intent_stop_price_required CHECK (((order_type <> 'STOP'::trading.order_type) OR (stop_price IS NOT NULL))),
    CONSTRAINT intent_trailing_offset_required CHECK (((order_type <> 'TRAILING_STOP'::trading.order_type) OR ((trailing_offset_type IS NOT NULL) AND (trailing_offset_value > (0)::numeric)))),
    CONSTRAINT system_intent_has_no_evaluation CHECK (((origin_type = 'FLOW_EVALUATION'::trading.intent_origin_type) OR (evaluation_run_id IS NULL)))
);


--
-- Name: TABLE order_intents; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_intents IS 'Flow 또는 시스템 안전 절차가 만든 원래 의도와 승인·파티션 내부 상계·최종 잔여 결과의 불변 기록. Flow 주문 Element는 최소 재활성화 기간 경과와 동일 Element·종목의 OPEN Order/ACTIVE Reservation 부재를 먼저 검사한다. 매수 requested_notional은 실행 시점 Partition 가용 현금에 orderSizePercent를 적용한 상한이고, 매도 requested_quantity는 해당 Flow의 예약되지 않은 매도 가능 소수점 수량에 같은 퍼센트를 적용한 결과다. 같은 (bot_id, partition_id, batch_id)의 호환 가능한 종목·방향·주문 계약만 하나의 Order로 결합하며 다른 파티션이나 사용자와 절대 통합하지 않는다.';


--
-- Name: COLUMN order_intents.evaluation_run_id; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON COLUMN trading.order_intents.evaluation_run_id IS 'FLOW_EVALUATION에서만 필수. 시스템 강제 청산·강제 바이인은 평가 실행 없이 공식 사건에서 생성한다.';


--
-- Name: COLUMN order_intents.post_netting_quantity; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON COLUMN trading.order_intents.post_netting_quantity IS '상계로 제거된 양이 아니라 상계 후 실제 주문 대상으로 남은 수량.';


--
-- Name: order_state_projections; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.order_state_projections (
    order_id uuid NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    status trading.order_status NOT NULL,
    filled_quantity numeric(28,8) NOT NULL,
    remaining_quantity numeric(28,8) NOT NULL,
    reserved_cash numeric(24,8) NOT NULL,
    reserved_quantity numeric(28,8) NOT NULL,
    active_stop_price numeric(24,8),
    trailing_reference_price numeric(24,8),
    last_order_event_sequence bigint NOT NULL,
    last_bot_event_sequence bigint NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT closed_projection_has_no_active_remainder CHECK (((status <> ALL (ARRAY['CANCELLED'::trading.order_status, 'EXPIRED'::trading.order_status])) OR (remaining_quantity = (0)::numeric))),
    CONSTRAINT filled_projection_is_complete CHECK (((status <> 'FILLED'::trading.order_status) OR ((filled_quantity > (0)::numeric) AND (remaining_quantity = (0)::numeric)))),
    CONSTRAINT open_projection_has_remaining_quantity CHECK (((status <> 'OPEN'::trading.order_status) OR (remaining_quantity > (0)::numeric))),
    CONSTRAINT order_projection_active_stop_positive CHECK (((active_stop_price IS NULL) OR (active_stop_price > (0)::numeric))),
    CONSTRAINT order_projection_filled_nonnegative CHECK ((filled_quantity >= (0)::numeric)),
    CONSTRAINT order_projection_remaining_nonnegative CHECK ((remaining_quantity >= (0)::numeric)),
    CONSTRAINT order_projection_reserved_cash_nonnegative CHECK ((reserved_cash >= (0)::numeric)),
    CONSTRAINT order_projection_reserved_quantity_nonnegative CHECK ((reserved_quantity >= (0)::numeric)),
    CONSTRAINT order_projection_trailing_reference_positive CHECK (((trailing_reference_price IS NULL) OR (trailing_reference_price > (0)::numeric))),
    CONSTRAINT pending_projection_has_no_fill CHECK (((status <> 'PENDING'::trading.order_status) OR ((filled_quantity = (0)::numeric) AND (remaining_quantity > (0)::numeric)))),
    CONSTRAINT rejected_projection_has_no_fill CHECK (((status <> 'REJECTED'::trading.order_status) OR ((filled_quantity = (0)::numeric) AND (remaining_quantity = (0)::numeric))))
);


--
-- Name: TABLE order_state_projections; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.order_state_projections IS '재구축 가능한 현재 주문 읽기 모델. filled_quantity는 0 또는 Order 전량뿐이며 중간값을 허용하지 않는다. 정본은 order_events와 정상 Fill이다.';


--
-- Name: orders; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    instrument_id uuid NOT NULL,
    replaces_order_id uuid,
    replacement_reason_code character varying(80),
    order_key character varying(160) NOT NULL,
    side trading.order_side NOT NULL,
    order_type trading.order_type NOT NULL,
    time_in_force trading.time_in_force NOT NULL,
    requested_quantity numeric(28,8) NOT NULL,
    requested_notional numeric(24,8),
    limit_price numeric(24,8),
    stop_price numeric(24,8),
    trailing_offset_type trading.trailing_offset_type,
    trailing_offset_value numeric(24,8),
    broker_rules_version character varying(80) NOT NULL,
    precision_rules_version character varying(80) NOT NULL,
    slippage_rate_bps integer NOT NULL,
    fee_policy_id uuid NOT NULL,
    accepted_event_id uuid NOT NULL,
    accepted_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone,
    contract_hash character varying(128) NOT NULL,
    CONSTRAINT order_does_not_replace_itself CHECK (((replaces_order_id IS NULL) OR (replaces_order_id <> id))),
    CONSTRAINT order_expiry_after_acceptance CHECK (((expires_at IS NULL) OR (expires_at > accepted_at))),
    CONSTRAINT order_expiry_within_ninety_days CHECK (((expires_at IS NULL) OR (expires_at <= (accepted_at + '90 days'::interval)))),
    CONSTRAINT order_fixed_slippage_five_bps CHECK ((slippage_rate_bps = 5)),
    CONSTRAINT order_gtd_expiry_required CHECK (((time_in_force <> 'GTD'::trading.time_in_force) OR (expires_at IS NOT NULL))),
    CONSTRAINT order_limit_price_required CHECK (((order_type <> 'LIMIT'::trading.order_type) OR (limit_price IS NOT NULL))),
    CONSTRAINT order_market_contract_valid CHECK (((order_type <> 'MARKET'::trading.order_type) OR ((limit_price IS NULL) AND (stop_price IS NULL) AND (trailing_offset_type IS NULL) AND (time_in_force = 'DAY'::trading.time_in_force)))),
    CONSTRAINT order_non_trailing_has_no_offset CHECK (((order_type = 'TRAILING_STOP'::trading.order_type) OR ((trailing_offset_type IS NULL) AND (trailing_offset_value IS NULL)))),
    CONSTRAINT order_replacement_reason_consistent CHECK (((replaces_order_id IS NULL) = (replacement_reason_code IS NULL))),
    CONSTRAINT order_requested_notional_positive CHECK (((requested_notional IS NULL) OR (requested_notional > (0)::numeric))),
    CONSTRAINT order_requested_quantity_positive CHECK ((requested_quantity > (0)::numeric)),
    CONSTRAINT order_stop_limit_prices_required CHECK (((order_type <> 'STOP_LIMIT'::trading.order_type) OR ((limit_price IS NOT NULL) AND (stop_price IS NOT NULL)))),
    CONSTRAINT order_stop_price_required CHECK (((order_type <> 'STOP'::trading.order_type) OR (stop_price IS NOT NULL))),
    CONSTRAINT order_trailing_offset_required CHECK (((order_type <> 'TRAILING_STOP'::trading.order_type) OR ((trailing_offset_type IS NOT NULL) AND (trailing_offset_value > (0)::numeric))))
);


--
-- Name: TABLE orders; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.orders IS '파티션 내부 상계 후 제출되는 불변 파티션 전용 가상 주문 계약. 요청 수량은 접수 뒤 변경하지 않는다. CANCELLED는 사용자·봇 중지·운영자 조작으로 만들 수 없고, 이미 OPEN인 주문에 자동 replacement 정책을 적용할 때 원본을 철회하는 시스템 전이로만 사용한다. 더 작은 소수점 수량이 필요하면 원본 예약을 전액 해제하고 같은 파티션의 새 order component·reservation을 가진 replacement Order를 만든다. 현재 상태는 추가 전용 order_events와 projection에서만 얻는다.';


--
-- Name: partition_budget_projections; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.partition_budget_projections (
    partition_id uuid NOT NULL,
    bot_id uuid NOT NULL,
    currency_code character(3) NOT NULL,
    budget_cap_amount numeric(24,8) NOT NULL,
    active_reservation_amount numeric(24,8) NOT NULL,
    invested_amount numeric(24,8) NOT NULL,
    segregated_short_proceeds_amount numeric(24,8) NOT NULL,
    short_collateral_amount numeric(24,8) NOT NULL,
    valuation_at timestamp with time zone NOT NULL,
    valuation_status character varying(30) NOT NULL,
    last_event_sequence bigint NOT NULL,
    projection_hash character varying(128) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT partition_budget_cap_positive CHECK ((budget_cap_amount > (0)::numeric)),
    CONSTRAINT partition_budget_invested_nonnegative CHECK ((invested_amount >= (0)::numeric)),
    CONSTRAINT partition_budget_reservation_nonnegative CHECK ((active_reservation_amount >= (0)::numeric)),
    CONSTRAINT partition_budget_short_collateral_nonnegative CHECK ((short_collateral_amount >= (0)::numeric)),
    CONSTRAINT partition_budget_short_proceeds_nonnegative CHECK ((segregated_short_proceeds_amount >= (0)::numeric))
);


--
-- Name: TABLE partition_budget_projections; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.partition_budget_projections IS '파티션 상한 사용량의 재구축 가능한 Projection. bot_id를 명시해 테넌트·소유 범위를 보존하고, 현재 청산가능 가격의 보유액·활성 예약·격리 숏 대금·담보를 공식 계산 규칙대로 분리한다.';


--
-- Name: partition_position_projections; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.partition_position_projections (
    partition_id uuid NOT NULL,
    bot_id uuid NOT NULL,
    instrument_id uuid NOT NULL,
    net_quantity numeric(28,8) NOT NULL,
    average_cost numeric(24,8),
    realized_pnl numeric(24,8) NOT NULL,
    last_valuation_price numeric(24,8),
    last_valuation_at timestamp with time zone,
    valuation_status character varying(30) NOT NULL,
    last_bot_event_sequence bigint NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT position_projection_average_cost_nonnegative CHECK (((average_cost IS NULL) OR (average_cost >= (0)::numeric))),
    CONSTRAINT position_projection_valuation_price_positive CHECK (((last_valuation_price IS NULL) OR (last_valuation_price > (0)::numeric)))
);


--
-- Name: TABLE partition_position_projections; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.partition_position_projections IS '주문 가능 보유량과 순포지션 검사에 사용하는 재구축 가능한 파티션별 현재 상태. 서로 다른 파티션 포지션을 상계하지 않으며 Bot 전체 화면은 이 행들을 읽기 전용으로 합산한다. 원장·로트 기록이 정본.';


--
-- Name: position_lot_projections; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.position_lot_projections (
    position_lot_id uuid NOT NULL,
    remaining_quantity numeric(28,8) NOT NULL,
    remaining_cost_basis_amount numeric(24,8) NOT NULL,
    active_reserved_quantity numeric(28,8) NOT NULL,
    last_movement_id uuid NOT NULL,
    last_event_sequence bigint NOT NULL,
    closed_at timestamp with time zone,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT lot_projection_basis_nonnegative CHECK ((remaining_cost_basis_amount >= (0)::numeric)),
    CONSTRAINT lot_projection_closed_consistent CHECK (((remaining_quantity = (0)::numeric) = (closed_at IS NOT NULL))),
    CONSTRAINT lot_projection_remaining_nonnegative CHECK ((remaining_quantity >= (0)::numeric)),
    CONSTRAINT lot_projection_reservation_within_remaining CHECK (((active_reserved_quantity >= (0)::numeric) AND (active_reserved_quantity <= remaining_quantity)))
);


--
-- Name: TABLE position_lot_projections; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.position_lot_projections IS '재구축 가능한 로트 현재 상태. 동일 Flow의 FIFO 예약과 청산 조회를 빠르게 하며 정본은 position_lots와 lot_movements다.';


--
-- Name: position_lot_reservations; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.position_lot_reservations (
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    flow_id uuid NOT NULL,
    reservation_id uuid NOT NULL,
    position_lot_id uuid NOT NULL,
    reserved_quantity numeric(28,8) NOT NULL,
    CONSTRAINT position_lot_reservation_quantity_positive CHECK ((reserved_quantity > (0)::numeric))
);


--
-- Name: TABLE position_lot_reservations; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.position_lot_reservations IS 'POSITION_QUANTITY 예약이 같은 Bot·Partition·Flow의 FIFO lot 중 어떤 잔량을 잠갔는지 고정한다. 복합 FK가 다른 파티션 또는 다른 Flow의 lot 매도를 차단하고, 활성 예약 합계는 지연 트리거가 현재 잔량 이하로 제한한다.';


--
-- Name: position_lots; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.position_lots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    flow_id uuid NOT NULL,
    instrument_id uuid NOT NULL,
    opening_order_component_id uuid NOT NULL,
    lot_side trading.lot_side NOT NULL,
    opened_quantity numeric(28,8) NOT NULL,
    unit_cost numeric(24,8) NOT NULL,
    opened_cost_basis_amount numeric(24,8) NOT NULL,
    opened_at timestamp with time zone NOT NULL,
    opening_fill_allocation_id uuid NOT NULL,
    CONSTRAINT position_lot_opened_basis_nonnegative CHECK ((opened_cost_basis_amount >= (0)::numeric)),
    CONSTRAINT position_lot_opened_quantity_positive CHECK ((opened_quantity > (0)::numeric)),
    CONSTRAINT position_lot_unit_cost_nonnegative CHECK ((unit_cost >= (0)::numeric))
);


--
-- Name: TABLE position_lots; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.position_lots IS 'Each immutable FIFO lot originates from one exact fill-component allocation.';


--
-- Name: reservation_events; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.reservation_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    reservation_id uuid NOT NULL,
    bot_event_id uuid NOT NULL,
    source_fill_id uuid,
    event_key character varying(160) NOT NULL,
    reservation_sequence bigint NOT NULL,
    event_type trading.reservation_event_type NOT NULL,
    consumed_amount_delta numeric(24,8),
    released_amount_delta numeric(24,8),
    consumed_quantity_delta numeric(28,8),
    released_quantity_delta numeric(28,8),
    status_after trading.reservation_status NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    event_hash character varying(128) NOT NULL,
    CONSTRAINT fill_consumption_source_required CHECK (((event_type <> ALL (ARRAY['CONSUMED_BY_FILL'::trading.reservation_event_type, 'SETTLED_BY_FILL'::trading.reservation_event_type])) OR (source_fill_id IS NOT NULL))),
    CONSTRAINT fill_settlement_status_valid CHECK (((event_type <> 'SETTLED_BY_FILL'::trading.reservation_event_type) OR (status_after = 'SETTLED'::trading.reservation_status))),
    CONSTRAINT non_fill_reservation_event_has_no_fill CHECK (((event_type = ANY (ARRAY['CONSUMED_BY_FILL'::trading.reservation_event_type, 'SETTLED_BY_FILL'::trading.reservation_event_type])) OR (source_fill_id IS NULL))),
    CONSTRAINT partial_fill_consumption_stays_active CHECK (((event_type <> 'CONSUMED_BY_FILL'::trading.reservation_event_type) OR (status_after = 'ACTIVE'::trading.reservation_status))),
    CONSTRAINT release_event_status_valid CHECK (((event_type <> ALL (ARRAY['RELEASED_BY_CANCEL'::trading.reservation_event_type, 'RELEASED_BY_EXPIRY'::trading.reservation_event_type, 'RELEASED_BY_REJECTION'::trading.reservation_event_type, 'RELEASED_BY_REPLACEMENT'::trading.reservation_event_type])) OR (status_after = ANY (ARRAY['RELEASED'::trading.reservation_status, 'SETTLED'::trading.reservation_status])))),
    CONSTRAINT reservation_event_consumed_amount_nonnegative CHECK (((consumed_amount_delta IS NULL) OR (consumed_amount_delta >= (0)::numeric))),
    CONSTRAINT reservation_event_consumed_quantity_nonnegative CHECK (((consumed_quantity_delta IS NULL) OR (consumed_quantity_delta >= (0)::numeric))),
    CONSTRAINT reservation_event_released_amount_nonnegative CHECK (((released_amount_delta IS NULL) OR (released_amount_delta >= (0)::numeric))),
    CONSTRAINT reservation_event_released_quantity_nonnegative CHECK (((released_quantity_delta IS NULL) OR (released_quantity_delta >= (0)::numeric))),
    CONSTRAINT reservation_event_sequence_positive CHECK ((reservation_sequence > 0))
);


--
-- Name: TABLE reservation_events; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.reservation_events IS '예약 생성과 정확히 한 번의 최종 정산을 추가 전용으로 기록한다. Fill 정산 사건 한 건은 실제 사용액 소비와 완충액·잔액 해제를 함께 기록한다. 취소·만료·거절·replacement는 전액 해제하며 event_key와 sequence가 중복 효과를 차단한다.';


--
-- Name: resource_reservations; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.resource_reservations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reservation_key character varying(200) NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    flow_id uuid NOT NULL,
    intent_id uuid NOT NULL,
    resource_type trading.reservation_resource_type NOT NULL,
    currency_code character(3),
    instrument_id uuid,
    buffer_policy_id uuid,
    fee_policy_id uuid,
    short_risk_policy_id uuid,
    precision_rules_version character varying(80) NOT NULL,
    status trading.reservation_status NOT NULL,
    reference_price numeric(24,8),
    reference_observed_at timestamp with time zone,
    reference_market_hash character varying(128),
    base_notional numeric(24,8),
    fixed_slippage_amount numeric(24,8),
    estimated_fee_amount numeric(24,8),
    buffer_amount numeric(24,8),
    reserved_amount numeric(24,8),
    consumed_amount numeric(24,8) DEFAULT 0 NOT NULL,
    released_amount numeric(24,8) DEFAULT 0 NOT NULL,
    reserved_quantity numeric(28,8),
    consumed_quantity numeric(28,8) DEFAULT 0 NOT NULL,
    released_quantity numeric(28,8) DEFAULT 0 NOT NULL,
    created_event_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_event_sequence bigint DEFAULT 1 NOT NULL,
    CONSTRAINT active_reservation_not_released CHECK (((status <> 'ACTIVE'::trading.reservation_status) OR ((released_amount = (0)::numeric) AND (released_quantity = (0)::numeric)))),
    CONSTRAINT cash_policies_only_for_buying_power CHECK (((resource_type = 'CASH_BUYING_POWER'::trading.reservation_resource_type) OR ((buffer_policy_id IS NULL) AND (fee_policy_id IS NULL) AND (buffer_amount IS NULL)))),
    CONSTRAINT cash_reservation_evidence_required CHECK (((resource_type <> 'CASH_BUYING_POWER'::trading.reservation_resource_type) OR ((currency_code IS NOT NULL) AND (buffer_policy_id IS NOT NULL) AND (fee_policy_id IS NOT NULL) AND (reserved_amount IS NOT NULL)))),
    CONSTRAINT quantity_reservation_instrument_required CHECK (((resource_type <> 'POSITION_QUANTITY'::trading.reservation_resource_type) OR ((instrument_id IS NOT NULL) AND (reserved_quantity IS NOT NULL)))),
    CONSTRAINT released_reservation_has_no_consumption CHECK (((status <> 'RELEASED'::trading.reservation_status) OR ((consumed_amount = (0)::numeric) AND (consumed_quantity = (0)::numeric)))),
    CONSTRAINT reservation_amount_final_conservation CHECK (((reserved_amount IS NULL) OR (status = 'ACTIVE'::trading.reservation_status) OR ((consumed_amount + released_amount) = reserved_amount))),
    CONSTRAINT reservation_amount_not_exceeded CHECK (((reserved_amount IS NULL) OR ((consumed_amount + released_amount) <= reserved_amount))),
    CONSTRAINT reservation_amount_positive CHECK (((reserved_amount IS NULL) OR (reserved_amount > (0)::numeric))),
    CONSTRAINT reservation_consumed_amount_nonnegative CHECK ((consumed_amount >= (0)::numeric)),
    CONSTRAINT reservation_consumed_quantity_nonnegative CHECK ((consumed_quantity >= (0)::numeric)),
    CONSTRAINT reservation_exactly_one_measure CHECK (((reserved_amount IS NOT NULL) <> (reserved_quantity IS NOT NULL))),
    CONSTRAINT reservation_quantity_final_conservation CHECK (((reserved_quantity IS NULL) OR (status = 'ACTIVE'::trading.reservation_status) OR ((consumed_quantity + released_quantity) = reserved_quantity))),
    CONSTRAINT reservation_quantity_not_exceeded CHECK (((reserved_quantity IS NULL) OR ((consumed_quantity + released_quantity) <= reserved_quantity))),
    CONSTRAINT reservation_quantity_positive CHECK (((reserved_quantity IS NULL) OR (reserved_quantity > (0)::numeric))),
    CONSTRAINT reservation_released_amount_nonnegative CHECK ((released_amount >= (0)::numeric)),
    CONSTRAINT reservation_released_quantity_nonnegative CHECK ((released_quantity >= (0)::numeric)),
    CONSTRAINT settled_reservation_has_consumption CHECK (((status <> 'SETTLED'::trading.reservation_status) OR (((reserved_amount IS NOT NULL) AND (consumed_amount > (0)::numeric)) OR ((reserved_quantity IS NOT NULL) AND (consumed_quantity > (0)::numeric))))),
    CONSTRAINT short_collateral_policy_required CHECK (((resource_type <> 'SHORT_COLLATERAL_CASH'::trading.reservation_resource_type) OR (short_risk_policy_id IS NOT NULL))),
    CONSTRAINT short_collateral_reservation_evidence_required CHECK (((resource_type <> 'SHORT_COLLATERAL_CASH'::trading.reservation_resource_type) OR ((currency_code IS NOT NULL) AND (instrument_id IS NOT NULL) AND (reserved_amount IS NOT NULL)))),
    CONSTRAINT short_policy_only_for_collateral CHECK (((resource_type = 'SHORT_COLLATERAL_CASH'::trading.reservation_resource_type) OR (short_risk_policy_id IS NULL)))
);


--
-- Name: TABLE resource_reservations; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.resource_reservations IS '파티션·Flow 주문 의도별 자원을 나타내는 mutable 현재 Projection. ACTIVE 상태에서는 소비·해제가 모두 0이다. 전량 Fill 시 한 번만 SETTLED로 전환해 실제 사용액을 소비하고 Buying Power 완충액·잔액을 동시에 해제한다. 취소·만료·거절·replacement 시 전액 RELEASED다. 금액·수량 모두 최종 consumed + released = reserved를 행 CHECK와 사건 합계 지연 트리거로 이중 강제한다.';


--
-- Name: COLUMN resource_reservations.reservation_key; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON COLUMN trading.resource_reservations.reservation_key IS '의도·자원종류·통화 또는 종목을 정규화한 null 없는 멱등 키.';


--
-- Name: short_borrow_fee_accruals; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.short_borrow_fee_accruals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    position_lot_id uuid NOT NULL,
    bot_event_id uuid NOT NULL,
    short_borrow_fee_policy_id uuid NOT NULL,
    ledger_transaction_id uuid NOT NULL,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone NOT NULL,
    annual_fee_rate_bps numeric(12,6) NOT NULL,
    day_count_basis character varying(20) NOT NULL,
    fee_basis_amount numeric(24,8) NOT NULL,
    accrued_fee_amount numeric(24,8) NOT NULL,
    calculation_hash character varying(128) NOT NULL,
    CONSTRAINT short_borrow_fee_amount_nonnegative CHECK ((accrued_fee_amount >= (0)::numeric)),
    CONSTRAINT short_borrow_fee_basis_nonnegative CHECK ((fee_basis_amount >= (0)::numeric)),
    CONSTRAINT short_borrow_fee_period_valid CHECK ((period_end > period_start)),
    CONSTRAINT short_borrow_fee_rate_nonnegative CHECK ((annual_fee_rate_bps >= (0)::numeric))
);


--
-- Name: TABLE short_borrow_fee_accruals; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.short_borrow_fee_accruals IS '열린 가상 SHORT lot에 플랫폼 고정 연간 대차료를 기간별로 추가 전용 계산하고 공식 원장과 1:1 연결한다. 실제 대차시장 금리가 아니며 policy id, 적용 bps, day-count와 계산 해시를 고정한다. PostgreSQL 마이그레이션은 같은 lot의 비용 기간이 겹치지 않도록 exclusion constraint를 둔다.';


--
-- Name: short_borrow_fee_policy_versions; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.short_borrow_fee_policy_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    policy_code character varying(80) NOT NULL,
    version character varying(40) NOT NULL,
    annual_fee_rate_bps numeric(12,6) NOT NULL,
    day_count_basis character varying(20) NOT NULL,
    calculation_rules_version character varying(80) NOT NULL,
    rules_hash character varying(128) NOT NULL,
    effective_from timestamp with time zone NOT NULL,
    effective_to timestamp with time zone,
    published_at timestamp with time zone NOT NULL,
    CONSTRAINT short_borrow_fee_policy_effective_range CHECK (((effective_to IS NULL) OR (effective_to > effective_from))),
    CONSTRAINT short_borrow_fee_rate_nonnegative CHECK ((annual_fee_rate_bps >= (0)::numeric))
);


--
-- Name: TABLE short_borrow_fee_policy_versions; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.short_borrow_fee_policy_versions IS '실제 대차시장의 변동 금리가 아니라 플랫폼이 모든 가상 SHORT lot에 일관되게 적용하는 고정 연간 보유 비용 정책. 정확한 bps는 승인된 정책 버전으로만 도입하고 과거 비용 계산은 당시 policy id를 고정한다.';


--
-- Name: COLUMN short_borrow_fee_policy_versions.day_count_basis; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON COLUMN trading.short_borrow_fee_policy_versions.day_count_basis IS 'ACT_365 등 승인된 연환산 기준.';


--
-- Name: short_risk_policy_versions; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.short_risk_policy_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    policy_code character varying(80) NOT NULL,
    version character varying(40) NOT NULL,
    rules_document jsonb NOT NULL,
    rules_hash character varying(128) NOT NULL,
    effective_from timestamp with time zone NOT NULL,
    effective_to timestamp with time zone,
    published_at timestamp with time zone NOT NULL,
    CONSTRAINT short_risk_policy_effective_range CHECK (((effective_to IS NULL) OR (effective_to > effective_from)))
);


--
-- Name: TABLE short_risk_policy_versions; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.short_risk_policy_versions IS '가상 SHORT 포지션의 최초·유지 담보, 최대 노출·손실, Regulation SHO Rule 201 가격 제한과 시스템 청산 기준을 고정하는 불변 플랫폼 버전. 실제 주식 차입, 대여 가능 수량과 대여기관 회수는 모델링하지 않는다. 미결정 수치는 rules_document의 승인된 새 버전으로만 도입한다.';


--
-- Name: short_trade_checks; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.short_trade_checks (
    intent_id uuid NOT NULL,
    short_risk_policy_id uuid NOT NULL,
    assessed_at timestamp with time zone NOT NULL,
    reference_price numeric(24,8) NOT NULL,
    projected_short_quantity numeric(28,8) NOT NULL,
    projected_exposure_amount numeric(24,8) NOT NULL,
    required_initial_collateral_amount numeric(24,8) NOT NULL,
    required_maintenance_collateral_amount numeric(24,8) NOT NULL,
    rule_201_triggered boolean NOT NULL,
    rule_201_triggered_at timestamp with time zone,
    prior_regular_close_price numeric(24,8) NOT NULL,
    national_best_bid_price numeric(24,8) NOT NULL,
    minimum_permitted_short_price numeric(24,8),
    price_rule_observed_at timestamp with time zone NOT NULL,
    price_rule_market_hash character varying(128) NOT NULL,
    liquidation_reference_price numeric(24,8),
    approved boolean NOT NULL,
    decision_reason_code character varying(80) NOT NULL,
    evidence_hash character varying(128) NOT NULL,
    CONSTRAINT short_check_exposure_positive CHECK ((projected_exposure_amount > (0)::numeric)),
    CONSTRAINT short_check_initial_collateral_nonnegative CHECK ((required_initial_collateral_amount >= (0)::numeric)),
    CONSTRAINT short_check_initial_not_below_maintenance CHECK ((required_initial_collateral_amount >= required_maintenance_collateral_amount)),
    CONSTRAINT short_check_liquidation_price_positive CHECK (((liquidation_reference_price IS NULL) OR (liquidation_reference_price > (0)::numeric))),
    CONSTRAINT short_check_maintenance_collateral_nonnegative CHECK ((required_maintenance_collateral_amount >= (0)::numeric)),
    CONSTRAINT short_check_nbb_positive CHECK ((national_best_bid_price > (0)::numeric)),
    CONSTRAINT short_check_no_rule_201_evidence_when_inactive CHECK ((rule_201_triggered OR ((rule_201_triggered_at IS NULL) AND (minimum_permitted_short_price IS NULL)))),
    CONSTRAINT short_check_prior_close_positive CHECK ((prior_regular_close_price > (0)::numeric)),
    CONSTRAINT short_check_quantity_positive CHECK ((projected_short_quantity > (0)::numeric)),
    CONSTRAINT short_check_reference_price_positive CHECK ((reference_price > (0)::numeric)),
    CONSTRAINT short_check_rule_201_evidence_required CHECK (((NOT rule_201_triggered) OR ((rule_201_triggered_at IS NOT NULL) AND (minimum_permitted_short_price > national_best_bid_price))))
);


--
-- Name: TABLE short_trade_checks; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.short_trade_checks IS 'OPEN_SHORT 의도 승인에 사용한 가상 Short 노출, 최초·유지 담보, Rule 201 가격 제한과 청산 기준의 불변 판단 증적. 전일 정규장 종가 대비 장중 10% 이상 하락해 Rule 201이 발동하면 유효한 national best bid보다 높은 가격에서만 가상 공매도 Fill을 허용하며, 고정 매도 슬리피지를 적용한 Fill 가격도 이 조건을 만족해야 한다. 실제 주식 차입, 대여 가능 수량과 대여기관 회수는 판단하거나 저장하지 않는다.';


--
-- Name: system_close_actions; Type: TABLE; Schema: trading; Owner: -
--

CREATE TABLE trading.system_close_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bot_id uuid NOT NULL,
    partition_id uuid NOT NULL,
    flow_id uuid NOT NULL,
    instrument_id uuid NOT NULL,
    source_event_id uuid NOT NULL,
    reason_type trading.system_close_reason NOT NULL,
    requested_quantity numeric(28,8) NOT NULL,
    generated_intent_id uuid NOT NULL,
    reason_document jsonb NOT NULL,
    calculation_hash character varying(128) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    CONSTRAINT system_close_quantity_positive CHECK ((requested_quantity > (0)::numeric))
);


--
-- Name: TABLE system_close_actions; Type: COMMENT; Schema: trading; Owner: -
--

COMMENT ON TABLE trading.system_close_actions IS '가상 Position의 위험 한도 위반, Bot 중단, 대회 종료 또는 데이터 무결성 차단에 따라 플랫폼이 생성한 강제 청산 근거. 실제 대여기관 회수 사건은 만들지 않는다. 데이터 무결성 차단은 청산 필요성을 기록하되 유효한 최신 가격 전에는 Fill을 만들지 않는다. 사용자 Flow 판단과 구분하며 생성된 SYSTEM_* 주문 의도부터 파티션 전용 Order·전량 Fill·원장까지 동일 경로로 추적한다.';


--
-- Data for Name: detail_manifests; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.detail_manifests (id, run_id, object_id, record_type, week_start_date, period_start, period_end, part_number, row_count, schema_version, source_set_hash, supersedes_manifest_id, detail_hash, created_at) FROM stdin;
\.


--
-- Data for Name: execution_policy_versions; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.execution_policy_versions (version, policy_artifact_hash, policy_document, locked_at, retired_at) FROM stdin;
\.


--
-- Data for Name: failure_condition_counts; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.failure_condition_counts (id, monthly_summary_id, flow_or_branch_key, first_failure_condition_key, occurrence_count) FROM stdin;
\.


--
-- Data for Name: input_bundles; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.input_bundles (id, run_id, bundle_hash, as_of_at, locked_at) FROM stdin;
\.


--
-- Data for Name: input_datasets; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.input_datasets (input_bundle_id, dataset_manifest_id, purpose_code, locked_dataset_hash) FROM stdin;
\.


--
-- Data for Name: input_feature_materializations; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.input_feature_materializations (input_bundle_id, feature_materialization_id, locked_result_hash) FROM stdin;
\.


--
-- Data for Name: legacy_execution_policy_mappings; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.legacy_execution_policy_mappings (run_id, lane, message_id, canonical_payload_hash, aggregate_sequence, execution_policy_version, idempotency_scope, pinned_policy_artifact_hash, reviewed_by, reviewed_at) FROM stdin;
\.


--
-- Data for Name: monthly_judgment_summaries; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.monthly_judgment_summaries (id, run_id, et_year_month, evaluation_count, active_branch_count, trade_event_count, data_gap_count, triggered_count, rejected_count, summary_document, summary_hash) FROM stdin;
\.


--
-- Data for Name: performance_summaries; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.performance_summaries (run_id, metric_catalog_version, metrics_document, calculation_rules_version, source_set_hash, input_hash, result_hash, calculated_at) FROM stdin;
\.


--
-- Data for Name: run_attempts; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.run_attempts (id, run_id, attempt_number, worker_execution_key, status, started_at, completed_at, failure_code, claim_token, worker_id, claimed_at, claim_expires_at, last_heartbeat_at, previous_attempt_id, terminal_reason_code) FROM stdin;
\.


--
-- Data for Name: run_input_pins; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.run_input_pins (run_id, input_bundle_id, input_bundle_fingerprint, input_contract_version, compiled_plan_checksum, strategy_snapshot_hash, execution_policy_version, pinned_at) FROM stdin;
\.


--
-- Data for Name: runs; Type: TABLE DATA; Schema: backtest; Owner: -
--

COPY backtest.runs (id, bot_id, owner_account_id, configuration_hash, status, evaluation_start, evaluation_end, initial_cash_amount, market_rules_version, accounting_rules_version, precision_rules_version, fee_policy_id, slippage_rate_bps, buying_power_buffer_policy_id, idempotency_key, queued_at, started_at, completed_at, failure_code, result_hash, owner_anonymized_at, lane, message_id, canonical_payload_hash, aggregate_sequence, execution_policy_version, idempotency_scope, cancellation_requested_at, cancellation_reason_code, cancelled_at, result_manifest_id, retryable, missing_requirements) FROM stdin;
\.


--
-- Data for Name: bot_events; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.bot_events (id, bot_id, event_sequence, event_type, event_schema_version, causation_event_id, correlation_id, idempotency_key, occurred_at, received_at, committed_at, summary_document, market_dataset_manifest_id, evidence_object_id) FROM stdin;
\.


--
-- Data for Name: bot_partitions; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.bot_partitions (id, bot_id, name, description, budget_cap_bps, position_x, position_y, configuration_hash, edit_sequence, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: bots; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.bots (id, owner_account_id, mode, name, lifecycle_status, lifecycle_changed_at, execution_blocked_at, execution_block_reason_code, execution_block_event_id, created_at, execution_eligible_from, started_at, stop_requested_at, stopped_at, stop_reason_code, archived_at, deleted_at, edit_sequence, updated_at, owner_anonymized_at) FROM stdin;
\.


--
-- Data for Name: continuation_deadlines; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.continuation_deadlines (bot_id, due_at, last_renewed_at, renewal_sequence, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: evaluation_runs; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.evaluation_runs (id, bot_id, partition_id, flow_id, trigger_event_id, result_event_id, feature_snapshot_batch_id, feature_snapshot_key, feature_snapshot_hash, status, attempt_count, lease_expires_at, input_state_hash, input_market_hash, candidate_set_hash, candidate_count, state_change_count, result_hash, summary_document, queued_at, started_at, completed_at, failure_code) FROM stdin;
\.


--
-- Data for Name: flow_feature_requirements; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.flow_feature_requirements (flow_id, instrument_id, feature_definition_id) FROM stdin;
\.


--
-- Data for Name: flow_instruments; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.flow_instruments (flow_id, instrument_id) FROM stdin;
\.


--
-- Data for Name: flow_time_triggers; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.flow_time_triggers (flow_id, trigger_type, schedule_key) FROM stdin;
\.


--
-- Data for Name: flows; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.flows (id, partition_id, name, description, element_catalog_version_id, compiled_flow_plan_id, position_x, position_y, semantic_document, layout_document, layout_schema_version, semantic_hash, layout_hash, configuration_hash, edit_sequence, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: launch_configurations; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.launch_configurations (bot_id, initial_cash_amount, currency_code, broker_rules_version, accounting_rules_version, precision_rules_version, fee_policy_id, slippage_rate_bps, buying_power_buffer_policy_id, candidate_conflict_policy, configuration_hash) FROM stdin;
\.


--
-- Data for Name: launch_contract_plans; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.launch_contract_plans (bot_id, contract_version, plan_schema_version, plan_checksum, plan_document, created_at) FROM stdin;
\.


--
-- Data for Name: launch_snapshots; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.launch_snapshots (bot_id, snapshot_schema_version, semantic_snapshot, presentation_snapshot, semantic_hash, presentation_hash, snapshot_hash, created_at) FROM stdin;
\.


--
-- Data for Name: runtime_state_changes; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.runtime_state_changes (bot_id, bot_event_id, runtime_state_value_id, previous_value_hash, new_value, new_value_hash, change_reason_code) FROM stdin;
\.


--
-- Data for Name: runtime_state_values; Type: TABLE DATA; Schema: bot; Owner: -
--

COPY bot.runtime_state_values (id, bot_id, partition_id, flow_id, instrument_id, element_instance_key, state_definition_key, value_type, current_value, last_event_sequence, updated_at) FROM stdin;
\.


--
-- Data for Name: backtest_aggregate_results; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.backtest_aggregate_results (id, participation_id, evaluation_plan_room_id, scoring_template_version_id, weighted_return_pct, weighted_sharpe_ratio, weighted_max_drawdown_pct, worst_period_max_drawdown_pct, final_score, metrics_document, period_result_set_hash, calculation_rules_version, aggregate_hash, calculated_at, verified_at, published_at) FROM stdin;
\.


--
-- Data for Name: backtest_evaluation_periods; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.backtest_evaluation_periods (id, evaluation_plan_room_id, period_sequence, evaluation_start, evaluation_end, importance_weight, input_set_hash) FROM stdin;
\.


--
-- Data for Name: backtest_evaluation_plans; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.backtest_evaluation_plans (room_id, plan_version, period_count, plan_hash, commitment_hash, commitment_nonce_ciphertext, nonce_key_version, locked_at, disclosed_at) FROM stdin;
\.


--
-- Data for Name: backtest_period_datasets; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.backtest_period_datasets (evaluation_period_id, dataset_manifest_id, purpose_code, locked_dataset_hash) FROM stdin;
\.


--
-- Data for Name: backtest_period_feature_materializations; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.backtest_period_feature_materializations (evaluation_period_id, feature_materialization_id, locked_result_hash) FROM stdin;
\.


--
-- Data for Name: backtest_period_runs; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.backtest_period_runs (participation_id, evaluation_period_id, run_id, verified_at, verification_failure_code, locked_result_hash) FROM stdin;
\.


--
-- Data for Name: leaderboard_entries; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.leaderboard_entries (snapshot_id, participation_id, performance_snapshot_id, backtest_aggregate_result_id, rank, is_joint_rank, eligibility_status, eligibility_reason_code, score, tie_break_document, calculation_document) FROM stdin;
\.


--
-- Data for Name: leaderboard_snapshots; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.leaderboard_snapshots (id, room_id, scoring_template_version_id, cutoff_at, status, result_hash, created_at) FROM stdin;
\.


--
-- Data for Name: live_evaluation_segments; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.live_evaluation_segments (id, participation_id, segment_type, starts_at, ends_at, start_event_sequence, end_event_sequence, initial_state_hash, final_state_hash, source_set_hash, virtual_liquidation_document, finalized_at) FROM stdin;
\.


--
-- Data for Name: live_room_rules; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.live_room_rules (room_id, stopped_bot_slot_policy, minimum_operation_seconds, minimum_fill_count) FROM stdin;
\.


--
-- Data for Name: participation_events; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.participation_events (id, participation_id, event_sequence, event_type, reason_code, occurred_at, payload_document) FROM stdin;
\.


--
-- Data for Name: participations; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.participations (id, room_id, bot_id, owner_account_id, anonymous_alias, status, joined_at, evaluation_started_at, evaluation_finished_at, evaluation_failure_code, withdrawn_at, withdrawal_reason_code, expelled_at, expulsion_reason_code, post_room_action, action_recorded_at, action_locked_at, owner_anonymized_at) FROM stdin;
\.


--
-- Data for Name: room_evaluation_account_results; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.room_evaluation_account_results (request_message_id, result_message_id, participation_id, bot_id, evaluation_segment_id, result_type, producer_idempotency_key, request_payload_hash, result_payload_hash, payload_document, received_at, applied_at, failure_code) FROM stdin;
\.


--
-- Data for Name: room_events; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.room_events (id, room_id, event_sequence, event_type, resulting_status, reason_code, occurred_at, payload_document) FROM stdin;
\.


--
-- Data for Name: room_final_access_grants; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.room_final_access_grants (room_id, account_id, snapshot_id, eligibility_basis, granted_at) FROM stdin;
\.


--
-- Data for Name: room_invitations; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.room_invitations (id, room_id, issued_by_account_id, credential_type, credential_digest, issued_at, expires_at, revoked_at, revocation_reason_code) FROM stdin;
\.


--
-- Data for Name: room_rules; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.room_rules (room_id, scoring_template_version_id, initial_cash_amount, currency_code, bot_participation_limit, per_account_bot_limit, eligibility_document, market_scope_document, scoring_parameters, fee_policy_id, slippage_rate_bps, buying_power_buffer_policy_id, precision_rules_version, rules_hash, locked_at) FROM stdin;
\.


--
-- Data for Name: room_schedules; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.room_schedules (room_id, recruitment_opens_at, participation_opens_at, evaluation_starts_at, participation_closes_at, evaluation_ends_at, finalization_deadline_at, timezone_name) FROM stdin;
\.


--
-- Data for Name: rooms; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.rooms (id, competition_type, organizer_type, creator_account_id, created_by_operator_id, name, access_type, status, created_at, ended_at, invalidated_at, invalidation_reason_code, creator_anonymized_at) FROM stdin;
\.


--
-- Data for Name: scoring_template_versions; Type: TABLE DATA; Schema: competition; Owner: -
--

COPY competition.scoring_template_versions (id, template_code, version, rules_document, rules_hash, published_at, retired_at) FROM stdin;
\.


--
-- Data for Name: account_closure_readiness; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_closure_readiness (correlation_id, generation, account_id, domain, status, reason_code, evidence, observed_at) FROM stdin;
\.


--
-- Data for Name: account_closure_runs; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_closure_runs (correlation_id, account_id, lifecycle_version, cancellation_deadline_at, generation, started_at, last_checked_at, closed_at) FROM stdin;
\.


--
-- Data for Name: account_consents; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_consents (id, account_id, policy_document_id, decision, supersedes_consent_id, recorded_at) FROM stdin;
\.


--
-- Data for Name: account_emails; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_emails (account_id, email_ciphertext, email_lookup_hmac, email_lookup_key_version, encryption_key_version, status, verified_at, created_at, revoked_at) FROM stdin;
\.


--
-- Data for Name: account_identifier_quarantines; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_identifier_quarantines (id, account_id, lifecycle_event_id, identifier_kind, provider_code, identifier_fingerprint, fingerprint_key_version, quarantined_at, reuse_eligible_at, released_at, release_reason_code, created_at) FROM stdin;
\.


--
-- Data for Name: account_legal_holds; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_legal_holds (id, account_id, data_category, status, blocks_identifier_reuse, basis_reference, applied_by, applied_at, released_by, released_at, created_at) FROM stdin;
\.


--
-- Data for Name: account_lifecycle_command_receipts; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_lifecycle_command_receipts (account_id, command_type, idempotency_key, request_hash, response_status, response_code, response_document, lifecycle_event_id, completed_at) FROM stdin;
\.


--
-- Data for Name: account_lifecycle_events; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_lifecycle_events (id, account_id, event_sequence, previous_status, new_status, reason_code, occurred_at, previous_event_id, lifecycle_version, command_type, actor_type, actor_id, correlation_id, idempotency_key, request_hash, retention_policy_version, cancellation_deadline_at, dormancy_basis_at) FROM stdin;
\.


--
-- Data for Name: account_preferences; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_preferences (account_id, language_code, timezone_name, created_at, updated_at, theme_preference) FROM stdin;
\.


--
-- Data for Name: account_retention_execution_attempts; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_retention_execution_attempts (id, obligation_id, account_id, data_category, correlation_id, legal_hold_id, outcome, failure_code, evidence, occurred_at) FROM stdin;
\.


--
-- Data for Name: account_retention_obligations; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_retention_obligations (id, account_id, lifecycle_event_id, retention_policy_version, data_category, disposition, retention_days, retain_until, status, failure_code, completed_at, created_at) FROM stdin;
\.


--
-- Data for Name: account_retention_policy_proposals; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_retention_policy_proposals (proposal_key, canonical_status, proposal_document, product_approver_subject, product_approval_evidence, product_approved_at, recorded_at) FROM stdin;
A12-2026-08-02	PROPOSED	{"profile": {"days": 0, "disposition": "ANONYMIZE"}, "botStrategy": {"days": 30, "disposition": "DELETE"}, "competition": {"days": 365, "disposition": "ANONYMIZE"}, "emailOidcBinding": {"days": 30, "disposition": "RELEASE"}, "retentionStartsAt": "CLOSED", "generalOperationsLog": {"days": 365, "disposition": "DELETE"}, "consentTradingSecurityAudit": {"days": 1825, "disposition": "RETAIN"}}	user:kcrmin	https://github.com/Idea2Strategy/Idea2Strategy-backend/issues/127#issuecomment-5156817219	2026-08-02 09:20:30+00	2026-08-13 06:27:32.780641+00
\.


--
-- Data for Name: account_retention_policy_rules; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_retention_policy_rules (policy_version, data_category, disposition, retention_days, legal_basis_code, created_at) FROM stdin;
A12-2026-08-02	PROFILE	ANONYMIZE	0	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	CONTACT_IDENTIFIER	DELETE	30	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	AUTH_CREDENTIAL	DELETE	0	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	POLICY_CONSENT	RETAIN	1825	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	ACCOUNT_LIFECYCLE_AUDIT	RETAIN	1825	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	TRADING_FINANCIAL_RECORD	RETAIN	1825	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	BOT_STRATEGY_EVALUATION	RETAIN	\N	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	BOT_STRATEGY_PRIVATE_DATA	DELETE	30	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	COMPETITION_RESULT_EVIDENCE	ANONYMIZE	365	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
A12-2026-08-02	OPERATIONS_DELIVERY_LOG	DELETE	365	A12-PRODUCT-APPROVAL	2026-08-13 06:27:32.941642+00
\.


--
-- Data for Name: account_retention_policy_versions; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_retention_policy_versions (version, effective_from, approved_at, approved_by, basis_reference, created_at) FROM stdin;
A12-2026-08-02	2026-08-02 10:54:25+00	2026-08-02 09:20:30+00	user:kcrmin	https://github.com/Idea2Strategy/Idea2Strategy/pull/125	2026-08-13 06:27:32.941642+00
\.


--
-- Data for Name: account_sanction_command_receipts; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_sanction_command_receipts (account_id, command_type, idempotency_key, request_hash, sanction_id, correlation_id, response_document, completed_at) FROM stdin;
\.


--
-- Data for Name: account_sanction_events; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_sanction_events (id, sanction_id, event_sequence, event_type, actor_operator_id, reason_code, evidence_object_id, occurred_at, account_id, correlation_id, previous_status, resulting_status) FROM stdin;
\.


--
-- Data for Name: account_sanction_heads; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_sanction_heads (account_id, aggregate_version, updated_at) FROM stdin;
\.


--
-- Data for Name: account_sanctions; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_sanctions (id, account_id, sanction_type, status, reason_code, applied_by_operator_id, applied_at, effective_at, expires_at, source_case_id, status_changed_at, public_reference) FROM stdin;
\.


--
-- Data for Name: account_security_states; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.account_security_states (account_id, auth_epoch, credentials_revoked_before, updated_at) FROM stdin;
\.


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.accounts (id, lifecycle_status, status_changed_at, created_at, lifecycle_version, last_lifecycle_event_id, last_successful_auth_at, dormant_at, withdrawal_requested_at, cancellation_deadline_at, closing_previous_status, closed_at, anonymized_at) FROM stdin;
\.


--
-- Data for Name: auth_providers; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.auth_providers (id, code, display_name, provider_type, issuer, is_active, created_at, updated_at) FROM stdin;
1	PASSWORD	Email and password	PASSWORD	\N	t	2026-08-13 06:27:32.364815+00	2026-08-13 06:27:32.364815+00
3	GOOGLE	Google	OIDC	https://accounts.google.com	t	2026-08-13 06:27:33.965822+00	2026-08-13 06:27:33.965822+00
\.


--
-- Data for Name: authentication_events; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.authentication_events (id, account_id, event_sequence, event_type, subject_login_identity_id, previous_login_identity_id, new_login_identity_id, actor_type, actor_id, reason_code, correlation_id, idempotency_key, occurred_at) FROM stdin;
\.


--
-- Data for Name: delegated_authorization_events; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.delegated_authorization_events (id, authorization_id, event_sequence, event_type, actor_type, actor_id, reason_code, correlation_id, idempotency_key, occurred_at, payload_document) FROM stdin;
\.


--
-- Data for Name: delegated_authorization_scopes; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.delegated_authorization_scopes (authorization_id, scope_code, granted_at) FROM stdin;
\.


--
-- Data for Name: delegated_authorization_strategy_targets; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.delegated_authorization_strategy_targets (authorization_id, strategy_id, owner_account_id_at_grant, strategy_access_epoch_at_grant, granted_at) FROM stdin;
\.


--
-- Data for Name: delegated_authorizations; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.delegated_authorizations (id, account_id, client_label, external_provider_code, status, expiry_mode, auth_epoch_at_grant, disclosure_policy_document_id, scope_set_hash, authorized_at, expires_at, revoked_at, revoke_reason_code, authorization_version, replaces_authorization_id, strategy_target_set_hash) FROM stdin;
\.


--
-- Data for Name: delegated_credentials; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.delegated_credentials (id, authorization_id, credential_type, token_digest, digest_key_version, issued_at, expires_at, last_seen_at, revoked_at, revoke_reason_code, superseded_by_credential_id) FROM stdin;
\.


--
-- Data for Name: delegated_strategy_derivations; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.delegated_strategy_derivations (id, authorization_id, credential_id, derivation_type, source_strategy_id, result_strategy_id, owner_account_id_at_creation, strategy_access_epoch_at_creation, correlation_id, idempotency_key, request_hash, created_at) FROM stdin;
\.


--
-- Data for Name: device_authorization_requests; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.device_authorization_requests (id, device_code_digest, user_code_digest, digest_key_version, client_label, status, approved_account_id, approved_login_identity_id, poll_interval_seconds, requested_at, expires_at, approved_at, consumed_at, denied_at, failed_attempt_count, last_polled_at) FROM stdin;
\.


--
-- Data for Name: email_verification_requests; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.email_verification_requests (id, account_id, token_digest, digest_key_version, requested_at, expires_at, consumed_at, revoked_at, failed_attempt_count, request_ip_prefix) FROM stdin;
\.


--
-- Data for Name: login_identities; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.login_identities (id, account_id, provider_id, provider_subject_hmac, subject_key_version, status, created_at, linked_at, activated_at, last_authenticated_at, replaced_at, disabled_at, disabled_reason_code, failed_attempt_count, last_failed_at) FROM stdin;
\.


--
-- Data for Name: oidc_step_up_nonces; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.oidc_step_up_nonces (id, provider_id, nonce_digest, digest_key_version, requested_at, expires_at, verification_attempt_count, last_verification_attempt_at, consumed_at, consumed_by_account_id) FROM stdin;
\.


--
-- Data for Name: password_credentials; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.password_credentials (login_identity_id, password_hash, hash_scheme, hash_parameters, credential_version, password_changed_at, compromised_at) FROM stdin;
\.


--
-- Data for Name: password_reset_requests; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.password_reset_requests (id, account_id, login_identity_id, auth_epoch_at_issue, credential_version_at_issue, token_digest, digest_key_version, requested_at, expires_at, consumed_at, revoked_at, failed_attempt_count, request_ip_prefix) FROM stdin;
\.


--
-- Data for Name: policy_documents; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.policy_documents (id, policy_code, version, language_code, title, content_format, content_text, content_hash, is_required, published_at, retired_at) FROM stdin;
97c3c7da-1375-42fb-8779-1c63680b3c0c	delegation.strategy-edit.disclosure	v1	ko	외부 도구에 전략 편집을 위임합니다	MARKDOWN	# 외부 도구에 전략 편집을 위임합니다\n\n이 위임을 만들면 선택한 외부 도구가 회원님을 대신해 다음을 할 수 있습니다.\n\n- 지정한 전략의 **Basic 블록을 추가·삭제·연결하고 값을 바꾸는 것**\n- (검증 범위를 함께 준 경우) 그 전략을 검증하는 것\n\n이 위임으로 **할 수 없는 것**은 다음과 같습니다.\n\n- 주문·체결, 자금 이동, 봇 실행이나 중단\n- 전략 출시\n- 지정하지 않은 다른 전략의 열람이나 편집\n- 임의 코드 실행, 외부 데이터 가져오기\n\n도구가 전략을 바꾸려면 **먼저 변경 내용을 미리보기로 제시**해야 하고, 그 미리보기와 정확히 같은 내용만 반영됩니다. 다른 내용으로 바꿔치기할 수 없습니다.\n\n이 위임에는 **만료 시각**이 있으며, 그 전에도 언제든 회수할 수 있습니다. 회수하면 즉시 효력을 잃습니다.\n\n위임 생성·사용·회수 기록은 회원님의 계정 활동에 남습니다.\n	f4654be4b6d2341d6f889031a6386789e700447bc193ab7f8016d35d1ef59743	f	2026-08-09 00:00:00+00	2026-08-09 00:00:01+00
7ab03430-d558-441c-bb82-e2644be7035d	delegation.strategy-edit.disclosure	v2	ko	외부 도구에 전략 편집을 위임합니다	MARKDOWN	# 외부 도구에 전략 편집을 위임합니다\n\n이 위임을 만들면 선택한 외부 도구가 회원님을 대신해 다음을 할 수 있습니다.\n\n- 지정한 전략에 **매수·매도 컨테이너를 만드는 것**. 컨테이너를 만들 때 매수/매도 방향, 조건을 결합하는 방식, 자금을 배분하는 방식, 거래할 종목을 함께 정합니다\n- 그 안의 **Basic 블록을 추가·삭제·연결하고 값을 바꾸는 것**\n- (검증 범위를 함께 준 경우) 그 전략을 검증하는 것\n\n즉 **빈 전략을 건네면 도구가 전략의 뼈대부터 만들 수 있습니다.**\n\n이 위임으로 **할 수 없는 것**은 다음과 같습니다.\n\n- 주문·체결, 자금 이동, 봇 실행이나 중단\n- 전략 출시\n- 지정하지 않은 다른 전략의 열람이나 편집\n- 임의 코드 실행, 외부 데이터 가져오기\n\n도구가 전략을 바꾸려면 **먼저 변경 내용을 미리보기로 제시**해야 하고, 그 미리보기와 정확히 같은 내용만 반영됩니다. 다른 내용으로 바꿔치기할 수 없습니다.\n\n이 위임에는 **만료 시각**이 있으며, 그 전에도 언제든 회수할 수 있습니다. 회수하면 즉시 효력을 잃습니다.\n\n위임 생성·사용·회수 기록은 회원님의 계정 활동에 남습니다.\n	f0ef1f915ee37b886fd34902e4225213ec6834bca327ca8c3d8e774cd819d584	f	2026-08-09 00:00:01+00	\N
\.


--
-- Data for Name: recovery_code_sets; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.recovery_code_sets (id, account_id, purpose, issued_at, revoked_at, revoke_reason_code) FROM stdin;
\.


--
-- Data for Name: recovery_codes; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.recovery_codes (id, recovery_code_set_id, code_digest, digest_key_version, used_at) FROM stdin;
\.


--
-- Data for Name: refresh_token_families; Type: TABLE DATA; Schema: identity; Owner: -
--

COPY identity.refresh_token_families (id, account_id, authenticated_by_login_identity_id, auth_epoch_at_issue, credential_version_at_issue, current_token_digest, digest_key_version, issued_at, last_rotated_at, expires_at, revoked_at, revoke_reason_code) FROM stdin;
\.


--
-- Data for Name: corporate_actions; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.corporate_actions (id, instrument_id, source_manifest_id, provider_event_key, action_type, effective_at, terms_document, terms_hash, supersedes_action_id, created_at) FROM stdin;
\.


--
-- Data for Name: dataset_lineage; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.dataset_lineage (derived_manifest_id, source_manifest_id, relation_type) FROM stdin;
\.


--
-- Data for Name: dataset_manifests; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.dataset_manifests (id, feed_id, instrument_id, data_layer, resolution, revision_number, status, period_start, period_end, schema_version, dataset_hash, supersedes_manifest_id, created_at, available_at, object_count) FROM stdin;
\.


--
-- Data for Name: dataset_object_lineage; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.dataset_object_lineage (derived_dataset_object_id, source_dataset_object_id, pipeline_run_id, relation_type, created_at) FROM stdin;
\.


--
-- Data for Name: dataset_objects; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.dataset_objects (id, dataset_manifest_id, object_id, object_kind, partition_granularity, partition_start, partition_end, period_start, period_end, shard_key, part_number, row_count, min_instrument_id, max_instrument_id) FROM stdin;
\.


--
-- Data for Name: feature_definitions; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.feature_definitions (id, element_catalog_version_id, feature_code, calculator_version, resolution, normalized_parameters, output_value_type, required_history_points, definition_hash, created_at) FROM stdin;
0f1b0000-0000-4000-8000-000000000001	0f1a0000-0000-4000-8000-000000000001	RSI_14	rsi:1.0.0	1m	{"method": "SIMPLE_AVERAGE_BOUNDED_WINDOW", "period": 14, "calendar_id": "XNYS", "price_field": "close", "input_adjustment": "SPLIT_DIVIDEND_ADJUSTED"}	NUMBER	15	sha256:1a7c3e5b9d2f4068a1c3e5b7d9f20416283a5c7e9b1d3f50627496a8c0e2b4d6	2026-08-04 00:00:00+00
4b1c6801-0259-5176-a857-0e5ea923d898	0f4a0000-0000-4000-8000-000000000001	RSI_14	rsi:1.0.0	30m	{"method": "SIMPLE_AVERAGE_BOUNDED_WINDOW", "period": 14, "calendar_id": "XNYS", "price_field": "close", "input_adjustment": "SPLIT_DIVIDEND_ADJUSTED"}	NUMBER	15	363f534dc77c6af0ebfe58f35be4fd2aa208906b1eaa36b550b17e9acb8692e4	2026-08-08 12:01:00+00
2e18c093-5d4e-5d9a-bd22-b7e5679f1a3e	0f4a0000-0000-4000-8000-000000000001	RSI_14	rsi:1.0.0	1h	{"method": "SIMPLE_AVERAGE_BOUNDED_WINDOW", "period": 14, "calendar_id": "XNYS", "price_field": "close", "input_adjustment": "SPLIT_DIVIDEND_ADJUSTED"}	NUMBER	15	9b8512c0502ca80e1804711ac624eb4a3b4e294a875dac2364e3510e284cc8b9	2026-08-08 12:01:00+00
1b2785bd-20f0-50a2-ae96-6a1f7bad74b9	0f4a0000-0000-4000-8000-000000000001	RSI_14	rsi:1.0.0	4h	{"method": "SIMPLE_AVERAGE_BOUNDED_WINDOW", "period": 14, "calendar_id": "XNYS", "price_field": "close", "input_adjustment": "SPLIT_DIVIDEND_ADJUSTED"}	NUMBER	15	da3aff028a1fdef861abb1d68852e2ba3a91ed3917f7c7196e2d43ef48176b2c	2026-08-08 12:01:00+00
eddfb2d4-8586-5260-8fc9-9c8125990270	0f4a0000-0000-4000-8000-000000000001	RSI_14	rsi:1.0.0	1d	{"method": "SIMPLE_AVERAGE_BOUNDED_WINDOW", "period": 14, "calendar_id": "XNYS", "price_field": "close", "input_adjustment": "SPLIT_DIVIDEND_ADJUSTED"}	NUMBER	15	0cf646eb9cacf5826d26f7dcb982bf7cec9213cc438b99716ac47883aa04ba04	2026-08-08 12:01:00+00
\.


--
-- Data for Name: feature_materializations; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.feature_materializations (id, feature_definition_id, instrument_id, pipeline_run_id, input_dataset_set_hash, period_start, period_end, source_watermark, output_dataset_manifest_id, result_hash, status, available_at, created_at) FROM stdin;
\.


--
-- Data for Name: feature_snapshot_batches; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.feature_snapshot_batches (id, feature_set_hash, input_market_set_hash, source_start_watermark, source_end_watermark, period_start, period_end, snapshot_object_id, batch_hash, row_count, status, idempotency_key, available_at, created_at) FROM stdin;
\.


--
-- Data for Name: feeds; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.feeds (id, provider_id, code, data_kind, resolution, timezone_name, feed_version, created_at, retired_at) FROM stdin;
063f8f27-5c6a-5348-b2bb-abc3c634149c	b9146ed9-dbb0-5323-93e3-8518f3851236	FEATURE_RSI_14_1M_RSI_1_0_0	FEATURE_SERIES	1m	UTC	rsi-1.0.0+feature-series.parquet.v1	2026-08-06 12:00:00+00	\N
57794d8c-2254-53e4-966e-44f97edd9e6a	b9146ed9-dbb0-5323-93e3-8518f3851236	FEATURE_RSI_14_30M_RSI_1_0_0	FEATURE_SERIES	30m	UTC	rsi-1.0.0+feature-series.parquet.v1	2026-08-08 12:01:00+00	\N
28012549-4f45-56d3-8bb6-329e4c7a9d77	b9146ed9-dbb0-5323-93e3-8518f3851236	FEATURE_RSI_14_1H_RSI_1_0_0	FEATURE_SERIES	1h	UTC	rsi-1.0.0+feature-series.parquet.v1	2026-08-08 12:01:00+00	\N
e1d7d508-aaf1-5ae9-8098-c4af870f6fa4	b9146ed9-dbb0-5323-93e3-8518f3851236	FEATURE_RSI_14_4H_RSI_1_0_0	FEATURE_SERIES	4h	UTC	rsi-1.0.0+feature-series.parquet.v1	2026-08-08 12:01:00+00	\N
6d2647f8-5caf-55ee-8821-869dc693f68a	b9146ed9-dbb0-5323-93e3-8518f3851236	FEATURE_RSI_14_1D_RSI_1_0_0	FEATURE_SERIES	1d	UTC	rsi-1.0.0+feature-series.parquet.v1	2026-08-08 12:01:00+00	\N
\.


--
-- Data for Name: instrument_symbols; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.instrument_symbols (id, instrument_id, exchange_mic, symbol, effective_from, effective_to) FROM stdin;
\.


--
-- Data for Name: instruments; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.instruments (id, asset_type, primary_exchange_mic, currency_code, provider_reference, listed_at, delisted_at, created_at) FROM stdin;
\.


--
-- Data for Name: pipeline_runs; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.pipeline_runs (id, pipeline_code, pipeline_version, idempotency_key, status, input_hash, output_hash, started_at, completed_at, failure_code) FROM stdin;
\.


--
-- Data for Name: providers; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.providers (id, code, display_name, rights_version, status, created_at) FROM stdin;
b9146ed9-dbb0-5323-93e3-8518f3851236	IDEA2STRATEGY_INTERNAL	Idea2Strategy Derived Data	internal-derived-v1	ACTIVE	2026-08-06 12:00:00+00
\.


--
-- Data for Name: quality_incidents; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.quality_incidents (id, dataset_manifest_id, instrument_id, severity, incident_code, period_start, period_end, status, evidence_object_id, detected_at, resolved_at) FROM stdin;
\.


--
-- Data for Name: stream_watermarks; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.stream_watermarks (feed_id, last_source_event_at, last_ingested_at, last_sequence, updated_at) FROM stdin;
\.


--
-- Data for Name: trading_sessions; Type: TABLE DATA; Schema: market_data; Owner: -
--

COPY market_data.trading_sessions (id, exchange_mic, session_date, opens_at, closes_at, session_type, calendar_version) FROM stdin;
\.


--
-- Data for Name: account_email_notification_preferences; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.account_email_notification_preferences (account_id, enabled, updated_at) FROM stdin;
\.


--
-- Data for Name: account_integrations; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.account_integrations (id, account_id, integration_code, status, freeze_requested_at, closed_at, updated_at) FROM stdin;
\.


--
-- Data for Name: audit_events; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.audit_events (id, actor_type, actor_id, delegated_authorization_id, action_type, target_domain, target_id, reason_code, correlation_id, idempotency_key, before_hash, after_hash, evidence_object_id, occurred_at, recorded_at, rbac_catalog_version, resolved_rbac_catalog_version, request_hash, decision_status, response_status, response_code, evidence_hash, request_document, response_document, before_document, after_document, evidence_document) FROM stdin;
\.


--
-- Data for Name: batch_item_attempts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.batch_item_attempts (batch_item_id, attempt_number, claim_token, worker_id, runtime_policy_version, correlation_id, claimed_at, claim_expires_at, completed_at, outcome, domain_result_code, failure_code, next_attempt_at) FROM stdin;
\.


--
-- Data for Name: batch_items; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.batch_items (id, discovered_by_run_id, category_code, source_key, source_version, due_at, replay_sequence, original_item_id, replayed_from_item_id, replay_audit_event_id, status, claim_token, claimed_by, claimed_at, claim_expires_at, attempt_count, next_attempt_at, correlation_id, first_discovered_at, completed_at, domain_result_code, terminal_failure_code) FROM stdin;
\.


--
-- Data for Name: batch_job_versions; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.batch_job_versions (job_code, job_version, status, category_set_document, content_hash, published_at, retired_at) FROM stdin;
\.


--
-- Data for Name: batch_run_checkpoints; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.batch_run_checkpoints (job_code, job_version, category_code, shard_key, cursor_due_at, cursor_source_key, last_run_id, scanned_count, updated_at) FROM stdin;
\.


--
-- Data for Name: batch_runs; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.batch_runs (id, job_code, job_version, runtime_policy_version, trigger_id, window_start, window_end, status, started_at, completed_at, discovered_count, succeeded_count, quarantined_count) FROM stdin;
\.


--
-- Data for Name: case_command_receipts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.case_command_receipts (account_id, command_type, idempotency_key, request_hash, case_id, case_event_id, response_status, response_code, response_document, completed_at) FROM stdin;
\.


--
-- Data for Name: case_deadline_receipts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.case_deadline_receipts (case_id, expected_case_version, response_deadline_at, decision_status, case_event_id, correlation_id, decided_at) FROM stdin;
\.


--
-- Data for Name: case_events; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.case_events (id, case_id, event_sequence, actor_type, actor_id, event_type, payload_document, created_at, account_id, previous_event_id, resulting_status, visibility, reason_code, correlation_id) FROM stdin;
\.


--
-- Data for Name: case_evidence_references; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.case_evidence_references (case_id, account_id, case_event_id, storage_object_id, source_domain, source_resource_id, owner_account_id, ownership_policy_version, ownership_verified_at, attached_at) FROM stdin;
\.


--
-- Data for Name: cases; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.cases (id, account_id, case_type, status, subject, created_at, closed_at, resolution_code, case_version, current_event_sequence, last_case_event_id, updated_at, assignee_operator_id, response_deadline_at, deadline_policy_version) FROM stdin;
\.


--
-- Data for Name: delivery_attempts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.delivery_attempts (id, notification_id, channel, attempt_number, status, attempted_at, completed_at, provider_message_key, failure_code, next_attempt_at, outbox_message_id, runtime_policy_version) FROM stdin;
\.


--
-- Data for Name: notification_policies; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.notification_policies (type_code, policy_version, mandatory, default_channels, active, activated_at) FROM stdin;
\.


--
-- Data for Name: notification_preferences; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.notification_preferences (id, account_id, bot_id, event_type, channel, enabled, updated_at, policy_version) FROM stdin;
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.notifications (id, account_id, bot_id, notification_type, mandatory, locale, template_version, payload_document, idempotency_key, created_at, read_at, expires_at, source_event_id, source_event_hash, policy_version, selected_channels, correlation_id) FROM stdin;
\.


--
-- Data for Name: operator_accounts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.operator_accounts (id, status, created_at, disabled_at) FROM stdin;
\.


--
-- Data for Name: operator_bootstrap_receipts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.operator_bootstrap_receipts (bootstrap_key, manifest_hash, catalog_version, operator_account_id, operator_role_assignment_id, credential_version, correlation_id, audit_event_id, applied_at) FROM stdin;
\.


--
-- Data for Name: operator_case_command_receipts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.operator_case_command_receipts (operator_id, command_type, idempotency_key, request_hash, case_id, case_event_id, decision_status, response_code, response_document, audit_document, completed_at) FROM stdin;
\.


--
-- Data for Name: operator_role_assignments; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.operator_role_assignments (id, operator_account_id, role_id, granted_by_operator_id, granted_at, expires_at, revoked_by_operator_id, revoked_at, revocation_reason_code, catalog_version) FROM stdin;
\.


--
-- Data for Name: outbox_consumer_receipts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.outbox_consumer_receipts (consumer_handler_id, outbox_message_id, producer_idempotency_key, payload_hash, status, claim_token, claimed_by, claimed_at, claim_expires_at, receive_attempt_count, first_received_at, last_received_at, completed_at, result_hash, failure_code) FROM stdin;
\.


--
-- Data for Name: outbox_delivery_attempts; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.outbox_delivery_attempts (outbox_message_id, attempt_number, claim_token, worker_id, runtime_policy_version, claimed_at, claim_expires_at, completed_at, outcome, transport_message_key, failure_code, next_attempt_at) FROM stdin;
\.


--
-- Data for Name: outbox_messages; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.outbox_messages (id, owner_domain, aggregate_id, aggregate_sequence, event_type, event_schema_version, payload_document, idempotency_key, created_at, published_at, publish_attempt_count, next_attempt_at, last_failure_code, payload_hash, producer_idempotency_key, original_message_id, replayed_from_message_id, replay_sequence, replay_audit_event_id, delivery_status, claim_token, claimed_by, claimed_at, claim_expires_at, dead_lettered_at, dead_letter_reason_code) FROM stdin;
\.


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.permissions (id, code, description, sensitivity) FROM stdin;
e3000000-0000-4000-8000-000000000001	COMPETITION_ROOM_READ	Read operator-safe official competition room state and result provenance	SENSITIVE
e3000000-0000-4000-8000-000000000002	COMPETITION_ROOM_MANAGE	Cancel or invalidate official competition rooms through audited commands	HIGH
\.


--
-- Data for Name: projection_checkpoints; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.projection_checkpoints (id, projection_name, target_store, shard_key, source_domain, last_source_sequence, last_source_time, projection_version, status, updated_at, failure_code) FROM stdin;
\.


--
-- Data for Name: rbac_catalog_permissions; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.rbac_catalog_permissions (catalog_version, permission_id, permission_status) FROM stdin;
\.


--
-- Data for Name: rbac_catalog_role_permissions; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.rbac_catalog_role_permissions (catalog_version, role_id, permission_id, delegable) FROM stdin;
\.


--
-- Data for Name: rbac_catalog_roles; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.rbac_catalog_roles (catalog_version, role_id, hierarchy_rank, role_status) FROM stdin;
\.


--
-- Data for Name: rbac_catalog_versions; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.rbac_catalog_versions (catalog_version, content_hash, status, activated_at, retired_at, created_at) FROM stdin;
\.


--
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.role_permissions (role_id, permission_id) FROM stdin;
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: operations; Owner: -
--

COPY operations.roles (id, code, hierarchy_rank, status) FROM stdin;
\.


--
-- Data for Name: bot_current_projections; Type: TABLE DATA; Schema: performance; Owner: -
--

COPY performance.bot_current_projections (bot_id, equity_amount, total_return_pct, max_drawdown_pct, sharpe_ratio, metrics_document, ledger_state_hash, position_state_hash, calculation_rules_version, last_event_sequence, projection_hash, updated_at) FROM stdin;
\.


--
-- Data for Name: bot_snapshots; Type: TABLE DATA; Schema: performance; Owner: -
--

COPY performance.bot_snapshots (id, bot_id, snapshot_type, source_event_sequence, evaluated_at, equity_amount, total_return_pct, max_drawdown_pct, sharpe_ratio, metrics_document, input_hash, calculation_rules_version, snapshot_hash, created_at) FROM stdin;
\.


--
-- Data for Name: series_manifests; Type: TABLE DATA; Schema: performance; Owner: -
--

COPY performance.series_manifests (id, bot_id, object_id, series_type, week_start_date, period_start, period_end, part_number, revision_number, row_count, schema_version, calculation_rules_version, supersedes_manifest_id, series_hash, created_at, available_at) FROM stdin;
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, status, storage_provider, bucket_name, object_key, provider_version_id, content_hash, byte_size, file_format, compression_codec, media_type, schema_version, row_count, period_start, period_end, encryption_key_ref, retention_policy_version, retention_until, legal_hold, created_at, verified_at, quarantined_at, superseded_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: compiled_flow_plans; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.compiled_flow_plans (id, element_catalog_version_id, semantic_hash, compiler_version, required_feature_set_hash, plan_document, plan_hash, created_at) FROM stdin;
\.


--
-- Data for Name: element_catalog_versions; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.element_catalog_versions (id, language_version, schema_version, catalog_version, data_requirement_version, definition_hash, published_at, retired_at) FROM stdin;
0f1a0000-0000-4000-8000-000000000001	basic/v1	basic-semantic/v1	basic-elements:2026-08-04	alpaca-sip/v1	sha256:9d5f4b1c7e2a8f6039c4b5d8e1a7f20395c8d4b6e2a9f7013c5b8d4e6a2f9017	2026-08-04 00:00:00+00	2026-08-07 13:00:00+00
0f2a0000-0000-4000-8000-000000000001	basic/v1	basic-semantic/v1	basic-elements:2026-08-07	alpaca-sip/v1	sha256:92a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301	2026-08-07 13:00:00+00	2026-08-07 15:00:00+00
0f3a0000-0000-4000-8000-000000000001	basic/v1	basic-semantic/v1	basic-elements:2026-08-08-live-bars	alpaca-sip/v1	sha256:30a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301	2026-08-07 15:00:00+00	2026-08-07 16:00:00+00
0f4a0000-0000-4000-8000-000000000001	basic/v1	basic-semantic/v1	basic-elements:2026-08-08	alpaca-sip/v1	sha256:a46b05ff472bb14f011d288900804142e385520f8c9c448b9bf4da8ea6f755da	2026-08-07 16:00:00+00	\N
\.


--
-- Data for Name: element_definitions; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.element_definitions (id, element_catalog_version_id, element_code, element_kind, parameter_schema, input_port_schema, output_port_schema, execution_contract, definition_hash) FROM stdin;
0f1c0000-0000-4000-8000-000000000001	0f1a0000-0000-4000-8000-000000000001	BASIC_RSI_READ	INDICATOR	{"type": "object", "required": ["resolution"], "properties": {"resolution": {"type": "string"}}}	{}	{"value": {"type": "number"}}	{"runtime": {"arguments": {"feature": "RSI_14", "resolution": "$resolution"}, "operation": "LOAD_FEATURE"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": ["RSI_14"], "supported": true}, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "{resolution} 봉의 RSI(14)를 확인한다"}}	sha256:2b8d4f60a3c5e7b9d1f30528496a8c0e2b4d6f81032547698ba1c3e5d7f90a24
0f1c0000-0000-4000-8000-000000000002	0f1a0000-0000-4000-8000-000000000001	BASIC_VALUE_COMPARE	CONDITION	{"type": "object", "required": ["operator", "threshold"], "properties": {"operator": {"type": "string"}, "threshold": {"type": "string"}}}	{"value": {"type": "number"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "threshold": "$threshold"}, "operation": "COMPARE"}, "backtest": {"feeds": [], "features": [], "supported": true}, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "값이 {threshold} {operator} 조건을 만족하면"}}	sha256:3c9e5071b4d6f8a0e2043619507b9d1f3052849617a3c5e7b9d1f3052849617b
0f1c0000-0000-4000-8000-000000000003	0f1a0000-0000-4000-8000-000000000001	BASIC_EQUAL_ALLOCATION_ORDER	ACTION	{"type": "object", "required": [], "properties": {}}	{"passed": {"type": "boolean"}}	{}	{"runtime": {"arguments": {"side": "$container", "orderType": "MARKET", "allocation": "EQUAL", "timeInForce": "DAY"}, "operation": "EMIT_ORDER_CANDIDATE"}, "backtest": {"feeds": [], "features": [], "supported": true}, "terminal": true, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "보유 예산을 균등 배분해 시장가로 주문한다"}}	sha256:4d0f6182c5e70921f31547208619ae2c4d6f8103254769b8a1c3e5d7f90a2436
0f2c0000-0000-4000-8000-000000000001	0f2a0000-0000-4000-8000-000000000001	BASIC_PRICE_COMPARE	CONDITION	{"type": "object", "required": ["resolution", "operator", "reference"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "reference": {"enum": ["PREVIOUS_CLOSE", "SESSION_OPEN", "AVERAGE_ENTRY_PRICE", "SMA_5", "SMA_20", "SMA_60", "HIGH_5", "HIGH_20", "HIGH_60", "LOW_5", "LOW_20", "LOW_60"], "type": "string"}, "resolution": {"type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "reference": "$reference", "resolution": "$resolution"}, "operation": "PRICE_COMPARE"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PRICE_COMPARE"}}	sha256:01a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000002	0f2a0000-0000-4000-8000-000000000001	BASIC_PRICE_CHANGE_PERCENT	CONDITION	{"type": "object", "required": ["resolution", "base", "direction", "thresholdPercent"], "properties": {"base": {"enum": ["PREVIOUS_CLOSE", "SESSION_OPEN", "AVERAGE_ENTRY_PRICE"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "resolution": {"type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"base": "$base", "direction": "$direction", "resolution": "$resolution", "thresholdPercent": "$thresholdPercent"}, "operation": "PRICE_CHANGE_PERCENT"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PRICE_CHANGE_PERCENT"}}	sha256:02a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000003	0f2a0000-0000-4000-8000-000000000001	BASIC_VOLUME_COMPARE	CONDITION	{"type": "object", "required": ["resolution", "operator", "reference", "period", "multiplier"], "properties": {"period": {"enum": ["1", "5", "20", "60"], "type": "string"}, "operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "reference": {"enum": ["PREVIOUS_VOLUME", "AVERAGE_VOLUME"], "type": "string"}, "multiplier": {"enum": ["1", "2", "3"], "type": "string"}, "resolution": {"type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "operator": "$operator", "reference": "$reference", "multiplier": "$multiplier", "resolution": "$resolution"}, "operation": "VOLUME_COMPARE"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_VOLUME_COMPARE"}}	sha256:03a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000004	0f2a0000-0000-4000-8000-000000000001	BASIC_STREAK	CONDITION	{"type": "object", "required": ["resolution", "direction", "bars"], "properties": {"bars": {"enum": ["2", "3", "5", "10", "20", "30"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "resolution": {"type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"bars": "$bars", "direction": "$direction", "resolution": "$resolution"}, "operation": "STREAK"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_STREAK"}}	sha256:04a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000005	0f2a0000-0000-4000-8000-000000000001	BASIC_SMA_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "shortPeriod", "longPeriod"], "properties": {"direction": {"enum": ["UP", "DOWN"], "type": "string"}, "longPeriod": {"enum": ["20", "60", "120"], "type": "string"}, "resolution": {"type": "string"}, "shortPeriod": {"enum": ["5", "20", "60"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "longPeriod": "$longPeriod", "resolution": "$resolution", "shortPeriod": "$shortPeriod"}, "operation": "SMA_CROSS"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_SMA_CROSS"}}	sha256:05a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000006	0f2a0000-0000-4000-8000-000000000001	BASIC_RSI_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "period", "threshold"], "properties": {"period": {"enum": ["14"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "threshold": {"type": "string", "minLength": 1}, "resolution": {"type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "direction": "$direction", "threshold": "$threshold", "resolution": "$resolution"}, "operation": "RSI_CROSS"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_RSI_CROSS"}}	sha256:06a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000007	0f2a0000-0000-4000-8000-000000000001	BASIC_MACD_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "fastPeriod", "slowPeriod", "signalPeriod"], "properties": {"direction": {"enum": ["UP", "DOWN"], "type": "string"}, "fastPeriod": {"enum": ["12"], "type": "string"}, "resolution": {"type": "string"}, "slowPeriod": {"enum": ["26"], "type": "string"}, "signalPeriod": {"enum": ["9"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "fastPeriod": "$fastPeriod", "resolution": "$resolution", "slowPeriod": "$slowPeriod", "signalPeriod": "$signalPeriod"}, "operation": "MACD_CROSS"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_MACD_CROSS"}}	sha256:07a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000008	0f2a0000-0000-4000-8000-000000000001	BASIC_BOLLINGER_REVERSAL	CONDITION	{"type": "object", "required": ["resolution", "direction", "period", "deviations"], "properties": {"period": {"enum": ["20"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "deviations": {"enum": ["2"], "type": "string"}, "resolution": {"type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "direction": "$direction", "deviations": "$deviations", "resolution": "$resolution"}, "operation": "BOLLINGER_REVERSAL"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_BOLLINGER_REVERSAL"}}	sha256:08a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000009	0f2a0000-0000-4000-8000-000000000001	BASIC_POSITION_RETURN	CONDITION	{"type": "object", "required": ["direction", "thresholdPercent"], "properties": {"direction": {"enum": ["PROFIT", "LOSS"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "thresholdPercent": "$thresholdPercent"}, "operation": "POSITION_RETURN"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_POSITION_RETURN"}}	sha256:09a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000010	0f2a0000-0000-4000-8000-000000000001	BASIC_HOLDING_PERIOD	CONDITION	{"type": "object", "required": ["unit", "amount", "resolution"], "properties": {"unit": {"enum": ["SESSION_CLOSE", "BAR", "TRADING_DAY"], "type": "string"}, "amount": {"enum": ["0", "1", "5", "20"], "type": "string"}, "resolution": {"type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"unit": "$unit", "amount": "$amount", "resolution": "$resolution"}, "operation": "HOLDING_PERIOD"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_HOLDING_PERIOD"}}	sha256:10a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000011	0f2a0000-0000-4000-8000-000000000001	BASIC_PEAK_RETURN	CONDITION	{"type": "object", "required": ["operator", "thresholdPercent"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "thresholdPercent": "$thresholdPercent"}, "operation": "PEAK_RETURN"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PEAK_RETURN"}}	sha256:11a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000012	0f2a0000-0000-4000-8000-000000000001	BASIC_DRAWDOWN_FROM_PEAK	CONDITION	{"type": "object", "required": ["operator", "thresholdPercent"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "thresholdPercent": "$thresholdPercent"}, "operation": "DRAWDOWN_FROM_PEAK"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_DRAWDOWN_FROM_PEAK"}}	sha256:12a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000013	0f2a0000-0000-4000-8000-000000000001	BASIC_SCHEDULE	TRIGGER	{"type": "object", "required": ["cycle", "interval", "resolution"], "properties": {"cycle": {"enum": ["EVERY_TRADING_DAY", "WEEK_FIRST_TRADING_DAY", "MONTH_FIRST_TRADING_DAY", "MONTH_LAST_TRADING_DAY", "EVERY_N_TRADING_DAYS"], "type": "string"}, "interval": {"type": "string", "minLength": 1}, "resolution": {"type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"cycle": "$cycle", "interval": "$interval", "resolution": "$resolution"}, "operation": "SCHEDULE"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_SCHEDULE"}}	sha256:13a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f2c0000-0000-4000-8000-000000000014	0f2a0000-0000-4000-8000-000000000001	BASIC_EQUAL_ALLOCATION_ORDER	ACTION	{"type": "object", "required": ["orderPercent", "executionMode", "waitMode", "waitInterval", "maxExecutions"], "properties": {"waitMode": {"type": "string"}, "orderPercent": {"type": "string", "minLength": 1}, "waitInterval": {"type": "string", "minLength": 1}, "executionMode": {"type": "string"}, "maxExecutions": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{}	{"runtime": {"arguments": {"side": "$container", "waitMode": "$waitMode", "orderType": "MARKET", "allocation": "EQUAL", "timeInForce": "DAY", "orderPercent": "$orderPercent", "waitInterval": "$waitInterval", "executionMode": "$executionMode", "maxExecutions": "$maxExecutions"}, "operation": "EMIT_ORDER_CANDIDATE"}, "backtest": {"feeds": [], "features": [], "supported": true}, "terminal": true, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_EQUAL_ALLOCATION_ORDER"}}	sha256:14a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f3c0000-0000-4000-8000-000000000008	0f3a0000-0000-4000-8000-000000000001	BASIC_BOLLINGER_REVERSAL	CONDITION	{"type": "object", "required": ["resolution", "direction", "period", "deviations"], "properties": {"period": {"enum": ["20"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "deviations": {"enum": ["2"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "direction": "$direction", "deviations": "$deviations", "resolution": "$resolution"}, "operation": "BOLLINGER_REVERSAL"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_BOLLINGER_REVERSAL"}}	sha256:b18dd01bd39078e7fe16db5a186d958fb04b6a2b2ed19155f686957f5106055c
0f3c0000-0000-4000-8000-000000000012	0f3a0000-0000-4000-8000-000000000001	BASIC_DRAWDOWN_FROM_PEAK	CONDITION	{"type": "object", "required": ["operator", "thresholdPercent"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "thresholdPercent": "$thresholdPercent"}, "operation": "DRAWDOWN_FROM_PEAK"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_DRAWDOWN_FROM_PEAK"}}	sha256:053216453db25a9ad794fec4ad423ce3f56e26313936df963b09eb1edb7de835
0f3c0000-0000-4000-8000-000000000014	0f3a0000-0000-4000-8000-000000000001	BASIC_EQUAL_ALLOCATION_ORDER	ACTION	{"type": "object", "required": ["orderPercent", "executionMode", "waitMode", "waitInterval", "maxExecutions"], "properties": {"waitMode": {"type": "string"}, "orderPercent": {"type": "string", "minLength": 1}, "waitInterval": {"type": "string", "minLength": 1}, "executionMode": {"type": "string"}, "maxExecutions": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{}	{"runtime": {"arguments": {"side": "$container", "waitMode": "$waitMode", "orderType": "MARKET", "allocation": "EQUAL", "timeInForce": "DAY", "orderPercent": "$orderPercent", "waitInterval": "$waitInterval", "executionMode": "$executionMode", "maxExecutions": "$maxExecutions"}, "operation": "EMIT_ORDER_CANDIDATE"}, "backtest": {"feeds": [], "features": [], "supported": true}, "terminal": true, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_EQUAL_ALLOCATION_ORDER"}}	sha256:b5e47755634da87933e73302c6ad666c735e466d93f1325db970bc7618793d35
0f3c0000-0000-4000-8000-000000000010	0f3a0000-0000-4000-8000-000000000001	BASIC_HOLDING_PERIOD	CONDITION	{"type": "object", "required": ["unit", "amount", "resolution"], "properties": {"unit": {"enum": ["SESSION_CLOSE", "BAR", "TRADING_DAY"], "type": "string"}, "amount": {"enum": ["0", "1", "5", "20"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"unit": "$unit", "amount": "$amount", "resolution": "$resolution"}, "operation": "HOLDING_PERIOD"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_HOLDING_PERIOD"}}	sha256:c1dd1ad6be6fec7583855b5d264854eca87583d7f0c22372aa68485f2405979d
0f3c0000-0000-4000-8000-000000000007	0f3a0000-0000-4000-8000-000000000001	BASIC_MACD_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "fastPeriod", "slowPeriod", "signalPeriod"], "properties": {"direction": {"enum": ["UP", "DOWN"], "type": "string"}, "fastPeriod": {"enum": ["12"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}, "slowPeriod": {"enum": ["26"], "type": "string"}, "signalPeriod": {"enum": ["9"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "fastPeriod": "$fastPeriod", "resolution": "$resolution", "slowPeriod": "$slowPeriod", "signalPeriod": "$signalPeriod"}, "operation": "MACD_CROSS"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_MACD_CROSS"}}	sha256:68b5088db3d87f2bf64273a40d26f555d772b88eb29a5aca44df865a9be45149
0f3c0000-0000-4000-8000-000000000011	0f3a0000-0000-4000-8000-000000000001	BASIC_PEAK_RETURN	CONDITION	{"type": "object", "required": ["operator", "thresholdPercent"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "thresholdPercent": "$thresholdPercent"}, "operation": "PEAK_RETURN"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PEAK_RETURN"}}	sha256:aa37818341e24aea747a1ee7b3e6b8e91db02f9cfe3644a776492b0338a49977
0f3c0000-0000-4000-8000-000000000009	0f3a0000-0000-4000-8000-000000000001	BASIC_POSITION_RETURN	CONDITION	{"type": "object", "required": ["direction", "thresholdPercent"], "properties": {"direction": {"enum": ["PROFIT", "LOSS"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "thresholdPercent": "$thresholdPercent"}, "operation": "POSITION_RETURN"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_POSITION_RETURN"}}	sha256:d343ff3f49132474ea2f7b5ebb6657f08049792f1254b87924c4138be56f4250
0f3c0000-0000-4000-8000-000000000002	0f3a0000-0000-4000-8000-000000000001	BASIC_PRICE_CHANGE_PERCENT	CONDITION	{"type": "object", "required": ["resolution", "base", "direction", "thresholdPercent"], "properties": {"base": {"enum": ["PREVIOUS_CLOSE", "SESSION_OPEN", "AVERAGE_ENTRY_PRICE"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"base": "$base", "direction": "$direction", "resolution": "$resolution", "thresholdPercent": "$thresholdPercent"}, "operation": "PRICE_CHANGE_PERCENT"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PRICE_CHANGE_PERCENT"}}	sha256:69300727c4997213de19a5e8de8cf29b9530d70685d826bb17e4b00847574320
0f3c0000-0000-4000-8000-000000000001	0f3a0000-0000-4000-8000-000000000001	BASIC_PRICE_COMPARE	CONDITION	{"type": "object", "required": ["resolution", "operator", "reference"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "reference": {"enum": ["PREVIOUS_CLOSE", "SESSION_OPEN", "AVERAGE_ENTRY_PRICE", "SMA_5", "SMA_20", "SMA_60", "HIGH_5", "HIGH_20", "HIGH_60", "LOW_5", "LOW_20", "LOW_60"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "reference": "$reference", "resolution": "$resolution"}, "operation": "PRICE_COMPARE"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PRICE_COMPARE"}}	sha256:cde3349fccb430c7329ff8676fb7354263f1e3c517b302e28f8180bdc03dbde3
0f3c0000-0000-4000-8000-000000000006	0f3a0000-0000-4000-8000-000000000001	BASIC_RSI_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "period", "threshold"], "properties": {"period": {"enum": ["14"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "threshold": {"type": "string", "minLength": 1}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "direction": "$direction", "threshold": "$threshold", "resolution": "$resolution"}, "operation": "RSI_CROSS"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_RSI_CROSS"}}	sha256:86637da99a546477383eb14248f0739be38ca8bcebb7d88f5067652befbb38f8
0f3c0000-0000-4000-8000-000000000013	0f3a0000-0000-4000-8000-000000000001	BASIC_SCHEDULE	TRIGGER	{"type": "object", "required": ["cycle", "interval", "resolution"], "properties": {"cycle": {"enum": ["EVERY_TRADING_DAY", "WEEK_FIRST_TRADING_DAY", "MONTH_FIRST_TRADING_DAY", "MONTH_LAST_TRADING_DAY", "EVERY_N_TRADING_DAYS"], "type": "string"}, "interval": {"type": "string", "minLength": 1}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"cycle": "$cycle", "interval": "$interval", "resolution": "$resolution"}, "operation": "SCHEDULE"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_SCHEDULE"}}	sha256:3bb0bc060b0c1b3686120420bf298acc5b0b92cd099c53ce4a437b0ea30f31d8
0f3c0000-0000-4000-8000-000000000005	0f3a0000-0000-4000-8000-000000000001	BASIC_SMA_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "shortPeriod", "longPeriod"], "properties": {"direction": {"enum": ["UP", "DOWN"], "type": "string"}, "longPeriod": {"enum": ["20", "60", "120"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}, "shortPeriod": {"enum": ["5", "20", "60"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "longPeriod": "$longPeriod", "resolution": "$resolution", "shortPeriod": "$shortPeriod"}, "operation": "SMA_CROSS"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_SMA_CROSS"}}	sha256:4e15d8154329d3f6058e64de90be49b6ddf8dab4915ab720024843c49b282748
0f3c0000-0000-4000-8000-000000000004	0f3a0000-0000-4000-8000-000000000001	BASIC_STREAK	CONDITION	{"type": "object", "required": ["resolution", "direction", "bars"], "properties": {"bars": {"enum": ["2", "3", "5", "10", "20", "30"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"bars": "$bars", "direction": "$direction", "resolution": "$resolution"}, "operation": "STREAK"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_STREAK"}}	sha256:bfaf0a942579b66a7482ed6916256f665f6ec4f2d587a23183081273405dfc0e
0f3c0000-0000-4000-8000-000000000003	0f3a0000-0000-4000-8000-000000000001	BASIC_VOLUME_COMPARE	CONDITION	{"type": "object", "required": ["resolution", "operator", "reference", "period", "multiplier"], "properties": {"period": {"enum": ["1", "5", "20", "60"], "type": "string"}, "operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "reference": {"enum": ["PREVIOUS_VOLUME", "AVERAGE_VOLUME"], "type": "string"}, "multiplier": {"enum": ["1", "2", "3"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "operator": "$operator", "reference": "$reference", "multiplier": "$multiplier", "resolution": "$resolution"}, "operation": "VOLUME_COMPARE"}, "backtest": {"feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}], "features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_VOLUME_COMPARE"}}	sha256:39987068fcae981d0940b6b94bc6e477b384c145b6257c372df55c217aebd5af
0f4c0000-0000-4000-8000-000000000001	0f4a0000-0000-4000-8000-000000000001	BASIC_PRICE_COMPARE	CONDITION	{"type": "object", "required": ["resolution", "operator", "reference"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "reference": {"enum": ["PREVIOUS_CLOSE", "SESSION_OPEN", "AVERAGE_ENTRY_PRICE", "SMA_5", "SMA_20", "SMA_60", "HIGH_5", "HIGH_20", "HIGH_60", "LOW_5", "LOW_20", "LOW_60"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "reference": "$reference", "resolution": "$resolution"}, "operation": "PRICE_COMPARE"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PRICE_COMPARE"}}	sha256:71a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000002	0f4a0000-0000-4000-8000-000000000001	BASIC_PRICE_CHANGE_PERCENT	CONDITION	{"type": "object", "required": ["resolution", "base", "direction", "thresholdPercent"], "properties": {"base": {"enum": ["PREVIOUS_CLOSE", "SESSION_OPEN", "AVERAGE_ENTRY_PRICE"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"base": "$base", "direction": "$direction", "resolution": "$resolution", "thresholdPercent": "$thresholdPercent"}, "operation": "PRICE_CHANGE_PERCENT"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PRICE_CHANGE_PERCENT"}}	sha256:72a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000003	0f4a0000-0000-4000-8000-000000000001	BASIC_VOLUME_COMPARE	CONDITION	{"type": "object", "required": ["resolution", "operator", "reference", "period", "multiplier"], "properties": {"period": {"enum": ["1", "5", "20", "60"], "type": "string"}, "operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "reference": {"enum": ["PREVIOUS_VOLUME", "AVERAGE_VOLUME"], "type": "string"}, "multiplier": {"enum": ["1", "2", "3"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "operator": "$operator", "reference": "$reference", "multiplier": "$multiplier", "resolution": "$resolution"}, "operation": "VOLUME_COMPARE"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_VOLUME_COMPARE"}}	sha256:73a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000004	0f4a0000-0000-4000-8000-000000000001	BASIC_STREAK	CONDITION	{"type": "object", "required": ["resolution", "direction", "bars"], "properties": {"bars": {"enum": ["2", "3", "5", "10", "20", "30"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"bars": "$bars", "direction": "$direction", "resolution": "$resolution"}, "operation": "STREAK"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_STREAK"}}	sha256:74a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000005	0f4a0000-0000-4000-8000-000000000001	BASIC_SMA_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "shortPeriod", "longPeriod"], "properties": {"direction": {"enum": ["UP", "DOWN"], "type": "string"}, "longPeriod": {"enum": ["20", "60", "120"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}, "shortPeriod": {"enum": ["5", "20", "60"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "longPeriod": "$longPeriod", "resolution": "$resolution", "shortPeriod": "$shortPeriod"}, "operation": "SMA_CROSS"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_SMA_CROSS"}}	sha256:75a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000006	0f4a0000-0000-4000-8000-000000000001	BASIC_RSI_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "period", "threshold"], "properties": {"period": {"enum": ["14"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "threshold": {"type": "string", "minLength": 1}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "direction": "$direction", "threshold": "$threshold", "resolution": "$resolution"}, "operation": "RSI_CROSS"}, "backtest": {"features": ["RSI_14"], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_RSI_CROSS"}}	sha256:76a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000007	0f4a0000-0000-4000-8000-000000000001	BASIC_MACD_CROSS	CONDITION	{"type": "object", "required": ["resolution", "direction", "fastPeriod", "slowPeriod", "signalPeriod"], "properties": {"direction": {"enum": ["UP", "DOWN"], "type": "string"}, "fastPeriod": {"enum": ["12"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}, "slowPeriod": {"enum": ["26"], "type": "string"}, "signalPeriod": {"enum": ["9"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "fastPeriod": "$fastPeriod", "resolution": "$resolution", "slowPeriod": "$slowPeriod", "signalPeriod": "$signalPeriod"}, "operation": "MACD_CROSS"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_MACD_CROSS"}}	sha256:77a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000008	0f4a0000-0000-4000-8000-000000000001	BASIC_BOLLINGER_REVERSAL	CONDITION	{"type": "object", "required": ["resolution", "direction", "period", "deviations"], "properties": {"period": {"enum": ["20"], "type": "string"}, "direction": {"enum": ["UP", "DOWN"], "type": "string"}, "deviations": {"enum": ["2"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"period": "$period", "direction": "$direction", "deviations": "$deviations", "resolution": "$resolution"}, "operation": "BOLLINGER_REVERSAL"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_BOLLINGER_REVERSAL"}}	sha256:78a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000009	0f4a0000-0000-4000-8000-000000000001	BASIC_POSITION_RETURN	CONDITION	{"type": "object", "required": ["direction", "thresholdPercent"], "properties": {"direction": {"enum": ["PROFIT", "LOSS"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"direction": "$direction", "thresholdPercent": "$thresholdPercent"}, "operation": "POSITION_RETURN"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_POSITION_RETURN"}}	sha256:79a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000010	0f4a0000-0000-4000-8000-000000000001	BASIC_HOLDING_PERIOD	CONDITION	{"type": "object", "required": ["unit", "amount", "resolution"], "properties": {"unit": {"enum": ["SESSION_CLOSE", "BAR", "TRADING_DAY"], "type": "string"}, "amount": {"enum": ["0", "1", "5", "20"], "type": "string"}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"unit": "$unit", "amount": "$amount", "resolution": "$resolution"}, "operation": "HOLDING_PERIOD"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_HOLDING_PERIOD"}}	sha256:80a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000011	0f4a0000-0000-4000-8000-000000000001	BASIC_PEAK_RETURN	CONDITION	{"type": "object", "required": ["operator", "thresholdPercent"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "thresholdPercent": "$thresholdPercent"}, "operation": "PEAK_RETURN"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_PEAK_RETURN"}}	sha256:81a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000012	0f4a0000-0000-4000-8000-000000000001	BASIC_DRAWDOWN_FROM_PEAK	CONDITION	{"type": "object", "required": ["operator", "thresholdPercent"], "properties": {"operator": {"enum": ["LT", "LTE", "GT", "GTE", "EQ", "NEQ"], "type": "string"}, "thresholdPercent": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"operator": "$operator", "thresholdPercent": "$thresholdPercent"}, "operation": "DRAWDOWN_FROM_PEAK"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_DRAWDOWN_FROM_PEAK"}}	sha256:82a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000013	0f4a0000-0000-4000-8000-000000000001	BASIC_SCHEDULE	TRIGGER	{"type": "object", "required": ["cycle", "interval", "resolution"], "properties": {"cycle": {"enum": ["EVERY_TRADING_DAY", "WEEK_FIRST_TRADING_DAY", "MONTH_FIRST_TRADING_DAY", "MONTH_LAST_TRADING_DAY", "EVERY_N_TRADING_DAYS"], "type": "string"}, "interval": {"type": "string", "minLength": 1}, "resolution": {"enum": ["30m", "1h", "4h", "1d"], "type": "string"}}}	{"passed": {"type": "boolean"}}	{"passed": {"type": "boolean"}}	{"runtime": {"arguments": {"cycle": "$cycle", "interval": "$interval", "resolution": "$resolution"}, "operation": "SCHEDULE"}, "backtest": {"features": [], "supported": true}, "terminal": false, "containers": ["BUY"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_SCHEDULE"}}	sha256:83a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
0f4c0000-0000-4000-8000-000000000014	0f4a0000-0000-4000-8000-000000000001	BASIC_EQUAL_ALLOCATION_ORDER	ACTION	{"type": "object", "required": ["orderPercent", "executionMode", "waitMode", "waitInterval", "maxExecutions"], "properties": {"waitMode": {"enum": ["조건 재충족", "N봉 이후", "N거래일 이후"], "type": "string"}, "orderPercent": {"type": "string", "minLength": 1}, "waitInterval": {"type": "string", "minLength": 1}, "executionMode": {"enum": ["1회만", "주기마다", "대기 후 재진입", "대기 후 재실행"], "type": "string"}, "maxExecutions": {"type": "string", "minLength": 1}}}	{"passed": {"type": "boolean"}}	{}	{"runtime": {"arguments": {"side": "$container", "waitMode": "$waitMode", "orderType": "MARKET", "allocation": "EQUAL", "timeInForce": "DAY", "orderPercent": "$orderPercent", "waitInterval": "$waitInterval", "executionMode": "$executionMode", "maxExecutions": "$maxExecutions"}, "operation": "EMIT_ORDER_CANDIDATE"}, "backtest": {"features": [], "supported": true}, "terminal": true, "containers": ["BUY", "SELL"], "deterministic": true, "reviewTemplates": {"ko-KR": "BASIC_EQUAL_ALLOCATION_ORDER"}}	sha256:84a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301
\.


--
-- Data for Name: package_versions; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.package_versions (id, package_id, version, element_catalog_version_id, name_i18n, description_i18n, flow_document, content_hash, published_at, retired_at) FROM stdin;
\.


--
-- Data for Name: packages; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.packages (id, code, status, created_at, retired_at) FROM stdin;
\.


--
-- Data for Name: strategies; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.strategies (id, owner_account_id, mode, name, description, edit_sequence, created_at, updated_at, archived_at, deleted_at, delegated_access_epoch) FROM stdin;
\.


--
-- Data for Name: strategy_documents; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.strategy_documents (strategy_id, semantic_document, presentation_document, semantic_schema_version, presentation_schema_version, semantic_hash, presentation_hash, edit_sequence, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: strategy_edit_leases; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.strategy_edit_leases (strategy_id, delegated_credential_id, lease_token_digest, digest_key_version, acquired_at, heartbeat_at, expires_at, account_id) FROM stdin;
\.


--
-- Data for Name: template_versions; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.template_versions (id, template_id, version, element_catalog_version_id, name_i18n, description_i18n, semantic_skeleton, content_hash, published_at, retired_at) FROM stdin;
\.


--
-- Data for Name: templates; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.templates (id, code, status, created_at, retired_at) FROM stdin;
\.


--
-- Data for Name: validation_runs; Type: TABLE DATA; Schema: strategy; Owner: -
--

COPY strategy.validation_runs (id, strategy_id, requested_by_account_id, delegated_authorization_id, requested_edit_sequence, semantic_hash, element_catalog_version_id, status, issue_count, result_document, requested_at, completed_at) FROM stdin;
\.


--
-- Data for Name: bot_budget_projections; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.bot_budget_projections (bot_id, currency_code, available_cash_amount, active_reservation_amount, invested_amount, segregated_short_proceeds_amount, short_collateral_amount, valuation_at, valuation_status, last_event_sequence, projection_hash, updated_at) FROM stdin;
\.


--
-- Data for Name: buying_power_buffer_policy_versions; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.buying_power_buffer_policy_versions (id, policy_code, version, buffer_bps, rounding_rules_version, rules_hash, effective_from, effective_to, published_at) FROM stdin;
\.


--
-- Data for Name: candidate_batch_processing; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.candidate_batch_processing (batch_id, evaluation_id, source_created_at, status, claim_token, lease_expires_at, failure_reason, started_at, updated_at) FROM stdin;
\.


--
-- Data for Name: fee_policy_versions; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.fee_policy_versions (id, policy_code, version, fee_rate_bps, calculation_rules_version, rules_hash, effective_from, effective_to, published_at) FROM stdin;
\.


--
-- Data for Name: fill_adjustments; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.fill_adjustments (id, bot_id, partition_id, fill_id, bot_event_id, adjustment_key, adjustment_type, quantity_delta, gross_amount_delta, fee_amount_delta, settlement_cash_delta, reason_code, occurred_at, recorded_at) FROM stdin;
\.


--
-- Data for Name: fill_component_allocations; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.fill_component_allocations (id, bot_id, partition_id, order_id, fill_id, order_component_id, allocation_sequence, allocated_quantity, allocated_gross_amount, allocated_fee_amount, allocated_settlement_cash_delta, allocation_rules_version, created_at) FROM stdin;
\.


--
-- Data for Name: fills; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.fills (id, order_id, bot_id, partition_id, bot_event_id, provider_fill_key, quantity, reference_price, reference_observed_at, reference_market_hash, slippage_rate_bps, slippage_amount, fill_price, gross_amount, fee_policy_id, fee_rate_bps, precision_rules_version, fee_basis_amount, fee_amount, settlement_cash_delta, occurred_at, recorded_at) FROM stdin;
\.


--
-- Data for Name: flow_position_projections; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.flow_position_projections (flow_id, partition_id, bot_id, instrument_id, long_quantity, short_quantity, cost_basis_amount, last_event_sequence, projection_hash, updated_at) FROM stdin;
\.


--
-- Data for Name: ledger_accounts; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.ledger_accounts (id, bot_id, account_key, partition_id, flow_id, account_type, currency_code, instrument_id, created_at, closed_at) FROM stdin;
\.


--
-- Data for Name: ledger_entries; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.ledger_entries (id, bot_id, partition_id, transaction_id, ledger_account_id, order_component_id, entry_sequence, direction, amount, quantity, entry_hash) FROM stdin;
\.


--
-- Data for Name: ledger_transactions; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.ledger_transactions (id, bot_id, partition_id, bot_event_id, transaction_type, transaction_key, source_type, source_id, currency_code, reversal_of_transaction_id, occurred_at, recorded_at, description_code) FROM stdin;
\.


--
-- Data for Name: lot_movements; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.lot_movements (id, bot_id, partition_id, position_lot_id, bot_event_id, source_fill_allocation_id, source_fill_adjustment_id, corporate_action_id, reverses_movement_id, movement_type, quantity_delta, cost_basis_delta, remaining_after, cost_basis_after, occurred_at) FROM stdin;
\.


--
-- Data for Name: order_component_reservations; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_component_reservations (bot_id, partition_id, reservation_id, order_component_id, reserved_amount, reserved_quantity) FROM stdin;
\.


--
-- Data for Name: order_components; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_components (id, bot_id, partition_id, order_id, intent_id, component_quantity, component_notional, component_sequence, composition_rules_version) FROM stdin;
\.


--
-- Data for Name: order_events; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_events (id, bot_id, partition_id, order_id, bot_event_id, order_sequence, event_type, previous_status, new_status, reason_code, occurred_at, event_document) FROM stdin;
\.


--
-- Data for Name: order_group_events; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_group_events (id, bot_id, partition_id, order_group_id, bot_event_id, group_sequence, previous_status, new_status, event_type, reason_code, occurred_at, event_document) FROM stdin;
\.


--
-- Data for Name: order_group_members; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_group_members (bot_id, partition_id, order_group_id, order_id, member_role, leg_sequence, quantity_ratio, activation_condition, cancellation_condition) FROM stdin;
\.


--
-- Data for Name: order_groups; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_groups (id, bot_id, partition_id, group_type, group_key, status, created_event_id, closed_event_id) FROM stdin;
\.


--
-- Data for Name: order_intent_batches; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_intent_batches (id, bot_id, partition_id, source_event_id, status, conflict_policy_hash, composition_rules_version, input_state_hash, result_hash, finalized_at) FROM stdin;
\.


--
-- Data for Name: order_intents; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_intents (id, bot_id, batch_id, source_event_id, origin_type, evaluation_run_id, partition_id, flow_id, instrument_id, intent_key, side, position_effect, order_type, time_in_force, requested_quantity, requested_notional, approved_quantity, approved_notional, post_netting_quantity, final_quantity, final_notional, limit_price, stop_price, trailing_offset_type, trailing_offset_value, requested_expires_at, decision, decision_reason_code) FROM stdin;
\.


--
-- Data for Name: order_state_projections; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.order_state_projections (order_id, bot_id, partition_id, status, filled_quantity, remaining_quantity, reserved_cash, reserved_quantity, active_stop_price, trailing_reference_price, last_order_event_sequence, last_bot_event_sequence, updated_at) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.orders (id, bot_id, partition_id, instrument_id, replaces_order_id, replacement_reason_code, order_key, side, order_type, time_in_force, requested_quantity, requested_notional, limit_price, stop_price, trailing_offset_type, trailing_offset_value, broker_rules_version, precision_rules_version, slippage_rate_bps, fee_policy_id, accepted_event_id, accepted_at, expires_at, contract_hash) FROM stdin;
\.


--
-- Data for Name: partition_budget_projections; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.partition_budget_projections (partition_id, bot_id, currency_code, budget_cap_amount, active_reservation_amount, invested_amount, segregated_short_proceeds_amount, short_collateral_amount, valuation_at, valuation_status, last_event_sequence, projection_hash, updated_at) FROM stdin;
\.


--
-- Data for Name: partition_position_projections; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.partition_position_projections (partition_id, bot_id, instrument_id, net_quantity, average_cost, realized_pnl, last_valuation_price, last_valuation_at, valuation_status, last_bot_event_sequence, updated_at) FROM stdin;
\.


--
-- Data for Name: position_lot_projections; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.position_lot_projections (position_lot_id, remaining_quantity, remaining_cost_basis_amount, active_reserved_quantity, last_movement_id, last_event_sequence, closed_at, updated_at) FROM stdin;
\.


--
-- Data for Name: position_lot_reservations; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.position_lot_reservations (bot_id, partition_id, flow_id, reservation_id, position_lot_id, reserved_quantity) FROM stdin;
\.


--
-- Data for Name: position_lots; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.position_lots (id, bot_id, partition_id, flow_id, instrument_id, opening_order_component_id, lot_side, opened_quantity, unit_cost, opened_cost_basis_amount, opened_at, opening_fill_allocation_id) FROM stdin;
\.


--
-- Data for Name: reservation_events; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.reservation_events (id, bot_id, partition_id, reservation_id, bot_event_id, source_fill_id, event_key, reservation_sequence, event_type, consumed_amount_delta, released_amount_delta, consumed_quantity_delta, released_quantity_delta, status_after, occurred_at, event_hash) FROM stdin;
\.


--
-- Data for Name: resource_reservations; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.resource_reservations (id, reservation_key, bot_id, partition_id, flow_id, intent_id, resource_type, currency_code, instrument_id, buffer_policy_id, fee_policy_id, short_risk_policy_id, precision_rules_version, status, reference_price, reference_observed_at, reference_market_hash, base_notional, fixed_slippage_amount, estimated_fee_amount, buffer_amount, reserved_amount, consumed_amount, released_amount, reserved_quantity, consumed_quantity, released_quantity, created_event_id, created_at, last_event_sequence) FROM stdin;
\.


--
-- Data for Name: short_borrow_fee_accruals; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.short_borrow_fee_accruals (id, bot_id, partition_id, position_lot_id, bot_event_id, short_borrow_fee_policy_id, ledger_transaction_id, period_start, period_end, annual_fee_rate_bps, day_count_basis, fee_basis_amount, accrued_fee_amount, calculation_hash) FROM stdin;
\.


--
-- Data for Name: short_borrow_fee_policy_versions; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.short_borrow_fee_policy_versions (id, policy_code, version, annual_fee_rate_bps, day_count_basis, calculation_rules_version, rules_hash, effective_from, effective_to, published_at) FROM stdin;
\.


--
-- Data for Name: short_risk_policy_versions; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.short_risk_policy_versions (id, policy_code, version, rules_document, rules_hash, effective_from, effective_to, published_at) FROM stdin;
\.


--
-- Data for Name: short_trade_checks; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.short_trade_checks (intent_id, short_risk_policy_id, assessed_at, reference_price, projected_short_quantity, projected_exposure_amount, required_initial_collateral_amount, required_maintenance_collateral_amount, rule_201_triggered, rule_201_triggered_at, prior_regular_close_price, national_best_bid_price, minimum_permitted_short_price, price_rule_observed_at, price_rule_market_hash, liquidation_reference_price, approved, decision_reason_code, evidence_hash) FROM stdin;
\.


--
-- Data for Name: system_close_actions; Type: TABLE DATA; Schema: trading; Owner: -
--

COPY trading.system_close_actions (id, bot_id, partition_id, flow_id, instrument_id, source_event_id, reason_type, requested_quantity, generated_intent_id, reason_document, calculation_hash, created_at) FROM stdin;
\.


--
-- Name: detail_manifests detail_manifests_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.detail_manifests
    ADD CONSTRAINT detail_manifests_pkey PRIMARY KEY (id);


--
-- Name: execution_policy_versions execution_policy_versions_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.execution_policy_versions
    ADD CONSTRAINT execution_policy_versions_pkey PRIMARY KEY (version);


--
-- Name: execution_policy_versions execution_policy_versions_policy_artifact_hash_key; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.execution_policy_versions
    ADD CONSTRAINT execution_policy_versions_policy_artifact_hash_key UNIQUE (policy_artifact_hash);


--
-- Name: failure_condition_counts failure_condition_counts_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.failure_condition_counts
    ADD CONSTRAINT failure_condition_counts_pkey PRIMARY KEY (id);


--
-- Name: input_bundles input_bundles_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_bundles
    ADD CONSTRAINT input_bundles_pkey PRIMARY KEY (id);


--
-- Name: input_bundles input_bundles_run_id_key; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_bundles
    ADD CONSTRAINT input_bundles_run_id_key UNIQUE (run_id);


--
-- Name: input_datasets input_datasets_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_datasets
    ADD CONSTRAINT input_datasets_pkey PRIMARY KEY (input_bundle_id, dataset_manifest_id, purpose_code);


--
-- Name: input_feature_materializations input_feature_materializations_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_feature_materializations
    ADD CONSTRAINT input_feature_materializations_pkey PRIMARY KEY (input_bundle_id, feature_materialization_id);


--
-- Name: legacy_execution_policy_mappings legacy_execution_policy_mappings_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.legacy_execution_policy_mappings
    ADD CONSTRAINT legacy_execution_policy_mappings_pkey PRIMARY KEY (run_id);


--
-- Name: monthly_judgment_summaries monthly_judgment_summaries_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.monthly_judgment_summaries
    ADD CONSTRAINT monthly_judgment_summaries_pkey PRIMARY KEY (id);


--
-- Name: performance_summaries performance_summaries_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.performance_summaries
    ADD CONSTRAINT performance_summaries_pkey PRIMARY KEY (run_id);


--
-- Name: run_attempts run_attempts_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_attempts
    ADD CONSTRAINT run_attempts_pkey PRIMARY KEY (id);


--
-- Name: run_attempts run_attempts_worker_execution_key_key; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_attempts
    ADD CONSTRAINT run_attempts_worker_execution_key_key UNIQUE (worker_execution_key);


--
-- Name: run_input_pins run_input_pins_input_bundle_id_key; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_input_pins
    ADD CONSTRAINT run_input_pins_input_bundle_id_key UNIQUE (input_bundle_id);


--
-- Name: run_input_pins run_input_pins_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_input_pins
    ADD CONSTRAINT run_input_pins_pkey PRIMARY KEY (run_id);


--
-- Name: runs runs_pkey; Type: CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.runs
    ADD CONSTRAINT runs_pkey PRIMARY KEY (id);


--
-- Name: bot_events bot_events_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bot_events
    ADD CONSTRAINT bot_events_pkey PRIMARY KEY (id);


--
-- Name: bot_partitions bot_partitions_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bot_partitions
    ADD CONSTRAINT bot_partitions_pkey PRIMARY KEY (id);


--
-- Name: bots bots_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bots
    ADD CONSTRAINT bots_pkey PRIMARY KEY (id);


--
-- Name: continuation_deadlines continuation_deadlines_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.continuation_deadlines
    ADD CONSTRAINT continuation_deadlines_pkey PRIMARY KEY (bot_id);


--
-- Name: evaluation_runs evaluation_runs_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.evaluation_runs
    ADD CONSTRAINT evaluation_runs_pkey PRIMARY KEY (id);


--
-- Name: evaluation_runs evaluation_runs_result_event_id_key; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.evaluation_runs
    ADD CONSTRAINT evaluation_runs_result_event_id_key UNIQUE (result_event_id);


--
-- Name: flow_feature_requirements flow_feature_requirements_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_feature_requirements
    ADD CONSTRAINT flow_feature_requirements_pkey PRIMARY KEY (flow_id, instrument_id, feature_definition_id);


--
-- Name: flow_instruments flow_instruments_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_instruments
    ADD CONSTRAINT flow_instruments_pkey PRIMARY KEY (flow_id, instrument_id);


--
-- Name: flow_time_triggers flow_time_triggers_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_time_triggers
    ADD CONSTRAINT flow_time_triggers_pkey PRIMARY KEY (flow_id, trigger_type, schedule_key);


--
-- Name: flows flows_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flows
    ADD CONSTRAINT flows_pkey PRIMARY KEY (id);


--
-- Name: launch_configurations launch_configurations_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.launch_configurations
    ADD CONSTRAINT launch_configurations_pkey PRIMARY KEY (bot_id);


--
-- Name: launch_contract_plans launch_contract_plans_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.launch_contract_plans
    ADD CONSTRAINT launch_contract_plans_pkey PRIMARY KEY (bot_id);


--
-- Name: launch_snapshots launch_snapshots_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.launch_snapshots
    ADD CONSTRAINT launch_snapshots_pkey PRIMARY KEY (bot_id);


--
-- Name: runtime_state_changes runtime_state_changes_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.runtime_state_changes
    ADD CONSTRAINT runtime_state_changes_pkey PRIMARY KEY (bot_event_id, runtime_state_value_id);


--
-- Name: runtime_state_values runtime_state_values_pkey; Type: CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.runtime_state_values
    ADD CONSTRAINT runtime_state_values_pkey PRIMARY KEY (id);


--
-- Name: backtest_aggregate_results backtest_aggregate_results_aggregate_hash_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_aggregate_results
    ADD CONSTRAINT backtest_aggregate_results_aggregate_hash_key UNIQUE (aggregate_hash);


--
-- Name: backtest_aggregate_results backtest_aggregate_results_participation_id_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_aggregate_results
    ADD CONSTRAINT backtest_aggregate_results_participation_id_key UNIQUE (participation_id);


--
-- Name: backtest_aggregate_results backtest_aggregate_results_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_aggregate_results
    ADD CONSTRAINT backtest_aggregate_results_pkey PRIMARY KEY (id);


--
-- Name: backtest_evaluation_periods backtest_evaluation_periods_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_evaluation_periods
    ADD CONSTRAINT backtest_evaluation_periods_pkey PRIMARY KEY (id);


--
-- Name: backtest_evaluation_plans backtest_evaluation_plans_commitment_hash_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_evaluation_plans
    ADD CONSTRAINT backtest_evaluation_plans_commitment_hash_key UNIQUE (commitment_hash);


--
-- Name: backtest_evaluation_plans backtest_evaluation_plans_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_evaluation_plans
    ADD CONSTRAINT backtest_evaluation_plans_pkey PRIMARY KEY (room_id);


--
-- Name: backtest_evaluation_plans backtest_evaluation_plans_plan_hash_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_evaluation_plans
    ADD CONSTRAINT backtest_evaluation_plans_plan_hash_key UNIQUE (plan_hash);


--
-- Name: backtest_period_datasets backtest_period_datasets_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_datasets
    ADD CONSTRAINT backtest_period_datasets_pkey PRIMARY KEY (evaluation_period_id, dataset_manifest_id, purpose_code);


--
-- Name: backtest_period_feature_materializations backtest_period_feature_materializations_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_feature_materializations
    ADD CONSTRAINT backtest_period_feature_materializations_pkey PRIMARY KEY (evaluation_period_id, feature_materialization_id);


--
-- Name: backtest_period_runs backtest_period_runs_participation_period_unique; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_runs
    ADD CONSTRAINT backtest_period_runs_participation_period_unique UNIQUE (participation_id, evaluation_period_id);


--
-- Name: backtest_period_runs backtest_period_runs_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_runs
    ADD CONSTRAINT backtest_period_runs_pkey PRIMARY KEY (participation_id, evaluation_period_id, run_id);


--
-- Name: room_final_access_grants competition_room_final_access_grants_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_final_access_grants
    ADD CONSTRAINT competition_room_final_access_grants_pkey PRIMARY KEY (room_id, account_id);


--
-- Name: room_final_access_grants competition_room_final_access_grants_snapshot_account_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_final_access_grants
    ADD CONSTRAINT competition_room_final_access_grants_snapshot_account_key UNIQUE (snapshot_id, account_id);


--
-- Name: leaderboard_entries leaderboard_entries_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.leaderboard_entries
    ADD CONSTRAINT leaderboard_entries_pkey PRIMARY KEY (snapshot_id, participation_id);


--
-- Name: leaderboard_snapshots leaderboard_snapshots_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.leaderboard_snapshots
    ADD CONSTRAINT leaderboard_snapshots_pkey PRIMARY KEY (id);


--
-- Name: live_evaluation_segments live_evaluation_segments_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.live_evaluation_segments
    ADD CONSTRAINT live_evaluation_segments_pkey PRIMARY KEY (id);


--
-- Name: live_room_rules live_room_rules_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.live_room_rules
    ADD CONSTRAINT live_room_rules_pkey PRIMARY KEY (room_id);


--
-- Name: participation_events participation_events_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.participation_events
    ADD CONSTRAINT participation_events_pkey PRIMARY KEY (id);


--
-- Name: participations participations_bot_id_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.participations
    ADD CONSTRAINT participations_bot_id_key UNIQUE (bot_id);


--
-- Name: participations participations_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.participations
    ADD CONSTRAINT participations_pkey PRIMARY KEY (id);


--
-- Name: room_evaluation_account_results room_evaluation_account_results_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_evaluation_account_results
    ADD CONSTRAINT room_evaluation_account_results_pkey PRIMARY KEY (request_message_id);


--
-- Name: room_evaluation_account_results room_evaluation_account_results_result_message_id_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_evaluation_account_results
    ADD CONSTRAINT room_evaluation_account_results_result_message_id_key UNIQUE (result_message_id);


--
-- Name: room_events room_events_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_events
    ADD CONSTRAINT room_events_pkey PRIMARY KEY (id);


--
-- Name: room_invitations room_invitations_credential_digest_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_invitations
    ADD CONSTRAINT room_invitations_credential_digest_key UNIQUE (credential_digest);


--
-- Name: room_invitations room_invitations_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_invitations
    ADD CONSTRAINT room_invitations_pkey PRIMARY KEY (id);


--
-- Name: room_rules room_rules_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_rules
    ADD CONSTRAINT room_rules_pkey PRIMARY KEY (room_id);


--
-- Name: room_schedules room_schedules_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_schedules
    ADD CONSTRAINT room_schedules_pkey PRIMARY KEY (room_id);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: scoring_template_versions scoring_template_versions_pkey; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.scoring_template_versions
    ADD CONSTRAINT scoring_template_versions_pkey PRIMARY KEY (id);


--
-- Name: scoring_template_versions scoring_template_versions_rules_hash_key; Type: CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.scoring_template_versions
    ADD CONSTRAINT scoring_template_versions_rules_hash_key UNIQUE (rules_hash);


--
-- Name: account_closure_readiness account_closure_readiness_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_closure_readiness
    ADD CONSTRAINT account_closure_readiness_pkey PRIMARY KEY (correlation_id, generation, domain);


--
-- Name: account_closure_runs account_closure_runs_account_id_lifecycle_version_cancellat_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_closure_runs
    ADD CONSTRAINT account_closure_runs_account_id_lifecycle_version_cancellat_key UNIQUE (account_id, lifecycle_version, cancellation_deadline_at);


--
-- Name: account_closure_runs account_closure_runs_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_closure_runs
    ADD CONSTRAINT account_closure_runs_pkey PRIMARY KEY (correlation_id);


--
-- Name: account_consents account_consents_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_consents
    ADD CONSTRAINT account_consents_pkey PRIMARY KEY (id);


--
-- Name: account_consents account_consents_supersedes_consent_id_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_consents
    ADD CONSTRAINT account_consents_supersedes_consent_id_key UNIQUE (supersedes_consent_id);


--
-- Name: account_emails account_emails_email_lookup_hmac_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_emails
    ADD CONSTRAINT account_emails_email_lookup_hmac_key UNIQUE (email_lookup_hmac);


--
-- Name: account_emails account_emails_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_emails
    ADD CONSTRAINT account_emails_pkey PRIMARY KEY (account_id);


--
-- Name: account_identifier_quarantines account_identifier_quarantines_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_identifier_quarantines
    ADD CONSTRAINT account_identifier_quarantines_pkey PRIMARY KEY (id);


--
-- Name: account_legal_holds account_legal_holds_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_legal_holds
    ADD CONSTRAINT account_legal_holds_pkey PRIMARY KEY (id);


--
-- Name: account_lifecycle_command_receipts account_lifecycle_command_receipts_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_lifecycle_command_receipts
    ADD CONSTRAINT account_lifecycle_command_receipts_pkey PRIMARY KEY (account_id, command_type, idempotency_key);


--
-- Name: account_lifecycle_events account_lifecycle_event_account_id_uq; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_lifecycle_events
    ADD CONSTRAINT account_lifecycle_event_account_id_uq UNIQUE (account_id, id);


--
-- Name: account_lifecycle_events account_lifecycle_events_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_lifecycle_events
    ADD CONSTRAINT account_lifecycle_events_pkey PRIMARY KEY (id);


--
-- Name: account_preferences account_preferences_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_preferences
    ADD CONSTRAINT account_preferences_pkey PRIMARY KEY (account_id);


--
-- Name: account_retention_execution_attempts account_retention_execution_attempts_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_execution_attempts
    ADD CONSTRAINT account_retention_execution_attempts_pkey PRIMARY KEY (id);


--
-- Name: account_retention_obligations account_retention_obligations_lifecycle_event_id_data_categ_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_obligations
    ADD CONSTRAINT account_retention_obligations_lifecycle_event_id_data_categ_key UNIQUE (lifecycle_event_id, data_category);


--
-- Name: account_retention_obligations account_retention_obligations_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_obligations
    ADD CONSTRAINT account_retention_obligations_pkey PRIMARY KEY (id);


--
-- Name: account_retention_policy_proposals account_retention_policy_proposals_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_policy_proposals
    ADD CONSTRAINT account_retention_policy_proposals_pkey PRIMARY KEY (proposal_key);


--
-- Name: account_retention_policy_rules account_retention_policy_rules_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_policy_rules
    ADD CONSTRAINT account_retention_policy_rules_pkey PRIMARY KEY (policy_version, data_category);


--
-- Name: account_retention_policy_versions account_retention_policy_versions_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_policy_versions
    ADD CONSTRAINT account_retention_policy_versions_pkey PRIMARY KEY (version);


--
-- Name: account_sanction_command_receipts account_sanction_command_receipts_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_command_receipts
    ADD CONSTRAINT account_sanction_command_receipts_pkey PRIMARY KEY (account_id, command_type, idempotency_key);


--
-- Name: account_sanction_events account_sanction_events_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_events
    ADD CONSTRAINT account_sanction_events_pkey PRIMARY KEY (id);


--
-- Name: account_sanction_heads account_sanction_heads_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_heads
    ADD CONSTRAINT account_sanction_heads_pkey PRIMARY KEY (account_id);


--
-- Name: account_sanctions account_sanction_public_reference_uq; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanctions
    ADD CONSTRAINT account_sanction_public_reference_uq UNIQUE (public_reference);


--
-- Name: account_sanctions account_sanctions_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanctions
    ADD CONSTRAINT account_sanctions_pkey PRIMARY KEY (id);


--
-- Name: account_security_states account_security_states_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_security_states
    ADD CONSTRAINT account_security_states_pkey PRIMARY KEY (account_id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: auth_providers auth_providers_code_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.auth_providers
    ADD CONSTRAINT auth_providers_code_key UNIQUE (code);


--
-- Name: auth_providers auth_providers_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.auth_providers
    ADD CONSTRAINT auth_providers_pkey PRIMARY KEY (id);


--
-- Name: authentication_events authentication_events_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.authentication_events
    ADD CONSTRAINT authentication_events_pkey PRIMARY KEY (id);


--
-- Name: delegated_authorization_events delegated_authorization_events_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorization_events
    ADD CONSTRAINT delegated_authorization_events_pkey PRIMARY KEY (id);


--
-- Name: delegated_authorizations delegated_authorization_id_account_uq; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorizations
    ADD CONSTRAINT delegated_authorization_id_account_uq UNIQUE (id, account_id);


--
-- Name: delegated_authorizations delegated_authorization_replacement_uq; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorizations
    ADD CONSTRAINT delegated_authorization_replacement_uq UNIQUE (replaces_authorization_id);


--
-- Name: delegated_authorization_scopes delegated_authorization_scopes_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorization_scopes
    ADD CONSTRAINT delegated_authorization_scopes_pkey PRIMARY KEY (authorization_id, scope_code);


--
-- Name: delegated_authorization_strategy_targets delegated_authorization_strategy_targets_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorization_strategy_targets
    ADD CONSTRAINT delegated_authorization_strategy_targets_pkey PRIMARY KEY (authorization_id, strategy_id);


--
-- Name: delegated_authorizations delegated_authorizations_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorizations
    ADD CONSTRAINT delegated_authorizations_pkey PRIMARY KEY (id);


--
-- Name: delegated_credentials delegated_credential_authorization_id_uq; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_credentials
    ADD CONSTRAINT delegated_credential_authorization_id_uq UNIQUE (authorization_id, id);


--
-- Name: delegated_credentials delegated_credentials_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_credentials
    ADD CONSTRAINT delegated_credentials_pkey PRIMARY KEY (id);


--
-- Name: delegated_credentials delegated_credentials_token_digest_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_credentials
    ADD CONSTRAINT delegated_credentials_token_digest_key UNIQUE (token_digest);


--
-- Name: delegated_strategy_derivations delegated_strategy_derivation_command_uq; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_strategy_derivations
    ADD CONSTRAINT delegated_strategy_derivation_command_uq UNIQUE (authorization_id, idempotency_key);


--
-- Name: delegated_strategy_derivations delegated_strategy_derivation_result_uq; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_strategy_derivations
    ADD CONSTRAINT delegated_strategy_derivation_result_uq UNIQUE (result_strategy_id);


--
-- Name: delegated_strategy_derivations delegated_strategy_derivations_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_strategy_derivations
    ADD CONSTRAINT delegated_strategy_derivations_pkey PRIMARY KEY (id);


--
-- Name: device_authorization_requests device_authorization_requests_device_code_digest_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.device_authorization_requests
    ADD CONSTRAINT device_authorization_requests_device_code_digest_key UNIQUE (device_code_digest);


--
-- Name: device_authorization_requests device_authorization_requests_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.device_authorization_requests
    ADD CONSTRAINT device_authorization_requests_pkey PRIMARY KEY (id);


--
-- Name: device_authorization_requests device_authorization_requests_user_code_digest_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.device_authorization_requests
    ADD CONSTRAINT device_authorization_requests_user_code_digest_key UNIQUE (user_code_digest);


--
-- Name: email_verification_requests email_verification_requests_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.email_verification_requests
    ADD CONSTRAINT email_verification_requests_pkey PRIMARY KEY (id);


--
-- Name: email_verification_requests email_verification_requests_token_digest_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.email_verification_requests
    ADD CONSTRAINT email_verification_requests_token_digest_key UNIQUE (token_digest);


--
-- Name: login_identities login_identities_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.login_identities
    ADD CONSTRAINT login_identities_pkey PRIMARY KEY (id);


--
-- Name: oidc_step_up_nonces oidc_step_up_nonces_nonce_digest_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.oidc_step_up_nonces
    ADD CONSTRAINT oidc_step_up_nonces_nonce_digest_key UNIQUE (nonce_digest);


--
-- Name: oidc_step_up_nonces oidc_step_up_nonces_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.oidc_step_up_nonces
    ADD CONSTRAINT oidc_step_up_nonces_pkey PRIMARY KEY (id);


--
-- Name: password_credentials password_credentials_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.password_credentials
    ADD CONSTRAINT password_credentials_pkey PRIMARY KEY (login_identity_id);


--
-- Name: password_reset_requests password_reset_requests_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.password_reset_requests
    ADD CONSTRAINT password_reset_requests_pkey PRIMARY KEY (id);


--
-- Name: password_reset_requests password_reset_requests_token_digest_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.password_reset_requests
    ADD CONSTRAINT password_reset_requests_token_digest_key UNIQUE (token_digest);


--
-- Name: policy_documents policy_documents_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.policy_documents
    ADD CONSTRAINT policy_documents_pkey PRIMARY KEY (id);


--
-- Name: recovery_code_sets recovery_code_sets_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.recovery_code_sets
    ADD CONSTRAINT recovery_code_sets_pkey PRIMARY KEY (id);


--
-- Name: recovery_codes recovery_codes_code_digest_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.recovery_codes
    ADD CONSTRAINT recovery_codes_code_digest_key UNIQUE (code_digest);


--
-- Name: recovery_codes recovery_codes_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.recovery_codes
    ADD CONSTRAINT recovery_codes_pkey PRIMARY KEY (id);


--
-- Name: refresh_token_families refresh_token_families_current_token_digest_key; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.refresh_token_families
    ADD CONSTRAINT refresh_token_families_current_token_digest_key UNIQUE (current_token_digest);


--
-- Name: refresh_token_families refresh_token_families_pkey; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.refresh_token_families
    ADD CONSTRAINT refresh_token_families_pkey PRIMARY KEY (id);


--
-- Name: corporate_actions corporate_actions_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.corporate_actions
    ADD CONSTRAINT corporate_actions_pkey PRIMARY KEY (id);


--
-- Name: dataset_lineage dataset_lineage_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_lineage
    ADD CONSTRAINT dataset_lineage_pkey PRIMARY KEY (derived_manifest_id, source_manifest_id, relation_type);


--
-- Name: dataset_manifests dataset_manifests_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_manifests
    ADD CONSTRAINT dataset_manifests_pkey PRIMARY KEY (id);


--
-- Name: dataset_object_lineage dataset_object_lineage_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_object_lineage
    ADD CONSTRAINT dataset_object_lineage_pkey PRIMARY KEY (derived_dataset_object_id, source_dataset_object_id, relation_type);


--
-- Name: dataset_objects dataset_objects_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_objects
    ADD CONSTRAINT dataset_objects_pkey PRIMARY KEY (id);


--
-- Name: feature_definitions feature_definitions_definition_hash_key; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_definitions
    ADD CONSTRAINT feature_definitions_definition_hash_key UNIQUE (definition_hash);


--
-- Name: feature_definitions feature_definitions_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_definitions
    ADD CONSTRAINT feature_definitions_pkey PRIMARY KEY (id);


--
-- Name: feature_materializations feature_materializations_pipeline_run_id_key; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_materializations
    ADD CONSTRAINT feature_materializations_pipeline_run_id_key UNIQUE (pipeline_run_id);


--
-- Name: feature_materializations feature_materializations_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_materializations
    ADD CONSTRAINT feature_materializations_pkey PRIMARY KEY (id);


--
-- Name: feature_snapshot_batches feature_snapshot_batches_idempotency_key_key; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_snapshot_batches
    ADD CONSTRAINT feature_snapshot_batches_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: feature_snapshot_batches feature_snapshot_batches_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_snapshot_batches
    ADD CONSTRAINT feature_snapshot_batches_pkey PRIMARY KEY (id);


--
-- Name: feeds feeds_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feeds
    ADD CONSTRAINT feeds_pkey PRIMARY KEY (id);


--
-- Name: instrument_symbols instrument_symbols_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.instrument_symbols
    ADD CONSTRAINT instrument_symbols_pkey PRIMARY KEY (id);


--
-- Name: instruments instruments_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.instruments
    ADD CONSTRAINT instruments_pkey PRIMARY KEY (id);


--
-- Name: pipeline_runs pipeline_runs_idempotency_key_key; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.pipeline_runs
    ADD CONSTRAINT pipeline_runs_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: pipeline_runs pipeline_runs_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.pipeline_runs
    ADD CONSTRAINT pipeline_runs_pkey PRIMARY KEY (id);


--
-- Name: providers providers_code_key; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.providers
    ADD CONSTRAINT providers_code_key UNIQUE (code);


--
-- Name: providers providers_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (id);


--
-- Name: quality_incidents quality_incidents_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.quality_incidents
    ADD CONSTRAINT quality_incidents_pkey PRIMARY KEY (id);


--
-- Name: stream_watermarks stream_watermarks_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.stream_watermarks
    ADD CONSTRAINT stream_watermarks_pkey PRIMARY KEY (feed_id);


--
-- Name: trading_sessions trading_sessions_pkey; Type: CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.trading_sessions
    ADD CONSTRAINT trading_sessions_pkey PRIMARY KEY (id);


--
-- Name: account_email_notification_preferences account_email_notification_preferences_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.account_email_notification_preferences
    ADD CONSTRAINT account_email_notification_preferences_pkey PRIMARY KEY (account_id);


--
-- Name: account_integrations account_integrations_account_id_integration_code_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.account_integrations
    ADD CONSTRAINT account_integrations_account_id_integration_code_key UNIQUE (account_id, integration_code);


--
-- Name: account_integrations account_integrations_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.account_integrations
    ADD CONSTRAINT account_integrations_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_idempotency_key_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.audit_events
    ADD CONSTRAINT audit_events_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: batch_item_attempts batch_item_attempts_claim_token_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_item_attempts
    ADD CONSTRAINT batch_item_attempts_claim_token_key UNIQUE (claim_token);


--
-- Name: batch_item_attempts batch_item_attempts_pk; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_item_attempts
    ADD CONSTRAINT batch_item_attempts_pk PRIMARY KEY (batch_item_id, attempt_number);


--
-- Name: batch_items batch_item_stable_identity_unique; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_item_stable_identity_unique UNIQUE (category_code, source_key, source_version, due_at, replay_sequence);


--
-- Name: batch_items batch_items_claim_token_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_items_claim_token_key UNIQUE (claim_token);


--
-- Name: batch_items batch_items_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_items_pkey PRIMARY KEY (id);


--
-- Name: batch_items batch_items_replay_audit_event_id_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_items_replay_audit_event_id_key UNIQUE (replay_audit_event_id);


--
-- Name: batch_items batch_items_replayed_from_item_id_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_items_replayed_from_item_id_key UNIQUE (replayed_from_item_id);


--
-- Name: batch_job_versions batch_job_versions_content_hash_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_job_versions
    ADD CONSTRAINT batch_job_versions_content_hash_key UNIQUE (content_hash);


--
-- Name: batch_job_versions batch_job_versions_pk; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_job_versions
    ADD CONSTRAINT batch_job_versions_pk PRIMARY KEY (job_code, job_version);


--
-- Name: batch_run_checkpoints batch_run_checkpoints_pk; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_run_checkpoints
    ADD CONSTRAINT batch_run_checkpoints_pk PRIMARY KEY (job_code, job_version, category_code, shard_key);


--
-- Name: batch_runs batch_runs_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_runs
    ADD CONSTRAINT batch_runs_pkey PRIMARY KEY (id);


--
-- Name: batch_runs batch_runs_trigger_id_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_runs
    ADD CONSTRAINT batch_runs_trigger_id_key UNIQUE (trigger_id);


--
-- Name: cases case_account_id_uq; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.cases
    ADD CONSTRAINT case_account_id_uq UNIQUE (account_id, id);


--
-- Name: case_command_receipts case_command_receipt_event_uq; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_command_receipts
    ADD CONSTRAINT case_command_receipt_event_uq UNIQUE (case_id, case_event_id);


--
-- Name: case_command_receipts case_command_receipts_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_command_receipts
    ADD CONSTRAINT case_command_receipts_pkey PRIMARY KEY (account_id, command_type, idempotency_key);


--
-- Name: case_deadline_receipts case_deadline_receipt_event_uq; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_deadline_receipts
    ADD CONSTRAINT case_deadline_receipt_event_uq UNIQUE (case_id, case_event_id);


--
-- Name: case_deadline_receipts case_deadline_receipts_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_deadline_receipts
    ADD CONSTRAINT case_deadline_receipts_pkey PRIMARY KEY (case_id, expected_case_version, response_deadline_at);


--
-- Name: case_events case_event_case_id_uq; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_events
    ADD CONSTRAINT case_event_case_id_uq UNIQUE (case_id, id);


--
-- Name: case_events case_event_previous_uq; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_events
    ADD CONSTRAINT case_event_previous_uq UNIQUE (case_id, previous_event_id);


--
-- Name: case_events case_events_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_events
    ADD CONSTRAINT case_events_pkey PRIMARY KEY (id);


--
-- Name: case_evidence_references case_evidence_references_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_evidence_references
    ADD CONSTRAINT case_evidence_references_pkey PRIMARY KEY (case_id, storage_object_id);


--
-- Name: cases case_id_head_uq; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.cases
    ADD CONSTRAINT case_id_head_uq UNIQUE (id, last_case_event_id);


--
-- Name: cases cases_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (id);


--
-- Name: delivery_attempts delivery_attempts_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.delivery_attempts
    ADD CONSTRAINT delivery_attempts_pkey PRIMARY KEY (id);


--
-- Name: notification_policies notification_policies_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.notification_policies
    ADD CONSTRAINT notification_policies_pkey PRIMARY KEY (type_code, policy_version);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_idempotency_key_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.notifications
    ADD CONSTRAINT notifications_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: operator_accounts operator_accounts_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_accounts
    ADD CONSTRAINT operator_accounts_pkey PRIMARY KEY (id);


--
-- Name: operator_bootstrap_receipts operator_bootstrap_assignment_unique; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_bootstrap_receipts
    ADD CONSTRAINT operator_bootstrap_assignment_unique UNIQUE (operator_account_id, operator_role_assignment_id);


--
-- Name: operator_bootstrap_receipts operator_bootstrap_receipts_audit_event_id_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_bootstrap_receipts
    ADD CONSTRAINT operator_bootstrap_receipts_audit_event_id_key UNIQUE (audit_event_id);


--
-- Name: operator_bootstrap_receipts operator_bootstrap_receipts_manifest_hash_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_bootstrap_receipts
    ADD CONSTRAINT operator_bootstrap_receipts_manifest_hash_key UNIQUE (manifest_hash);


--
-- Name: operator_bootstrap_receipts operator_bootstrap_receipts_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_bootstrap_receipts
    ADD CONSTRAINT operator_bootstrap_receipts_pkey PRIMARY KEY (bootstrap_key);


--
-- Name: operator_case_command_receipts operator_case_command_receipts_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_case_command_receipts
    ADD CONSTRAINT operator_case_command_receipts_pkey PRIMARY KEY (operator_id, command_type, idempotency_key);


--
-- Name: operator_role_assignments operator_role_assignments_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_role_assignments
    ADD CONSTRAINT operator_role_assignments_pkey PRIMARY KEY (id);


--
-- Name: outbox_consumer_receipts outbox_consumer_receipts_claim_token_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_consumer_receipts
    ADD CONSTRAINT outbox_consumer_receipts_claim_token_key UNIQUE (claim_token);


--
-- Name: outbox_consumer_receipts outbox_consumer_receipts_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_consumer_receipts
    ADD CONSTRAINT outbox_consumer_receipts_pkey PRIMARY KEY (consumer_handler_id, outbox_message_id);


--
-- Name: outbox_delivery_attempts outbox_delivery_attempts_claim_token_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_delivery_attempts
    ADD CONSTRAINT outbox_delivery_attempts_claim_token_key UNIQUE (claim_token);


--
-- Name: outbox_delivery_attempts outbox_delivery_attempts_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_delivery_attempts
    ADD CONSTRAINT outbox_delivery_attempts_pkey PRIMARY KEY (outbox_message_id, attempt_number);


--
-- Name: outbox_messages outbox_messages_idempotency_key_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_messages
    ADD CONSTRAINT outbox_messages_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: outbox_messages outbox_messages_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_messages
    ADD CONSTRAINT outbox_messages_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_code_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.permissions
    ADD CONSTRAINT permissions_code_key UNIQUE (code);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: projection_checkpoints projection_checkpoints_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.projection_checkpoints
    ADD CONSTRAINT projection_checkpoints_pkey PRIMARY KEY (id);


--
-- Name: rbac_catalog_permissions rbac_catalog_permissions_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_permissions
    ADD CONSTRAINT rbac_catalog_permissions_pkey PRIMARY KEY (catalog_version, permission_id);


--
-- Name: rbac_catalog_role_permissions rbac_catalog_role_permissions_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_role_permissions
    ADD CONSTRAINT rbac_catalog_role_permissions_pkey PRIMARY KEY (catalog_version, role_id, permission_id);


--
-- Name: rbac_catalog_roles rbac_catalog_roles_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_roles
    ADD CONSTRAINT rbac_catalog_roles_pkey PRIMARY KEY (catalog_version, role_id);


--
-- Name: rbac_catalog_versions rbac_catalog_versions_content_hash_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_versions
    ADD CONSTRAINT rbac_catalog_versions_content_hash_key UNIQUE (content_hash);


--
-- Name: rbac_catalog_versions rbac_catalog_versions_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_versions
    ADD CONSTRAINT rbac_catalog_versions_pkey PRIMARY KEY (catalog_version);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_id);


--
-- Name: roles roles_code_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.roles
    ADD CONSTRAINT roles_code_key UNIQUE (code);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: bot_current_projections bot_current_projections_pkey; Type: CONSTRAINT; Schema: performance; Owner: -
--

ALTER TABLE ONLY performance.bot_current_projections
    ADD CONSTRAINT bot_current_projections_pkey PRIMARY KEY (bot_id);


--
-- Name: bot_snapshots bot_snapshots_pkey; Type: CONSTRAINT; Schema: performance; Owner: -
--

ALTER TABLE ONLY performance.bot_snapshots
    ADD CONSTRAINT bot_snapshots_pkey PRIMARY KEY (id);


--
-- Name: series_manifests series_manifests_pkey; Type: CONSTRAINT; Schema: performance; Owner: -
--

ALTER TABLE ONLY performance.series_manifests
    ADD CONSTRAINT series_manifests_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: compiled_flow_plans compiled_flow_plans_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.compiled_flow_plans
    ADD CONSTRAINT compiled_flow_plans_pkey PRIMARY KEY (id);


--
-- Name: compiled_flow_plans compiled_flow_plans_plan_hash_key; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.compiled_flow_plans
    ADD CONSTRAINT compiled_flow_plans_plan_hash_key UNIQUE (plan_hash);


--
-- Name: element_catalog_versions element_catalog_versions_definition_hash_key; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.element_catalog_versions
    ADD CONSTRAINT element_catalog_versions_definition_hash_key UNIQUE (definition_hash);


--
-- Name: element_catalog_versions element_catalog_versions_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.element_catalog_versions
    ADD CONSTRAINT element_catalog_versions_pkey PRIMARY KEY (id);


--
-- Name: element_definitions element_definitions_definition_hash_key; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.element_definitions
    ADD CONSTRAINT element_definitions_definition_hash_key UNIQUE (definition_hash);


--
-- Name: element_definitions element_definitions_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.element_definitions
    ADD CONSTRAINT element_definitions_pkey PRIMARY KEY (id);


--
-- Name: package_versions package_versions_content_hash_key; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.package_versions
    ADD CONSTRAINT package_versions_content_hash_key UNIQUE (content_hash);


--
-- Name: package_versions package_versions_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.package_versions
    ADD CONSTRAINT package_versions_pkey PRIMARY KEY (id);


--
-- Name: packages packages_code_key; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.packages
    ADD CONSTRAINT packages_code_key UNIQUE (code);


--
-- Name: packages packages_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.packages
    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);


--
-- Name: strategies strategies_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategies
    ADD CONSTRAINT strategies_pkey PRIMARY KEY (id);


--
-- Name: strategy_documents strategy_documents_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategy_documents
    ADD CONSTRAINT strategy_documents_pkey PRIMARY KEY (strategy_id);


--
-- Name: strategy_edit_leases strategy_edit_leases_lease_token_digest_key; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategy_edit_leases
    ADD CONSTRAINT strategy_edit_leases_lease_token_digest_key UNIQUE (lease_token_digest);


--
-- Name: strategy_edit_leases strategy_edit_leases_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategy_edit_leases
    ADD CONSTRAINT strategy_edit_leases_pkey PRIMARY KEY (strategy_id);


--
-- Name: strategies strategy_id_owner_uq; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategies
    ADD CONSTRAINT strategy_id_owner_uq UNIQUE (id, owner_account_id);


--
-- Name: template_versions template_versions_content_hash_key; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.template_versions
    ADD CONSTRAINT template_versions_content_hash_key UNIQUE (content_hash);


--
-- Name: template_versions template_versions_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.template_versions
    ADD CONSTRAINT template_versions_pkey PRIMARY KEY (id);


--
-- Name: templates templates_code_key; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.templates
    ADD CONSTRAINT templates_code_key UNIQUE (code);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: validation_runs validation_runs_pkey; Type: CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.validation_runs
    ADD CONSTRAINT validation_runs_pkey PRIMARY KEY (id);


--
-- Name: bot_budget_projections bot_budget_projections_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.bot_budget_projections
    ADD CONSTRAINT bot_budget_projections_pkey PRIMARY KEY (bot_id);


--
-- Name: buying_power_buffer_policy_versions buying_power_buffer_policy_versions_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.buying_power_buffer_policy_versions
    ADD CONSTRAINT buying_power_buffer_policy_versions_pkey PRIMARY KEY (id);


--
-- Name: buying_power_buffer_policy_versions buying_power_buffer_policy_versions_rules_hash_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.buying_power_buffer_policy_versions
    ADD CONSTRAINT buying_power_buffer_policy_versions_rules_hash_key UNIQUE (rules_hash);


--
-- Name: candidate_batch_processing candidate_batch_processing_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.candidate_batch_processing
    ADD CONSTRAINT candidate_batch_processing_pkey PRIMARY KEY (batch_id);


--
-- Name: fee_policy_versions fee_policy_versions_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fee_policy_versions
    ADD CONSTRAINT fee_policy_versions_pkey PRIMARY KEY (id);


--
-- Name: fee_policy_versions fee_policy_versions_rules_hash_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fee_policy_versions
    ADD CONSTRAINT fee_policy_versions_rules_hash_key UNIQUE (rules_hash);


--
-- Name: fill_adjustments fill_adjustments_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fill_adjustments
    ADD CONSTRAINT fill_adjustments_pkey PRIMARY KEY (id);


--
-- Name: fill_component_allocations fill_component_allocations_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fill_component_allocations
    ADD CONSTRAINT fill_component_allocations_pkey PRIMARY KEY (id);


--
-- Name: fills fills_bot_event_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fills
    ADD CONSTRAINT fills_bot_event_id_key UNIQUE (bot_event_id);


--
-- Name: fills fills_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fills
    ADD CONSTRAINT fills_pkey PRIMARY KEY (id);


--
-- Name: flow_position_projections flow_position_projections_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.flow_position_projections
    ADD CONSTRAINT flow_position_projections_pkey PRIMARY KEY (flow_id, instrument_id);


--
-- Name: ledger_accounts ledger_accounts_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_accounts
    ADD CONSTRAINT ledger_accounts_pkey PRIMARY KEY (id);


--
-- Name: ledger_entries ledger_entries_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_entries
    ADD CONSTRAINT ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: ledger_transactions ledger_transactions_bot_event_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_transactions
    ADD CONSTRAINT ledger_transactions_bot_event_id_key UNIQUE (bot_event_id);


--
-- Name: ledger_transactions ledger_transactions_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_transactions
    ADD CONSTRAINT ledger_transactions_pkey PRIMARY KEY (id);


--
-- Name: lot_movements lot_movements_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.lot_movements
    ADD CONSTRAINT lot_movements_pkey PRIMARY KEY (id);


--
-- Name: order_component_reservations order_component_reservations_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_component_reservations
    ADD CONSTRAINT order_component_reservations_pkey PRIMARY KEY (reservation_id);


--
-- Name: order_components order_components_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_components
    ADD CONSTRAINT order_components_pkey PRIMARY KEY (id);


--
-- Name: order_events order_events_bot_event_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_events
    ADD CONSTRAINT order_events_bot_event_id_key UNIQUE (bot_event_id);


--
-- Name: order_events order_events_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_events
    ADD CONSTRAINT order_events_pkey PRIMARY KEY (id);


--
-- Name: order_group_events order_group_events_bot_event_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_group_events
    ADD CONSTRAINT order_group_events_bot_event_id_key UNIQUE (bot_event_id);


--
-- Name: order_group_events order_group_events_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_group_events
    ADD CONSTRAINT order_group_events_pkey PRIMARY KEY (id);


--
-- Name: order_group_members order_group_members_order_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_group_members
    ADD CONSTRAINT order_group_members_order_id_key UNIQUE (order_id);


--
-- Name: order_group_members order_group_members_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_group_members
    ADD CONSTRAINT order_group_members_pkey PRIMARY KEY (order_group_id, order_id);


--
-- Name: order_groups order_groups_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_groups
    ADD CONSTRAINT order_groups_pkey PRIMARY KEY (id);


--
-- Name: order_intent_batches order_intent_batches_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intent_batches
    ADD CONSTRAINT order_intent_batches_pkey PRIMARY KEY (id);


--
-- Name: order_intents order_intents_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intents
    ADD CONSTRAINT order_intents_pkey PRIMARY KEY (id);


--
-- Name: order_state_projections order_state_projections_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_state_projections
    ADD CONSTRAINT order_state_projections_pkey PRIMARY KEY (order_id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: orders orders_replaces_order_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.orders
    ADD CONSTRAINT orders_replaces_order_id_key UNIQUE (replaces_order_id);


--
-- Name: partition_budget_projections partition_budget_projections_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.partition_budget_projections
    ADD CONSTRAINT partition_budget_projections_pkey PRIMARY KEY (partition_id);


--
-- Name: partition_position_projections partition_position_projections_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.partition_position_projections
    ADD CONSTRAINT partition_position_projections_pkey PRIMARY KEY (partition_id, instrument_id);


--
-- Name: position_lot_projections position_lot_projections_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lot_projections
    ADD CONSTRAINT position_lot_projections_pkey PRIMARY KEY (position_lot_id);


--
-- Name: position_lot_reservations position_lot_reservations_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lot_reservations
    ADD CONSTRAINT position_lot_reservations_pkey PRIMARY KEY (reservation_id, position_lot_id);


--
-- Name: position_lots position_lots_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lots
    ADD CONSTRAINT position_lots_pkey PRIMARY KEY (id);


--
-- Name: reservation_events reservation_events_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.reservation_events
    ADD CONSTRAINT reservation_events_pkey PRIMARY KEY (id);


--
-- Name: resource_reservations resource_reservations_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_pkey PRIMARY KEY (id);


--
-- Name: short_borrow_fee_accruals short_borrow_fee_accruals_bot_event_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_accruals
    ADD CONSTRAINT short_borrow_fee_accruals_bot_event_id_key UNIQUE (bot_event_id);


--
-- Name: short_borrow_fee_accruals short_borrow_fee_accruals_ledger_transaction_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_accruals
    ADD CONSTRAINT short_borrow_fee_accruals_ledger_transaction_id_key UNIQUE (ledger_transaction_id);


--
-- Name: short_borrow_fee_accruals short_borrow_fee_accruals_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_accruals
    ADD CONSTRAINT short_borrow_fee_accruals_pkey PRIMARY KEY (id);


--
-- Name: short_borrow_fee_policy_versions short_borrow_fee_policy_versions_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_policy_versions
    ADD CONSTRAINT short_borrow_fee_policy_versions_pkey PRIMARY KEY (id);


--
-- Name: short_borrow_fee_policy_versions short_borrow_fee_policy_versions_rules_hash_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_policy_versions
    ADD CONSTRAINT short_borrow_fee_policy_versions_rules_hash_key UNIQUE (rules_hash);


--
-- Name: short_risk_policy_versions short_risk_policy_versions_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_risk_policy_versions
    ADD CONSTRAINT short_risk_policy_versions_pkey PRIMARY KEY (id);


--
-- Name: short_risk_policy_versions short_risk_policy_versions_rules_hash_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_risk_policy_versions
    ADD CONSTRAINT short_risk_policy_versions_rules_hash_key UNIQUE (rules_hash);


--
-- Name: short_trade_checks short_trade_checks_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_trade_checks
    ADD CONSTRAINT short_trade_checks_pkey PRIMARY KEY (intent_id);


--
-- Name: system_close_actions system_close_actions_generated_intent_id_key; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.system_close_actions
    ADD CONSTRAINT system_close_actions_generated_intent_id_key UNIQUE (generated_intent_id);


--
-- Name: system_close_actions system_close_actions_pkey; Type: CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.system_close_actions
    ADD CONSTRAINT system_close_actions_pkey PRIMARY KEY (id);


--
-- Name: detail_manifests_object_id_idx; Type: INDEX; Schema: backtest; Owner: -
--

CREATE UNIQUE INDEX detail_manifests_object_id_idx ON backtest.detail_manifests USING btree (object_id);


--
-- Name: detail_manifests_run_id_record_type_week_start_date_part_nu_idx; Type: INDEX; Schema: backtest; Owner: -
--

CREATE UNIQUE INDEX detail_manifests_run_id_record_type_week_start_date_part_nu_idx ON backtest.detail_manifests USING btree (run_id, record_type, week_start_date, part_number);


--
-- Name: failure_condition_counts_monthly_summary_id_flow_or_branch__idx; Type: INDEX; Schema: backtest; Owner: -
--

CREATE UNIQUE INDEX failure_condition_counts_monthly_summary_id_flow_or_branch__idx ON backtest.failure_condition_counts USING btree (monthly_summary_id, flow_or_branch_key, first_failure_condition_key);


--
-- Name: ix_backtest_run_attempt_expiry; Type: INDEX; Schema: backtest; Owner: -
--

CREATE INDEX ix_backtest_run_attempt_expiry ON backtest.run_attempts USING btree (run_id, claim_expires_at);


--
-- Name: ix_backtest_run_execution_policy; Type: INDEX; Schema: backtest; Owner: -
--

CREATE INDEX ix_backtest_run_execution_policy ON backtest.runs USING btree (execution_policy_version, queued_at);


--
-- Name: monthly_judgment_summaries_run_id_et_year_month_idx; Type: INDEX; Schema: backtest; Owner: -
--

CREATE UNIQUE INDEX monthly_judgment_summaries_run_id_et_year_month_idx ON backtest.monthly_judgment_summaries USING btree (run_id, et_year_month);


--
-- Name: run_attempts_run_id_attempt_number_idx; Type: INDEX; Schema: backtest; Owner: -
--

CREATE UNIQUE INDEX run_attempts_run_id_attempt_number_idx ON backtest.run_attempts USING btree (run_id, attempt_number);


--
-- Name: runs_bot_id_queued_at_idx; Type: INDEX; Schema: backtest; Owner: -
--

CREATE INDEX runs_bot_id_queued_at_idx ON backtest.runs USING btree (bot_id, queued_at);


--
-- Name: runs_owner_account_id_queued_at_idx; Type: INDEX; Schema: backtest; Owner: -
--

CREATE INDEX runs_owner_account_id_queued_at_idx ON backtest.runs USING btree (owner_account_id, queued_at);


--
-- Name: runs_status_queued_at_idx; Type: INDEX; Schema: backtest; Owner: -
--

CREATE INDEX runs_status_queued_at_idx ON backtest.runs USING btree (status, queued_at);


--
-- Name: uq_backtest_run_attempt_claim_token; Type: INDEX; Schema: backtest; Owner: -
--

CREATE UNIQUE INDEX uq_backtest_run_attempt_claim_token ON backtest.run_attempts USING btree (claim_token) WHERE (claim_token IS NOT NULL);


--
-- Name: uq_backtest_run_idempotency; Type: INDEX; Schema: backtest; Owner: -
--

CREATE UNIQUE INDEX uq_backtest_run_idempotency ON backtest.runs USING btree (lane, idempotency_scope, idempotency_key);


--
-- Name: uq_backtest_run_message_id; Type: INDEX; Schema: backtest; Owner: -
--

CREATE UNIQUE INDEX uq_backtest_run_message_id ON backtest.runs USING btree (message_id);


--
-- Name: bot_events_bot_id_event_sequence_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX bot_events_bot_id_event_sequence_idx ON bot.bot_events USING btree (bot_id, event_sequence);


--
-- Name: bot_events_bot_id_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX bot_events_bot_id_id_idx ON bot.bot_events USING btree (bot_id, id);


--
-- Name: bot_events_bot_id_idempotency_key_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX bot_events_bot_id_idempotency_key_idx ON bot.bot_events USING btree (bot_id, idempotency_key);


--
-- Name: bot_events_correlation_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX bot_events_correlation_id_idx ON bot.bot_events USING btree (correlation_id);


--
-- Name: bot_events_event_type_committed_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX bot_events_event_type_committed_at_idx ON bot.bot_events USING btree (event_type, committed_at);


--
-- Name: bot_partitions_bot_id_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX bot_partitions_bot_id_id_idx ON bot.bot_partitions USING btree (bot_id, id);


--
-- Name: bot_partitions_bot_id_position_y_position_x_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX bot_partitions_bot_id_position_y_position_x_id_idx ON bot.bot_partitions USING btree (bot_id, position_y, position_x, id);


--
-- Name: bots_lifecycle_status_execution_blocked_at_created_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX bots_lifecycle_status_execution_blocked_at_created_at_idx ON bot.bots USING btree (lifecycle_status, execution_blocked_at, created_at);


--
-- Name: bots_lifecycle_status_execution_eligible_from_created_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX bots_lifecycle_status_execution_eligible_from_created_at_idx ON bot.bots USING btree (lifecycle_status, execution_eligible_from, created_at);


--
-- Name: bots_owner_account_id_deleted_at_archived_at_created_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX bots_owner_account_id_deleted_at_archived_at_created_at_idx ON bot.bots USING btree (owner_account_id, deleted_at, archived_at, created_at);


--
-- Name: bots_owner_account_id_lifecycle_status_created_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX bots_owner_account_id_lifecycle_status_created_at_idx ON bot.bots USING btree (owner_account_id, lifecycle_status, created_at);


--
-- Name: continuation_deadlines_due_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX continuation_deadlines_due_at_idx ON bot.continuation_deadlines USING btree (due_at);


--
-- Name: evaluation_runs_bot_id_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX evaluation_runs_bot_id_id_idx ON bot.evaluation_runs USING btree (bot_id, id);


--
-- Name: evaluation_runs_bot_id_queued_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX evaluation_runs_bot_id_queued_at_idx ON bot.evaluation_runs USING btree (bot_id, queued_at);


--
-- Name: evaluation_runs_feature_snapshot_batch_id_feature_snapshot__idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX evaluation_runs_feature_snapshot_batch_id_feature_snapshot__idx ON bot.evaluation_runs USING btree (feature_snapshot_batch_id, feature_snapshot_key);


--
-- Name: evaluation_runs_flow_id_queued_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX evaluation_runs_flow_id_queued_at_idx ON bot.evaluation_runs USING btree (flow_id, queued_at);


--
-- Name: evaluation_runs_status_lease_expires_at_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX evaluation_runs_status_lease_expires_at_idx ON bot.evaluation_runs USING btree (status, lease_expires_at);


--
-- Name: evaluation_runs_trigger_event_id_flow_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX evaluation_runs_trigger_event_id_flow_id_idx ON bot.evaluation_runs USING btree (trigger_event_id, flow_id);


--
-- Name: flow_feature_requirements_feature_definition_id_instrument__idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX flow_feature_requirements_feature_definition_id_instrument__idx ON bot.flow_feature_requirements USING btree (feature_definition_id, instrument_id, flow_id);


--
-- Name: flow_time_triggers_trigger_type_schedule_key_flow_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX flow_time_triggers_trigger_type_schedule_key_flow_id_idx ON bot.flow_time_triggers USING btree (trigger_type, schedule_key, flow_id);


--
-- Name: flows_partition_id_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX flows_partition_id_id_idx ON bot.flows USING btree (partition_id, id);


--
-- Name: flows_partition_id_position_y_position_x_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX flows_partition_id_position_y_position_x_id_idx ON bot.flows USING btree (partition_id, position_y, position_x, id);


--
-- Name: flows_semantic_hash_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX flows_semantic_hash_idx ON bot.flows USING btree (semantic_hash);


--
-- Name: launch_snapshots_semantic_hash_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX launch_snapshots_semantic_hash_idx ON bot.launch_snapshots USING btree (semantic_hash);


--
-- Name: launch_snapshots_snapshot_hash_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX launch_snapshots_snapshot_hash_idx ON bot.launch_snapshots USING btree (snapshot_hash);


--
-- Name: runtime_state_values_bot_id_id_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX runtime_state_values_bot_id_id_idx ON bot.runtime_state_values USING btree (bot_id, id);


--
-- Name: runtime_state_values_bot_id_last_event_sequence_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE INDEX runtime_state_values_bot_id_last_event_sequence_idx ON bot.runtime_state_values USING btree (bot_id, last_event_sequence);


--
-- Name: runtime_state_values_bot_id_partition_id_flow_id_element_in_idx; Type: INDEX; Schema: bot; Owner: -
--

CREATE UNIQUE INDEX runtime_state_values_bot_id_partition_id_flow_id_element_in_idx ON bot.runtime_state_values USING btree (bot_id, partition_id, flow_id, element_instance_key, state_definition_key, instrument_id);


--
-- Name: backtest_aggregate_results_evaluation_plan_room_id_publishe_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE INDEX backtest_aggregate_results_evaluation_plan_room_id_publishe_idx ON competition.backtest_aggregate_results USING btree (evaluation_plan_room_id, published_at);


--
-- Name: backtest_evaluation_periods_evaluation_plan_room_id_evaluat_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX backtest_evaluation_periods_evaluation_plan_room_id_evaluat_idx ON competition.backtest_evaluation_periods USING btree (evaluation_plan_room_id, evaluation_start, evaluation_end);


--
-- Name: backtest_evaluation_periods_evaluation_plan_room_id_period__idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX backtest_evaluation_periods_evaluation_plan_room_id_period__idx ON competition.backtest_evaluation_periods USING btree (evaluation_plan_room_id, period_sequence);


--
-- Name: backtest_period_runs_run_id_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX backtest_period_runs_run_id_idx ON competition.backtest_period_runs USING btree (run_id);


--
-- Name: leaderboard_entries_snapshot_id_rank_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE INDEX leaderboard_entries_snapshot_id_rank_idx ON competition.leaderboard_entries USING btree (snapshot_id, rank);


--
-- Name: leaderboard_snapshots_room_id_cutoff_at_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX leaderboard_snapshots_room_id_cutoff_at_idx ON competition.leaderboard_snapshots USING btree (room_id, cutoff_at);


--
-- Name: live_evaluation_segments_participation_id_starts_at_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX live_evaluation_segments_participation_id_starts_at_idx ON competition.live_evaluation_segments USING btree (participation_id, starts_at);


--
-- Name: participation_events_participation_id_event_sequence_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX participation_events_participation_id_event_sequence_idx ON competition.participation_events USING btree (participation_id, event_sequence);


--
-- Name: participations_room_id_anonymous_alias_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX participations_room_id_anonymous_alias_idx ON competition.participations USING btree (room_id, anonymous_alias);


--
-- Name: participations_room_id_owner_account_id_status_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE INDEX participations_room_id_owner_account_id_status_idx ON competition.participations USING btree (room_id, owner_account_id, status);


--
-- Name: participations_room_id_status_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE INDEX participations_room_id_status_idx ON competition.participations USING btree (room_id, status);


--
-- Name: room_evaluation_account_result_pending_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE INDEX room_evaluation_account_result_pending_idx ON competition.room_evaluation_account_results USING btree (participation_id, received_at) WHERE (applied_at IS NULL);


--
-- Name: room_events_room_id_event_sequence_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX room_events_room_id_event_sequence_idx ON competition.room_events USING btree (room_id, event_sequence);


--
-- Name: room_invitations_room_id_revoked_at_expires_at_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE INDEX room_invitations_room_id_revoked_at_expires_at_idx ON competition.room_invitations USING btree (room_id, revoked_at, expires_at);


--
-- Name: rooms_competition_type_organizer_type_status_created_at_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE INDEX rooms_competition_type_organizer_type_status_created_at_idx ON competition.rooms USING btree (competition_type, organizer_type, status, created_at);


--
-- Name: rooms_creator_account_id_created_at_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE INDEX rooms_creator_account_id_created_at_idx ON competition.rooms USING btree (creator_account_id, created_at);


--
-- Name: scoring_template_versions_template_code_version_idx; Type: INDEX; Schema: competition; Owner: -
--

CREATE UNIQUE INDEX scoring_template_versions_template_code_version_idx ON competition.scoring_template_versions USING btree (template_code, version);


--
-- Name: account_closure_readiness_account_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_closure_readiness_account_idx ON identity.account_closure_readiness USING btree (account_id, status, observed_at);


--
-- Name: account_consents_account_id_policy_document_id_recorded_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_consents_account_id_policy_document_id_recorded_at_idx ON identity.account_consents USING btree (account_id, policy_document_id, recorded_at);


--
-- Name: account_emails_status_created_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_emails_status_created_at_idx ON identity.account_emails USING btree (status, created_at);


--
-- Name: account_identifier_quarantine_account_kind_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_identifier_quarantine_account_kind_idx ON identity.account_identifier_quarantines USING btree (account_id, identifier_kind);


--
-- Name: account_identifier_quarantine_active_fingerprint_uq; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX account_identifier_quarantine_active_fingerprint_uq ON identity.account_identifier_quarantines USING btree (identifier_kind, provider_code, identifier_fingerprint) WHERE (released_at IS NULL);


--
-- Name: account_identifier_quarantine_due_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_identifier_quarantine_due_idx ON identity.account_identifier_quarantines USING btree (reuse_eligible_at, released_at);


--
-- Name: account_legal_hold_account_category_status_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_legal_hold_account_category_status_idx ON identity.account_legal_holds USING btree (account_id, data_category, status);


--
-- Name: account_legal_hold_active_uq; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX account_legal_hold_active_uq ON identity.account_legal_holds USING btree (account_id, data_category) WHERE (status = 'ACTIVE'::identity.legal_hold_status);


--
-- Name: account_legal_hold_status_applied_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_legal_hold_status_applied_idx ON identity.account_legal_holds USING btree (status, applied_at);


--
-- Name: account_lifecycle_closing_deadline_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_lifecycle_closing_deadline_idx ON identity.accounts USING btree (lifecycle_status, cancellation_deadline_at);


--
-- Name: account_lifecycle_dormancy_scan_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_lifecycle_dormancy_scan_idx ON identity.accounts USING btree (lifecycle_status, last_successful_auth_at);


--
-- Name: account_lifecycle_event_command_idempotency_uq; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX account_lifecycle_event_command_idempotency_uq ON identity.account_lifecycle_events USING btree (account_id, command_type, idempotency_key);


--
-- Name: account_lifecycle_event_genesis_uq; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX account_lifecycle_event_genesis_uq ON identity.account_lifecycle_events USING btree (account_id) WHERE (previous_event_id IS NULL);


--
-- Name: account_lifecycle_event_predecessor_uq; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX account_lifecycle_event_predecessor_uq ON identity.account_lifecycle_events USING btree (account_id, previous_event_id) WHERE (previous_event_id IS NOT NULL);


--
-- Name: account_lifecycle_events_account_id_event_sequence_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX account_lifecycle_events_account_id_event_sequence_idx ON identity.account_lifecycle_events USING btree (account_id, event_sequence);


--
-- Name: account_lifecycle_events_account_id_occurred_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_lifecycle_events_account_id_occurred_at_idx ON identity.account_lifecycle_events USING btree (account_id, occurred_at);


--
-- Name: account_lifecycle_receipt_completed_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_lifecycle_receipt_completed_idx ON identity.account_lifecycle_command_receipts USING btree (completed_at);


--
-- Name: account_retention_account_category_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_retention_account_category_idx ON identity.account_retention_obligations USING btree (account_id, data_category);


--
-- Name: account_retention_attempt_held_state_uq; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX account_retention_attempt_held_state_uq ON identity.account_retention_execution_attempts USING btree (obligation_id, legal_hold_id, outcome) WHERE ((outcome)::text = 'HELD'::text);


--
-- Name: account_retention_attempt_obligation_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_retention_attempt_obligation_idx ON identity.account_retention_execution_attempts USING btree (obligation_id, occurred_at);


--
-- Name: account_retention_due_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_retention_due_idx ON identity.account_retention_obligations USING btree (status, retain_until);


--
-- Name: account_sanction_due_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_sanction_due_idx ON identity.account_sanctions USING btree (expires_at, account_id, id) WHERE ((status = 'ACTIVE'::identity.sanction_status) AND ((sanction_type)::text = 'SUSPENSION'::text));


--
-- Name: account_sanction_event_account_time_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_sanction_event_account_time_idx ON identity.account_sanction_events USING btree (account_id, occurred_at, sanction_id);


--
-- Name: account_sanction_events_occurred_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_sanction_events_occurred_at_idx ON identity.account_sanction_events USING btree (occurred_at);


--
-- Name: account_sanction_events_sanction_id_event_sequence_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX account_sanction_events_sanction_id_event_sequence_idx ON identity.account_sanction_events USING btree (sanction_id, event_sequence);


--
-- Name: account_sanctions_account_id_effective_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_sanctions_account_id_effective_at_idx ON identity.account_sanctions USING btree (account_id, effective_at);


--
-- Name: account_sanctions_status_expires_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX account_sanctions_status_expires_at_idx ON identity.account_sanctions USING btree (status, expires_at);


--
-- Name: accounts_lifecycle_status_created_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX accounts_lifecycle_status_created_at_idx ON identity.accounts USING btree (lifecycle_status, created_at);


--
-- Name: authentication_events_account_id_event_sequence_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX authentication_events_account_id_event_sequence_idx ON identity.authentication_events USING btree (account_id, event_sequence);


--
-- Name: authentication_events_account_id_idempotency_key_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX authentication_events_account_id_idempotency_key_idx ON identity.authentication_events USING btree (account_id, idempotency_key);


--
-- Name: authentication_events_correlation_id_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX authentication_events_correlation_id_idx ON identity.authentication_events USING btree (correlation_id);


--
-- Name: authentication_events_event_type_occurred_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX authentication_events_event_type_occurred_at_idx ON identity.authentication_events USING btree (event_type, occurred_at);


--
-- Name: delegated_authorization_event_authorization_id_event_sequen_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX delegated_authorization_event_authorization_id_event_sequen_idx ON identity.delegated_authorization_events USING btree (authorization_id, event_sequence);


--
-- Name: delegated_authorization_event_authorization_id_idempotency__idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX delegated_authorization_event_authorization_id_idempotency__idx ON identity.delegated_authorization_events USING btree (authorization_id, idempotency_key);


--
-- Name: delegated_authorization_events_correlation_id_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX delegated_authorization_events_correlation_id_idx ON identity.delegated_authorization_events USING btree (correlation_id);


--
-- Name: delegated_authorizations_account_id_status_authorized_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX delegated_authorizations_account_id_status_authorized_at_idx ON identity.delegated_authorizations USING btree (account_id, status, authorized_at);


--
-- Name: delegated_authorizations_status_expires_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX delegated_authorizations_status_expires_at_idx ON identity.delegated_authorizations USING btree (status, expires_at);


--
-- Name: delegated_credentials_authorization_id_credential_type_expi_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX delegated_credentials_authorization_id_credential_type_expi_idx ON identity.delegated_credentials USING btree (authorization_id, credential_type, expires_at);


--
-- Name: delegated_credentials_expires_at_revoked_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX delegated_credentials_expires_at_revoked_at_idx ON identity.delegated_credentials USING btree (expires_at, revoked_at);


--
-- Name: delegated_strategy_derivation_authorization_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX delegated_strategy_derivation_authorization_idx ON identity.delegated_strategy_derivations USING btree (authorization_id, created_at);


--
-- Name: delegated_strategy_target_strategy_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX delegated_strategy_target_strategy_idx ON identity.delegated_authorization_strategy_targets USING btree (strategy_id, authorization_id);


--
-- Name: device_authorization_requests_approved_account_id_requested_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX device_authorization_requests_approved_account_id_requested_idx ON identity.device_authorization_requests USING btree (approved_account_id, requested_at);


--
-- Name: device_authorization_requests_status_expires_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX device_authorization_requests_status_expires_at_idx ON identity.device_authorization_requests USING btree (status, expires_at);


--
-- Name: email_verification_one_open_per_account; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX email_verification_one_open_per_account ON identity.email_verification_requests USING btree (account_id) WHERE ((consumed_at IS NULL) AND (revoked_at IS NULL));


--
-- Name: email_verification_requests_account_id_requested_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX email_verification_requests_account_id_requested_at_idx ON identity.email_verification_requests USING btree (account_id, requested_at);


--
-- Name: email_verification_requests_expires_at_consumed_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX email_verification_requests_expires_at_consumed_at_idx ON identity.email_verification_requests USING btree (expires_at, consumed_at);


--
-- Name: login_identities_account_id_id_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX login_identities_account_id_id_idx ON identity.login_identities USING btree (account_id, id);


--
-- Name: login_identities_account_id_status_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX login_identities_account_id_status_idx ON identity.login_identities USING btree (account_id, status);


--
-- Name: login_identities_provider_id_provider_subject_hmac_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX login_identities_provider_id_provider_subject_hmac_idx ON identity.login_identities USING btree (provider_id, provider_subject_hmac);


--
-- Name: login_identity_one_active_per_account; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX login_identity_one_active_per_account ON identity.login_identities USING btree (account_id) WHERE (status = 'ACTIVE'::identity.login_identity_status);


--
-- Name: login_identity_one_pending_per_account; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX login_identity_one_pending_per_account ON identity.login_identities USING btree (account_id) WHERE (status = 'PENDING'::identity.login_identity_status);


--
-- Name: oidc_step_up_nonce_expiry_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX oidc_step_up_nonce_expiry_idx ON identity.oidc_step_up_nonces USING btree (expires_at) WHERE (consumed_at IS NULL);


--
-- Name: oidc_step_up_nonce_provider_expiry_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX oidc_step_up_nonce_provider_expiry_idx ON identity.oidc_step_up_nonces USING btree (provider_id, expires_at) WHERE (consumed_at IS NULL);


--
-- Name: password_reset_requests_account_id_requested_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX password_reset_requests_account_id_requested_at_idx ON identity.password_reset_requests USING btree (account_id, requested_at);


--
-- Name: password_reset_requests_expires_at_consumed_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX password_reset_requests_expires_at_consumed_at_idx ON identity.password_reset_requests USING btree (expires_at, consumed_at);


--
-- Name: password_reset_requests_login_identity_id_consumed_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX password_reset_requests_login_identity_id_consumed_at_idx ON identity.password_reset_requests USING btree (login_identity_id, consumed_at);


--
-- Name: policy_documents_is_required_published_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX policy_documents_is_required_published_at_idx ON identity.policy_documents USING btree (is_required, published_at);


--
-- Name: policy_documents_policy_code_version_language_code_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX policy_documents_policy_code_version_language_code_idx ON identity.policy_documents USING btree (policy_code, version, language_code);


--
-- Name: recovery_code_sets_account_id_purpose_issued_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX recovery_code_sets_account_id_purpose_issued_at_idx ON identity.recovery_code_sets USING btree (account_id, purpose, issued_at);


--
-- Name: recovery_codes_recovery_code_set_id_used_at_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX recovery_codes_recovery_code_set_id_used_at_idx ON identity.recovery_codes USING btree (recovery_code_set_id, used_at);


--
-- Name: refresh_token_families_account_expiry_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX refresh_token_families_account_expiry_idx ON identity.refresh_token_families USING btree (account_id, expires_at);


--
-- Name: refresh_token_families_account_revoked_idx; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX refresh_token_families_account_revoked_idx ON identity.refresh_token_families USING btree (account_id, revoked_at);


--
-- Name: corporate_actions_instrument_id_effective_at_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX corporate_actions_instrument_id_effective_at_idx ON market_data.corporate_actions USING btree (instrument_id, effective_at);


--
-- Name: corporate_actions_source_manifest_id_provider_event_key_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX corporate_actions_source_manifest_id_provider_event_key_idx ON market_data.corporate_actions USING btree (source_manifest_id, provider_event_key);


--
-- Name: dataset_manifests_feed_id_instrument_id_data_layer_resoluti_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX dataset_manifests_feed_id_instrument_id_data_layer_resoluti_idx ON market_data.dataset_manifests USING btree (feed_id, instrument_id, data_layer, resolution, period_start, revision_number);


--
-- Name: dataset_manifests_status_period_start_period_end_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX dataset_manifests_status_period_start_period_end_idx ON market_data.dataset_manifests USING btree (status, period_start, period_end);


--
-- Name: dataset_object_lineage_pipeline_run_id_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX dataset_object_lineage_pipeline_run_id_idx ON market_data.dataset_object_lineage USING btree (pipeline_run_id);


--
-- Name: dataset_object_lineage_source_dataset_object_id_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX dataset_object_lineage_source_dataset_object_id_idx ON market_data.dataset_object_lineage USING btree (source_dataset_object_id);


--
-- Name: dataset_objects_dataset_manifest_id_object_kind_partition_g_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX dataset_objects_dataset_manifest_id_object_kind_partition_g_idx ON market_data.dataset_objects USING btree (dataset_manifest_id, object_kind, partition_granularity, partition_start, partition_end, shard_key, part_number);


--
-- Name: dataset_objects_dataset_manifest_id_period_start_period_end_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX dataset_objects_dataset_manifest_id_period_start_period_end_idx ON market_data.dataset_objects USING btree (dataset_manifest_id, period_start, period_end);


--
-- Name: dataset_objects_partition_granularity_partition_start_parti_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX dataset_objects_partition_granularity_partition_start_parti_idx ON market_data.dataset_objects USING btree (partition_granularity, partition_start, partition_end);


--
-- Name: feature_definitions_element_catalog_version_id_feature_code_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX feature_definitions_element_catalog_version_id_feature_code_idx ON market_data.feature_definitions USING btree (element_catalog_version_id, feature_code, calculator_version, resolution, definition_hash);


--
-- Name: feature_materializations_feature_definition_id_instrument_i_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX feature_materializations_feature_definition_id_instrument_i_idx ON market_data.feature_materializations USING btree (feature_definition_id, instrument_id, input_dataset_set_hash, period_start, period_end);


--
-- Name: feature_materializations_instrument_id_period_end_status_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX feature_materializations_instrument_id_period_end_status_idx ON market_data.feature_materializations USING btree (instrument_id, period_end, status);


--
-- Name: feature_materializations_output_dataset_manifest_id_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX feature_materializations_output_dataset_manifest_id_idx ON market_data.feature_materializations USING btree (output_dataset_manifest_id);


--
-- Name: feature_snapshot_batches_feature_set_hash_input_market_set__idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX feature_snapshot_batches_feature_set_hash_input_market_set__idx ON market_data.feature_snapshot_batches USING btree (feature_set_hash, input_market_set_hash, period_start, period_end);


--
-- Name: feature_snapshot_batches_status_period_end_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX feature_snapshot_batches_status_period_end_idx ON market_data.feature_snapshot_batches USING btree (status, period_end);


--
-- Name: feeds_provider_id_code_feed_version_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX feeds_provider_id_code_feed_version_idx ON market_data.feeds USING btree (provider_id, code, feed_version);


--
-- Name: instrument_symbols_exchange_mic_symbol_effective_from_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX instrument_symbols_exchange_mic_symbol_effective_from_idx ON market_data.instrument_symbols USING btree (exchange_mic, symbol, effective_from);


--
-- Name: instrument_symbols_instrument_id_effective_from_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX instrument_symbols_instrument_id_effective_from_idx ON market_data.instrument_symbols USING btree (instrument_id, effective_from);


--
-- Name: instruments_asset_type_primary_exchange_mic_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX instruments_asset_type_primary_exchange_mic_idx ON market_data.instruments USING btree (asset_type, primary_exchange_mic);


--
-- Name: pipeline_runs_pipeline_code_status_started_at_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX pipeline_runs_pipeline_code_status_started_at_idx ON market_data.pipeline_runs USING btree (pipeline_code, status, started_at);


--
-- Name: quality_incidents_dataset_manifest_id_period_start_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX quality_incidents_dataset_manifest_id_period_start_idx ON market_data.quality_incidents USING btree (dataset_manifest_id, period_start);


--
-- Name: quality_incidents_status_severity_detected_at_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE INDEX quality_incidents_status_severity_detected_at_idx ON market_data.quality_incidents USING btree (status, severity, detected_at);


--
-- Name: trading_sessions_exchange_mic_session_date_calendar_version_idx; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX trading_sessions_exchange_mic_session_date_calendar_version_idx ON market_data.trading_sessions USING btree (exchange_mic, session_date, calendar_version);


--
-- Name: uq_dataset_manifests_dataset_hash; Type: INDEX; Schema: market_data; Owner: -
--

CREATE UNIQUE INDEX uq_dataset_manifests_dataset_hash ON market_data.dataset_manifests USING btree (dataset_hash) WHERE (object_count > 0);


--
-- Name: audit_events_actor_type_actor_id_occurred_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX audit_events_actor_type_actor_id_occurred_at_idx ON operations.audit_events USING btree (actor_type, actor_id, occurred_at);


--
-- Name: audit_events_correlation_id_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX audit_events_correlation_id_idx ON operations.audit_events USING btree (correlation_id);


--
-- Name: audit_events_delegated_authorization_id_occurred_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX audit_events_delegated_authorization_id_occurred_at_idx ON operations.audit_events USING btree (delegated_authorization_id, occurred_at);


--
-- Name: audit_events_target_domain_target_id_occurred_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX audit_events_target_domain_target_id_occurred_at_idx ON operations.audit_events USING btree (target_domain, target_id, occurred_at);


--
-- Name: batch_item_attempts_outcome_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX batch_item_attempts_outcome_idx ON operations.batch_item_attempts USING btree (outcome, completed_at);


--
-- Name: batch_item_replay_generation_unique; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX batch_item_replay_generation_unique ON operations.batch_items USING btree (original_item_id, replay_sequence) WHERE (original_item_id IS NOT NULL);


--
-- Name: batch_items_claimable_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX batch_items_claimable_idx ON operations.batch_items USING btree (status, next_attempt_at, due_at, id);


--
-- Name: batch_job_one_active_version; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX batch_job_one_active_version ON operations.batch_job_versions USING btree (job_code) WHERE (status = 'ACTIVE'::operations.batch_job_version_status);


--
-- Name: batch_runs_job_started_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX batch_runs_job_started_idx ON operations.batch_runs USING btree (job_code, job_version, started_at);


--
-- Name: batch_runs_status_started_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX batch_runs_status_started_idx ON operations.batch_runs USING btree (status, started_at);


--
-- Name: case_account_status_created_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX case_account_status_created_idx ON operations.cases USING btree (account_id, status, created_at, id);


--
-- Name: case_event_account_created_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX case_event_account_created_idx ON operations.case_events USING btree (account_id, created_at);


--
-- Name: case_event_correlation_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX case_event_correlation_idx ON operations.case_events USING btree (correlation_id);


--
-- Name: case_events_case_id_event_sequence_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX case_events_case_id_event_sequence_idx ON operations.case_events USING btree (case_id, event_sequence);


--
-- Name: case_evidence_account_attached_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX case_evidence_account_attached_idx ON operations.case_evidence_references USING btree (account_id, attached_at);


--
-- Name: case_evidence_source_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX case_evidence_source_idx ON operations.case_evidence_references USING btree (source_domain, source_resource_id);


--
-- Name: case_operator_queue_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX case_operator_queue_idx ON operations.cases USING btree (case_type, status, assignee_operator_id, updated_at DESC, id DESC);


--
-- Name: case_response_deadline_due_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX case_response_deadline_due_idx ON operations.cases USING btree (response_deadline_at, id) WHERE (response_deadline_at IS NOT NULL);


--
-- Name: cases_account_id_status_created_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX cases_account_id_status_created_at_idx ON operations.cases USING btree (account_id, status, created_at);


--
-- Name: delivery_attempts_notification_id_channel_attempt_number_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX delivery_attempts_notification_id_channel_attempt_number_idx ON operations.delivery_attempts USING btree (notification_id, channel, attempt_number);


--
-- Name: delivery_attempts_status_next_attempt_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX delivery_attempts_status_next_attempt_at_idx ON operations.delivery_attempts USING btree (status, next_attempt_at);


--
-- Name: notification_delivery_outbox_attempt_unique; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX notification_delivery_outbox_attempt_unique ON operations.delivery_attempts USING btree (outbox_message_id, attempt_number) WHERE (outbox_message_id IS NOT NULL);


--
-- Name: notification_policy_one_active_per_type; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX notification_policy_one_active_per_type ON operations.notification_policies USING btree (type_code) WHERE active;


--
-- Name: notification_preference_versioned_scope_unique; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX notification_preference_versioned_scope_unique ON operations.notification_preferences USING btree (account_id, COALESCE(bot_id, '00000000-0000-0000-0000-000000000000'::uuid), event_type, policy_version, channel);


--
-- Name: notification_source_event_unique; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX notification_source_event_unique ON operations.notifications USING btree (account_id, notification_type, source_event_id) WHERE (source_event_id IS NOT NULL);


--
-- Name: notifications_account_id_read_at_created_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX notifications_account_id_read_at_created_at_idx ON operations.notifications USING btree (account_id, read_at, created_at);


--
-- Name: operator_case_receipt_case_completed_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX operator_case_receipt_case_completed_idx ON operations.operator_case_command_receipts USING btree (case_id, completed_at);


--
-- Name: operator_role_assignments_expires_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX operator_role_assignments_expires_at_idx ON operations.operator_role_assignments USING btree (expires_at);


--
-- Name: operator_role_assignments_operator_account_id_role_id_grant_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX operator_role_assignments_operator_account_id_role_id_grant_idx ON operations.operator_role_assignments USING btree (operator_account_id, role_id, granted_at);


--
-- Name: outbox_consumer_receipt_producer_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX outbox_consumer_receipt_producer_idx ON operations.outbox_consumer_receipts USING btree (consumer_handler_id, producer_idempotency_key);


--
-- Name: outbox_consumer_receipt_status_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX outbox_consumer_receipt_status_idx ON operations.outbox_consumer_receipts USING btree (status, claim_expires_at);


--
-- Name: outbox_delivery_attempt_outcome_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX outbox_delivery_attempt_outcome_idx ON operations.outbox_delivery_attempts USING btree (outcome, completed_at);


--
-- Name: outbox_message_claim_token_unique; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX outbox_message_claim_token_unique ON operations.outbox_messages USING btree (claim_token) WHERE (claim_token IS NOT NULL);


--
-- Name: outbox_message_delivery_due_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX outbox_message_delivery_due_idx ON operations.outbox_messages USING btree (delivery_status, next_attempt_at, claim_expires_at);


--
-- Name: outbox_message_producer_key_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX outbox_message_producer_key_idx ON operations.outbox_messages USING btree (producer_idempotency_key);


--
-- Name: outbox_message_replay_audit_unique; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX outbox_message_replay_audit_unique ON operations.outbox_messages USING btree (replay_audit_event_id) WHERE (replay_audit_event_id IS NOT NULL);


--
-- Name: outbox_message_replay_sequence_unique; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX outbox_message_replay_sequence_unique ON operations.outbox_messages USING btree (original_message_id, replay_sequence) WHERE (original_message_id IS NOT NULL);


--
-- Name: outbox_message_replayed_from_unique; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX outbox_message_replayed_from_unique ON operations.outbox_messages USING btree (replayed_from_message_id) WHERE (replayed_from_message_id IS NOT NULL);


--
-- Name: outbox_messages_owner_domain_aggregate_id_aggregate_sequenc_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX outbox_messages_owner_domain_aggregate_id_aggregate_sequenc_idx ON operations.outbox_messages USING btree (owner_domain, aggregate_id, aggregate_sequence);


--
-- Name: outbox_messages_published_at_next_attempt_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX outbox_messages_published_at_next_attempt_at_idx ON operations.outbox_messages USING btree (published_at, next_attempt_at);


--
-- Name: projection_checkpoints_projection_name_target_store_shard_k_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX projection_checkpoints_projection_name_target_store_shard_k_idx ON operations.projection_checkpoints USING btree (projection_name, target_store, shard_key);


--
-- Name: projection_checkpoints_status_updated_at_idx; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX projection_checkpoints_status_updated_at_idx ON operations.projection_checkpoints USING btree (status, updated_at);


--
-- Name: rbac_catalog_one_active; Type: INDEX; Schema: operations; Owner: -
--

CREATE UNIQUE INDEX rbac_catalog_one_active ON operations.rbac_catalog_versions USING btree (status) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: bot_current_projections_max_drawdown_pct_bot_id_idx; Type: INDEX; Schema: performance; Owner: -
--

CREATE INDEX bot_current_projections_max_drawdown_pct_bot_id_idx ON performance.bot_current_projections USING btree (max_drawdown_pct, bot_id);


--
-- Name: bot_current_projections_sharpe_ratio_bot_id_idx; Type: INDEX; Schema: performance; Owner: -
--

CREATE INDEX bot_current_projections_sharpe_ratio_bot_id_idx ON performance.bot_current_projections USING btree (sharpe_ratio, bot_id);


--
-- Name: bot_current_projections_total_return_pct_bot_id_idx; Type: INDEX; Schema: performance; Owner: -
--

CREATE INDEX bot_current_projections_total_return_pct_bot_id_idx ON performance.bot_current_projections USING btree (total_return_pct, bot_id);


--
-- Name: bot_snapshots_bot_id_evaluated_at_idx; Type: INDEX; Schema: performance; Owner: -
--

CREATE INDEX bot_snapshots_bot_id_evaluated_at_idx ON performance.bot_snapshots USING btree (bot_id, evaluated_at);


--
-- Name: bot_snapshots_bot_id_snapshot_type_source_event_sequence_idx; Type: INDEX; Schema: performance; Owner: -
--

CREATE UNIQUE INDEX bot_snapshots_bot_id_snapshot_type_source_event_sequence_idx ON performance.bot_snapshots USING btree (bot_id, snapshot_type, source_event_sequence);


--
-- Name: series_manifests_bot_id_series_type_week_start_date_part_n_idx1; Type: INDEX; Schema: performance; Owner: -
--

CREATE INDEX series_manifests_bot_id_series_type_week_start_date_part_n_idx1 ON performance.series_manifests USING btree (bot_id, series_type, week_start_date, part_number);


--
-- Name: series_manifests_bot_id_series_type_week_start_date_part_nu_idx; Type: INDEX; Schema: performance; Owner: -
--

CREATE UNIQUE INDEX series_manifests_bot_id_series_type_week_start_date_part_nu_idx ON performance.series_manifests USING btree (bot_id, series_type, week_start_date, part_number, revision_number);


--
-- Name: series_manifests_object_id_idx; Type: INDEX; Schema: performance; Owner: -
--

CREATE UNIQUE INDEX series_manifests_object_id_idx ON performance.series_manifests USING btree (object_id);


--
-- Name: series_manifests_supersedes_manifest_id_idx; Type: INDEX; Schema: performance; Owner: -
--

CREATE UNIQUE INDEX series_manifests_supersedes_manifest_id_idx ON performance.series_manifests USING btree (supersedes_manifest_id);


--
-- Name: objects_content_hash_byte_size_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX objects_content_hash_byte_size_idx ON storage.objects USING btree (content_hash, byte_size);


--
-- Name: objects_retention_until_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX objects_retention_until_idx ON storage.objects USING btree (retention_until);


--
-- Name: objects_status_created_at_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX objects_status_created_at_idx ON storage.objects USING btree (status, created_at);


--
-- Name: objects_storage_provider_bucket_name_object_key_provider_ve_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX objects_storage_provider_bucket_name_object_key_provider_ve_idx ON storage.objects USING btree (storage_provider, bucket_name, object_key, provider_version_id);


--
-- Name: compiled_flow_plans_element_catalog_version_id_semantic_has_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE UNIQUE INDEX compiled_flow_plans_element_catalog_version_id_semantic_has_idx ON strategy.compiled_flow_plans USING btree (element_catalog_version_id, semantic_hash, compiler_version);


--
-- Name: compiled_flow_plans_required_feature_set_hash_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE INDEX compiled_flow_plans_required_feature_set_hash_idx ON strategy.compiled_flow_plans USING btree (required_feature_set_hash);


--
-- Name: element_catalog_versions_language_version_schema_version_ca_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE UNIQUE INDEX element_catalog_versions_language_version_schema_version_ca_idx ON strategy.element_catalog_versions USING btree (language_version, schema_version, catalog_version);


--
-- Name: element_definitions_element_catalog_version_id_element_code_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE UNIQUE INDEX element_definitions_element_catalog_version_id_element_code_idx ON strategy.element_definitions USING btree (element_catalog_version_id, element_code);


--
-- Name: package_versions_package_id_version_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE UNIQUE INDEX package_versions_package_id_version_idx ON strategy.package_versions USING btree (package_id, version);


--
-- Name: strategies_owner_account_id_deleted_at_archived_at_updated__idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE INDEX strategies_owner_account_id_deleted_at_archived_at_updated__idx ON strategy.strategies USING btree (owner_account_id, deleted_at, archived_at, updated_at);


--
-- Name: strategy_documents_semantic_hash_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE INDEX strategy_documents_semantic_hash_idx ON strategy.strategy_documents USING btree (semantic_hash);


--
-- Name: strategy_documents_updated_at_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE INDEX strategy_documents_updated_at_idx ON strategy.strategy_documents USING btree (updated_at);


--
-- Name: strategy_edit_leases_expires_at_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE INDEX strategy_edit_leases_expires_at_idx ON strategy.strategy_edit_leases USING btree (expires_at);


--
-- Name: template_versions_template_id_version_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE UNIQUE INDEX template_versions_template_id_version_idx ON strategy.template_versions USING btree (template_id, version);


--
-- Name: validation_runs_delegated_authorization_id_requested_at_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE INDEX validation_runs_delegated_authorization_id_requested_at_idx ON strategy.validation_runs USING btree (delegated_authorization_id, requested_at);


--
-- Name: validation_runs_strategy_id_requested_at_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE INDEX validation_runs_strategy_id_requested_at_idx ON strategy.validation_runs USING btree (strategy_id, requested_at);


--
-- Name: validation_runs_strategy_id_requested_edit_sequence_semanti_idx; Type: INDEX; Schema: strategy; Owner: -
--

CREATE INDEX validation_runs_strategy_id_requested_edit_sequence_semanti_idx ON strategy.validation_runs USING btree (strategy_id, requested_edit_sequence, semantic_hash, status);


--
-- Name: buying_power_buffer_policy_versi_policy_code_effective_from_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX buying_power_buffer_policy_versi_policy_code_effective_from_idx ON trading.buying_power_buffer_policy_versions USING btree (policy_code, effective_from);


--
-- Name: buying_power_buffer_policy_versions_policy_code_version_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX buying_power_buffer_policy_versions_policy_code_version_idx ON trading.buying_power_buffer_policy_versions USING btree (policy_code, version);


--
-- Name: candidate_batch_processing_evaluation_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX candidate_batch_processing_evaluation_idx ON trading.candidate_batch_processing USING btree (evaluation_id);


--
-- Name: fee_policy_versions_policy_code_effective_from_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX fee_policy_versions_policy_code_effective_from_idx ON trading.fee_policy_versions USING btree (policy_code, effective_from);


--
-- Name: fee_policy_versions_policy_code_version_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fee_policy_versions_policy_code_version_idx ON trading.fee_policy_versions USING btree (policy_code, version);


--
-- Name: fill_adjustments_bot_id_partition_id_bot_event_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_adjustments_bot_id_partition_id_bot_event_id_idx ON trading.fill_adjustments USING btree (bot_id, partition_id, bot_event_id);


--
-- Name: fill_adjustments_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_adjustments_bot_id_partition_id_id_idx ON trading.fill_adjustments USING btree (bot_id, partition_id, id);


--
-- Name: fill_adjustments_fill_id_adjustment_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_adjustments_fill_id_adjustment_key_idx ON trading.fill_adjustments USING btree (fill_id, adjustment_key);


--
-- Name: fill_component_allocations_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_component_allocations_bot_id_partition_id_id_idx ON trading.fill_component_allocations USING btree (bot_id, partition_id, id);


--
-- Name: fill_component_allocations_bot_id_partition_id_order_compon_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_component_allocations_bot_id_partition_id_order_compon_idx ON trading.fill_component_allocations USING btree (bot_id, partition_id, order_component_id, id);


--
-- Name: fill_component_allocations_bot_id_partition_id_order_id_fil_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_component_allocations_bot_id_partition_id_order_id_fil_idx ON trading.fill_component_allocations USING btree (bot_id, partition_id, order_id, fill_id, id);


--
-- Name: fill_component_allocations_bot_id_partition_id_order_id_ord_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_component_allocations_bot_id_partition_id_order_id_ord_idx ON trading.fill_component_allocations USING btree (bot_id, partition_id, order_id, order_component_id, id);


--
-- Name: fill_component_allocations_fill_id_allocation_sequence_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_component_allocations_fill_id_allocation_sequence_idx ON trading.fill_component_allocations USING btree (fill_id, allocation_sequence);


--
-- Name: fill_component_allocations_fill_id_order_component_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fill_component_allocations_fill_id_order_component_id_idx ON trading.fill_component_allocations USING btree (fill_id, order_component_id);


--
-- Name: fill_component_allocations_order_component_id_fill_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX fill_component_allocations_order_component_id_fill_id_idx ON trading.fill_component_allocations USING btree (order_component_id, fill_id);


--
-- Name: fills_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fills_bot_id_partition_id_id_idx ON trading.fills USING btree (bot_id, partition_id, id);


--
-- Name: fills_bot_id_partition_id_occurred_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX fills_bot_id_partition_id_occurred_at_idx ON trading.fills USING btree (bot_id, partition_id, occurred_at);


--
-- Name: fills_bot_id_partition_id_order_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fills_bot_id_partition_id_order_id_id_idx ON trading.fills USING btree (bot_id, partition_id, order_id, id);


--
-- Name: fills_bot_id_partition_id_provider_fill_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX fills_bot_id_partition_id_provider_fill_key_idx ON trading.fills USING btree (bot_id, partition_id, provider_fill_key);


--
-- Name: fills_order_id_occurred_at_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX fills_order_id_occurred_at_id_idx ON trading.fills USING btree (order_id, occurred_at, id);


--
-- Name: fills_partition_id_occurred_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX fills_partition_id_occurred_at_idx ON trading.fills USING btree (partition_id, occurred_at);


--
-- Name: flow_position_projections_bot_id_instrument_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX flow_position_projections_bot_id_instrument_id_idx ON trading.flow_position_projections USING btree (bot_id, instrument_id);


--
-- Name: flow_position_projections_partition_id_instrument_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX flow_position_projections_partition_id_instrument_id_idx ON trading.flow_position_projections USING btree (partition_id, instrument_id);


--
-- Name: ledger_accounts_bot_id_account_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX ledger_accounts_bot_id_account_key_idx ON trading.ledger_accounts USING btree (bot_id, account_key);


--
-- Name: ledger_accounts_bot_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX ledger_accounts_bot_id_id_idx ON trading.ledger_accounts USING btree (bot_id, id);


--
-- Name: ledger_accounts_bot_id_partition_id_flow_id_account_type_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX ledger_accounts_bot_id_partition_id_flow_id_account_type_idx ON trading.ledger_accounts USING btree (bot_id, partition_id, flow_id, account_type);


--
-- Name: ledger_accounts_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX ledger_accounts_bot_id_partition_id_id_idx ON trading.ledger_accounts USING btree (bot_id, partition_id, id);


--
-- Name: ledger_entries_bot_id_partition_id_ledger_account_id_transa_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX ledger_entries_bot_id_partition_id_ledger_account_id_transa_idx ON trading.ledger_entries USING btree (bot_id, partition_id, ledger_account_id, transaction_id);


--
-- Name: ledger_entries_order_component_id_transaction_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX ledger_entries_order_component_id_transaction_id_idx ON trading.ledger_entries USING btree (order_component_id, transaction_id);


--
-- Name: ledger_entries_transaction_id_entry_sequence_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX ledger_entries_transaction_id_entry_sequence_idx ON trading.ledger_entries USING btree (transaction_id, entry_sequence);


--
-- Name: ledger_transactions_bot_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX ledger_transactions_bot_id_id_idx ON trading.ledger_transactions USING btree (bot_id, id);


--
-- Name: ledger_transactions_bot_id_occurred_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX ledger_transactions_bot_id_occurred_at_idx ON trading.ledger_transactions USING btree (bot_id, occurred_at);


--
-- Name: ledger_transactions_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX ledger_transactions_bot_id_partition_id_id_idx ON trading.ledger_transactions USING btree (bot_id, partition_id, id);


--
-- Name: ledger_transactions_bot_id_source_type_source_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX ledger_transactions_bot_id_source_type_source_id_idx ON trading.ledger_transactions USING btree (bot_id, source_type, source_id);


--
-- Name: ledger_transactions_bot_id_transaction_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX ledger_transactions_bot_id_transaction_key_idx ON trading.ledger_transactions USING btree (bot_id, transaction_key);


--
-- Name: lot_movements_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX lot_movements_bot_id_partition_id_id_idx ON trading.lot_movements USING btree (bot_id, partition_id, id);


--
-- Name: lot_movements_position_lot_id_bot_event_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX lot_movements_position_lot_id_bot_event_id_idx ON trading.lot_movements USING btree (position_lot_id, bot_event_id);


--
-- Name: lot_movements_position_lot_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX lot_movements_position_lot_id_id_idx ON trading.lot_movements USING btree (position_lot_id, id);


--
-- Name: lot_movements_source_fill_adjustment_id_position_lot_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX lot_movements_source_fill_adjustment_id_position_lot_id_idx ON trading.lot_movements USING btree (source_fill_adjustment_id, position_lot_id);


--
-- Name: lot_movements_source_fill_allocation_id_position_lot_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX lot_movements_source_fill_allocation_id_position_lot_id_idx ON trading.lot_movements USING btree (source_fill_allocation_id, position_lot_id);


--
-- Name: one_reversal_per_fill; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX one_reversal_per_fill ON trading.fill_adjustments USING btree (fill_id) WHERE (adjustment_type = 'REVERSAL'::trading.fill_adjustment_type);


--
-- Name: order_component_reservations_order_component_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX order_component_reservations_order_component_id_idx ON trading.order_component_reservations USING btree (order_component_id);


--
-- Name: order_components_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_components_bot_id_partition_id_id_idx ON trading.order_components USING btree (bot_id, partition_id, id);


--
-- Name: order_components_bot_id_partition_id_order_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_components_bot_id_partition_id_order_id_id_idx ON trading.order_components USING btree (bot_id, partition_id, order_id, id);


--
-- Name: order_components_intent_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX order_components_intent_id_idx ON trading.order_components USING btree (intent_id);


--
-- Name: order_components_order_id_component_sequence_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_components_order_id_component_sequence_idx ON trading.order_components USING btree (order_id, component_sequence);


--
-- Name: order_components_order_id_intent_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_components_order_id_intent_id_idx ON trading.order_components USING btree (order_id, intent_id);


--
-- Name: order_events_bot_id_partition_id_bot_event_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_events_bot_id_partition_id_bot_event_id_idx ON trading.order_events USING btree (bot_id, partition_id, bot_event_id);


--
-- Name: order_events_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_events_bot_id_partition_id_id_idx ON trading.order_events USING btree (bot_id, partition_id, id);


--
-- Name: order_events_order_id_order_sequence_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_events_order_id_order_sequence_idx ON trading.order_events USING btree (order_id, order_sequence);


--
-- Name: order_group_events_order_group_id_group_sequence_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_group_events_order_group_id_group_sequence_idx ON trading.order_group_events USING btree (order_group_id, group_sequence);


--
-- Name: order_group_members_order_group_id_leg_sequence_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_group_members_order_group_id_leg_sequence_idx ON trading.order_group_members USING btree (order_group_id, leg_sequence);


--
-- Name: order_groups_bot_id_partition_id_group_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_groups_bot_id_partition_id_group_key_idx ON trading.order_groups USING btree (bot_id, partition_id, group_key);


--
-- Name: order_groups_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_groups_bot_id_partition_id_id_idx ON trading.order_groups USING btree (bot_id, partition_id, id);


--
-- Name: order_intent_batches_bot_id_partition_id_finalized_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX order_intent_batches_bot_id_partition_id_finalized_at_idx ON trading.order_intent_batches USING btree (bot_id, partition_id, finalized_at);


--
-- Name: order_intent_batches_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_intent_batches_bot_id_partition_id_id_idx ON trading.order_intent_batches USING btree (bot_id, partition_id, id);


--
-- Name: order_intent_batches_bot_id_partition_id_source_event_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_intent_batches_bot_id_partition_id_source_event_id_idx ON trading.order_intent_batches USING btree (bot_id, partition_id, source_event_id);


--
-- Name: order_intents_batch_id_intent_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_intents_batch_id_intent_key_idx ON trading.order_intents USING btree (batch_id, intent_key);


--
-- Name: order_intents_bot_id_partition_id_batch_id_instrument_id_si_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX order_intents_bot_id_partition_id_batch_id_instrument_id_si_idx ON trading.order_intents USING btree (bot_id, partition_id, batch_id, instrument_id, side);


--
-- Name: order_intents_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_intents_bot_id_partition_id_id_idx ON trading.order_intents USING btree (bot_id, partition_id, id);


--
-- Name: order_intents_evaluation_run_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX order_intents_evaluation_run_id_idx ON trading.order_intents USING btree (evaluation_run_id);


--
-- Name: order_intents_partition_id_flow_id_instrument_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX order_intents_partition_id_flow_id_instrument_id_idx ON trading.order_intents USING btree (partition_id, flow_id, instrument_id);


--
-- Name: order_state_projections_bot_id_partition_id_order_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX order_state_projections_bot_id_partition_id_order_id_idx ON trading.order_state_projections USING btree (bot_id, partition_id, order_id);


--
-- Name: order_state_projections_bot_id_partition_id_status_updated__idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX order_state_projections_bot_id_partition_id_status_updated__idx ON trading.order_state_projections USING btree (bot_id, partition_id, status, updated_at);


--
-- Name: orders_bot_id_partition_id_accepted_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX orders_bot_id_partition_id_accepted_at_idx ON trading.orders USING btree (bot_id, partition_id, accepted_at);


--
-- Name: orders_bot_id_partition_id_contract_hash_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX orders_bot_id_partition_id_contract_hash_idx ON trading.orders USING btree (bot_id, partition_id, contract_hash);


--
-- Name: orders_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX orders_bot_id_partition_id_id_idx ON trading.orders USING btree (bot_id, partition_id, id);


--
-- Name: orders_bot_id_partition_id_order_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX orders_bot_id_partition_id_order_key_idx ON trading.orders USING btree (bot_id, partition_id, order_key);


--
-- Name: orders_partition_id_instrument_id_accepted_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX orders_partition_id_instrument_id_accepted_at_idx ON trading.orders USING btree (partition_id, instrument_id, accepted_at);


--
-- Name: partition_budget_projections_bot_id_partition_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX partition_budget_projections_bot_id_partition_id_idx ON trading.partition_budget_projections USING btree (bot_id, partition_id);


--
-- Name: partition_position_projection_bot_id_partition_id_instrumen_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX partition_position_projection_bot_id_partition_id_instrumen_idx ON trading.partition_position_projections USING btree (bot_id, partition_id, instrument_id);


--
-- Name: partition_position_projections_bot_id_instrument_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX partition_position_projections_bot_id_instrument_id_idx ON trading.partition_position_projections USING btree (bot_id, instrument_id);


--
-- Name: position_lot_reservations_position_lot_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX position_lot_reservations_position_lot_id_idx ON trading.position_lot_reservations USING btree (position_lot_id);


--
-- Name: position_lots_bot_id_partition_id_flow_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX position_lots_bot_id_partition_id_flow_id_id_idx ON trading.position_lots USING btree (bot_id, partition_id, flow_id, id);


--
-- Name: position_lots_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX position_lots_bot_id_partition_id_id_idx ON trading.position_lots USING btree (bot_id, partition_id, id);


--
-- Name: position_lots_bot_id_partition_id_instrument_id_opened_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX position_lots_bot_id_partition_id_instrument_id_opened_at_idx ON trading.position_lots USING btree (bot_id, partition_id, instrument_id, opened_at);


--
-- Name: position_lots_bot_id_partition_id_opening_order_component_i_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX position_lots_bot_id_partition_id_opening_order_component_i_idx ON trading.position_lots USING btree (bot_id, partition_id, opening_order_component_id, opening_fill_allocation_id);


--
-- Name: position_lots_opening_fill_allocation_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX position_lots_opening_fill_allocation_id_idx ON trading.position_lots USING btree (opening_fill_allocation_id);


--
-- Name: position_lots_opening_order_component_id_opened_at_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX position_lots_opening_order_component_id_opened_at_id_idx ON trading.position_lots USING btree (opening_order_component_id, opened_at, id);


--
-- Name: position_lots_partition_id_flow_id_instrument_id_opened_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX position_lots_partition_id_flow_id_instrument_id_opened_at_idx ON trading.position_lots USING btree (partition_id, flow_id, instrument_id, opened_at);


--
-- Name: reservation_events_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX reservation_events_bot_id_partition_id_id_idx ON trading.reservation_events USING btree (bot_id, partition_id, id);


--
-- Name: reservation_events_reservation_id_event_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX reservation_events_reservation_id_event_key_idx ON trading.reservation_events USING btree (reservation_id, event_key);


--
-- Name: reservation_events_reservation_id_reservation_sequence_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX reservation_events_reservation_id_reservation_sequence_idx ON trading.reservation_events USING btree (reservation_id, reservation_sequence);


--
-- Name: reservation_events_source_fill_id_reservation_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX reservation_events_source_fill_id_reservation_id_idx ON trading.reservation_events USING btree (source_fill_id, reservation_id);


--
-- Name: resource_reservations_bot_id_partition_id_flow_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX resource_reservations_bot_id_partition_id_flow_id_id_idx ON trading.resource_reservations USING btree (bot_id, partition_id, flow_id, id);


--
-- Name: resource_reservations_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX resource_reservations_bot_id_partition_id_id_idx ON trading.resource_reservations USING btree (bot_id, partition_id, id);


--
-- Name: resource_reservations_bot_id_partition_id_status_created_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX resource_reservations_bot_id_partition_id_status_created_at_idx ON trading.resource_reservations USING btree (bot_id, partition_id, status, created_at);


--
-- Name: resource_reservations_intent_id_reservation_key_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX resource_reservations_intent_id_reservation_key_idx ON trading.resource_reservations USING btree (intent_id, reservation_key);


--
-- Name: resource_reservations_partition_id_flow_id_status_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX resource_reservations_partition_id_flow_id_status_idx ON trading.resource_reservations USING btree (partition_id, flow_id, status);


--
-- Name: short_borrow_fee_accruals_bot_id_partition_id_id_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX short_borrow_fee_accruals_bot_id_partition_id_id_idx ON trading.short_borrow_fee_accruals USING btree (bot_id, partition_id, id);


--
-- Name: short_borrow_fee_accruals_position_lot_id_period_start_peri_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX short_borrow_fee_accruals_position_lot_id_period_start_peri_idx ON trading.short_borrow_fee_accruals USING btree (position_lot_id, period_start, period_end);


--
-- Name: short_borrow_fee_policy_versions_policy_code_effective_from_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX short_borrow_fee_policy_versions_policy_code_effective_from_idx ON trading.short_borrow_fee_policy_versions USING btree (policy_code, effective_from);


--
-- Name: short_borrow_fee_policy_versions_policy_code_version_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX short_borrow_fee_policy_versions_policy_code_version_idx ON trading.short_borrow_fee_policy_versions USING btree (policy_code, version);


--
-- Name: short_risk_policy_versions_policy_code_effective_from_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX short_risk_policy_versions_policy_code_effective_from_idx ON trading.short_risk_policy_versions USING btree (policy_code, effective_from);


--
-- Name: short_risk_policy_versions_policy_code_version_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX short_risk_policy_versions_policy_code_version_idx ON trading.short_risk_policy_versions USING btree (policy_code, version);


--
-- Name: system_close_actions_bot_id_source_event_id_instrument_id_r_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE UNIQUE INDEX system_close_actions_bot_id_source_event_id_instrument_id_r_idx ON trading.system_close_actions USING btree (bot_id, source_event_id, instrument_id, reason_type);


--
-- Name: system_close_actions_flow_id_created_at_idx; Type: INDEX; Schema: trading; Owner: -
--

CREATE INDEX system_close_actions_flow_id_created_at_idx ON trading.system_close_actions USING btree (flow_id, created_at);


--
-- Name: run_attempts backtest_attempt_lineage_guard; Type: TRIGGER; Schema: backtest; Owner: -
--

CREATE CONSTRAINT TRIGGER backtest_attempt_lineage_guard AFTER INSERT OR UPDATE OF run_id, attempt_number, previous_attempt_id ON backtest.run_attempts DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION backtest.validate_attempt_lineage();


--
-- Name: bots bot_account_creation_gate; Type: TRIGGER; Schema: bot; Owner: -
--

CREATE TRIGGER bot_account_creation_gate BEFORE INSERT ON bot.bots FOR EACH ROW EXECUTE FUNCTION identity.guard_owner_account_creation();


--
-- Name: bots competition_bot_owner_anonymization_guard; Type: TRIGGER; Schema: bot; Owner: -
--

CREATE CONSTRAINT TRIGGER competition_bot_owner_anonymization_guard AFTER UPDATE OF owner_account_id, owner_anonymized_at ON bot.bots DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION competition.enforce_anonymized_bot_participation();


--
-- Name: leaderboard_entries competition_leaderboard_result_source_guard; Type: TRIGGER; Schema: competition; Owner: -
--

CREATE CONSTRAINT TRIGGER competition_leaderboard_result_source_guard AFTER INSERT OR UPDATE OF snapshot_id, participation_id, performance_snapshot_id, backtest_aggregate_result_id ON competition.leaderboard_entries DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION competition.enforce_leaderboard_result_source();


--
-- Name: participations competition_participation_creation_gate; Type: TRIGGER; Schema: competition; Owner: -
--

CREATE TRIGGER competition_participation_creation_gate BEFORE INSERT ON competition.participations FOR EACH ROW EXECUTE FUNCTION identity.guard_competition_participation_creation();


--
-- Name: live_evaluation_segments validate_room_ledger_handoff; Type: TRIGGER; Schema: competition; Owner: -
--

CREATE CONSTRAINT TRIGGER validate_room_ledger_handoff AFTER INSERT OR UPDATE ON competition.live_evaluation_segments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION competition.validate_room_ledger_handoff();


--
-- Name: account_identifier_quarantines account_identifier_quarantine_category_lock; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_identifier_quarantine_category_lock BEFORE INSERT OR UPDATE ON identity.account_identifier_quarantines FOR EACH ROW EXECUTE FUNCTION identity.lock_identifier_quarantine_change();


--
-- Name: account_identifier_quarantines account_identifier_quarantine_release_guard; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_identifier_quarantine_release_guard BEFORE UPDATE ON identity.account_identifier_quarantines FOR EACH ROW EXECUTE FUNCTION identity.guard_identifier_quarantine_release();


--
-- Name: account_legal_holds account_legal_hold_retention_lock; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_legal_hold_retention_lock BEFORE INSERT OR DELETE OR UPDATE ON identity.account_legal_holds FOR EACH ROW EXECUTE FUNCTION identity.lock_account_retention_category();


--
-- Name: accounts account_lifecycle_account_projection_guard; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE CONSTRAINT TRIGGER account_lifecycle_account_projection_guard AFTER UPDATE ON identity.accounts DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identity.enforce_account_lifecycle_projection_head();


--
-- Name: account_lifecycle_command_receipts account_lifecycle_command_receipts_immutable; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_lifecycle_command_receipts_immutable BEFORE DELETE OR UPDATE ON identity.account_lifecycle_command_receipts FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();


--
-- Name: account_lifecycle_events account_lifecycle_event_chain_guard; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE CONSTRAINT TRIGGER account_lifecycle_event_chain_guard AFTER INSERT ON identity.account_lifecycle_events DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identity.enforce_account_lifecycle_event_chain();


--
-- Name: account_lifecycle_events account_lifecycle_events_append_only; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_lifecycle_events_append_only BEFORE DELETE OR UPDATE ON identity.account_lifecycle_events FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();


--
-- Name: accounts account_lifecycle_genesis; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_lifecycle_genesis AFTER INSERT ON identity.accounts FOR EACH ROW EXECUTE FUNCTION identity.create_account_lifecycle_genesis();


--
-- Name: account_lifecycle_events account_lifecycle_projection_head_guard; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE CONSTRAINT TRIGGER account_lifecycle_projection_head_guard AFTER INSERT ON identity.account_lifecycle_events DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identity.enforce_account_lifecycle_projection_head();


--
-- Name: account_retention_execution_attempts account_retention_execution_attempts_append_only; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_retention_execution_attempts_append_only BEFORE DELETE OR UPDATE ON identity.account_retention_execution_attempts FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();


--
-- Name: account_retention_policy_proposals account_retention_policy_proposals_immutable; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_retention_policy_proposals_immutable BEFORE DELETE OR UPDATE ON identity.account_retention_policy_proposals FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();


--
-- Name: account_retention_policy_rules account_retention_policy_rules_immutable; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_retention_policy_rules_immutable BEFORE DELETE OR UPDATE ON identity.account_retention_policy_rules FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();


--
-- Name: account_retention_policy_versions account_retention_policy_versions_immutable; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_retention_policy_versions_immutable BEFORE DELETE OR UPDATE ON identity.account_retention_policy_versions FOR EACH ROW EXECUTE FUNCTION identity.reject_immutable_account_contract_change();


--
-- Name: account_sanction_events account_sanction_events_append_only; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_sanction_events_append_only BEFORE DELETE OR UPDATE ON identity.account_sanction_events FOR EACH ROW EXECUTE FUNCTION identity.reject_account_sanction_history_mutation();


--
-- Name: account_sanction_command_receipts account_sanction_receipts_append_only; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER account_sanction_receipts_append_only BEFORE DELETE OR UPDATE ON identity.account_sanction_command_receipts FOR EACH ROW EXECUTE FUNCTION identity.reject_account_sanction_history_mutation();


--
-- Name: delegated_strategy_derivations delegated_strategy_derivations_append_only; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER delegated_strategy_derivations_append_only BEFORE DELETE OR UPDATE ON identity.delegated_strategy_derivations FOR EACH ROW EXECUTE FUNCTION identity.reject_delegated_strategy_scope_mutation();


--
-- Name: delegated_authorization_strategy_targets delegated_strategy_targets_append_only; Type: TRIGGER; Schema: identity; Owner: -
--

CREATE TRIGGER delegated_strategy_targets_append_only BEFORE DELETE OR UPDATE ON identity.delegated_authorization_strategy_targets FOR EACH ROW EXECUTE FUNCTION identity.reject_delegated_strategy_scope_mutation();


--
-- Name: dataset_objects dataset_manifest_object_count_maintain; Type: TRIGGER; Schema: market_data; Owner: -
--

CREATE TRIGGER dataset_manifest_object_count_maintain AFTER INSERT OR DELETE OR UPDATE OF dataset_manifest_id ON market_data.dataset_objects FOR EACH ROW EXECUTE FUNCTION market_data.maintain_dataset_manifest_object_count();


--
-- Name: account_integrations account_integration_activation_gate; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER account_integration_activation_gate BEFORE INSERT OR UPDATE OF status ON operations.account_integrations FOR EACH ROW EXECUTE FUNCTION identity.guard_account_scoped_activation();


--
-- Name: case_command_receipts case_command_receipts_append_only; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER case_command_receipts_append_only BEFORE DELETE OR UPDATE ON operations.case_command_receipts FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();


--
-- Name: case_deadline_receipts case_deadline_receipts_append_only; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER case_deadline_receipts_append_only BEFORE DELETE OR UPDATE ON operations.case_deadline_receipts FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();


--
-- Name: case_events case_events_append_only; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER case_events_append_only BEFORE DELETE OR UPDATE ON operations.case_events FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();


--
-- Name: case_evidence_references case_evidence_references_append_only; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER case_evidence_references_append_only BEFORE DELETE OR UPDATE ON operations.case_evidence_references FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();


--
-- Name: audit_events guard_operator_bootstrap_audit_before_change; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER guard_operator_bootstrap_audit_before_change BEFORE DELETE OR UPDATE ON operations.audit_events FOR EACH ROW EXECUTE FUNCTION operations.guard_operator_bootstrap_audit_immutable();


--
-- Name: operator_bootstrap_receipts guard_operator_bootstrap_receipt_immutable; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER guard_operator_bootstrap_receipt_immutable BEFORE DELETE OR UPDATE ON operations.operator_bootstrap_receipts FOR EACH ROW EXECUTE FUNCTION operations.guard_operator_bootstrap_receipt_immutable();


--
-- Name: audit_events guard_operator_rbac_audit_before_change; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER guard_operator_rbac_audit_before_change BEFORE DELETE OR UPDATE ON operations.audit_events FOR EACH ROW EXECUTE FUNCTION operations.guard_operator_rbac_audit_immutable();


--
-- Name: outbox_messages guard_outbox_immutable_envelope_before_update; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER guard_outbox_immutable_envelope_before_update BEFORE UPDATE ON operations.outbox_messages FOR EACH ROW EXECUTE FUNCTION operations.guard_outbox_immutable_envelope();


--
-- Name: rbac_catalog_role_permissions guard_rbac_catalog_mappings_snapshot; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER guard_rbac_catalog_mappings_snapshot BEFORE INSERT OR DELETE OR UPDATE ON operations.rbac_catalog_role_permissions FOR EACH ROW EXECUTE FUNCTION operations.guard_rbac_catalog_snapshot();


--
-- Name: rbac_catalog_permissions guard_rbac_catalog_permissions_snapshot; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER guard_rbac_catalog_permissions_snapshot BEFORE INSERT OR DELETE OR UPDATE ON operations.rbac_catalog_permissions FOR EACH ROW EXECUTE FUNCTION operations.guard_rbac_catalog_snapshot();


--
-- Name: rbac_catalog_roles guard_rbac_catalog_roles_snapshot; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER guard_rbac_catalog_roles_snapshot BEFORE INSERT OR DELETE OR UPDATE ON operations.rbac_catalog_roles FOR EACH ROW EXECUTE FUNCTION operations.guard_rbac_catalog_snapshot();


--
-- Name: rbac_catalog_versions guard_rbac_catalog_version_update; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER guard_rbac_catalog_version_update BEFORE DELETE OR UPDATE ON operations.rbac_catalog_versions FOR EACH ROW EXECUTE FUNCTION operations.guard_rbac_catalog_immutable();


--
-- Name: notification_preferences notification_preference_activation_gate; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER notification_preference_activation_gate BEFORE INSERT OR UPDATE OF enabled ON operations.notification_preferences FOR EACH ROW EXECUTE FUNCTION identity.guard_account_scoped_activation();


--
-- Name: operator_case_command_receipts operator_case_command_receipts_append_only; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER operator_case_command_receipts_append_only BEFORE DELETE OR UPDATE ON operations.operator_case_command_receipts FOR EACH ROW EXECUTE FUNCTION operations.reject_case_append_only_mutation();


--
-- Name: outbox_messages prepare_outbox_envelope_before_insert; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER prepare_outbox_envelope_before_insert BEFORE INSERT ON operations.outbox_messages FOR EACH ROW EXECUTE FUNCTION operations.prepare_outbox_envelope();


--
-- Name: operator_role_assignments require_active_assignment_catalog_before_insert; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER require_active_assignment_catalog_before_insert BEFORE INSERT ON operations.operator_role_assignments FOR EACH ROW EXECUTE FUNCTION operations.require_active_assignment_catalog();


--
-- Name: operator_bootstrap_receipts require_coherent_operator_bootstrap_receipt_before_insert; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER require_coherent_operator_bootstrap_receipt_before_insert BEFORE INSERT ON operations.operator_bootstrap_receipts FOR EACH ROW EXECUTE FUNCTION operations.require_coherent_operator_bootstrap_receipt();


--
-- Name: operator_bootstrap_receipts require_complete_operator_bootstrap_evidence_before_insert; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER require_complete_operator_bootstrap_evidence_before_insert BEFORE INSERT ON operations.operator_bootstrap_receipts FOR EACH ROW EXECUTE FUNCTION operations.require_complete_operator_bootstrap_evidence();


--
-- Name: case_events verify_case_event_chain; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE CONSTRAINT TRIGGER verify_case_event_chain AFTER INSERT ON operations.case_events DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION operations.verify_case_head_and_chain();


--
-- Name: cases verify_case_projection_head; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE CONSTRAINT TRIGGER verify_case_projection_head AFTER INSERT OR UPDATE ON operations.cases DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION operations.verify_case_head_and_chain();


--
-- Name: short_borrow_fee_accruals borrow_fee_period_isolation_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER borrow_fee_period_isolation_deferred AFTER INSERT OR UPDATE ON trading.short_borrow_fee_accruals DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_borrow_fee_accrual_trigger();


--
-- Name: fill_adjustments fill_adjustments_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER fill_adjustments_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.fill_adjustments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_fill_adjustment_trigger();


--
-- Name: fill_component_allocations fill_allocation_totals_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER fill_allocation_totals_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.fill_component_allocations DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_fill_allocation_trigger();


--
-- Name: fills fill_totals_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER fill_totals_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.fills DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_fill_trigger();


--
-- Name: ledger_entries ledger_entry_balanced_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER ledger_entry_balanced_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.ledger_entries DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_ledger_entry_trigger();


--
-- Name: ledger_transactions ledger_transaction_balanced_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER ledger_transaction_balanced_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.ledger_transactions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_ledger_transaction_trigger();


--
-- Name: lot_movements lot_movement_provenance_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER lot_movement_provenance_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.lot_movements DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_lot_movement_trigger();


--
-- Name: order_state_projections order_fill_projection_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER order_fill_projection_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.order_state_projections DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_order_projection_trigger();


--
-- Name: position_lots position_lot_provenance_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER position_lot_provenance_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.position_lots DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_position_lot_trigger();


--
-- Name: reservation_events reservation_events_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER reservation_events_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.reservation_events DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_reservation_event_trigger();


--
-- Name: resource_reservations reservation_projection_deferred; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE CONSTRAINT TRIGGER reservation_projection_deferred AFTER INSERT OR DELETE OR UPDATE ON trading.resource_reservations DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION trading.check_reservation_trigger();


--
-- Name: orders trading_order_account_creation_gate; Type: TRIGGER; Schema: trading; Owner: -
--

CREATE TRIGGER trading_order_account_creation_gate BEFORE INSERT ON trading.orders FOR EACH ROW EXECUTE FUNCTION identity.guard_trading_order_creation();


--
-- Name: run_attempts backtest_attempt_previous_fk; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_attempts
    ADD CONSTRAINT backtest_attempt_previous_fk FOREIGN KEY (previous_attempt_id) REFERENCES backtest.run_attempts(id);


--
-- Name: runs backtest_run_execution_policy_fk; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.runs
    ADD CONSTRAINT backtest_run_execution_policy_fk FOREIGN KEY (execution_policy_version) REFERENCES backtest.execution_policy_versions(version);


--
-- Name: detail_manifests detail_manifests_object_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.detail_manifests
    ADD CONSTRAINT detail_manifests_object_id_fkey FOREIGN KEY (object_id) REFERENCES storage.objects(id) DEFERRABLE;


--
-- Name: detail_manifests detail_manifests_run_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.detail_manifests
    ADD CONSTRAINT detail_manifests_run_id_fkey FOREIGN KEY (run_id) REFERENCES backtest.runs(id) DEFERRABLE;


--
-- Name: detail_manifests detail_manifests_supersedes_manifest_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.detail_manifests
    ADD CONSTRAINT detail_manifests_supersedes_manifest_id_fkey FOREIGN KEY (supersedes_manifest_id) REFERENCES backtest.detail_manifests(id) DEFERRABLE;


--
-- Name: failure_condition_counts failure_condition_counts_monthly_summary_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.failure_condition_counts
    ADD CONSTRAINT failure_condition_counts_monthly_summary_id_fkey FOREIGN KEY (monthly_summary_id) REFERENCES backtest.monthly_judgment_summaries(id) DEFERRABLE;


--
-- Name: input_bundles input_bundles_run_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_bundles
    ADD CONSTRAINT input_bundles_run_id_fkey FOREIGN KEY (run_id) REFERENCES backtest.runs(id) DEFERRABLE;


--
-- Name: input_datasets input_datasets_dataset_manifest_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_datasets
    ADD CONSTRAINT input_datasets_dataset_manifest_id_fkey FOREIGN KEY (dataset_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: input_datasets input_datasets_input_bundle_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_datasets
    ADD CONSTRAINT input_datasets_input_bundle_id_fkey FOREIGN KEY (input_bundle_id) REFERENCES backtest.input_bundles(id) DEFERRABLE;


--
-- Name: input_feature_materializations input_feature_materializations_feature_materialization_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_feature_materializations
    ADD CONSTRAINT input_feature_materializations_feature_materialization_id_fkey FOREIGN KEY (feature_materialization_id) REFERENCES market_data.feature_materializations(id) DEFERRABLE;


--
-- Name: input_feature_materializations input_feature_materializations_input_bundle_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.input_feature_materializations
    ADD CONSTRAINT input_feature_materializations_input_bundle_id_fkey FOREIGN KEY (input_bundle_id) REFERENCES backtest.input_bundles(id) DEFERRABLE;


--
-- Name: legacy_execution_policy_mappings legacy_execution_policy_mappings_execution_policy_version_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.legacy_execution_policy_mappings
    ADD CONSTRAINT legacy_execution_policy_mappings_execution_policy_version_fkey FOREIGN KEY (execution_policy_version) REFERENCES backtest.execution_policy_versions(version);


--
-- Name: legacy_execution_policy_mappings legacy_execution_policy_mappings_run_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.legacy_execution_policy_mappings
    ADD CONSTRAINT legacy_execution_policy_mappings_run_id_fkey FOREIGN KEY (run_id) REFERENCES backtest.runs(id) ON DELETE CASCADE;


--
-- Name: monthly_judgment_summaries monthly_judgment_summaries_run_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.monthly_judgment_summaries
    ADD CONSTRAINT monthly_judgment_summaries_run_id_fkey FOREIGN KEY (run_id) REFERENCES backtest.runs(id) DEFERRABLE;


--
-- Name: performance_summaries performance_summaries_run_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.performance_summaries
    ADD CONSTRAINT performance_summaries_run_id_fkey FOREIGN KEY (run_id) REFERENCES backtest.runs(id) DEFERRABLE;


--
-- Name: run_attempts run_attempts_run_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_attempts
    ADD CONSTRAINT run_attempts_run_id_fkey FOREIGN KEY (run_id) REFERENCES backtest.runs(id) DEFERRABLE;


--
-- Name: run_input_pins run_input_pins_execution_policy_version_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_input_pins
    ADD CONSTRAINT run_input_pins_execution_policy_version_fkey FOREIGN KEY (execution_policy_version) REFERENCES backtest.execution_policy_versions(version);


--
-- Name: run_input_pins run_input_pins_input_bundle_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_input_pins
    ADD CONSTRAINT run_input_pins_input_bundle_id_fkey FOREIGN KEY (input_bundle_id) REFERENCES backtest.input_bundles(id);


--
-- Name: run_input_pins run_input_pins_run_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.run_input_pins
    ADD CONSTRAINT run_input_pins_run_id_fkey FOREIGN KEY (run_id) REFERENCES backtest.runs(id);


--
-- Name: runs runs_bot_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.runs
    ADD CONSTRAINT runs_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: runs runs_buying_power_buffer_policy_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.runs
    ADD CONSTRAINT runs_buying_power_buffer_policy_id_fkey FOREIGN KEY (buying_power_buffer_policy_id) REFERENCES trading.buying_power_buffer_policy_versions(id) DEFERRABLE;


--
-- Name: runs runs_fee_policy_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.runs
    ADD CONSTRAINT runs_fee_policy_id_fkey FOREIGN KEY (fee_policy_id) REFERENCES trading.fee_policy_versions(id) DEFERRABLE;


--
-- Name: runs runs_owner_account_id_fkey; Type: FK CONSTRAINT; Schema: backtest; Owner: -
--

ALTER TABLE ONLY backtest.runs
    ADD CONSTRAINT runs_owner_account_id_fkey FOREIGN KEY (owner_account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: bot_events bot_events_bot_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bot_events
    ADD CONSTRAINT bot_events_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: bot_events bot_events_causation_event_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bot_events
    ADD CONSTRAINT bot_events_causation_event_id_fkey FOREIGN KEY (causation_event_id) REFERENCES bot.bot_events(id) DEFERRABLE;


--
-- Name: bot_events bot_events_evidence_object_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bot_events
    ADD CONSTRAINT bot_events_evidence_object_id_fkey FOREIGN KEY (evidence_object_id) REFERENCES storage.objects(id) DEFERRABLE;


--
-- Name: bot_events bot_events_market_dataset_manifest_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bot_events
    ADD CONSTRAINT bot_events_market_dataset_manifest_id_fkey FOREIGN KEY (market_dataset_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: bot_partitions bot_partitions_bot_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bot_partitions
    ADD CONSTRAINT bot_partitions_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: bots bots_execution_block_event_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bots
    ADD CONSTRAINT bots_execution_block_event_id_fkey FOREIGN KEY (execution_block_event_id) REFERENCES bot.bot_events(id) DEFERRABLE;


--
-- Name: bots bots_owner_account_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.bots
    ADD CONSTRAINT bots_owner_account_id_fkey FOREIGN KEY (owner_account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: continuation_deadlines continuation_deadlines_bot_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.continuation_deadlines
    ADD CONSTRAINT continuation_deadlines_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: evaluation_runs evaluation_runs_bot_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.evaluation_runs
    ADD CONSTRAINT evaluation_runs_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: evaluation_runs evaluation_runs_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.evaluation_runs
    ADD CONSTRAINT evaluation_runs_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: evaluation_runs evaluation_runs_bot_id_result_event_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.evaluation_runs
    ADD CONSTRAINT evaluation_runs_bot_id_result_event_id_fkey FOREIGN KEY (bot_id, result_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: evaluation_runs evaluation_runs_bot_id_trigger_event_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.evaluation_runs
    ADD CONSTRAINT evaluation_runs_bot_id_trigger_event_id_fkey FOREIGN KEY (bot_id, trigger_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: evaluation_runs evaluation_runs_feature_snapshot_batch_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.evaluation_runs
    ADD CONSTRAINT evaluation_runs_feature_snapshot_batch_id_fkey FOREIGN KEY (feature_snapshot_batch_id) REFERENCES market_data.feature_snapshot_batches(id) DEFERRABLE;


--
-- Name: evaluation_runs evaluation_runs_partition_id_flow_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.evaluation_runs
    ADD CONSTRAINT evaluation_runs_partition_id_flow_id_fkey FOREIGN KEY (partition_id, flow_id) REFERENCES bot.flows(partition_id, id) DEFERRABLE;


--
-- Name: flow_feature_requirements flow_feature_requirements_feature_definition_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_feature_requirements
    ADD CONSTRAINT flow_feature_requirements_feature_definition_id_fkey FOREIGN KEY (feature_definition_id) REFERENCES market_data.feature_definitions(id) DEFERRABLE;


--
-- Name: flow_feature_requirements flow_feature_requirements_flow_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_feature_requirements
    ADD CONSTRAINT flow_feature_requirements_flow_id_fkey FOREIGN KEY (flow_id) REFERENCES bot.flows(id) DEFERRABLE;


--
-- Name: flow_feature_requirements flow_feature_requirements_flow_id_instrument_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_feature_requirements
    ADD CONSTRAINT flow_feature_requirements_flow_id_instrument_id_fkey FOREIGN KEY (flow_id, instrument_id) REFERENCES bot.flow_instruments(flow_id, instrument_id) DEFERRABLE;


--
-- Name: flow_instruments flow_instruments_flow_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_instruments
    ADD CONSTRAINT flow_instruments_flow_id_fkey FOREIGN KEY (flow_id) REFERENCES bot.flows(id) DEFERRABLE;


--
-- Name: flow_instruments flow_instruments_instrument_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_instruments
    ADD CONSTRAINT flow_instruments_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: flow_time_triggers flow_time_triggers_flow_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flow_time_triggers
    ADD CONSTRAINT flow_time_triggers_flow_id_fkey FOREIGN KEY (flow_id) REFERENCES bot.flows(id) DEFERRABLE;


--
-- Name: flows flows_compiled_flow_plan_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flows
    ADD CONSTRAINT flows_compiled_flow_plan_id_fkey FOREIGN KEY (compiled_flow_plan_id) REFERENCES strategy.compiled_flow_plans(id) DEFERRABLE;


--
-- Name: flows flows_element_catalog_version_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flows
    ADD CONSTRAINT flows_element_catalog_version_id_fkey FOREIGN KEY (element_catalog_version_id) REFERENCES strategy.element_catalog_versions(id) DEFERRABLE;


--
-- Name: flows flows_partition_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.flows
    ADD CONSTRAINT flows_partition_id_fkey FOREIGN KEY (partition_id) REFERENCES bot.bot_partitions(id) DEFERRABLE;


--
-- Name: launch_configurations launch_configurations_bot_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.launch_configurations
    ADD CONSTRAINT launch_configurations_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: launch_configurations launch_configurations_buying_power_buffer_policy_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.launch_configurations
    ADD CONSTRAINT launch_configurations_buying_power_buffer_policy_id_fkey FOREIGN KEY (buying_power_buffer_policy_id) REFERENCES trading.buying_power_buffer_policy_versions(id) DEFERRABLE;


--
-- Name: launch_configurations launch_configurations_fee_policy_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.launch_configurations
    ADD CONSTRAINT launch_configurations_fee_policy_id_fkey FOREIGN KEY (fee_policy_id) REFERENCES trading.fee_policy_versions(id) DEFERRABLE;


--
-- Name: launch_contract_plans launch_contract_plan_bot_fk; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.launch_contract_plans
    ADD CONSTRAINT launch_contract_plan_bot_fk FOREIGN KEY (bot_id) REFERENCES bot.launch_snapshots(bot_id);


--
-- Name: launch_snapshots launch_snapshots_bot_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.launch_snapshots
    ADD CONSTRAINT launch_snapshots_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: runtime_state_changes runtime_state_changes_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.runtime_state_changes
    ADD CONSTRAINT runtime_state_changes_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: runtime_state_changes runtime_state_changes_bot_id_runtime_state_value_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.runtime_state_changes
    ADD CONSTRAINT runtime_state_changes_bot_id_runtime_state_value_id_fkey FOREIGN KEY (bot_id, runtime_state_value_id) REFERENCES bot.runtime_state_values(bot_id, id) DEFERRABLE;


--
-- Name: runtime_state_values runtime_state_values_bot_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.runtime_state_values
    ADD CONSTRAINT runtime_state_values_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: runtime_state_values runtime_state_values_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.runtime_state_values
    ADD CONSTRAINT runtime_state_values_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: runtime_state_values runtime_state_values_instrument_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.runtime_state_values
    ADD CONSTRAINT runtime_state_values_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: runtime_state_values runtime_state_values_partition_id_flow_id_fkey; Type: FK CONSTRAINT; Schema: bot; Owner: -
--

ALTER TABLE ONLY bot.runtime_state_values
    ADD CONSTRAINT runtime_state_values_partition_id_flow_id_fkey FOREIGN KEY (partition_id, flow_id) REFERENCES bot.flows(partition_id, id) DEFERRABLE;


--
-- Name: backtest_aggregate_results backtest_aggregate_results_evaluation_plan_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_aggregate_results
    ADD CONSTRAINT backtest_aggregate_results_evaluation_plan_room_id_fkey FOREIGN KEY (evaluation_plan_room_id) REFERENCES competition.backtest_evaluation_plans(room_id) DEFERRABLE;


--
-- Name: backtest_aggregate_results backtest_aggregate_results_participation_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_aggregate_results
    ADD CONSTRAINT backtest_aggregate_results_participation_id_fkey FOREIGN KEY (participation_id) REFERENCES competition.participations(id) DEFERRABLE;


--
-- Name: backtest_aggregate_results backtest_aggregate_results_scoring_template_version_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_aggregate_results
    ADD CONSTRAINT backtest_aggregate_results_scoring_template_version_id_fkey FOREIGN KEY (scoring_template_version_id) REFERENCES competition.scoring_template_versions(id) DEFERRABLE;


--
-- Name: backtest_evaluation_periods backtest_evaluation_periods_evaluation_plan_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_evaluation_periods
    ADD CONSTRAINT backtest_evaluation_periods_evaluation_plan_room_id_fkey FOREIGN KEY (evaluation_plan_room_id) REFERENCES competition.backtest_evaluation_plans(room_id) DEFERRABLE;


--
-- Name: backtest_evaluation_plans backtest_evaluation_plans_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_evaluation_plans
    ADD CONSTRAINT backtest_evaluation_plans_room_id_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: backtest_period_datasets backtest_period_datasets_dataset_manifest_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_datasets
    ADD CONSTRAINT backtest_period_datasets_dataset_manifest_id_fkey FOREIGN KEY (dataset_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: backtest_period_datasets backtest_period_datasets_evaluation_period_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_datasets
    ADD CONSTRAINT backtest_period_datasets_evaluation_period_id_fkey FOREIGN KEY (evaluation_period_id) REFERENCES competition.backtest_evaluation_periods(id) DEFERRABLE;


--
-- Name: backtest_period_feature_materializations backtest_period_feature_materia_feature_materialization_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_feature_materializations
    ADD CONSTRAINT backtest_period_feature_materia_feature_materialization_id_fkey FOREIGN KEY (feature_materialization_id) REFERENCES market_data.feature_materializations(id) DEFERRABLE;


--
-- Name: backtest_period_feature_materializations backtest_period_feature_materializati_evaluation_period_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_feature_materializations
    ADD CONSTRAINT backtest_period_feature_materializati_evaluation_period_id_fkey FOREIGN KEY (evaluation_period_id) REFERENCES competition.backtest_evaluation_periods(id) DEFERRABLE;


--
-- Name: backtest_period_runs backtest_period_runs_evaluation_period_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_runs
    ADD CONSTRAINT backtest_period_runs_evaluation_period_id_fkey FOREIGN KEY (evaluation_period_id) REFERENCES competition.backtest_evaluation_periods(id) DEFERRABLE;


--
-- Name: backtest_period_runs backtest_period_runs_participation_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_runs
    ADD CONSTRAINT backtest_period_runs_participation_id_fkey FOREIGN KEY (participation_id) REFERENCES competition.participations(id) DEFERRABLE;


--
-- Name: backtest_period_runs backtest_period_runs_run_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.backtest_period_runs
    ADD CONSTRAINT backtest_period_runs_run_id_fkey FOREIGN KEY (run_id) REFERENCES backtest.runs(id) DEFERRABLE;


--
-- Name: room_final_access_grants competition_room_final_access_grants_account_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_final_access_grants
    ADD CONSTRAINT competition_room_final_access_grants_account_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: room_final_access_grants competition_room_final_access_grants_room_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_final_access_grants
    ADD CONSTRAINT competition_room_final_access_grants_room_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: room_final_access_grants competition_room_final_access_grants_snapshot_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_final_access_grants
    ADD CONSTRAINT competition_room_final_access_grants_snapshot_fkey FOREIGN KEY (snapshot_id) REFERENCES competition.leaderboard_snapshots(id) DEFERRABLE;


--
-- Name: leaderboard_entries leaderboard_entries_backtest_aggregate_result_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.leaderboard_entries
    ADD CONSTRAINT leaderboard_entries_backtest_aggregate_result_id_fkey FOREIGN KEY (backtest_aggregate_result_id) REFERENCES competition.backtest_aggregate_results(id) DEFERRABLE;


--
-- Name: leaderboard_entries leaderboard_entries_participation_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.leaderboard_entries
    ADD CONSTRAINT leaderboard_entries_participation_id_fkey FOREIGN KEY (participation_id) REFERENCES competition.participations(id) DEFERRABLE;


--
-- Name: leaderboard_entries leaderboard_entries_performance_snapshot_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.leaderboard_entries
    ADD CONSTRAINT leaderboard_entries_performance_snapshot_id_fkey FOREIGN KEY (performance_snapshot_id) REFERENCES performance.bot_snapshots(id) DEFERRABLE;


--
-- Name: leaderboard_entries leaderboard_entries_snapshot_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.leaderboard_entries
    ADD CONSTRAINT leaderboard_entries_snapshot_id_fkey FOREIGN KEY (snapshot_id) REFERENCES competition.leaderboard_snapshots(id) DEFERRABLE;


--
-- Name: leaderboard_snapshots leaderboard_snapshots_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.leaderboard_snapshots
    ADD CONSTRAINT leaderboard_snapshots_room_id_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: leaderboard_snapshots leaderboard_snapshots_scoring_template_version_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.leaderboard_snapshots
    ADD CONSTRAINT leaderboard_snapshots_scoring_template_version_id_fkey FOREIGN KEY (scoring_template_version_id) REFERENCES competition.scoring_template_versions(id) DEFERRABLE;


--
-- Name: live_evaluation_segments live_evaluation_segments_participation_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.live_evaluation_segments
    ADD CONSTRAINT live_evaluation_segments_participation_id_fkey FOREIGN KEY (participation_id) REFERENCES competition.participations(id) DEFERRABLE;


--
-- Name: live_room_rules live_room_rules_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.live_room_rules
    ADD CONSTRAINT live_room_rules_room_id_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: participation_events participation_events_participation_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.participation_events
    ADD CONSTRAINT participation_events_participation_id_fkey FOREIGN KEY (participation_id) REFERENCES competition.participations(id) DEFERRABLE;


--
-- Name: participations participations_bot_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.participations
    ADD CONSTRAINT participations_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: participations participations_owner_account_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.participations
    ADD CONSTRAINT participations_owner_account_id_fkey FOREIGN KEY (owner_account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: participations participations_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.participations
    ADD CONSTRAINT participations_room_id_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: room_evaluation_account_results room_evaluation_account_result_participation_fk; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_evaluation_account_results
    ADD CONSTRAINT room_evaluation_account_result_participation_fk FOREIGN KEY (participation_id) REFERENCES competition.participations(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: room_events room_events_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_events
    ADD CONSTRAINT room_events_room_id_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: room_invitations room_invitations_issued_by_account_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_invitations
    ADD CONSTRAINT room_invitations_issued_by_account_id_fkey FOREIGN KEY (issued_by_account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: room_invitations room_invitations_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_invitations
    ADD CONSTRAINT room_invitations_room_id_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: room_rules room_rules_buying_power_buffer_policy_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_rules
    ADD CONSTRAINT room_rules_buying_power_buffer_policy_id_fkey FOREIGN KEY (buying_power_buffer_policy_id) REFERENCES trading.buying_power_buffer_policy_versions(id) DEFERRABLE;


--
-- Name: room_rules room_rules_fee_policy_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_rules
    ADD CONSTRAINT room_rules_fee_policy_id_fkey FOREIGN KEY (fee_policy_id) REFERENCES trading.fee_policy_versions(id) DEFERRABLE;


--
-- Name: room_rules room_rules_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_rules
    ADD CONSTRAINT room_rules_room_id_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: room_rules room_rules_scoring_template_version_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_rules
    ADD CONSTRAINT room_rules_scoring_template_version_id_fkey FOREIGN KEY (scoring_template_version_id) REFERENCES competition.scoring_template_versions(id) DEFERRABLE;


--
-- Name: room_schedules room_schedules_room_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.room_schedules
    ADD CONSTRAINT room_schedules_room_id_fkey FOREIGN KEY (room_id) REFERENCES competition.rooms(id) DEFERRABLE;


--
-- Name: rooms rooms_created_by_operator_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.rooms
    ADD CONSTRAINT rooms_created_by_operator_id_fkey FOREIGN KEY (created_by_operator_id) REFERENCES operations.operator_accounts(id) DEFERRABLE;


--
-- Name: rooms rooms_creator_account_id_fkey; Type: FK CONSTRAINT; Schema: competition; Owner: -
--

ALTER TABLE ONLY competition.rooms
    ADD CONSTRAINT rooms_creator_account_id_fkey FOREIGN KEY (creator_account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: account_closure_readiness account_closure_readiness_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_closure_readiness
    ADD CONSTRAINT account_closure_readiness_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: account_closure_readiness account_closure_readiness_correlation_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_closure_readiness
    ADD CONSTRAINT account_closure_readiness_correlation_id_fkey FOREIGN KEY (correlation_id) REFERENCES identity.account_closure_runs(correlation_id) ON DELETE CASCADE;


--
-- Name: account_closure_runs account_closure_runs_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_closure_runs
    ADD CONSTRAINT account_closure_runs_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: account_consents account_consents_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_consents
    ADD CONSTRAINT account_consents_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: account_consents account_consents_policy_document_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_consents
    ADD CONSTRAINT account_consents_policy_document_id_fkey FOREIGN KEY (policy_document_id) REFERENCES identity.policy_documents(id) DEFERRABLE;


--
-- Name: account_consents account_consents_supersedes_consent_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_consents
    ADD CONSTRAINT account_consents_supersedes_consent_id_fkey FOREIGN KEY (supersedes_consent_id) REFERENCES identity.account_consents(id) DEFERRABLE;


--
-- Name: account_emails account_emails_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_emails
    ADD CONSTRAINT account_emails_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: account_identifier_quarantines account_identifier_quarantine_event_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_identifier_quarantines
    ADD CONSTRAINT account_identifier_quarantine_event_account_fk FOREIGN KEY (account_id, lifecycle_event_id) REFERENCES identity.account_lifecycle_events(account_id, id);


--
-- Name: account_identifier_quarantines account_identifier_quarantines_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_identifier_quarantines
    ADD CONSTRAINT account_identifier_quarantines_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: account_legal_holds account_legal_holds_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_legal_holds
    ADD CONSTRAINT account_legal_holds_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: account_lifecycle_events account_lifecycle_event_retention_policy_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_lifecycle_events
    ADD CONSTRAINT account_lifecycle_event_retention_policy_fk FOREIGN KEY (retention_policy_version) REFERENCES identity.account_retention_policy_versions(version);


--
-- Name: account_lifecycle_events account_lifecycle_events_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_lifecycle_events
    ADD CONSTRAINT account_lifecycle_events_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: account_lifecycle_command_receipts account_lifecycle_receipt_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_lifecycle_command_receipts
    ADD CONSTRAINT account_lifecycle_receipt_account_fk FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: account_lifecycle_command_receipts account_lifecycle_receipt_event_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_lifecycle_command_receipts
    ADD CONSTRAINT account_lifecycle_receipt_event_account_fk FOREIGN KEY (account_id, lifecycle_event_id) REFERENCES identity.account_lifecycle_events(account_id, id);


--
-- Name: account_preferences account_preferences_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_preferences
    ADD CONSTRAINT account_preferences_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: account_retention_execution_attempts account_retention_execution_attempts_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_execution_attempts
    ADD CONSTRAINT account_retention_execution_attempts_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: account_retention_execution_attempts account_retention_execution_attempts_obligation_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_execution_attempts
    ADD CONSTRAINT account_retention_execution_attempts_obligation_id_fkey FOREIGN KEY (obligation_id) REFERENCES identity.account_retention_obligations(id);


--
-- Name: account_retention_obligations account_retention_lifecycle_event_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_obligations
    ADD CONSTRAINT account_retention_lifecycle_event_account_fk FOREIGN KEY (account_id, lifecycle_event_id) REFERENCES identity.account_lifecycle_events(account_id, id);


--
-- Name: account_retention_obligations account_retention_obligations_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_obligations
    ADD CONSTRAINT account_retention_obligations_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: account_retention_policy_rules account_retention_policy_rule_version_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_policy_rules
    ADD CONSTRAINT account_retention_policy_rule_version_fk FOREIGN KEY (policy_version) REFERENCES identity.account_retention_policy_versions(version);


--
-- Name: account_retention_obligations account_retention_policy_version_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_retention_obligations
    ADD CONSTRAINT account_retention_policy_version_fk FOREIGN KEY (retention_policy_version) REFERENCES identity.account_retention_policy_versions(version);


--
-- Name: account_sanction_events account_sanction_event_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_events
    ADD CONSTRAINT account_sanction_event_account_fk FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: account_sanction_events account_sanction_events_actor_operator_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_events
    ADD CONSTRAINT account_sanction_events_actor_operator_id_fkey FOREIGN KEY (actor_operator_id) REFERENCES operations.operator_accounts(id) DEFERRABLE;


--
-- Name: account_sanction_events account_sanction_events_evidence_object_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_events
    ADD CONSTRAINT account_sanction_events_evidence_object_id_fkey FOREIGN KEY (evidence_object_id) REFERENCES storage.objects(id) DEFERRABLE;


--
-- Name: account_sanction_events account_sanction_events_sanction_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_events
    ADD CONSTRAINT account_sanction_events_sanction_id_fkey FOREIGN KEY (sanction_id) REFERENCES identity.account_sanctions(id) DEFERRABLE;


--
-- Name: account_sanction_heads account_sanction_heads_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_heads
    ADD CONSTRAINT account_sanction_heads_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: account_sanctions account_sanctions_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanctions
    ADD CONSTRAINT account_sanctions_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: account_sanctions account_sanctions_applied_by_operator_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanctions
    ADD CONSTRAINT account_sanctions_applied_by_operator_id_fkey FOREIGN KEY (applied_by_operator_id) REFERENCES operations.operator_accounts(id) DEFERRABLE;


--
-- Name: account_sanctions account_sanctions_source_case_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanctions
    ADD CONSTRAINT account_sanctions_source_case_id_fkey FOREIGN KEY (source_case_id) REFERENCES operations.cases(id) DEFERRABLE;


--
-- Name: account_security_states account_security_states_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_security_states
    ADD CONSTRAINT account_security_states_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: authentication_events authentication_events_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.authentication_events
    ADD CONSTRAINT authentication_events_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: authentication_events authentication_events_new_login_identity_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.authentication_events
    ADD CONSTRAINT authentication_events_new_login_identity_id_fkey FOREIGN KEY (new_login_identity_id) REFERENCES identity.login_identities(id) DEFERRABLE;


--
-- Name: authentication_events authentication_events_previous_login_identity_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.authentication_events
    ADD CONSTRAINT authentication_events_previous_login_identity_id_fkey FOREIGN KEY (previous_login_identity_id) REFERENCES identity.login_identities(id) DEFERRABLE;


--
-- Name: authentication_events authentication_events_subject_login_identity_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.authentication_events
    ADD CONSTRAINT authentication_events_subject_login_identity_id_fkey FOREIGN KEY (subject_login_identity_id) REFERENCES identity.login_identities(id) DEFERRABLE;


--
-- Name: delegated_authorization_events delegated_authorization_events_authorization_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorization_events
    ADD CONSTRAINT delegated_authorization_events_authorization_id_fkey FOREIGN KEY (authorization_id) REFERENCES identity.delegated_authorizations(id) DEFERRABLE;


--
-- Name: delegated_authorizations delegated_authorization_replacement_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorizations
    ADD CONSTRAINT delegated_authorization_replacement_fk FOREIGN KEY (replaces_authorization_id, account_id) REFERENCES identity.delegated_authorizations(id, account_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: delegated_authorization_scopes delegated_authorization_scopes_authorization_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorization_scopes
    ADD CONSTRAINT delegated_authorization_scopes_authorization_id_fkey FOREIGN KEY (authorization_id) REFERENCES identity.delegated_authorizations(id) DEFERRABLE;


--
-- Name: delegated_authorizations delegated_authorizations_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorizations
    ADD CONSTRAINT delegated_authorizations_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: delegated_authorizations delegated_authorizations_disclosure_policy_document_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorizations
    ADD CONSTRAINT delegated_authorizations_disclosure_policy_document_id_fkey FOREIGN KEY (disclosure_policy_document_id) REFERENCES identity.policy_documents(id) DEFERRABLE;


--
-- Name: delegated_credentials delegated_credentials_authorization_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_credentials
    ADD CONSTRAINT delegated_credentials_authorization_id_fkey FOREIGN KEY (authorization_id) REFERENCES identity.delegated_authorizations(id) DEFERRABLE;


--
-- Name: delegated_credentials delegated_credentials_superseded_by_credential_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_credentials
    ADD CONSTRAINT delegated_credentials_superseded_by_credential_id_fkey FOREIGN KEY (superseded_by_credential_id) REFERENCES identity.delegated_credentials(id) DEFERRABLE;


--
-- Name: delegated_strategy_derivations delegated_strategy_derivation_credential_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_strategy_derivations
    ADD CONSTRAINT delegated_strategy_derivation_credential_fk FOREIGN KEY (authorization_id, credential_id) REFERENCES identity.delegated_credentials(authorization_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: delegated_strategy_derivations delegated_strategy_derivation_result_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_strategy_derivations
    ADD CONSTRAINT delegated_strategy_derivation_result_fk FOREIGN KEY (result_strategy_id, owner_account_id_at_creation) REFERENCES strategy.strategies(id, owner_account_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: delegated_strategy_derivations delegated_strategy_derivation_source_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_strategy_derivations
    ADD CONSTRAINT delegated_strategy_derivation_source_fk FOREIGN KEY (authorization_id, source_strategy_id) REFERENCES identity.delegated_authorization_strategy_targets(authorization_id, strategy_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: delegated_authorization_strategy_targets delegated_strategy_target_authorization_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorization_strategy_targets
    ADD CONSTRAINT delegated_strategy_target_authorization_fk FOREIGN KEY (authorization_id, owner_account_id_at_grant) REFERENCES identity.delegated_authorizations(id, account_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: delegated_authorization_strategy_targets delegated_strategy_target_strategy_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.delegated_authorization_strategy_targets
    ADD CONSTRAINT delegated_strategy_target_strategy_fk FOREIGN KEY (strategy_id, owner_account_id_at_grant) REFERENCES strategy.strategies(id, owner_account_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: device_authorization_requests device_authorization_requests_approved_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.device_authorization_requests
    ADD CONSTRAINT device_authorization_requests_approved_account_id_fkey FOREIGN KEY (approved_account_id) REFERENCES identity.accounts(id);


--
-- Name: device_authorization_requests device_authorization_requests_approved_login_identity_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.device_authorization_requests
    ADD CONSTRAINT device_authorization_requests_approved_login_identity_id_fkey FOREIGN KEY (approved_login_identity_id) REFERENCES identity.login_identities(id);


--
-- Name: email_verification_requests email_verification_requests_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.email_verification_requests
    ADD CONSTRAINT email_verification_requests_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.account_emails(account_id) DEFERRABLE;


--
-- Name: accounts last_lifecycle_event_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.accounts
    ADD CONSTRAINT last_lifecycle_event_account_fk FOREIGN KEY (id, last_lifecycle_event_id) REFERENCES identity.account_lifecycle_events(account_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: login_identities login_identities_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.login_identities
    ADD CONSTRAINT login_identities_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: login_identities login_identities_provider_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.login_identities
    ADD CONSTRAINT login_identities_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES identity.auth_providers(id) DEFERRABLE;


--
-- Name: oidc_step_up_nonces oidc_step_up_nonce_consumed_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.oidc_step_up_nonces
    ADD CONSTRAINT oidc_step_up_nonce_consumed_account_fk FOREIGN KEY (consumed_by_account_id) REFERENCES identity.accounts(id);


--
-- Name: oidc_step_up_nonces oidc_step_up_nonce_provider_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.oidc_step_up_nonces
    ADD CONSTRAINT oidc_step_up_nonce_provider_fk FOREIGN KEY (provider_id) REFERENCES identity.auth_providers(id);


--
-- Name: password_credentials password_credentials_login_identity_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.password_credentials
    ADD CONSTRAINT password_credentials_login_identity_id_fkey FOREIGN KEY (login_identity_id) REFERENCES identity.login_identities(id) DEFERRABLE;


--
-- Name: password_reset_requests password_reset_requests_account_id_login_identity_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.password_reset_requests
    ADD CONSTRAINT password_reset_requests_account_id_login_identity_id_fkey FOREIGN KEY (account_id, login_identity_id) REFERENCES identity.login_identities(account_id, id) DEFERRABLE;


--
-- Name: account_lifecycle_events previous_event_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_lifecycle_events
    ADD CONSTRAINT previous_event_account_fk FOREIGN KEY (account_id, previous_event_id) REFERENCES identity.account_lifecycle_events(account_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: recovery_code_sets recovery_code_sets_account_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.recovery_code_sets
    ADD CONSTRAINT recovery_code_sets_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: recovery_codes recovery_codes_recovery_code_set_id_fkey; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.recovery_codes
    ADD CONSTRAINT recovery_codes_recovery_code_set_id_fkey FOREIGN KEY (recovery_code_set_id) REFERENCES identity.recovery_code_sets(id) DEFERRABLE;


--
-- Name: refresh_token_families refresh_token_family_login_identity_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.refresh_token_families
    ADD CONSTRAINT refresh_token_family_login_identity_fk FOREIGN KEY (account_id, authenticated_by_login_identity_id) REFERENCES identity.login_identities(account_id, id);


--
-- Name: account_sanction_command_receipts sanction_receipt_account_fk; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.account_sanction_command_receipts
    ADD CONSTRAINT sanction_receipt_account_fk FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: corporate_actions corporate_actions_instrument_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.corporate_actions
    ADD CONSTRAINT corporate_actions_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: corporate_actions corporate_actions_source_manifest_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.corporate_actions
    ADD CONSTRAINT corporate_actions_source_manifest_id_fkey FOREIGN KEY (source_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: corporate_actions corporate_actions_supersedes_action_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.corporate_actions
    ADD CONSTRAINT corporate_actions_supersedes_action_id_fkey FOREIGN KEY (supersedes_action_id) REFERENCES market_data.corporate_actions(id) DEFERRABLE;


--
-- Name: dataset_lineage dataset_lineage_derived_manifest_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_lineage
    ADD CONSTRAINT dataset_lineage_derived_manifest_id_fkey FOREIGN KEY (derived_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: dataset_lineage dataset_lineage_source_manifest_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_lineage
    ADD CONSTRAINT dataset_lineage_source_manifest_id_fkey FOREIGN KEY (source_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: dataset_manifests dataset_manifests_feed_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_manifests
    ADD CONSTRAINT dataset_manifests_feed_id_fkey FOREIGN KEY (feed_id) REFERENCES market_data.feeds(id) DEFERRABLE;


--
-- Name: dataset_manifests dataset_manifests_instrument_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_manifests
    ADD CONSTRAINT dataset_manifests_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: dataset_manifests dataset_manifests_supersedes_manifest_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_manifests
    ADD CONSTRAINT dataset_manifests_supersedes_manifest_id_fkey FOREIGN KEY (supersedes_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: dataset_object_lineage dataset_object_lineage_derived_dataset_object_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_object_lineage
    ADD CONSTRAINT dataset_object_lineage_derived_dataset_object_id_fkey FOREIGN KEY (derived_dataset_object_id) REFERENCES market_data.dataset_objects(id) DEFERRABLE;


--
-- Name: dataset_object_lineage dataset_object_lineage_pipeline_run_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_object_lineage
    ADD CONSTRAINT dataset_object_lineage_pipeline_run_id_fkey FOREIGN KEY (pipeline_run_id) REFERENCES market_data.pipeline_runs(id) DEFERRABLE;


--
-- Name: dataset_object_lineage dataset_object_lineage_source_dataset_object_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_object_lineage
    ADD CONSTRAINT dataset_object_lineage_source_dataset_object_id_fkey FOREIGN KEY (source_dataset_object_id) REFERENCES market_data.dataset_objects(id) DEFERRABLE;


--
-- Name: dataset_objects dataset_objects_dataset_manifest_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_objects
    ADD CONSTRAINT dataset_objects_dataset_manifest_id_fkey FOREIGN KEY (dataset_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: dataset_objects dataset_objects_object_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.dataset_objects
    ADD CONSTRAINT dataset_objects_object_id_fkey FOREIGN KEY (object_id) REFERENCES storage.objects(id) DEFERRABLE;


--
-- Name: feature_definitions feature_definitions_element_catalog_version_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_definitions
    ADD CONSTRAINT feature_definitions_element_catalog_version_id_fkey FOREIGN KEY (element_catalog_version_id) REFERENCES strategy.element_catalog_versions(id) DEFERRABLE;


--
-- Name: feature_materializations feature_materializations_feature_definition_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_materializations
    ADD CONSTRAINT feature_materializations_feature_definition_id_fkey FOREIGN KEY (feature_definition_id) REFERENCES market_data.feature_definitions(id) DEFERRABLE;


--
-- Name: feature_materializations feature_materializations_instrument_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_materializations
    ADD CONSTRAINT feature_materializations_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: feature_materializations feature_materializations_output_dataset_manifest_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_materializations
    ADD CONSTRAINT feature_materializations_output_dataset_manifest_id_fkey FOREIGN KEY (output_dataset_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: feature_materializations feature_materializations_pipeline_run_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_materializations
    ADD CONSTRAINT feature_materializations_pipeline_run_id_fkey FOREIGN KEY (pipeline_run_id) REFERENCES market_data.pipeline_runs(id) DEFERRABLE;


--
-- Name: feature_snapshot_batches feature_snapshot_batches_snapshot_object_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feature_snapshot_batches
    ADD CONSTRAINT feature_snapshot_batches_snapshot_object_id_fkey FOREIGN KEY (snapshot_object_id) REFERENCES storage.objects(id) DEFERRABLE;


--
-- Name: feeds feeds_provider_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.feeds
    ADD CONSTRAINT feeds_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES market_data.providers(id) DEFERRABLE;


--
-- Name: instrument_symbols instrument_symbols_instrument_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.instrument_symbols
    ADD CONSTRAINT instrument_symbols_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: quality_incidents quality_incidents_dataset_manifest_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.quality_incidents
    ADD CONSTRAINT quality_incidents_dataset_manifest_id_fkey FOREIGN KEY (dataset_manifest_id) REFERENCES market_data.dataset_manifests(id) DEFERRABLE;


--
-- Name: quality_incidents quality_incidents_evidence_object_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.quality_incidents
    ADD CONSTRAINT quality_incidents_evidence_object_id_fkey FOREIGN KEY (evidence_object_id) REFERENCES storage.objects(id) DEFERRABLE;


--
-- Name: quality_incidents quality_incidents_instrument_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.quality_incidents
    ADD CONSTRAINT quality_incidents_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: stream_watermarks stream_watermarks_feed_id_fkey; Type: FK CONSTRAINT; Schema: market_data; Owner: -
--

ALTER TABLE ONLY market_data.stream_watermarks
    ADD CONSTRAINT stream_watermarks_feed_id_fkey FOREIGN KEY (feed_id) REFERENCES market_data.feeds(id) DEFERRABLE;


--
-- Name: account_email_notification_preferences account_email_notification_preference_account_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.account_email_notification_preferences
    ADD CONSTRAINT account_email_notification_preference_account_fk FOREIGN KEY (account_id) REFERENCES identity.accounts(id) ON DELETE CASCADE;


--
-- Name: account_integrations account_integrations_account_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.account_integrations
    ADD CONSTRAINT account_integrations_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: audit_events audit_events_delegated_authorization_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.audit_events
    ADD CONSTRAINT audit_events_delegated_authorization_id_fkey FOREIGN KEY (delegated_authorization_id) REFERENCES identity.delegated_authorizations(id) DEFERRABLE;


--
-- Name: audit_events audit_events_evidence_object_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.audit_events
    ADD CONSTRAINT audit_events_evidence_object_id_fkey FOREIGN KEY (evidence_object_id) REFERENCES storage.objects(id) DEFERRABLE;


--
-- Name: audit_events audit_rbac_catalog_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.audit_events
    ADD CONSTRAINT audit_rbac_catalog_fk FOREIGN KEY (resolved_rbac_catalog_version) REFERENCES operations.rbac_catalog_versions(catalog_version);


--
-- Name: batch_run_checkpoints batch_checkpoint_job_version_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_run_checkpoints
    ADD CONSTRAINT batch_checkpoint_job_version_fk FOREIGN KEY (job_code, job_version) REFERENCES operations.batch_job_versions(job_code, job_version);


--
-- Name: batch_item_attempts batch_item_attempts_batch_item_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_item_attempts
    ADD CONSTRAINT batch_item_attempts_batch_item_id_fkey FOREIGN KEY (batch_item_id) REFERENCES operations.batch_items(id);


--
-- Name: batch_items batch_items_discovered_by_run_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_items_discovered_by_run_id_fkey FOREIGN KEY (discovered_by_run_id) REFERENCES operations.batch_runs(id);


--
-- Name: batch_items batch_items_original_item_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_items_original_item_id_fkey FOREIGN KEY (original_item_id) REFERENCES operations.batch_items(id);


--
-- Name: batch_items batch_items_replay_audit_event_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_items_replay_audit_event_id_fkey FOREIGN KEY (replay_audit_event_id) REFERENCES operations.audit_events(id);


--
-- Name: batch_items batch_items_replayed_from_item_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_items
    ADD CONSTRAINT batch_items_replayed_from_item_id_fkey FOREIGN KEY (replayed_from_item_id) REFERENCES operations.batch_items(id);


--
-- Name: batch_run_checkpoints batch_run_checkpoints_last_run_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_run_checkpoints
    ADD CONSTRAINT batch_run_checkpoints_last_run_id_fkey FOREIGN KEY (last_run_id) REFERENCES operations.batch_runs(id);


--
-- Name: batch_runs batch_run_job_version_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.batch_runs
    ADD CONSTRAINT batch_run_job_version_fk FOREIGN KEY (job_code, job_version) REFERENCES operations.batch_job_versions(job_code, job_version);


--
-- Name: cases case_assignee_operator_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.cases
    ADD CONSTRAINT case_assignee_operator_fk FOREIGN KEY (assignee_operator_id) REFERENCES operations.operator_accounts(id) DEFERRABLE;


--
-- Name: case_command_receipts case_command_receipt_case_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_command_receipts
    ADD CONSTRAINT case_command_receipt_case_fk FOREIGN KEY (account_id, case_id) REFERENCES operations.cases(account_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: case_command_receipts case_command_receipt_event_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_command_receipts
    ADD CONSTRAINT case_command_receipt_event_fk FOREIGN KEY (case_id, case_event_id) REFERENCES operations.case_events(case_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: case_deadline_receipts case_deadline_receipt_case_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_deadline_receipts
    ADD CONSTRAINT case_deadline_receipt_case_fk FOREIGN KEY (case_id) REFERENCES operations.cases(id);


--
-- Name: case_deadline_receipts case_deadline_receipt_event_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_deadline_receipts
    ADD CONSTRAINT case_deadline_receipt_event_fk FOREIGN KEY (case_id, case_event_id) REFERENCES operations.case_events(case_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: case_events case_event_account_case_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_events
    ADD CONSTRAINT case_event_account_case_fk FOREIGN KEY (account_id, case_id) REFERENCES operations.cases(account_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: case_events case_event_previous_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_events
    ADD CONSTRAINT case_event_previous_fk FOREIGN KEY (case_id, previous_event_id) REFERENCES operations.case_events(case_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: case_events case_events_case_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_events
    ADD CONSTRAINT case_events_case_id_fkey FOREIGN KEY (case_id) REFERENCES operations.cases(id) DEFERRABLE;


--
-- Name: case_evidence_references case_evidence_case_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_evidence_references
    ADD CONSTRAINT case_evidence_case_fk FOREIGN KEY (account_id, case_id) REFERENCES operations.cases(account_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: case_evidence_references case_evidence_event_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_evidence_references
    ADD CONSTRAINT case_evidence_event_fk FOREIGN KEY (case_id, case_event_id) REFERENCES operations.case_events(case_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: case_evidence_references case_evidence_object_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_evidence_references
    ADD CONSTRAINT case_evidence_object_fk FOREIGN KEY (storage_object_id) REFERENCES storage.objects(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: case_evidence_references case_evidence_owner_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.case_evidence_references
    ADD CONSTRAINT case_evidence_owner_fk FOREIGN KEY (owner_account_id) REFERENCES identity.accounts(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cases case_head_event_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.cases
    ADD CONSTRAINT case_head_event_fk FOREIGN KEY (id, last_case_event_id) REFERENCES operations.case_events(case_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cases cases_account_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.cases
    ADD CONSTRAINT cases_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: delivery_attempts delivery_attempts_notification_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.delivery_attempts
    ADD CONSTRAINT delivery_attempts_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES operations.notifications(id) DEFERRABLE;


--
-- Name: delivery_attempts notification_delivery_outbox_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.delivery_attempts
    ADD CONSTRAINT notification_delivery_outbox_fk FOREIGN KEY (outbox_message_id) REFERENCES operations.outbox_messages(id) DEFERRABLE;


--
-- Name: notification_preferences notification_preferences_account_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.notification_preferences
    ADD CONSTRAINT notification_preferences_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: notification_preferences notification_preferences_bot_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.notification_preferences
    ADD CONSTRAINT notification_preferences_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: notifications notifications_account_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.notifications
    ADD CONSTRAINT notifications_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: notifications notifications_bot_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.notifications
    ADD CONSTRAINT notifications_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: operator_role_assignments operator_assignment_catalog_role_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_role_assignments
    ADD CONSTRAINT operator_assignment_catalog_role_fk FOREIGN KEY (catalog_version, role_id) REFERENCES operations.rbac_catalog_roles(catalog_version, role_id) DEFERRABLE;


--
-- Name: operator_bootstrap_receipts operator_bootstrap_account_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_bootstrap_receipts
    ADD CONSTRAINT operator_bootstrap_account_fk FOREIGN KEY (operator_account_id) REFERENCES operations.operator_accounts(id);


--
-- Name: operator_login_credentials operator_login_credentials_account_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_login_credentials
    ADD CONSTRAINT operator_login_credentials_account_fk FOREIGN KEY (operator_account_id) REFERENCES operations.operator_accounts(id);


--
-- Name: operator_sessions operator_sessions_account_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_sessions
    ADD CONSTRAINT operator_sessions_account_fk FOREIGN KEY (operator_account_id) REFERENCES operations.operator_accounts(id);


--
-- Name: operator_bootstrap_receipts operator_bootstrap_assignment_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_bootstrap_receipts
    ADD CONSTRAINT operator_bootstrap_assignment_fk FOREIGN KEY (operator_role_assignment_id) REFERENCES operations.operator_role_assignments(id);


--
-- Name: operator_bootstrap_receipts operator_bootstrap_audit_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_bootstrap_receipts
    ADD CONSTRAINT operator_bootstrap_audit_fk FOREIGN KEY (audit_event_id) REFERENCES operations.audit_events(id);


--
-- Name: operator_bootstrap_receipts operator_bootstrap_catalog_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_bootstrap_receipts
    ADD CONSTRAINT operator_bootstrap_catalog_fk FOREIGN KEY (catalog_version) REFERENCES operations.rbac_catalog_versions(catalog_version);


--
-- Name: operator_case_command_receipts operator_case_receipt_case_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_case_command_receipts
    ADD CONSTRAINT operator_case_receipt_case_fk FOREIGN KEY (case_id) REFERENCES operations.cases(id);


--
-- Name: operator_case_command_receipts operator_case_receipt_event_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_case_command_receipts
    ADD CONSTRAINT operator_case_receipt_event_fk FOREIGN KEY (case_id, case_event_id) REFERENCES operations.case_events(case_id, id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: operator_case_command_receipts operator_case_receipt_operator_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_case_command_receipts
    ADD CONSTRAINT operator_case_receipt_operator_fk FOREIGN KEY (operator_id) REFERENCES operations.operator_accounts(id);


--
-- Name: operator_role_assignments operator_role_assignments_granted_by_operator_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_role_assignments
    ADD CONSTRAINT operator_role_assignments_granted_by_operator_id_fkey FOREIGN KEY (granted_by_operator_id) REFERENCES operations.operator_accounts(id) DEFERRABLE;


--
-- Name: operator_role_assignments operator_role_assignments_operator_account_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_role_assignments
    ADD CONSTRAINT operator_role_assignments_operator_account_id_fkey FOREIGN KEY (operator_account_id) REFERENCES operations.operator_accounts(id) DEFERRABLE;


--
-- Name: operator_role_assignments operator_role_assignments_revoked_by_operator_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_role_assignments
    ADD CONSTRAINT operator_role_assignments_revoked_by_operator_id_fkey FOREIGN KEY (revoked_by_operator_id) REFERENCES operations.operator_accounts(id) DEFERRABLE;


--
-- Name: operator_role_assignments operator_role_assignments_role_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.operator_role_assignments
    ADD CONSTRAINT operator_role_assignments_role_id_fkey FOREIGN KEY (role_id) REFERENCES operations.roles(id) DEFERRABLE;


--
-- Name: outbox_delivery_attempts outbox_attempt_message_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_delivery_attempts
    ADD CONSTRAINT outbox_attempt_message_fk FOREIGN KEY (outbox_message_id) REFERENCES operations.outbox_messages(id) DEFERRABLE;


--
-- Name: outbox_consumer_receipts outbox_consumer_receipt_message_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_consumer_receipts
    ADD CONSTRAINT outbox_consumer_receipt_message_fk FOREIGN KEY (outbox_message_id) REFERENCES operations.outbox_messages(id) DEFERRABLE;


--
-- Name: outbox_messages outbox_original_message_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_messages
    ADD CONSTRAINT outbox_original_message_fk FOREIGN KEY (original_message_id) REFERENCES operations.outbox_messages(id) DEFERRABLE;


--
-- Name: outbox_messages outbox_replay_audit_event_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_messages
    ADD CONSTRAINT outbox_replay_audit_event_fk FOREIGN KEY (replay_audit_event_id) REFERENCES operations.audit_events(id) DEFERRABLE;


--
-- Name: outbox_messages outbox_replayed_from_message_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.outbox_messages
    ADD CONSTRAINT outbox_replayed_from_message_fk FOREIGN KEY (replayed_from_message_id) REFERENCES operations.outbox_messages(id) DEFERRABLE;


--
-- Name: rbac_catalog_permissions rbac_catalog_permission_id_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_permissions
    ADD CONSTRAINT rbac_catalog_permission_id_fk FOREIGN KEY (permission_id) REFERENCES operations.permissions(id);


--
-- Name: rbac_catalog_permissions rbac_catalog_permission_version_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_permissions
    ADD CONSTRAINT rbac_catalog_permission_version_fk FOREIGN KEY (catalog_version) REFERENCES operations.rbac_catalog_versions(catalog_version);


--
-- Name: rbac_catalog_roles rbac_catalog_role_id_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_roles
    ADD CONSTRAINT rbac_catalog_role_id_fk FOREIGN KEY (role_id) REFERENCES operations.roles(id);


--
-- Name: rbac_catalog_role_permissions rbac_catalog_role_permission_permission_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_role_permissions
    ADD CONSTRAINT rbac_catalog_role_permission_permission_fk FOREIGN KEY (catalog_version, permission_id) REFERENCES operations.rbac_catalog_permissions(catalog_version, permission_id);


--
-- Name: rbac_catalog_role_permissions rbac_catalog_role_permission_role_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_role_permissions
    ADD CONSTRAINT rbac_catalog_role_permission_role_fk FOREIGN KEY (catalog_version, role_id) REFERENCES operations.rbac_catalog_roles(catalog_version, role_id);


--
-- Name: rbac_catalog_roles rbac_catalog_role_version_fk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.rbac_catalog_roles
    ADD CONSTRAINT rbac_catalog_role_version_fk FOREIGN KEY (catalog_version) REFERENCES operations.rbac_catalog_versions(catalog_version);


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES operations.permissions(id) DEFERRABLE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES operations.roles(id) DEFERRABLE;


--
-- Name: bot_current_projections bot_current_projections_bot_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: -
--

ALTER TABLE ONLY performance.bot_current_projections
    ADD CONSTRAINT bot_current_projections_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: bot_snapshots bot_snapshots_bot_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: -
--

ALTER TABLE ONLY performance.bot_snapshots
    ADD CONSTRAINT bot_snapshots_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: series_manifests series_manifests_bot_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: -
--

ALTER TABLE ONLY performance.series_manifests
    ADD CONSTRAINT series_manifests_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: series_manifests series_manifests_object_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: -
--

ALTER TABLE ONLY performance.series_manifests
    ADD CONSTRAINT series_manifests_object_id_fkey FOREIGN KEY (object_id) REFERENCES storage.objects(id) DEFERRABLE;


--
-- Name: series_manifests series_manifests_supersedes_manifest_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: -
--

ALTER TABLE ONLY performance.series_manifests
    ADD CONSTRAINT series_manifests_supersedes_manifest_id_fkey FOREIGN KEY (supersedes_manifest_id) REFERENCES performance.series_manifests(id) DEFERRABLE;


--
-- Name: compiled_flow_plans compiled_flow_plans_element_catalog_version_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.compiled_flow_plans
    ADD CONSTRAINT compiled_flow_plans_element_catalog_version_id_fkey FOREIGN KEY (element_catalog_version_id) REFERENCES strategy.element_catalog_versions(id) DEFERRABLE;


--
-- Name: element_definitions element_definitions_element_catalog_version_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.element_definitions
    ADD CONSTRAINT element_definitions_element_catalog_version_id_fkey FOREIGN KEY (element_catalog_version_id) REFERENCES strategy.element_catalog_versions(id) DEFERRABLE;


--
-- Name: package_versions package_versions_element_catalog_version_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.package_versions
    ADD CONSTRAINT package_versions_element_catalog_version_id_fkey FOREIGN KEY (element_catalog_version_id) REFERENCES strategy.element_catalog_versions(id) DEFERRABLE;


--
-- Name: package_versions package_versions_package_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.package_versions
    ADD CONSTRAINT package_versions_package_id_fkey FOREIGN KEY (package_id) REFERENCES strategy.packages(id) DEFERRABLE;


--
-- Name: strategies strategies_owner_account_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategies
    ADD CONSTRAINT strategies_owner_account_id_fkey FOREIGN KEY (owner_account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: strategy_documents strategy_documents_strategy_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategy_documents
    ADD CONSTRAINT strategy_documents_strategy_id_fkey FOREIGN KEY (strategy_id) REFERENCES strategy.strategies(id) DEFERRABLE;


--
-- Name: strategy_edit_leases strategy_edit_leases_account_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategy_edit_leases
    ADD CONSTRAINT strategy_edit_leases_account_id_fkey FOREIGN KEY (account_id) REFERENCES identity.accounts(id);


--
-- Name: strategy_edit_leases strategy_edit_leases_delegated_credential_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategy_edit_leases
    ADD CONSTRAINT strategy_edit_leases_delegated_credential_id_fkey FOREIGN KEY (delegated_credential_id) REFERENCES identity.delegated_credentials(id) DEFERRABLE;


--
-- Name: strategy_edit_leases strategy_edit_leases_strategy_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.strategy_edit_leases
    ADD CONSTRAINT strategy_edit_leases_strategy_id_fkey FOREIGN KEY (strategy_id) REFERENCES strategy.strategies(id) DEFERRABLE;


--
-- Name: template_versions template_versions_element_catalog_version_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.template_versions
    ADD CONSTRAINT template_versions_element_catalog_version_id_fkey FOREIGN KEY (element_catalog_version_id) REFERENCES strategy.element_catalog_versions(id) DEFERRABLE;


--
-- Name: template_versions template_versions_template_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.template_versions
    ADD CONSTRAINT template_versions_template_id_fkey FOREIGN KEY (template_id) REFERENCES strategy.templates(id) DEFERRABLE;


--
-- Name: validation_runs validation_runs_delegated_authorization_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.validation_runs
    ADD CONSTRAINT validation_runs_delegated_authorization_id_fkey FOREIGN KEY (delegated_authorization_id) REFERENCES identity.delegated_authorizations(id) DEFERRABLE;


--
-- Name: validation_runs validation_runs_element_catalog_version_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.validation_runs
    ADD CONSTRAINT validation_runs_element_catalog_version_id_fkey FOREIGN KEY (element_catalog_version_id) REFERENCES strategy.element_catalog_versions(id) DEFERRABLE;


--
-- Name: validation_runs validation_runs_requested_by_account_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.validation_runs
    ADD CONSTRAINT validation_runs_requested_by_account_id_fkey FOREIGN KEY (requested_by_account_id) REFERENCES identity.accounts(id) DEFERRABLE;


--
-- Name: validation_runs validation_runs_strategy_id_fkey; Type: FK CONSTRAINT; Schema: strategy; Owner: -
--

ALTER TABLE ONLY strategy.validation_runs
    ADD CONSTRAINT validation_runs_strategy_id_fkey FOREIGN KEY (strategy_id) REFERENCES strategy.strategies(id) DEFERRABLE;


--
-- Name: bot_budget_projections bot_budget_projections_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.bot_budget_projections
    ADD CONSTRAINT bot_budget_projections_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: fill_adjustments fill_adjustments_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fill_adjustments
    ADD CONSTRAINT fill_adjustments_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: fill_adjustments fill_adjustments_bot_id_partition_id_fill_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fill_adjustments
    ADD CONSTRAINT fill_adjustments_bot_id_partition_id_fill_id_fkey FOREIGN KEY (bot_id, partition_id, fill_id) REFERENCES trading.fills(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: fill_component_allocations fill_allocation_component_fk; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fill_component_allocations
    ADD CONSTRAINT fill_allocation_component_fk FOREIGN KEY (bot_id, partition_id, order_id, order_component_id) REFERENCES trading.order_components(bot_id, partition_id, order_id, id) DEFERRABLE;


--
-- Name: fill_component_allocations fill_allocation_fill_fk; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fill_component_allocations
    ADD CONSTRAINT fill_allocation_fill_fk FOREIGN KEY (bot_id, partition_id, order_id, fill_id) REFERENCES trading.fills(bot_id, partition_id, order_id, id) DEFERRABLE;


--
-- Name: fills fills_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fills
    ADD CONSTRAINT fills_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: fills fills_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fills
    ADD CONSTRAINT fills_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: fills fills_bot_id_partition_id_order_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fills
    ADD CONSTRAINT fills_bot_id_partition_id_order_id_fkey FOREIGN KEY (bot_id, partition_id, order_id) REFERENCES trading.orders(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: fills fills_fee_policy_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.fills
    ADD CONSTRAINT fills_fee_policy_id_fkey FOREIGN KEY (fee_policy_id) REFERENCES trading.fee_policy_versions(id) DEFERRABLE;


--
-- Name: flow_position_projections flow_position_projections_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.flow_position_projections
    ADD CONSTRAINT flow_position_projections_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: flow_position_projections flow_position_projections_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.flow_position_projections
    ADD CONSTRAINT flow_position_projections_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: flow_position_projections flow_position_projections_instrument_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.flow_position_projections
    ADD CONSTRAINT flow_position_projections_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: flow_position_projections flow_position_projections_partition_id_flow_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.flow_position_projections
    ADD CONSTRAINT flow_position_projections_partition_id_flow_id_fkey FOREIGN KEY (partition_id, flow_id) REFERENCES bot.flows(partition_id, id) DEFERRABLE;


--
-- Name: ledger_accounts ledger_accounts_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_accounts
    ADD CONSTRAINT ledger_accounts_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: ledger_accounts ledger_accounts_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_accounts
    ADD CONSTRAINT ledger_accounts_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: ledger_accounts ledger_accounts_flow_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_accounts
    ADD CONSTRAINT ledger_accounts_flow_id_fkey FOREIGN KEY (flow_id) REFERENCES bot.flows(id) DEFERRABLE;


--
-- Name: ledger_accounts ledger_accounts_instrument_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_accounts
    ADD CONSTRAINT ledger_accounts_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: ledger_accounts ledger_accounts_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_accounts
    ADD CONSTRAINT ledger_accounts_partition_id_fkey FOREIGN KEY (partition_id) REFERENCES bot.bot_partitions(id) DEFERRABLE;


--
-- Name: ledger_accounts ledger_accounts_partition_id_flow_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_accounts
    ADD CONSTRAINT ledger_accounts_partition_id_flow_id_fkey FOREIGN KEY (partition_id, flow_id) REFERENCES bot.flows(partition_id, id) DEFERRABLE;


--
-- Name: ledger_entries ledger_entries_bot_id_partition_id_ledger_account_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_entries
    ADD CONSTRAINT ledger_entries_bot_id_partition_id_ledger_account_id_fkey FOREIGN KEY (bot_id, partition_id, ledger_account_id) REFERENCES trading.ledger_accounts(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: ledger_entries ledger_entries_bot_id_partition_id_order_component_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_entries
    ADD CONSTRAINT ledger_entries_bot_id_partition_id_order_component_id_fkey FOREIGN KEY (bot_id, partition_id, order_component_id) REFERENCES trading.order_components(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: ledger_entries ledger_entries_bot_id_partition_id_transaction_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_entries
    ADD CONSTRAINT ledger_entries_bot_id_partition_id_transaction_id_fkey FOREIGN KEY (bot_id, partition_id, transaction_id) REFERENCES trading.ledger_transactions(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: ledger_entries ledger_entry_transaction_header_fk; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_entries
    ADD CONSTRAINT ledger_entry_transaction_header_fk FOREIGN KEY (transaction_id) REFERENCES trading.ledger_transactions(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: ledger_transactions ledger_transactions_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_transactions
    ADD CONSTRAINT ledger_transactions_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: ledger_transactions ledger_transactions_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_transactions
    ADD CONSTRAINT ledger_transactions_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: ledger_transactions ledger_transactions_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_transactions
    ADD CONSTRAINT ledger_transactions_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: ledger_transactions ledger_transactions_bot_id_reversal_of_transaction_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.ledger_transactions
    ADD CONSTRAINT ledger_transactions_bot_id_reversal_of_transaction_id_fkey FOREIGN KEY (bot_id, reversal_of_transaction_id) REFERENCES trading.ledger_transactions(bot_id, id) DEFERRABLE;


--
-- Name: lot_movements lot_movement_fill_allocation_fk; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.lot_movements
    ADD CONSTRAINT lot_movement_fill_allocation_fk FOREIGN KEY (bot_id, partition_id, source_fill_allocation_id) REFERENCES trading.fill_component_allocations(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: lot_movements lot_movements_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.lot_movements
    ADD CONSTRAINT lot_movements_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: lot_movements lot_movements_bot_id_partition_id_position_lot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.lot_movements
    ADD CONSTRAINT lot_movements_bot_id_partition_id_position_lot_id_fkey FOREIGN KEY (bot_id, partition_id, position_lot_id) REFERENCES trading.position_lots(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: lot_movements lot_movements_bot_id_partition_id_source_fill_adjustment_i_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.lot_movements
    ADD CONSTRAINT lot_movements_bot_id_partition_id_source_fill_adjustment_i_fkey FOREIGN KEY (bot_id, partition_id, source_fill_adjustment_id) REFERENCES trading.fill_adjustments(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: lot_movements lot_movements_corporate_action_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.lot_movements
    ADD CONSTRAINT lot_movements_corporate_action_id_fkey FOREIGN KEY (corporate_action_id) REFERENCES market_data.corporate_actions(id) DEFERRABLE;


--
-- Name: lot_movements lot_movements_position_lot_id_reverses_movement_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.lot_movements
    ADD CONSTRAINT lot_movements_position_lot_id_reverses_movement_id_fkey FOREIGN KEY (position_lot_id, reverses_movement_id) REFERENCES trading.lot_movements(position_lot_id, id) DEFERRABLE;


--
-- Name: order_component_reservations order_component_reservations_bot_id_partition_id_order_com_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_component_reservations
    ADD CONSTRAINT order_component_reservations_bot_id_partition_id_order_com_fkey FOREIGN KEY (bot_id, partition_id, order_component_id) REFERENCES trading.order_components(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_component_reservations order_component_reservations_bot_id_partition_id_reservati_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_component_reservations
    ADD CONSTRAINT order_component_reservations_bot_id_partition_id_reservati_fkey FOREIGN KEY (bot_id, partition_id, reservation_id) REFERENCES trading.resource_reservations(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_components order_components_bot_id_partition_id_intent_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_components
    ADD CONSTRAINT order_components_bot_id_partition_id_intent_id_fkey FOREIGN KEY (bot_id, partition_id, intent_id) REFERENCES trading.order_intents(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_components order_components_bot_id_partition_id_order_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_components
    ADD CONSTRAINT order_components_bot_id_partition_id_order_id_fkey FOREIGN KEY (bot_id, partition_id, order_id) REFERENCES trading.orders(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_events order_events_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_events
    ADD CONSTRAINT order_events_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: order_events order_events_bot_id_partition_id_order_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_events
    ADD CONSTRAINT order_events_bot_id_partition_id_order_id_fkey FOREIGN KEY (bot_id, partition_id, order_id) REFERENCES trading.orders(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_group_events order_group_events_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_group_events
    ADD CONSTRAINT order_group_events_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: order_group_events order_group_events_bot_id_partition_id_order_group_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_group_events
    ADD CONSTRAINT order_group_events_bot_id_partition_id_order_group_id_fkey FOREIGN KEY (bot_id, partition_id, order_group_id) REFERENCES trading.order_groups(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_group_members order_group_members_bot_id_partition_id_order_group_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_group_members
    ADD CONSTRAINT order_group_members_bot_id_partition_id_order_group_id_fkey FOREIGN KEY (bot_id, partition_id, order_group_id) REFERENCES trading.order_groups(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_group_members order_group_members_bot_id_partition_id_order_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_group_members
    ADD CONSTRAINT order_group_members_bot_id_partition_id_order_id_fkey FOREIGN KEY (bot_id, partition_id, order_id) REFERENCES trading.orders(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_groups order_groups_bot_id_closed_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_groups
    ADD CONSTRAINT order_groups_bot_id_closed_event_id_fkey FOREIGN KEY (bot_id, closed_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: order_groups order_groups_bot_id_created_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_groups
    ADD CONSTRAINT order_groups_bot_id_created_event_id_fkey FOREIGN KEY (bot_id, created_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: order_groups order_groups_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_groups
    ADD CONSTRAINT order_groups_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: order_groups order_groups_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_groups
    ADD CONSTRAINT order_groups_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: order_intent_batches order_intent_batches_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intent_batches
    ADD CONSTRAINT order_intent_batches_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: order_intent_batches order_intent_batches_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intent_batches
    ADD CONSTRAINT order_intent_batches_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: order_intent_batches order_intent_batches_bot_id_source_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intent_batches
    ADD CONSTRAINT order_intent_batches_bot_id_source_event_id_fkey FOREIGN KEY (bot_id, source_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: order_intents order_intents_bot_id_evaluation_run_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intents
    ADD CONSTRAINT order_intents_bot_id_evaluation_run_id_fkey FOREIGN KEY (bot_id, evaluation_run_id) REFERENCES bot.evaluation_runs(bot_id, id) DEFERRABLE;


--
-- Name: order_intents order_intents_bot_id_partition_id_batch_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intents
    ADD CONSTRAINT order_intents_bot_id_partition_id_batch_id_fkey FOREIGN KEY (bot_id, partition_id, batch_id) REFERENCES trading.order_intent_batches(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: order_intents order_intents_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intents
    ADD CONSTRAINT order_intents_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: order_intents order_intents_bot_id_source_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intents
    ADD CONSTRAINT order_intents_bot_id_source_event_id_fkey FOREIGN KEY (bot_id, source_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: order_intents order_intents_instrument_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intents
    ADD CONSTRAINT order_intents_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: order_intents order_intents_partition_id_flow_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_intents
    ADD CONSTRAINT order_intents_partition_id_flow_id_fkey FOREIGN KEY (partition_id, flow_id) REFERENCES bot.flows(partition_id, id) DEFERRABLE;


--
-- Name: order_state_projections order_state_projections_bot_id_partition_id_order_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.order_state_projections
    ADD CONSTRAINT order_state_projections_bot_id_partition_id_order_id_fkey FOREIGN KEY (bot_id, partition_id, order_id) REFERENCES trading.orders(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: orders orders_bot_id_accepted_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.orders
    ADD CONSTRAINT orders_bot_id_accepted_event_id_fkey FOREIGN KEY (bot_id, accepted_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: orders orders_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.orders
    ADD CONSTRAINT orders_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: orders orders_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.orders
    ADD CONSTRAINT orders_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: orders orders_bot_id_partition_id_replaces_order_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.orders
    ADD CONSTRAINT orders_bot_id_partition_id_replaces_order_id_fkey FOREIGN KEY (bot_id, partition_id, replaces_order_id) REFERENCES trading.orders(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: orders orders_fee_policy_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.orders
    ADD CONSTRAINT orders_fee_policy_id_fkey FOREIGN KEY (fee_policy_id) REFERENCES trading.fee_policy_versions(id) DEFERRABLE;


--
-- Name: orders orders_instrument_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.orders
    ADD CONSTRAINT orders_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: partition_budget_projections partition_budget_projections_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.partition_budget_projections
    ADD CONSTRAINT partition_budget_projections_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: partition_position_projections partition_position_projections_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.partition_position_projections
    ADD CONSTRAINT partition_position_projections_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: partition_position_projections partition_position_projections_instrument_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.partition_position_projections
    ADD CONSTRAINT partition_position_projections_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: position_lots position_lot_opening_allocation_fk; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lots
    ADD CONSTRAINT position_lot_opening_allocation_fk FOREIGN KEY (bot_id, partition_id, opening_order_component_id, opening_fill_allocation_id) REFERENCES trading.fill_component_allocations(bot_id, partition_id, order_component_id, id) DEFERRABLE;


--
-- Name: position_lot_projections position_lot_projections_position_lot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lot_projections
    ADD CONSTRAINT position_lot_projections_position_lot_id_fkey FOREIGN KEY (position_lot_id) REFERENCES trading.position_lots(id) DEFERRABLE;


--
-- Name: position_lot_projections position_lot_projections_position_lot_id_last_movement_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lot_projections
    ADD CONSTRAINT position_lot_projections_position_lot_id_last_movement_id_fkey FOREIGN KEY (position_lot_id, last_movement_id) REFERENCES trading.lot_movements(position_lot_id, id) DEFERRABLE;


--
-- Name: position_lot_reservations position_lot_reservations_bot_id_partition_id_flow_id_posi_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lot_reservations
    ADD CONSTRAINT position_lot_reservations_bot_id_partition_id_flow_id_posi_fkey FOREIGN KEY (bot_id, partition_id, flow_id, position_lot_id) REFERENCES trading.position_lots(bot_id, partition_id, flow_id, id) DEFERRABLE;


--
-- Name: position_lot_reservations position_lot_reservations_bot_id_partition_id_flow_id_rese_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lot_reservations
    ADD CONSTRAINT position_lot_reservations_bot_id_partition_id_flow_id_rese_fkey FOREIGN KEY (bot_id, partition_id, flow_id, reservation_id) REFERENCES trading.resource_reservations(bot_id, partition_id, flow_id, id) DEFERRABLE;


--
-- Name: position_lots position_lots_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lots
    ADD CONSTRAINT position_lots_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: position_lots position_lots_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lots
    ADD CONSTRAINT position_lots_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: position_lots position_lots_bot_id_partition_id_opening_order_component__fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lots
    ADD CONSTRAINT position_lots_bot_id_partition_id_opening_order_component__fkey FOREIGN KEY (bot_id, partition_id, opening_order_component_id) REFERENCES trading.order_components(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: position_lots position_lots_instrument_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lots
    ADD CONSTRAINT position_lots_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: position_lots position_lots_partition_id_flow_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.position_lots
    ADD CONSTRAINT position_lots_partition_id_flow_id_fkey FOREIGN KEY (partition_id, flow_id) REFERENCES bot.flows(partition_id, id) DEFERRABLE;


--
-- Name: reservation_events reservation_events_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.reservation_events
    ADD CONSTRAINT reservation_events_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: reservation_events reservation_events_bot_id_partition_id_reservation_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.reservation_events
    ADD CONSTRAINT reservation_events_bot_id_partition_id_reservation_id_fkey FOREIGN KEY (bot_id, partition_id, reservation_id) REFERENCES trading.resource_reservations(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: reservation_events reservation_events_bot_id_partition_id_source_fill_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.reservation_events
    ADD CONSTRAINT reservation_events_bot_id_partition_id_source_fill_id_fkey FOREIGN KEY (bot_id, partition_id, source_fill_id) REFERENCES trading.fills(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_bot_id_created_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_bot_id_created_event_id_fkey FOREIGN KEY (bot_id, created_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_bot_id_partition_id_intent_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_bot_id_partition_id_intent_id_fkey FOREIGN KEY (bot_id, partition_id, intent_id) REFERENCES trading.order_intents(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_buffer_policy_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_buffer_policy_id_fkey FOREIGN KEY (buffer_policy_id) REFERENCES trading.buying_power_buffer_policy_versions(id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_fee_policy_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_fee_policy_id_fkey FOREIGN KEY (fee_policy_id) REFERENCES trading.fee_policy_versions(id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_instrument_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_partition_id_flow_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_partition_id_flow_id_fkey FOREIGN KEY (partition_id, flow_id) REFERENCES bot.flows(partition_id, id) DEFERRABLE;


--
-- Name: resource_reservations resource_reservations_short_risk_policy_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.resource_reservations
    ADD CONSTRAINT resource_reservations_short_risk_policy_id_fkey FOREIGN KEY (short_risk_policy_id) REFERENCES trading.short_risk_policy_versions(id) DEFERRABLE;


--
-- Name: short_borrow_fee_accruals short_borrow_fee_accruals_bot_id_bot_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_accruals
    ADD CONSTRAINT short_borrow_fee_accruals_bot_id_bot_event_id_fkey FOREIGN KEY (bot_id, bot_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: short_borrow_fee_accruals short_borrow_fee_accruals_bot_id_partition_id_ledger_trans_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_accruals
    ADD CONSTRAINT short_borrow_fee_accruals_bot_id_partition_id_ledger_trans_fkey FOREIGN KEY (bot_id, partition_id, ledger_transaction_id) REFERENCES trading.ledger_transactions(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: short_borrow_fee_accruals short_borrow_fee_accruals_bot_id_partition_id_position_lot_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_accruals
    ADD CONSTRAINT short_borrow_fee_accruals_bot_id_partition_id_position_lot_fkey FOREIGN KEY (bot_id, partition_id, position_lot_id) REFERENCES trading.position_lots(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: short_borrow_fee_accruals short_borrow_fee_accruals_short_borrow_fee_policy_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_borrow_fee_accruals
    ADD CONSTRAINT short_borrow_fee_accruals_short_borrow_fee_policy_id_fkey FOREIGN KEY (short_borrow_fee_policy_id) REFERENCES trading.short_borrow_fee_policy_versions(id) DEFERRABLE;


--
-- Name: short_trade_checks short_trade_checks_intent_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_trade_checks
    ADD CONSTRAINT short_trade_checks_intent_id_fkey FOREIGN KEY (intent_id) REFERENCES trading.order_intents(id) DEFERRABLE;


--
-- Name: short_trade_checks short_trade_checks_short_risk_policy_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.short_trade_checks
    ADD CONSTRAINT short_trade_checks_short_risk_policy_id_fkey FOREIGN KEY (short_risk_policy_id) REFERENCES trading.short_risk_policy_versions(id) DEFERRABLE;


--
-- Name: system_close_actions system_close_actions_bot_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.system_close_actions
    ADD CONSTRAINT system_close_actions_bot_id_fkey FOREIGN KEY (bot_id) REFERENCES bot.bots(id) DEFERRABLE;


--
-- Name: system_close_actions system_close_actions_bot_id_partition_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.system_close_actions
    ADD CONSTRAINT system_close_actions_bot_id_partition_id_fkey FOREIGN KEY (bot_id, partition_id) REFERENCES bot.bot_partitions(bot_id, id) DEFERRABLE;


--
-- Name: system_close_actions system_close_actions_bot_id_partition_id_generated_intent__fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.system_close_actions
    ADD CONSTRAINT system_close_actions_bot_id_partition_id_generated_intent__fkey FOREIGN KEY (bot_id, partition_id, generated_intent_id) REFERENCES trading.order_intents(bot_id, partition_id, id) DEFERRABLE;


--
-- Name: system_close_actions system_close_actions_bot_id_source_event_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.system_close_actions
    ADD CONSTRAINT system_close_actions_bot_id_source_event_id_fkey FOREIGN KEY (bot_id, source_event_id) REFERENCES bot.bot_events(bot_id, id) DEFERRABLE;


--
-- Name: system_close_actions system_close_actions_instrument_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.system_close_actions
    ADD CONSTRAINT system_close_actions_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES market_data.instruments(id) DEFERRABLE;


--
-- Name: system_close_actions system_close_actions_partition_id_flow_id_fkey; Type: FK CONSTRAINT; Schema: trading; Owner: -
--

ALTER TABLE ONLY trading.system_close_actions
    ADD CONSTRAINT system_close_actions_partition_id_flow_id_fkey FOREIGN KEY (partition_id, flow_id) REFERENCES bot.flows(partition_id, id) DEFERRABLE;


--
-- PostgreSQL database dump complete
--
