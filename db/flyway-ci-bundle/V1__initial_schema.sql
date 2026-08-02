-- Generated from db/schema.dbml through dbdiagram PostgreSQL export.
-- DBML Records blocks are review-only sample data and are intentionally excluded.

CREATE SCHEMA "identity";

CREATE SCHEMA "strategy";

CREATE SCHEMA "bot";

CREATE SCHEMA "storage";

CREATE SCHEMA "market_data";

CREATE SCHEMA "trading";

CREATE SCHEMA "backtest";

CREATE SCHEMA "performance";

CREATE SCHEMA "competition";

CREATE SCHEMA "operations";

CREATE TYPE "identity"."account_lifecycle_status" AS ENUM (
  'PENDING_VERIFICATION',
  'ACTIVE',
  'CLOSING',
  'CLOSED'
);

CREATE TYPE "identity"."email_status" AS ENUM (
  'PENDING_VERIFICATION',
  'VERIFIED',
  'REVOKED'
);

CREATE TYPE "identity"."auth_provider_type" AS ENUM (
  'PASSWORD',
  'OIDC'
);

CREATE TYPE "identity"."login_identity_status" AS ENUM (
  'PENDING',
  'ACTIVE',
  'REPLACED',
  'DISABLED'
);

CREATE TYPE "identity"."consent_decision" AS ENUM (
  'ACCEPTED',
  'DECLINED',
  'WITHDRAWN'
);

CREATE TYPE "identity"."sanction_status" AS ENUM (
  'ACTIVE',
  'LIFTED',
  'EXPIRED'
);

CREATE TYPE "identity"."delegated_authorization_status" AS ENUM (
  'ACTIVE',
  'EXPIRED',
  'REVOKED'
);

CREATE TYPE "identity"."delegated_expiry_mode" AS ENUM (
  'SESSION_END',
  'AT_TIME',
  'UNTIL_REVOKED'
);

CREATE TYPE "identity"."delegated_credential_type" AS ENUM (
  'ACCESS_TOKEN',
  'REFRESH_TOKEN'
);

CREATE TYPE "identity"."delegated_scope" AS ENUM (
  'ACCOUNT_RESOURCE_READ',
  'STRATEGY_CREATE',
  'STRATEGY_COPY',
  'STRATEGY_EDIT',
  'STRATEGY_VALIDATE'
);

CREATE TYPE "strategy"."strategy_mode" AS ENUM (
  'BASIC',
  'PRO'
);

CREATE TYPE "bot"."lifecycle_status" AS ENUM (
  'RUNNING',
  'STOPPING',
  'STOPPED'
);

CREATE TYPE "bot"."time_trigger_type" AS ENUM (
  'MARKET_OPEN',
  'MARKET_CLOSE',
  'SCHEDULE'
);

CREATE TYPE "bot"."runtime_value_type" AS ENUM (
  'BOOLEAN',
  'INTEGER',
  'DECIMAL',
  'STRING',
  'TIMESTAMP',
  'JSON'
);

CREATE TYPE "storage"."object_status" AS ENUM (
  'STAGED',
  'AVAILABLE',
  'QUARANTINED',
  'SUPERSEDED',
  'DELETED'
);

CREATE TYPE "market_data"."asset_type" AS ENUM (
  'STOCK',
  'ETF',
  'INDEX'
);

CREATE TYPE "market_data"."dataset_status" AS ENUM (
  'BUILDING',
  'AVAILABLE',
  'QUARANTINED',
  'SUPERSEDED',
  'DELETED'
);

CREATE TYPE "market_data"."partition_granularity" AS ENUM (
  'DAY',
  'WEEK',
  'MONTH',
  'YEAR'
);

CREATE TYPE "trading"."order_side" AS ENUM (
  'BUY',
  'SELL'
);

CREATE TYPE "trading"."position_effect" AS ENUM (
  'OPEN_LONG',
  'CLOSE_LONG',
  'OPEN_SHORT',
  'CLOSE_SHORT'
);

CREATE TYPE "trading"."intent_origin_type" AS ENUM (
  'FLOW_EVALUATION',
  'SYSTEM_STOP_LIQUIDATION',
  'SYSTEM_FORCED_BUY_IN',
  'CORPORATE_ACTION'
);

CREATE TYPE "trading"."intent_decision" AS ENUM (
  'APPROVED',
  'REJECTED',
  'REDUCED',
  'NETTED',
  'CONFLICTED'
);

CREATE TYPE "trading"."order_type" AS ENUM (
  'MARKET',
  'LIMIT',
  'STOP',
  'STOP_LIMIT',
  'TRAILING_STOP'
);

CREATE TYPE "trading"."time_in_force" AS ENUM (
  'DAY',
  'GTC',
  'GTD'
);

CREATE TYPE "trading"."order_status" AS ENUM (
  'PENDING',
  'OPEN',
  'FILLED',
  'CANCELLED',
  'EXPIRED',
  'REJECTED'
);

CREATE TYPE "trading"."reservation_status" AS ENUM (
  'ACTIVE',
  'SETTLED',
  'RELEASED'
);

CREATE TYPE "trading"."reservation_resource_type" AS ENUM (
  'CASH_BUYING_POWER',
  'POSITION_QUANTITY',
  'SHORT_COLLATERAL_CASH'
);

CREATE TYPE "trading"."reservation_event_type" AS ENUM (
  'CREATED',
  'SETTLED_BY_FILL',
  'RELEASED_BY_CANCEL',
  'RELEASED_BY_EXPIRY',
  'RELEASED_BY_REJECTION',
  'RELEASED_BY_REPLACEMENT'
);

CREATE TYPE "trading"."fill_adjustment_type" AS ENUM (
  'CORRECTION',
  'REVERSAL'
);

CREATE TYPE "trading"."order_group_type" AS ENUM (
  'OCO',
  'BRACKET',
  'MULTI_LEG'
);

CREATE TYPE "trading"."order_group_status" AS ENUM (
  'PENDING',
  'ACTIVE',
  'COMPLETED',
  'CANCELLED',
  'FAILED'
);

CREATE TYPE "trading"."order_group_member_role" AS ENUM (
  'ENTRY',
  'TAKE_PROFIT',
  'STOP_LOSS',
  'LEG'
);

CREATE TYPE "trading"."trailing_offset_type" AS ENUM (
  'AMOUNT',
  'PERCENT'
);

CREATE TYPE "trading"."ledger_direction" AS ENUM (
  'DEBIT',
  'CREDIT'
);

CREATE TYPE "trading"."lot_side" AS ENUM (
  'LONG',
  'SHORT'
);

CREATE TYPE "trading"."lot_movement_type" AS ENUM (
  'OPEN',
  'CLOSE',
  'CORPORATE_ACTION_ADJUSTMENT',
  'CORRECTION',
  'REVERSAL'
);

CREATE TYPE "trading"."system_close_reason" AS ENUM (
  'RISK_LIMIT_BREACH',
  'BOT_STOP',
  'COMPETITION_END',
  'DATA_INTEGRITY_BLOCK'
);

CREATE TYPE "backtest"."run_status" AS ENUM (
  'QUEUED',
  'RUNNING',
  'COMPLETED',
  'FAILED',
  'UNAVAILABLE'
);

CREATE TYPE "performance"."snapshot_type" AS ENUM (
  'ET_DAILY_CLOSE',
  'ROOM_START',
  'ROOM_END',
  'BOT_STOP',
  'LEADERBOARD_CUTOFF'
);

CREATE TYPE "competition"."room_status" AS ENUM (
  'DRAFT',
  'RECRUITING',
  'EVALUATING',
  'ENDED',
  'CANCELLED',
  'INVALIDATED'
);

CREATE TYPE "competition"."competition_type" AS ENUM (
  'LIVE_PAPER',
  'BACKTEST'
);

CREATE TYPE "competition"."organizer_type" AS ENUM (
  'PLATFORM',
  'USER'
);

CREATE TYPE "competition"."room_access_type" AS ENUM (
  'PUBLIC',
  'SECRET'
);

CREATE TYPE "competition"."participation_status" AS ENUM (
  'REGISTERED',
  'ACTIVE',
  'EVALUATING',
  'WITHDRAWN',
  'EXPELLED',
  'COMPLETED',
  'EVALUATION_FAILED'
);

CREATE TYPE "competition"."leaderboard_status" AS ENUM (
  'PUBLISHED',
  'FINAL'
);

CREATE TYPE "competition"."invitation_credential_type" AS ENUM (
  'LINK',
  'CODE'
);

CREATE TYPE "competition"."post_room_action" AS ENUM (
  'CONTINUE_PRIVATE',
  'STOP'
);

CREATE TYPE "operations"."work_status" AS ENUM (
  'PENDING',
  'RUNNING',
  'SUCCEEDED',
  'FAILED',
  'CANCELLED',
  'SKIPPED'
);

CREATE TABLE "identity"."accounts" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "lifecycle_status" identity.account_lifecycle_status NOT NULL,
  "status_changed_at" timestamptz NOT NULL DEFAULT (now()),
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "identity"."account_security_states" (
  "account_id" uuid PRIMARY KEY,
  "auth_epoch" bigint NOT NULL DEFAULT 1,
  "sessions_revoked_before" timestamptz,
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "account_security_auth_epoch_positive" CHECK (auth_epoch > 0)
);

CREATE TABLE "identity"."account_lifecycle_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "event_sequence" bigint NOT NULL,
  "previous_status" identity.account_lifecycle_status,
  "new_status" identity.account_lifecycle_status NOT NULL,
  "reason_code" varchar(80),
  "occurred_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "identity"."account_preferences" (
  "account_id" uuid PRIMARY KEY,
  "language_code" varchar(12) NOT NULL,
  "timezone_name" varchar(80) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "identity"."account_emails" (
  "account_id" uuid PRIMARY KEY,
  "email_ciphertext" text NOT NULL,
  "email_lookup_hmac" varchar(128) UNIQUE NOT NULL,
  "email_lookup_key_version" smallint NOT NULL,
  "encryption_key_version" smallint NOT NULL,
  "status" identity.email_status NOT NULL,
  "verified_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "revoked_at" timestamptz
);

CREATE TABLE "identity"."email_verification_requests" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "token_digest" varchar(128) UNIQUE NOT NULL,
  "digest_key_version" smallint NOT NULL,
  "requested_at" timestamptz NOT NULL DEFAULT (now()),
  "expires_at" timestamptz NOT NULL,
  "consumed_at" timestamptz,
  "revoked_at" timestamptz,
  "failed_attempt_count" int NOT NULL DEFAULT 0,
  "request_ip_prefix" inet
);

CREATE TABLE "identity"."auth_providers" (
  "id" smallint PRIMARY KEY,
  "code" varchar(40) UNIQUE NOT NULL,
  "display_name" varchar(80) NOT NULL,
  "provider_type" identity.auth_provider_type NOT NULL,
  "issuer" text,
  "is_active" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "identity"."login_identities" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "provider_id" smallint NOT NULL,
  "provider_subject_hmac" varchar(128),
  "subject_key_version" smallint,
  "status" identity.login_identity_status NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "linked_at" timestamptz,
  "activated_at" timestamptz,
  "last_authenticated_at" timestamptz,
  "replaced_at" timestamptz,
  "disabled_at" timestamptz,
  "disabled_reason_code" varchar(80),
  CONSTRAINT "login_identity_active_state_complete" CHECK (status <> 'ACTIVE' OR (activated_at IS NOT NULL AND replaced_at IS NULL AND disabled_at IS NULL)),
  CONSTRAINT "login_identity_replaced_at_required" CHECK (status <> 'REPLACED' OR replaced_at IS NOT NULL),
  CONSTRAINT "login_identity_disabled_at_required" CHECK (status <> 'DISABLED' OR disabled_at IS NOT NULL)
);

CREATE TABLE "identity"."password_credentials" (
  "login_identity_id" uuid PRIMARY KEY,
  "password_hash" text NOT NULL,
  "hash_scheme" varchar(40) NOT NULL,
  "hash_parameters" jsonb NOT NULL,
  "credential_version" bigint NOT NULL DEFAULT 1,
  "password_changed_at" timestamptz NOT NULL,
  "compromised_at" timestamptz
);

CREATE TABLE "identity"."sessions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "authenticated_by_login_identity_id" uuid NOT NULL,
  "auth_epoch_at_issue" bigint NOT NULL,
  "credential_version_at_issue" bigint,
  "token_digest" varchar(128) UNIQUE NOT NULL,
  "digest_key_version" smallint NOT NULL,
  "device_label" varchar(120),
  "issued_at" timestamptz NOT NULL DEFAULT (now()),
  "last_seen_at" timestamptz NOT NULL,
  "expires_at" timestamptz NOT NULL,
  "reauthenticated_at" timestamptz,
  "revoked_at" timestamptz,
  "revoke_reason_code" varchar(80),
  CONSTRAINT "session_auth_epoch_positive" CHECK (auth_epoch_at_issue > 0),
  CONSTRAINT "session_credential_version_positive" CHECK (credential_version_at_issue IS NULL OR credential_version_at_issue > 0)
);

CREATE TABLE "identity"."password_reset_requests" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "login_identity_id" uuid NOT NULL,
  "auth_epoch_at_issue" bigint NOT NULL,
  "credential_version_at_issue" bigint NOT NULL,
  "token_digest" varchar(128) UNIQUE NOT NULL,
  "digest_key_version" smallint NOT NULL,
  "requested_at" timestamptz NOT NULL DEFAULT (now()),
  "expires_at" timestamptz NOT NULL,
  "consumed_at" timestamptz,
  "revoked_at" timestamptz,
  "failed_attempt_count" int NOT NULL DEFAULT 0,
  "request_ip_prefix" inet,
  CONSTRAINT "password_reset_auth_epoch_positive" CHECK (auth_epoch_at_issue > 0),
  CONSTRAINT "password_reset_credential_version_positive" CHECK (credential_version_at_issue > 0)
);

CREATE TABLE "identity"."authentication_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "event_sequence" bigint NOT NULL,
  "event_type" varchar(60) NOT NULL,
  "subject_login_identity_id" uuid,
  "previous_login_identity_id" uuid,
  "new_login_identity_id" uuid,
  "actor_type" varchar(30) NOT NULL,
  "actor_id" uuid,
  "reason_code" varchar(80),
  "correlation_id" uuid NOT NULL,
  "idempotency_key" varchar(160) NOT NULL,
  "occurred_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "identity"."recovery_code_sets" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "purpose" varchar(40) NOT NULL,
  "issued_at" timestamptz NOT NULL DEFAULT (now()),
  "revoked_at" timestamptz,
  "revoke_reason_code" varchar(80)
);

CREATE TABLE "identity"."recovery_codes" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "recovery_code_set_id" uuid NOT NULL,
  "code_digest" varchar(128) UNIQUE NOT NULL,
  "digest_key_version" smallint NOT NULL,
  "used_at" timestamptz
);

CREATE TABLE "identity"."policy_documents" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "policy_code" varchar(80) NOT NULL,
  "version" varchar(40) NOT NULL,
  "language_code" varchar(12) NOT NULL,
  "title" varchar(160) NOT NULL,
  "content_format" varchar(20) NOT NULL,
  "content_text" text NOT NULL,
  "content_hash" varchar(128) NOT NULL,
  "is_required" boolean NOT NULL DEFAULT true,
  "published_at" timestamptz NOT NULL,
  "retired_at" timestamptz
);

CREATE TABLE "identity"."account_consents" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "policy_document_id" uuid NOT NULL,
  "decision" identity.consent_decision NOT NULL,
  "supersedes_consent_id" uuid UNIQUE,
  "recorded_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "identity"."delegated_authorizations" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "client_label" varchar(120) NOT NULL,
  "external_provider_code" varchar(80),
  "status" identity.delegated_authorization_status NOT NULL,
  "expiry_mode" identity.delegated_expiry_mode NOT NULL,
  "auth_epoch_at_grant" bigint NOT NULL,
  "disclosure_policy_document_id" uuid NOT NULL,
  "scope_set_hash" varchar(128) NOT NULL,
  "authorized_at" timestamptz NOT NULL DEFAULT (now()),
  "expires_at" timestamptz,
  "revoked_at" timestamptz,
  "revoke_reason_code" varchar(80),
  CONSTRAINT "delegated_authorization_auth_epoch_positive" CHECK (auth_epoch_at_grant > 0),
  CONSTRAINT "delegated_authorization_expiry_mode_valid" CHECK ((expiry_mode = 'AT_TIME' AND expires_at IS NOT NULL) OR (expiry_mode <> 'AT_TIME' AND expires_at IS NULL)),
  CONSTRAINT "delegated_authorization_revocation_state_valid" CHECK ((status = 'REVOKED' AND revoked_at IS NOT NULL) OR (status <> 'REVOKED' AND revoked_at IS NULL))
);

CREATE TABLE "identity"."delegated_authorization_scopes" (
  "authorization_id" uuid NOT NULL,
  "scope_code" identity.delegated_scope NOT NULL,
  "granted_at" timestamptz NOT NULL DEFAULT (now()),
  PRIMARY KEY ("authorization_id", "scope_code")
);

CREATE TABLE "identity"."delegated_credentials" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "authorization_id" uuid NOT NULL,
  "credential_type" identity.delegated_credential_type NOT NULL,
  "token_digest" varchar(128) UNIQUE NOT NULL,
  "digest_key_version" smallint NOT NULL,
  "issued_at" timestamptz NOT NULL DEFAULT (now()),
  "expires_at" timestamptz NOT NULL,
  "last_seen_at" timestamptz,
  "revoked_at" timestamptz,
  "revoke_reason_code" varchar(80),
  "superseded_by_credential_id" uuid,
  CONSTRAINT "delegated_credential_digest_key_version_positive" CHECK (digest_key_version > 0),
  CONSTRAINT "delegated_credential_expiry_after_issue" CHECK (expires_at > issued_at)
);

CREATE TABLE "identity"."delegated_authorization_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "authorization_id" uuid NOT NULL,
  "event_sequence" bigint NOT NULL,
  "event_type" varchar(50) NOT NULL,
  "actor_type" varchar(30) NOT NULL,
  "actor_id" uuid,
  "reason_code" varchar(80),
  "correlation_id" uuid NOT NULL,
  "idempotency_key" varchar(160) NOT NULL,
  "occurred_at" timestamptz NOT NULL DEFAULT (now()),
  "payload_document" jsonb NOT NULL
);

CREATE TABLE "identity"."account_sanctions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "sanction_type" varchar(40) NOT NULL,
  "status" identity.sanction_status NOT NULL,
  "reason_code" varchar(80) NOT NULL,
  "applied_by_operator_id" uuid NOT NULL,
  "applied_at" timestamptz NOT NULL,
  "effective_at" timestamptz NOT NULL,
  "expires_at" timestamptz,
  "source_case_id" uuid,
  "status_changed_at" timestamptz NOT NULL
);

CREATE TABLE "identity"."account_sanction_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "sanction_id" uuid NOT NULL,
  "event_sequence" bigint NOT NULL,
  "event_type" varchar(40) NOT NULL,
  "actor_operator_id" uuid,
  "reason_code" varchar(80) NOT NULL,
  "evidence_object_id" uuid,
  "occurred_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "strategy"."strategies" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "owner_account_id" uuid NOT NULL,
  "mode" strategy.strategy_mode NOT NULL,
  "name" varchar(120) NOT NULL,
  "description" text,
  "edit_sequence" bigint NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "archived_at" timestamptz,
  "deleted_at" timestamptz
);

CREATE TABLE "strategy"."strategy_documents" (
  "strategy_id" uuid PRIMARY KEY,
  "semantic_document" jsonb NOT NULL,
  "presentation_document" jsonb NOT NULL,
  "semantic_schema_version" varchar(40) NOT NULL,
  "presentation_schema_version" varchar(40) NOT NULL,
  "semantic_hash" varchar(128) NOT NULL,
  "presentation_hash" varchar(128) NOT NULL,
  "edit_sequence" bigint NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "strategy"."strategy_edit_leases" (
  "strategy_id" uuid PRIMARY KEY,
  "session_id" uuid,
  "delegated_credential_id" uuid,
  "lease_token_digest" varchar(128) UNIQUE NOT NULL,
  "digest_key_version" smallint NOT NULL,
  "acquired_at" timestamptz NOT NULL,
  "heartbeat_at" timestamptz NOT NULL,
  "expires_at" timestamptz NOT NULL,
  CONSTRAINT "strategy_edit_lease_exactly_one_editor" CHECK ((session_id IS NOT NULL AND delegated_credential_id IS NULL) OR (session_id IS NULL AND delegated_credential_id IS NOT NULL)),
  CONSTRAINT "strategy_edit_lease_digest_key_version_positive" CHECK (digest_key_version > 0),
  CONSTRAINT "strategy_edit_lease_time_order_valid" CHECK (heartbeat_at >= acquired_at AND expires_at > heartbeat_at)
);

CREATE TABLE "strategy"."validation_runs" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "strategy_id" uuid NOT NULL,
  "requested_by_account_id" uuid NOT NULL,
  "delegated_authorization_id" uuid,
  "requested_edit_sequence" bigint NOT NULL,
  "semantic_hash" varchar(128) NOT NULL,
  "element_catalog_version_id" uuid NOT NULL,
  "status" varchar(30) NOT NULL,
  "issue_count" int NOT NULL DEFAULT 0,
  "result_document" jsonb NOT NULL,
  "requested_at" timestamptz NOT NULL DEFAULT (now()),
  "completed_at" timestamptz,
  CONSTRAINT "strategy_validation_edit_sequence_nonnegative" CHECK (requested_edit_sequence >= 0),
  CONSTRAINT "strategy_validation_issue_count_nonnegative" CHECK (issue_count >= 0),
  CONSTRAINT "strategy_validation_completion_state_valid" CHECK ((status = 'RUNNING' AND completed_at IS NULL) OR (status <> 'RUNNING' AND completed_at IS NOT NULL))
);

CREATE TABLE "strategy"."element_catalog_versions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "language_version" varchar(40) NOT NULL,
  "schema_version" varchar(40) NOT NULL,
  "catalog_version" varchar(40) NOT NULL,
  "data_requirement_version" varchar(40) NOT NULL,
  "definition_hash" varchar(128) UNIQUE NOT NULL,
  "published_at" timestamptz NOT NULL,
  "retired_at" timestamptz
);

CREATE TABLE "strategy"."element_definitions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "element_catalog_version_id" uuid NOT NULL,
  "element_code" varchar(120) NOT NULL,
  "element_kind" varchar(50) NOT NULL,
  "parameter_schema" jsonb NOT NULL,
  "input_port_schema" jsonb NOT NULL,
  "output_port_schema" jsonb NOT NULL,
  "execution_contract" jsonb NOT NULL,
  "definition_hash" varchar(128) UNIQUE NOT NULL
);

CREATE TABLE "strategy"."packages" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "code" varchar(80) UNIQUE NOT NULL,
  "status" varchar(30) NOT NULL,
  "created_at" timestamptz NOT NULL,
  "retired_at" timestamptz
);

CREATE TABLE "strategy"."package_versions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "package_id" uuid NOT NULL,
  "version" varchar(40) NOT NULL,
  "element_catalog_version_id" uuid NOT NULL,
  "name_i18n" jsonb NOT NULL,
  "description_i18n" jsonb NOT NULL,
  "flow_document" jsonb NOT NULL,
  "content_hash" varchar(128) UNIQUE NOT NULL,
  "published_at" timestamptz NOT NULL,
  "retired_at" timestamptz
);

CREATE TABLE "strategy"."templates" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "code" varchar(80) UNIQUE NOT NULL,
  "status" varchar(30) NOT NULL,
  "created_at" timestamptz NOT NULL,
  "retired_at" timestamptz
);

CREATE TABLE "strategy"."template_versions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "template_id" uuid NOT NULL,
  "version" varchar(40) NOT NULL,
  "element_catalog_version_id" uuid NOT NULL,
  "name_i18n" jsonb NOT NULL,
  "description_i18n" jsonb NOT NULL,
  "semantic_skeleton" jsonb NOT NULL,
  "content_hash" varchar(128) UNIQUE NOT NULL,
  "published_at" timestamptz NOT NULL,
  "retired_at" timestamptz
);

CREATE TABLE "strategy"."compiled_flow_plans" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "element_catalog_version_id" uuid NOT NULL,
  "semantic_hash" varchar(128) NOT NULL,
  "compiler_version" varchar(80) NOT NULL,
  "required_feature_set_hash" varchar(128) NOT NULL,
  "plan_document" jsonb NOT NULL,
  "plan_hash" varchar(128) UNIQUE NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "bot"."bots" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "owner_account_id" uuid NOT NULL,
  "mode" strategy.strategy_mode NOT NULL,
  "name" varchar(120) NOT NULL,
  "lifecycle_status" bot.lifecycle_status NOT NULL,
  "lifecycle_changed_at" timestamptz NOT NULL,
  "execution_blocked_at" timestamptz,
  "execution_block_reason_code" varchar(80),
  "execution_block_event_id" uuid,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "execution_eligible_from" timestamptz NOT NULL,
  "started_at" timestamptz,
  "stop_requested_at" timestamptz,
  "stopped_at" timestamptz,
  "stop_reason_code" varchar(80),
  "archived_at" timestamptz,
  "deleted_at" timestamptz,
  "edit_sequence" bigint NOT NULL DEFAULT 0,
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "bot_block_fields_together" CHECK (execution_blocked_at IS NOT NULL OR (execution_block_reason_code IS NULL AND execution_block_event_id IS NULL)),
  CONSTRAINT "bot_actual_start_after_eligibility" CHECK (started_at IS NULL OR started_at >= execution_eligible_from)
);

CREATE TABLE "bot"."launch_snapshots" (
  "bot_id" uuid PRIMARY KEY,
  "snapshot_schema_version" varchar(40) NOT NULL,
  "semantic_snapshot" jsonb NOT NULL,
  "presentation_snapshot" jsonb NOT NULL,
  "semantic_hash" varchar(128) NOT NULL,
  "presentation_hash" varchar(128) NOT NULL,
  "snapshot_hash" varchar(128) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "bot"."launch_configurations" (
  "bot_id" uuid PRIMARY KEY,
  "initial_cash_amount" numeric(24,8) NOT NULL,
  "currency_code" char(3) NOT NULL DEFAULT 'USD',
  "broker_rules_version" varchar(80) NOT NULL,
  "accounting_rules_version" varchar(80) NOT NULL,
  "precision_rules_version" varchar(80) NOT NULL,
  "fee_policy_id" uuid NOT NULL,
  "slippage_rate_bps" int NOT NULL,
  "buying_power_buffer_policy_id" uuid NOT NULL,
  "candidate_conflict_policy" jsonb NOT NULL,
  "configuration_hash" varchar(128) NOT NULL,
  CONSTRAINT "launch_initial_cash_positive" CHECK (initial_cash_amount > 0),
  CONSTRAINT "launch_fixed_slippage_five_bps" CHECK (slippage_rate_bps = 5)
);

CREATE TABLE "bot"."bot_partitions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "name" varchar(120) NOT NULL,
  "description" text,
  "budget_cap_bps" int NOT NULL,
  "position_x" numeric(14,4) NOT NULL,
  "position_y" numeric(14,4) NOT NULL,
  "configuration_hash" varchar(128) NOT NULL,
  "edit_sequence" bigint NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "partition_budget_cap_range" CHECK (budget_cap_bps > 0 AND budget_cap_bps <= 10000)
);

CREATE TABLE "bot"."flows" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "partition_id" uuid NOT NULL,
  "name" varchar(120) NOT NULL,
  "description" text,
  "element_catalog_version_id" uuid NOT NULL,
  "compiled_flow_plan_id" uuid NOT NULL,
  "position_x" numeric(14,4) NOT NULL,
  "position_y" numeric(14,4) NOT NULL,
  "semantic_document" jsonb NOT NULL,
  "layout_document" jsonb NOT NULL,
  "layout_schema_version" varchar(40) NOT NULL,
  "semantic_hash" varchar(128) NOT NULL,
  "layout_hash" varchar(128) NOT NULL,
  "configuration_hash" varchar(128) NOT NULL,
  "edit_sequence" bigint NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "bot"."flow_instruments" (
  "flow_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  PRIMARY KEY ("flow_id", "instrument_id")
);

CREATE TABLE "bot"."flow_feature_requirements" (
  "flow_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  "feature_definition_id" uuid NOT NULL,
  PRIMARY KEY ("flow_id", "instrument_id", "feature_definition_id")
);

CREATE TABLE "bot"."bot_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "event_sequence" bigint NOT NULL,
  "event_type" varchar(80) NOT NULL,
  "event_schema_version" varchar(40) NOT NULL,
  "causation_event_id" uuid,
  "correlation_id" uuid NOT NULL,
  "idempotency_key" varchar(160) NOT NULL,
  "occurred_at" timestamptz NOT NULL,
  "received_at" timestamptz NOT NULL,
  "committed_at" timestamptz NOT NULL DEFAULT (now()),
  "summary_document" jsonb NOT NULL,
  "market_dataset_manifest_id" uuid,
  "evidence_object_id" uuid
);

CREATE TABLE "bot"."flow_time_triggers" (
  "flow_id" uuid NOT NULL,
  "trigger_type" bot.time_trigger_type NOT NULL,
  "schedule_key" varchar(40) NOT NULL,
  PRIMARY KEY ("flow_id", "trigger_type", "schedule_key")
);

CREATE TABLE "bot"."evaluation_runs" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "flow_id" uuid NOT NULL,
  "trigger_event_id" uuid NOT NULL,
  "result_event_id" uuid UNIQUE,
  "feature_snapshot_batch_id" uuid,
  "feature_snapshot_key" varchar(200),
  "feature_snapshot_hash" varchar(128),
  "status" operations.work_status NOT NULL,
  "attempt_count" int NOT NULL DEFAULT 0,
  "lease_expires_at" timestamptz,
  "input_state_hash" varchar(128),
  "input_market_hash" varchar(128),
  "candidate_set_hash" varchar(128),
  "candidate_count" int,
  "state_change_count" int,
  "result_hash" varchar(128),
  "summary_document" jsonb,
  "queued_at" timestamptz NOT NULL,
  "started_at" timestamptz,
  "completed_at" timestamptz,
  "failure_code" varchar(80),
  CONSTRAINT "evaluation_attempt_count_nonnegative" CHECK (attempt_count >= 0),
  CONSTRAINT "evaluation_success_complete" CHECK (status <> 'SUCCEEDED' OR (completed_at IS NOT NULL AND result_hash IS NOT NULL))
);

CREATE TABLE "bot"."runtime_state_values" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "flow_id" uuid NOT NULL,
  "instrument_id" uuid,
  "element_instance_key" varchar(160) NOT NULL,
  "state_definition_key" varchar(160) NOT NULL,
  "value_type" bot.runtime_value_type NOT NULL,
  "current_value" jsonb NOT NULL,
  "last_event_sequence" bigint NOT NULL,
  "updated_at" timestamptz NOT NULL
);

CREATE TABLE "bot"."runtime_state_changes" (
  "bot_id" uuid NOT NULL,
  "bot_event_id" uuid NOT NULL,
  "runtime_state_value_id" uuid NOT NULL,
  "previous_value_hash" varchar(128),
  "new_value" jsonb NOT NULL,
  "new_value_hash" varchar(128) NOT NULL,
  "change_reason_code" varchar(80) NOT NULL,
  PRIMARY KEY ("bot_event_id", "runtime_state_value_id")
);

CREATE TABLE "storage"."objects" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "status" storage.object_status NOT NULL,
  "storage_provider" varchar(40) NOT NULL,
  "bucket_name" varchar(160) NOT NULL,
  "object_key" varchar(900) NOT NULL,
  "provider_version_id" varchar(300) NOT NULL,
  "content_hash" varchar(128) NOT NULL,
  "byte_size" bigint NOT NULL,
  "file_format" varchar(40) NOT NULL,
  "compression_codec" varchar(40) NOT NULL,
  "media_type" varchar(120) NOT NULL,
  "schema_version" varchar(40) NOT NULL,
  "row_count" bigint,
  "period_start" timestamptz,
  "period_end" timestamptz,
  "encryption_key_ref" varchar(300),
  "retention_policy_version" varchar(80) NOT NULL,
  "retention_until" timestamptz,
  "legal_hold" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "verified_at" timestamptz,
  "quarantined_at" timestamptz,
  "superseded_at" timestamptz,
  "deleted_at" timestamptz
);

CREATE TABLE "market_data"."instruments" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "asset_type" market_data.asset_type NOT NULL,
  "primary_exchange_mic" char(4) NOT NULL,
  "currency_code" char(3) NOT NULL DEFAULT 'USD',
  "provider_reference" varchar(160),
  "listed_at" date,
  "delisted_at" date,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "market_data"."instrument_symbols" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "instrument_id" uuid NOT NULL,
  "exchange_mic" char(4) NOT NULL,
  "symbol" varchar(32) NOT NULL,
  "effective_from" timestamptz NOT NULL,
  "effective_to" timestamptz
);

CREATE TABLE "market_data"."trading_sessions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "exchange_mic" char(4) NOT NULL,
  "session_date" date NOT NULL,
  "opens_at" timestamptz,
  "closes_at" timestamptz,
  "session_type" varchar(30) NOT NULL,
  "calendar_version" varchar(40) NOT NULL
);

CREATE TABLE "market_data"."providers" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "code" varchar(80) UNIQUE NOT NULL,
  "display_name" varchar(160) NOT NULL,
  "rights_version" varchar(80) NOT NULL,
  "status" varchar(30) NOT NULL,
  "created_at" timestamptz NOT NULL
);

CREATE TABLE "market_data"."feeds" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "provider_id" uuid NOT NULL,
  "code" varchar(80) NOT NULL,
  "data_kind" varchar(40) NOT NULL,
  "resolution" varchar(30) NOT NULL,
  "timezone_name" varchar(80) NOT NULL,
  "feed_version" varchar(40) NOT NULL,
  "created_at" timestamptz NOT NULL,
  "retired_at" timestamptz
);

CREATE TABLE "market_data"."dataset_manifests" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "feed_id" uuid NOT NULL,
  "instrument_id" uuid,
  "data_layer" varchar(40) NOT NULL,
  "resolution" varchar(30) NOT NULL,
  "revision_number" int NOT NULL,
  "status" market_data.dataset_status NOT NULL,
  "period_start" timestamptz NOT NULL,
  "period_end" timestamptz NOT NULL,
  "schema_version" varchar(40) NOT NULL,
  "dataset_hash" varchar(128) NOT NULL,
  "supersedes_manifest_id" uuid,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "available_at" timestamptz
);

CREATE TABLE "market_data"."dataset_objects" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "dataset_manifest_id" uuid NOT NULL,
  "object_id" uuid NOT NULL,
  "object_kind" varchar(40) NOT NULL,
  "partition_granularity" market_data.partition_granularity NOT NULL,
  "partition_start" date NOT NULL,
  "partition_end" date NOT NULL,
  "period_start" timestamptz NOT NULL,
  "period_end" timestamptz NOT NULL,
  "shard_key" varchar(120) NOT NULL,
  "part_number" int NOT NULL,
  "row_count" bigint NOT NULL,
  "min_instrument_id" uuid,
  "max_instrument_id" uuid,
  CONSTRAINT "dataset_object_partition_order" CHECK (partition_end > partition_start),
  CONSTRAINT "dataset_object_period_order" CHECK (period_end > period_start)
);

CREATE TABLE "market_data"."dataset_lineage" (
  "derived_manifest_id" uuid NOT NULL,
  "source_manifest_id" uuid NOT NULL,
  "relation_type" varchar(40) NOT NULL,
  PRIMARY KEY ("derived_manifest_id", "source_manifest_id", "relation_type")
);

CREATE TABLE "market_data"."dataset_object_lineage" (
  "derived_dataset_object_id" uuid NOT NULL,
  "source_dataset_object_id" uuid NOT NULL,
  "pipeline_run_id" uuid NOT NULL,
  "relation_type" varchar(40) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "dataset_object_lineage_no_self_reference" CHECK (derived_dataset_object_id <> source_dataset_object_id),
  PRIMARY KEY ("derived_dataset_object_id", "source_dataset_object_id", "relation_type")
);

CREATE TABLE "market_data"."feature_definitions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "element_catalog_version_id" uuid NOT NULL,
  "feature_code" varchar(120) NOT NULL,
  "calculator_version" varchar(80) NOT NULL,
  "resolution" varchar(30) NOT NULL,
  "normalized_parameters" jsonb NOT NULL,
  "output_value_type" varchar(40) NOT NULL,
  "required_history_points" int NOT NULL,
  "definition_hash" varchar(128) UNIQUE NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "feature_required_history_nonnegative" CHECK (required_history_points >= 0)
);

CREATE TABLE "market_data"."feature_materializations" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "feature_definition_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  "pipeline_run_id" uuid UNIQUE NOT NULL,
  "input_dataset_set_hash" varchar(128) NOT NULL,
  "period_start" timestamptz NOT NULL,
  "period_end" timestamptz NOT NULL,
  "source_watermark" varchar(300) NOT NULL,
  "output_dataset_manifest_id" uuid,
  "result_hash" varchar(128),
  "status" operations.work_status NOT NULL,
  "available_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "feature_materialization_period_order" CHECK (period_end > period_start),
  CONSTRAINT "feature_materialization_success_complete" CHECK (status <> 'SUCCEEDED' OR (output_dataset_manifest_id IS NOT NULL AND result_hash IS NOT NULL AND available_at IS NOT NULL))
);

CREATE TABLE "market_data"."feature_snapshot_batches" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "feature_set_hash" varchar(128) NOT NULL,
  "input_market_set_hash" varchar(128) NOT NULL,
  "source_start_watermark" varchar(300) NOT NULL,
  "source_end_watermark" varchar(300) NOT NULL,
  "period_start" timestamptz NOT NULL,
  "period_end" timestamptz NOT NULL,
  "snapshot_object_id" uuid,
  "batch_hash" varchar(128),
  "row_count" bigint,
  "status" operations.work_status NOT NULL,
  "idempotency_key" varchar(160) UNIQUE NOT NULL,
  "available_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "feature_snapshot_batch_period_order" CHECK (period_end > period_start),
  CONSTRAINT "feature_snapshot_batch_row_count_positive" CHECK (row_count IS NULL OR row_count > 0),
  CONSTRAINT "feature_snapshot_batch_success_complete" CHECK (status <> 'SUCCEEDED' OR (snapshot_object_id IS NOT NULL AND batch_hash IS NOT NULL AND row_count IS NOT NULL AND available_at IS NOT NULL))
);

CREATE TABLE "market_data"."corporate_actions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "instrument_id" uuid NOT NULL,
  "source_manifest_id" uuid NOT NULL,
  "provider_event_key" varchar(160) NOT NULL,
  "action_type" varchar(60) NOT NULL,
  "effective_at" timestamptz NOT NULL,
  "terms_document" jsonb NOT NULL,
  "terms_hash" varchar(128) NOT NULL,
  "supersedes_action_id" uuid,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "market_data"."quality_incidents" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "dataset_manifest_id" uuid,
  "instrument_id" uuid,
  "severity" varchar(20) NOT NULL,
  "incident_code" varchar(80) NOT NULL,
  "period_start" timestamptz NOT NULL,
  "period_end" timestamptz,
  "status" varchar(30) NOT NULL,
  "evidence_object_id" uuid,
  "detected_at" timestamptz NOT NULL,
  "resolved_at" timestamptz
);

CREATE TABLE "market_data"."pipeline_runs" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "pipeline_code" varchar(80) NOT NULL,
  "pipeline_version" varchar(40) NOT NULL,
  "idempotency_key" varchar(160) UNIQUE NOT NULL,
  "status" operations.work_status NOT NULL,
  "input_hash" varchar(128) NOT NULL,
  "output_hash" varchar(128),
  "started_at" timestamptz,
  "completed_at" timestamptz,
  "failure_code" varchar(80)
);

CREATE TABLE "market_data"."stream_watermarks" (
  "feed_id" uuid PRIMARY KEY,
  "last_source_event_at" timestamptz NOT NULL,
  "last_ingested_at" timestamptz NOT NULL,
  "last_sequence" bigint,
  "updated_at" timestamptz NOT NULL
);

CREATE TABLE "trading"."buying_power_buffer_policy_versions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "policy_code" varchar(80) NOT NULL,
  "version" varchar(40) NOT NULL,
  "buffer_bps" int NOT NULL,
  "rounding_rules_version" varchar(40) NOT NULL,
  "rules_hash" varchar(128) UNIQUE NOT NULL,
  "effective_from" timestamptz NOT NULL,
  "effective_to" timestamptz,
  "published_at" timestamptz NOT NULL,
  CONSTRAINT "buying_power_buffer_bps_nonnegative" CHECK (buffer_bps >= 0),
  CONSTRAINT "buying_power_buffer_effective_range" CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE TABLE "trading"."fee_policy_versions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "policy_code" varchar(80) NOT NULL,
  "version" varchar(40) NOT NULL,
  "fee_rate_bps" int NOT NULL,
  "calculation_rules_version" varchar(40) NOT NULL,
  "rules_hash" varchar(128) UNIQUE NOT NULL,
  "effective_from" timestamptz NOT NULL,
  "effective_to" timestamptz,
  "published_at" timestamptz NOT NULL,
  CONSTRAINT "official_fee_twenty_bps" CHECK (fee_rate_bps = 20),
  CONSTRAINT "fee_policy_effective_range" CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE TABLE "trading"."short_risk_policy_versions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "policy_code" varchar(80) NOT NULL,
  "version" varchar(40) NOT NULL,
  "rules_document" jsonb NOT NULL,
  "rules_hash" varchar(128) UNIQUE NOT NULL,
  "effective_from" timestamptz NOT NULL,
  "effective_to" timestamptz,
  "published_at" timestamptz NOT NULL,
  CONSTRAINT "short_risk_policy_effective_range" CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE TABLE "trading"."short_borrow_fee_policy_versions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "policy_code" varchar(80) NOT NULL,
  "version" varchar(40) NOT NULL,
  "annual_fee_rate_bps" numeric(12,6) NOT NULL,
  "day_count_basis" varchar(20) NOT NULL,
  "calculation_rules_version" varchar(80) NOT NULL,
  "rules_hash" varchar(128) UNIQUE NOT NULL,
  "effective_from" timestamptz NOT NULL,
  "effective_to" timestamptz,
  "published_at" timestamptz NOT NULL,
  CONSTRAINT "short_borrow_fee_rate_nonnegative" CHECK (annual_fee_rate_bps >= 0),
  CONSTRAINT "short_borrow_fee_policy_effective_range" CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE TABLE "trading"."order_intent_batches" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "source_event_id" uuid NOT NULL,
  "status" varchar(30) NOT NULL,
  "conflict_policy_hash" varchar(128) NOT NULL,
  "composition_rules_version" varchar(40) NOT NULL,
  "input_state_hash" varchar(128) NOT NULL,
  "result_hash" varchar(128),
  "finalized_at" timestamptz,
  CONSTRAINT "intent_batch_status_valid" CHECK (status IN ('COLLECTING', 'FINALIZED', 'FAILED')),
  CONSTRAINT "intent_batch_finalized_complete" CHECK (status <> 'FINALIZED' OR (finalized_at IS NOT NULL AND result_hash IS NOT NULL))
);

CREATE TABLE "trading"."order_intents" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "batch_id" uuid NOT NULL,
  "source_event_id" uuid NOT NULL,
  "origin_type" trading.intent_origin_type NOT NULL,
  "evaluation_run_id" uuid,
  "partition_id" uuid NOT NULL,
  "flow_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  "intent_key" varchar(160) NOT NULL,
  "side" trading.order_side NOT NULL,
  "position_effect" trading.position_effect NOT NULL,
  "order_type" trading.order_type NOT NULL,
  "time_in_force" trading.time_in_force NOT NULL,
  "requested_quantity" numeric(28,8),
  "requested_notional" numeric(24,8),
  "approved_quantity" numeric(28,8),
  "approved_notional" numeric(24,8),
  "post_netting_quantity" numeric(28,8) NOT NULL DEFAULT 0,
  "final_quantity" numeric(28,8),
  "final_notional" numeric(24,8),
  "limit_price" numeric(24,8),
  "stop_price" numeric(24,8),
  "trailing_offset_type" trading.trailing_offset_type,
  "trailing_offset_value" numeric(24,8),
  "requested_expires_at" timestamptz,
  "decision" trading.intent_decision NOT NULL,
  "decision_reason_code" varchar(80) NOT NULL,
  CONSTRAINT "intent_exactly_one_requested_measure" CHECK ((requested_quantity IS NOT NULL) <> (requested_notional IS NOT NULL)),
  CONSTRAINT "intent_requested_quantity_positive" CHECK (requested_quantity IS NULL OR requested_quantity > 0),
  CONSTRAINT "intent_requested_notional_positive" CHECK (requested_notional IS NULL OR requested_notional > 0),
  CONSTRAINT "intent_approved_quantity_nonnegative" CHECK (approved_quantity IS NULL OR approved_quantity >= 0),
  CONSTRAINT "intent_approved_notional_nonnegative" CHECK (approved_notional IS NULL OR approved_notional >= 0),
  CONSTRAINT "intent_post_netting_quantity_nonnegative" CHECK (post_netting_quantity >= 0),
  CONSTRAINT "intent_final_quantity_nonnegative" CHECK (final_quantity IS NULL OR final_quantity >= 0),
  CONSTRAINT "intent_final_notional_nonnegative" CHECK (final_notional IS NULL OR final_notional >= 0),
  CONSTRAINT "flow_intent_requires_evaluation" CHECK (origin_type <> 'FLOW_EVALUATION' OR evaluation_run_id IS NOT NULL),
  CONSTRAINT "system_intent_has_no_evaluation" CHECK (origin_type = 'FLOW_EVALUATION' OR evaluation_run_id IS NULL),
  CONSTRAINT "intent_limit_price_required" CHECK (order_type <> 'LIMIT' OR limit_price IS NOT NULL),
  CONSTRAINT "intent_stop_price_required" CHECK (order_type <> 'STOP' OR stop_price IS NOT NULL),
  CONSTRAINT "intent_stop_limit_prices_required" CHECK (order_type <> 'STOP_LIMIT' OR (limit_price IS NOT NULL AND stop_price IS NOT NULL)),
  CONSTRAINT "intent_trailing_offset_required" CHECK (order_type <> 'TRAILING_STOP' OR (trailing_offset_type IS NOT NULL AND trailing_offset_value > 0)),
  CONSTRAINT "intent_non_trailing_has_no_offset" CHECK (order_type = 'TRAILING_STOP' OR (trailing_offset_type IS NULL AND trailing_offset_value IS NULL)),
  CONSTRAINT "intent_market_contract_valid" CHECK (order_type <> 'MARKET' OR (limit_price IS NULL AND stop_price IS NULL AND trailing_offset_type IS NULL AND time_in_force = 'DAY')),
  CONSTRAINT "intent_gtd_expiry_required" CHECK (time_in_force <> 'GTD' OR requested_expires_at IS NOT NULL),
  CONSTRAINT "intent_side_effect_compatible" CHECK ((side = 'BUY' AND position_effect IN ('OPEN_LONG', 'CLOSE_SHORT')) OR (side = 'SELL' AND position_effect IN ('CLOSE_LONG', 'OPEN_SHORT'))),
  CONSTRAINT "intent_nonexecuting_decision_has_no_final" CHECK (decision NOT IN ('REJECTED', 'NETTED', 'CONFLICTED') OR (COALESCE(final_quantity, 0) = 0 AND COALESCE(final_notional, 0) = 0))
);

CREATE TABLE "trading"."orders" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  "replaces_order_id" uuid UNIQUE,
  "replacement_reason_code" varchar(80),
  "order_key" varchar(160) NOT NULL,
  "side" trading.order_side NOT NULL,
  "order_type" trading.order_type NOT NULL,
  "time_in_force" trading.time_in_force NOT NULL,
  "requested_quantity" numeric(28,8) NOT NULL,
  "requested_notional" numeric(24,8),
  "limit_price" numeric(24,8),
  "stop_price" numeric(24,8),
  "trailing_offset_type" trading.trailing_offset_type,
  "trailing_offset_value" numeric(24,8),
  "broker_rules_version" varchar(80) NOT NULL,
  "precision_rules_version" varchar(80) NOT NULL,
  "slippage_rate_bps" int NOT NULL,
  "fee_policy_id" uuid NOT NULL,
  "accepted_event_id" uuid NOT NULL,
  "accepted_at" timestamptz NOT NULL,
  "expires_at" timestamptz,
  "contract_hash" varchar(128) NOT NULL,
  CONSTRAINT "order_requested_quantity_positive" CHECK (requested_quantity > 0),
  CONSTRAINT "order_requested_notional_positive" CHECK (requested_notional IS NULL OR requested_notional > 0),
  CONSTRAINT "order_fixed_slippage_five_bps" CHECK (slippage_rate_bps = 5),
  CONSTRAINT "order_limit_price_required" CHECK (order_type <> 'LIMIT' OR limit_price IS NOT NULL),
  CONSTRAINT "order_stop_price_required" CHECK (order_type <> 'STOP' OR stop_price IS NOT NULL),
  CONSTRAINT "order_stop_limit_prices_required" CHECK (order_type <> 'STOP_LIMIT' OR (limit_price IS NOT NULL AND stop_price IS NOT NULL)),
  CONSTRAINT "order_trailing_offset_required" CHECK (order_type <> 'TRAILING_STOP' OR (trailing_offset_type IS NOT NULL AND trailing_offset_value > 0)),
  CONSTRAINT "order_non_trailing_has_no_offset" CHECK (order_type = 'TRAILING_STOP' OR (trailing_offset_type IS NULL AND trailing_offset_value IS NULL)),
  CONSTRAINT "order_market_contract_valid" CHECK (order_type <> 'MARKET' OR (limit_price IS NULL AND stop_price IS NULL AND trailing_offset_type IS NULL AND time_in_force = 'DAY')),
  CONSTRAINT "order_gtd_expiry_required" CHECK (time_in_force <> 'GTD' OR expires_at IS NOT NULL),
  CONSTRAINT "order_expiry_after_acceptance" CHECK (expires_at IS NULL OR expires_at > accepted_at),
  CONSTRAINT "order_expiry_within_ninety_days" CHECK (expires_at IS NULL OR expires_at <= accepted_at + interval '90 days'),
  CONSTRAINT "order_does_not_replace_itself" CHECK (replaces_order_id IS NULL OR replaces_order_id <> id),
  CONSTRAINT "order_replacement_reason_consistent" CHECK ((replaces_order_id IS NULL) = (replacement_reason_code IS NULL))
);

CREATE TABLE "trading"."order_groups" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "group_type" trading.order_group_type NOT NULL,
  "group_key" varchar(160) NOT NULL,
  "status" trading.order_group_status NOT NULL,
  "created_event_id" uuid NOT NULL,
  "closed_event_id" uuid
);

CREATE TABLE "trading"."order_group_members" (
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "order_group_id" uuid NOT NULL,
  "order_id" uuid UNIQUE NOT NULL,
  "member_role" trading.order_group_member_role NOT NULL,
  "leg_sequence" int NOT NULL,
  "quantity_ratio" numeric(18,8) NOT NULL DEFAULT 1,
  "activation_condition" jsonb NOT NULL,
  "cancellation_condition" jsonb NOT NULL,
  CONSTRAINT "order_group_leg_sequence_positive" CHECK (leg_sequence > 0),
  CONSTRAINT "order_group_quantity_ratio_positive" CHECK (quantity_ratio > 0),
  PRIMARY KEY ("order_group_id", "order_id")
);

CREATE TABLE "trading"."order_group_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "order_group_id" uuid NOT NULL,
  "bot_event_id" uuid UNIQUE NOT NULL,
  "group_sequence" bigint NOT NULL,
  "previous_status" trading.order_group_status,
  "new_status" trading.order_group_status NOT NULL,
  "event_type" varchar(50) NOT NULL,
  "reason_code" varchar(80),
  "occurred_at" timestamptz NOT NULL,
  "event_document" jsonb NOT NULL,
  CONSTRAINT "order_group_event_sequence_positive" CHECK (group_sequence > 0)
);

CREATE TABLE "trading"."order_components" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "order_id" uuid NOT NULL,
  "intent_id" uuid NOT NULL,
  "component_quantity" numeric(28,8) NOT NULL,
  "component_notional" numeric(24,8),
  "component_sequence" int NOT NULL,
  "composition_rules_version" varchar(40) NOT NULL,
  CONSTRAINT "order_component_quantity_positive" CHECK (component_quantity > 0),
  CONSTRAINT "order_component_notional_positive" CHECK (component_notional IS NULL OR component_notional > 0),
  CONSTRAINT "order_component_sequence_positive" CHECK (component_sequence > 0)
);

CREATE TABLE "trading"."resource_reservations" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "reservation_key" varchar(200) NOT NULL,
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "flow_id" uuid NOT NULL,
  "intent_id" uuid NOT NULL,
  "resource_type" trading.reservation_resource_type NOT NULL,
  "currency_code" char(3),
  "instrument_id" uuid,
  "buffer_policy_id" uuid,
  "fee_policy_id" uuid,
  "short_risk_policy_id" uuid,
  "precision_rules_version" varchar(80) NOT NULL,
  "status" trading.reservation_status NOT NULL,
  "reference_price" numeric(24,8),
  "reference_observed_at" timestamptz,
  "reference_market_hash" varchar(128),
  "base_notional" numeric(24,8),
  "fixed_slippage_amount" numeric(24,8),
  "estimated_fee_amount" numeric(24,8),
  "buffer_amount" numeric(24,8),
  "reserved_amount" numeric(24,8),
  "consumed_amount" numeric(24,8) NOT NULL DEFAULT 0,
  "released_amount" numeric(24,8) NOT NULL DEFAULT 0,
  "reserved_quantity" numeric(28,8),
  "consumed_quantity" numeric(28,8) NOT NULL DEFAULT 0,
  "released_quantity" numeric(28,8) NOT NULL DEFAULT 0,
  "created_event_id" uuid NOT NULL,
  "created_at" timestamptz NOT NULL,
  "last_event_sequence" bigint NOT NULL DEFAULT 1,
  CONSTRAINT "reservation_exactly_one_measure" CHECK ((reserved_amount IS NOT NULL) <> (reserved_quantity IS NOT NULL)),
  CONSTRAINT "reservation_amount_positive" CHECK (reserved_amount IS NULL OR reserved_amount > 0),
  CONSTRAINT "reservation_quantity_positive" CHECK (reserved_quantity IS NULL OR reserved_quantity > 0),
  CONSTRAINT "reservation_consumed_amount_nonnegative" CHECK (consumed_amount >= 0),
  CONSTRAINT "reservation_released_amount_nonnegative" CHECK (released_amount >= 0),
  CONSTRAINT "reservation_consumed_quantity_nonnegative" CHECK (consumed_quantity >= 0),
  CONSTRAINT "reservation_released_quantity_nonnegative" CHECK (released_quantity >= 0),
  CONSTRAINT "reservation_amount_not_exceeded" CHECK (reserved_amount IS NULL OR consumed_amount + released_amount <= reserved_amount),
  CONSTRAINT "reservation_quantity_not_exceeded" CHECK (reserved_quantity IS NULL OR consumed_quantity + released_quantity <= reserved_quantity),
  CONSTRAINT "reservation_amount_final_conservation" CHECK (reserved_amount IS NULL OR status = 'ACTIVE' OR consumed_amount + released_amount = reserved_amount),
  CONSTRAINT "reservation_quantity_final_conservation" CHECK (reserved_quantity IS NULL OR status = 'ACTIVE' OR consumed_quantity + released_quantity = reserved_quantity),
  CONSTRAINT "active_reservation_unsettled" CHECK (status <> 'ACTIVE' OR (consumed_amount = 0 AND released_amount = 0 AND consumed_quantity = 0 AND released_quantity = 0)),
  CONSTRAINT "settled_reservation_has_consumption" CHECK (status <> 'SETTLED' OR ((reserved_amount IS NOT NULL AND consumed_amount > 0) OR (reserved_quantity IS NOT NULL AND consumed_quantity > 0))),
  CONSTRAINT "released_reservation_has_no_consumption" CHECK (status <> 'RELEASED' OR (consumed_amount = 0 AND consumed_quantity = 0)),
  CONSTRAINT "cash_reservation_evidence_required" CHECK (resource_type <> 'CASH_BUYING_POWER' OR (currency_code IS NOT NULL AND buffer_policy_id IS NOT NULL AND fee_policy_id IS NOT NULL AND reserved_amount IS NOT NULL)),
  CONSTRAINT "quantity_reservation_instrument_required" CHECK (resource_type <> 'POSITION_QUANTITY' OR (instrument_id IS NOT NULL AND reserved_quantity IS NOT NULL)),
  CONSTRAINT "short_collateral_reservation_evidence_required" CHECK (resource_type <> 'SHORT_COLLATERAL_CASH' OR (currency_code IS NOT NULL AND instrument_id IS NOT NULL AND reserved_amount IS NOT NULL)),
  CONSTRAINT "cash_policies_only_for_buying_power" CHECK (resource_type = 'CASH_BUYING_POWER' OR (buffer_policy_id IS NULL AND fee_policy_id IS NULL AND buffer_amount IS NULL)),
  CONSTRAINT "short_collateral_policy_required" CHECK (resource_type <> 'SHORT_COLLATERAL_CASH' OR short_risk_policy_id IS NOT NULL),
  CONSTRAINT "short_policy_only_for_collateral" CHECK (resource_type = 'SHORT_COLLATERAL_CASH' OR short_risk_policy_id IS NULL)
);

CREATE TABLE "trading"."position_lot_reservations" (
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "flow_id" uuid NOT NULL,
  "reservation_id" uuid NOT NULL,
  "position_lot_id" uuid NOT NULL,
  "reserved_quantity" numeric(28,8) NOT NULL,
  CONSTRAINT "position_lot_reservation_quantity_positive" CHECK (reserved_quantity > 0),
  PRIMARY KEY ("reservation_id", "position_lot_id")
);

CREATE TABLE "trading"."order_component_reservations" (
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "reservation_id" uuid PRIMARY KEY NOT NULL,
  "order_component_id" uuid NOT NULL,
  "reserved_amount" numeric(24,8),
  "reserved_quantity" numeric(28,8),
  CONSTRAINT "order_component_reservation_exactly_one_measure" CHECK ((reserved_amount IS NOT NULL) <> (reserved_quantity IS NOT NULL)),
  CONSTRAINT "order_component_reservation_amount_positive" CHECK (reserved_amount IS NULL OR reserved_amount > 0),
  CONSTRAINT "order_component_reservation_quantity_positive" CHECK (reserved_quantity IS NULL OR reserved_quantity > 0)
);

CREATE TABLE "trading"."reservation_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "reservation_id" uuid NOT NULL,
  "bot_event_id" uuid NOT NULL,
  "source_fill_id" uuid,
  "event_key" varchar(160) NOT NULL,
  "reservation_sequence" bigint NOT NULL,
  "event_type" trading.reservation_event_type NOT NULL,
  "consumed_amount_delta" numeric(24,8),
  "released_amount_delta" numeric(24,8),
  "consumed_quantity_delta" numeric(28,8),
  "released_quantity_delta" numeric(28,8),
  "status_after" trading.reservation_status NOT NULL,
  "occurred_at" timestamptz NOT NULL,
  "event_hash" varchar(128) NOT NULL,
  CONSTRAINT "reservation_event_sequence_positive" CHECK (reservation_sequence > 0),
  CONSTRAINT "reservation_event_consumed_amount_nonnegative" CHECK (consumed_amount_delta IS NULL OR consumed_amount_delta >= 0),
  CONSTRAINT "reservation_event_released_amount_nonnegative" CHECK (released_amount_delta IS NULL OR released_amount_delta >= 0),
  CONSTRAINT "reservation_event_consumed_quantity_nonnegative" CHECK (consumed_quantity_delta IS NULL OR consumed_quantity_delta >= 0),
  CONSTRAINT "reservation_event_released_quantity_nonnegative" CHECK (released_quantity_delta IS NULL OR released_quantity_delta >= 0),
  CONSTRAINT "fill_settlement_source_required" CHECK (event_type <> 'SETTLED_BY_FILL' OR source_fill_id IS NOT NULL),
  CONSTRAINT "non_fill_reservation_event_has_no_fill" CHECK (event_type = 'SETTLED_BY_FILL' OR source_fill_id IS NULL),
  CONSTRAINT "fill_settlement_status_valid" CHECK (event_type <> 'SETTLED_BY_FILL' OR status_after = 'SETTLED'),
  CONSTRAINT "release_event_status_valid" CHECK (event_type NOT IN ('RELEASED_BY_CANCEL', 'RELEASED_BY_EXPIRY', 'RELEASED_BY_REJECTION', 'RELEASED_BY_REPLACEMENT') OR status_after = 'RELEASED')
);

CREATE TABLE "trading"."order_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "order_id" uuid NOT NULL,
  "bot_event_id" uuid UNIQUE NOT NULL,
  "order_sequence" bigint NOT NULL,
  "event_type" varchar(50) NOT NULL,
  "previous_status" trading.order_status,
  "new_status" trading.order_status NOT NULL,
  "reason_code" varchar(80),
  "occurred_at" timestamptz NOT NULL,
  "event_document" jsonb NOT NULL,
  CONSTRAINT "order_event_sequence_positive" CHECK (order_sequence > 0)
);

CREATE TABLE "trading"."order_state_projections" (
  "order_id" uuid PRIMARY KEY,
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "status" trading.order_status NOT NULL,
  "filled_quantity" numeric(28,8) NOT NULL,
  "remaining_quantity" numeric(28,8) NOT NULL,
  "reserved_cash" numeric(24,8) NOT NULL,
  "reserved_quantity" numeric(28,8) NOT NULL,
  "active_stop_price" numeric(24,8),
  "trailing_reference_price" numeric(24,8),
  "last_order_event_sequence" bigint NOT NULL,
  "last_bot_event_sequence" bigint NOT NULL,
  "updated_at" timestamptz NOT NULL,
  CONSTRAINT "order_projection_filled_nonnegative" CHECK (filled_quantity >= 0),
  CONSTRAINT "order_projection_remaining_nonnegative" CHECK (remaining_quantity >= 0),
  CONSTRAINT "order_projection_reserved_cash_nonnegative" CHECK (reserved_cash >= 0),
  CONSTRAINT "order_projection_reserved_quantity_nonnegative" CHECK (reserved_quantity >= 0),
  CONSTRAINT "order_projection_active_stop_positive" CHECK (active_stop_price IS NULL OR active_stop_price > 0),
  CONSTRAINT "order_projection_trailing_reference_positive" CHECK (trailing_reference_price IS NULL OR trailing_reference_price > 0),
  CONSTRAINT "filled_projection_is_complete" CHECK (status <> 'FILLED' OR (filled_quantity > 0 AND remaining_quantity = 0)),
  CONSTRAINT "nonfilled_terminal_projection_has_no_fill" CHECK (status NOT IN ('CANCELLED', 'EXPIRED', 'REJECTED') OR (filled_quantity = 0 AND remaining_quantity = 0)),
  CONSTRAINT "active_projection_has_no_partial_fill" CHECK (status NOT IN ('PENDING', 'OPEN') OR (filled_quantity = 0 AND remaining_quantity > 0))
);

CREATE TABLE "trading"."fills" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "order_id" uuid NOT NULL,
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "bot_event_id" uuid UNIQUE NOT NULL,
  "provider_fill_key" varchar(160) NOT NULL,
  "quantity" numeric(28,8) NOT NULL,
  "reference_price" numeric(24,8) NOT NULL,
  "reference_observed_at" timestamptz NOT NULL,
  "reference_market_hash" varchar(128) NOT NULL,
  "slippage_rate_bps" int NOT NULL,
  "slippage_amount" numeric(24,8) NOT NULL,
  "fill_price" numeric(24,8) NOT NULL,
  "gross_amount" numeric(24,8) NOT NULL,
  "fee_policy_id" uuid NOT NULL,
  "fee_rate_bps" int NOT NULL,
  "precision_rules_version" varchar(80) NOT NULL,
  "fee_basis_amount" numeric(24,8) NOT NULL,
  "fee_amount" numeric(24,8) NOT NULL,
  "settlement_cash_delta" numeric(24,8) NOT NULL,
  "occurred_at" timestamptz NOT NULL,
  "recorded_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "fill_quantity_positive" CHECK (quantity > 0),
  CONSTRAINT "fill_reference_price_positive" CHECK (reference_price > 0),
  CONSTRAINT "fill_fixed_slippage_five_bps" CHECK (slippage_rate_bps = 5),
  CONSTRAINT "fill_slippage_amount_nonnegative" CHECK (slippage_amount >= 0),
  CONSTRAINT "fill_price_positive" CHECK (fill_price > 0),
  CONSTRAINT "fill_gross_amount_positive" CHECK (gross_amount > 0),
  CONSTRAINT "fill_fee_twenty_bps" CHECK (fee_rate_bps = 20),
  CONSTRAINT "fill_fee_basis_positive" CHECK (fee_basis_amount > 0),
  CONSTRAINT "fill_fee_nonnegative" CHECK (fee_amount >= 0)
);

CREATE TABLE "trading"."fill_adjustments" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "fill_id" uuid NOT NULL,
  "bot_event_id" uuid NOT NULL,
  "adjustment_key" varchar(160) NOT NULL,
  "adjustment_type" trading.fill_adjustment_type NOT NULL,
  "quantity_delta" numeric(28,8) NOT NULL DEFAULT 0,
  "gross_amount_delta" numeric(24,8) NOT NULL DEFAULT 0,
  "fee_amount_delta" numeric(24,8) NOT NULL DEFAULT 0,
  "settlement_cash_delta" numeric(24,8) NOT NULL DEFAULT 0,
  "reason_code" varchar(80) NOT NULL,
  "occurred_at" timestamptz NOT NULL,
  "recorded_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "fill_adjustment_has_effect" CHECK (quantity_delta <> 0 OR gross_amount_delta <> 0 OR fee_amount_delta <> 0 OR settlement_cash_delta <> 0),
  CONSTRAINT "fill_correction_does_not_change_quantity" CHECK (adjustment_type <> 'CORRECTION' OR quantity_delta = 0)
);

CREATE TABLE "trading"."ledger_accounts" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "account_key" varchar(240) NOT NULL,
  "partition_id" uuid,
  "flow_id" uuid,
  "account_type" varchar(50) NOT NULL,
  "currency_code" char(3),
  "instrument_id" uuid,
  "created_at" timestamptz NOT NULL,
  "closed_at" timestamptz,
  CONSTRAINT "ledger_flow_requires_partition" CHECK (flow_id IS NULL OR partition_id IS NOT NULL),
  CONSTRAINT "ledger_account_exactly_one_unit" CHECK ((currency_code IS NOT NULL) <> (instrument_id IS NOT NULL)),
  CONSTRAINT "ledger_account_close_after_create" CHECK (closed_at IS NULL OR closed_at > created_at)
);

CREATE TABLE "trading"."ledger_transactions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid,
  "bot_event_id" uuid UNIQUE NOT NULL,
  "transaction_type" varchar(60) NOT NULL,
  "transaction_key" varchar(160) NOT NULL,
  "source_type" varchar(40) NOT NULL,
  "source_id" uuid NOT NULL,
  "currency_code" char(3) NOT NULL,
  "reversal_of_transaction_id" uuid,
  "occurred_at" timestamptz NOT NULL,
  "recorded_at" timestamptz NOT NULL DEFAULT (now()),
  "description_code" varchar(80) NOT NULL
);

CREATE TABLE "trading"."ledger_entries" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid,
  "transaction_id" uuid NOT NULL,
  "ledger_account_id" uuid NOT NULL,
  "order_component_id" uuid,
  "entry_sequence" int NOT NULL,
  "direction" trading.ledger_direction NOT NULL,
  "amount" numeric(24,8) NOT NULL,
  "quantity" numeric(28,8),
  "entry_hash" varchar(128) NOT NULL,
  CONSTRAINT "ledger_entry_sequence_positive" CHECK (entry_sequence > 0),
  CONSTRAINT "ledger_entry_amount_positive" CHECK (amount > 0),
  CONSTRAINT "ledger_entry_quantity_nonzero" CHECK (quantity IS NULL OR quantity <> 0),
  CONSTRAINT "order_component_ledger_entry_requires_partition" CHECK (order_component_id IS NULL OR partition_id IS NOT NULL)
);

CREATE TABLE "trading"."position_lots" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "flow_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  "opening_order_component_id" uuid UNIQUE NOT NULL,
  "lot_side" trading.lot_side NOT NULL,
  "opened_quantity" numeric(28,8) NOT NULL,
  "unit_cost" numeric(24,8) NOT NULL,
  "opened_cost_basis_amount" numeric(24,8) NOT NULL,
  "opened_at" timestamptz NOT NULL,
  CONSTRAINT "position_lot_opened_quantity_positive" CHECK (opened_quantity > 0),
  CONSTRAINT "position_lot_unit_cost_nonnegative" CHECK (unit_cost >= 0),
  CONSTRAINT "position_lot_opened_basis_nonnegative" CHECK (opened_cost_basis_amount >= 0)
);

CREATE TABLE "trading"."lot_movements" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "position_lot_id" uuid NOT NULL,
  "bot_event_id" uuid NOT NULL,
  "source_order_component_id" uuid,
  "source_fill_adjustment_id" uuid,
  "corporate_action_id" uuid,
  "reverses_movement_id" uuid,
  "movement_type" trading.lot_movement_type NOT NULL,
  "quantity_delta" numeric(28,8) NOT NULL,
  "cost_basis_delta" numeric(24,8) NOT NULL,
  "remaining_after" numeric(28,8) NOT NULL,
  "cost_basis_after" numeric(24,8) NOT NULL,
  "occurred_at" timestamptz NOT NULL,
  CONSTRAINT "lot_movement_quantity_nonzero" CHECK (quantity_delta <> 0),
  CONSTRAINT "lot_movement_remaining_nonnegative" CHECK (remaining_after >= 0),
  CONSTRAINT "lot_movement_basis_nonnegative" CHECK (cost_basis_after >= 0),
  CONSTRAINT "lot_movement_source_not_ambiguous" CHECK ((CASE WHEN source_order_component_id IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN source_fill_adjustment_id IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN corporate_action_id IS NOT NULL THEN 1 ELSE 0 END) <= 1),
  CONSTRAINT "fill_movement_source_required" CHECK (movement_type NOT IN ('OPEN', 'CLOSE') OR source_order_component_id IS NOT NULL),
  CONSTRAINT "corporate_movement_source_required" CHECK (movement_type <> 'CORPORATE_ACTION_ADJUSTMENT' OR corporate_action_id IS NOT NULL),
  CONSTRAINT "reversal_movement_source_required" CHECK (movement_type <> 'REVERSAL' OR (reverses_movement_id IS NOT NULL AND source_fill_adjustment_id IS NOT NULL))
);

CREATE TABLE "trading"."position_lot_projections" (
  "position_lot_id" uuid PRIMARY KEY,
  "remaining_quantity" numeric(28,8) NOT NULL,
  "remaining_cost_basis_amount" numeric(24,8) NOT NULL,
  "active_reserved_quantity" numeric(28,8) NOT NULL,
  "last_movement_id" uuid NOT NULL,
  "last_event_sequence" bigint NOT NULL,
  "closed_at" timestamptz,
  "updated_at" timestamptz NOT NULL,
  CONSTRAINT "lot_projection_remaining_nonnegative" CHECK (remaining_quantity >= 0),
  CONSTRAINT "lot_projection_basis_nonnegative" CHECK (remaining_cost_basis_amount >= 0),
  CONSTRAINT "lot_projection_reservation_within_remaining" CHECK (active_reserved_quantity >= 0 AND active_reserved_quantity <= remaining_quantity),
  CONSTRAINT "lot_projection_closed_consistent" CHECK ((remaining_quantity = 0) = (closed_at IS NOT NULL))
);

CREATE TABLE "trading"."short_trade_checks" (
  "intent_id" uuid PRIMARY KEY,
  "short_risk_policy_id" uuid NOT NULL,
  "assessed_at" timestamptz NOT NULL,
  "reference_price" numeric(24,8) NOT NULL,
  "projected_short_quantity" numeric(28,8) NOT NULL,
  "projected_exposure_amount" numeric(24,8) NOT NULL,
  "required_initial_collateral_amount" numeric(24,8) NOT NULL,
  "required_maintenance_collateral_amount" numeric(24,8) NOT NULL,
  "rule_201_triggered" boolean NOT NULL,
  "rule_201_triggered_at" timestamptz,
  "prior_regular_close_price" numeric(24,8) NOT NULL,
  "national_best_bid_price" numeric(24,8) NOT NULL,
  "minimum_permitted_short_price" numeric(24,8),
  "price_rule_observed_at" timestamptz NOT NULL,
  "price_rule_market_hash" varchar(128) NOT NULL,
  "liquidation_reference_price" numeric(24,8),
  "approved" boolean NOT NULL,
  "decision_reason_code" varchar(80) NOT NULL,
  "evidence_hash" varchar(128) NOT NULL,
  CONSTRAINT "short_check_reference_price_positive" CHECK (reference_price > 0),
  CONSTRAINT "short_check_quantity_positive" CHECK (projected_short_quantity > 0),
  CONSTRAINT "short_check_exposure_positive" CHECK (projected_exposure_amount > 0),
  CONSTRAINT "short_check_initial_collateral_nonnegative" CHECK (required_initial_collateral_amount >= 0),
  CONSTRAINT "short_check_maintenance_collateral_nonnegative" CHECK (required_maintenance_collateral_amount >= 0),
  CONSTRAINT "short_check_initial_not_below_maintenance" CHECK (required_initial_collateral_amount >= required_maintenance_collateral_amount),
  CONSTRAINT "short_check_prior_close_positive" CHECK (prior_regular_close_price > 0),
  CONSTRAINT "short_check_nbb_positive" CHECK (national_best_bid_price > 0),
  CONSTRAINT "short_check_rule_201_evidence_required" CHECK (NOT rule_201_triggered OR (rule_201_triggered_at IS NOT NULL AND minimum_permitted_short_price > national_best_bid_price)),
  CONSTRAINT "short_check_no_rule_201_evidence_when_inactive" CHECK (rule_201_triggered OR (rule_201_triggered_at IS NULL AND minimum_permitted_short_price IS NULL)),
  CONSTRAINT "short_check_liquidation_price_positive" CHECK (liquidation_reference_price IS NULL OR liquidation_reference_price > 0)
);

CREATE TABLE "trading"."system_close_actions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "flow_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  "source_event_id" uuid NOT NULL,
  "reason_type" trading.system_close_reason NOT NULL,
  "requested_quantity" numeric(28,8) NOT NULL,
  "generated_intent_id" uuid UNIQUE NOT NULL,
  "reason_document" jsonb NOT NULL,
  "calculation_hash" varchar(128) NOT NULL,
  "created_at" timestamptz NOT NULL,
  CONSTRAINT "system_close_quantity_positive" CHECK (requested_quantity > 0)
);

CREATE TABLE "trading"."short_borrow_fee_accruals" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "position_lot_id" uuid NOT NULL,
  "bot_event_id" uuid UNIQUE NOT NULL,
  "short_borrow_fee_policy_id" uuid NOT NULL,
  "ledger_transaction_id" uuid UNIQUE NOT NULL,
  "period_start" timestamptz NOT NULL,
  "period_end" timestamptz NOT NULL,
  "annual_fee_rate_bps" numeric(12,6) NOT NULL,
  "day_count_basis" varchar(20) NOT NULL,
  "fee_basis_amount" numeric(24,8) NOT NULL,
  "accrued_fee_amount" numeric(24,8) NOT NULL,
  "calculation_hash" varchar(128) NOT NULL,
  CONSTRAINT "short_borrow_fee_period_valid" CHECK (period_end > period_start),
  CONSTRAINT "short_borrow_fee_rate_nonnegative" CHECK (annual_fee_rate_bps >= 0),
  CONSTRAINT "short_borrow_fee_basis_nonnegative" CHECK (fee_basis_amount >= 0),
  CONSTRAINT "short_borrow_fee_amount_nonnegative" CHECK (accrued_fee_amount >= 0)
);

CREATE TABLE "trading"."flow_position_projections" (
  "flow_id" uuid NOT NULL,
  "partition_id" uuid NOT NULL,
  "bot_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  "long_quantity" numeric(28,8) NOT NULL,
  "short_quantity" numeric(28,8) NOT NULL,
  "cost_basis_amount" numeric(24,8) NOT NULL,
  "last_event_sequence" bigint NOT NULL,
  "projection_hash" varchar(128) NOT NULL,
  "updated_at" timestamptz NOT NULL,
  CONSTRAINT "flow_position_long_nonnegative" CHECK (long_quantity >= 0),
  CONSTRAINT "flow_position_short_nonnegative" CHECK (short_quantity >= 0),
  CONSTRAINT "flow_position_basis_nonnegative" CHECK (cost_basis_amount >= 0),
  PRIMARY KEY ("flow_id", "instrument_id")
);

CREATE TABLE "trading"."partition_position_projections" (
  "partition_id" uuid NOT NULL,
  "bot_id" uuid NOT NULL,
  "instrument_id" uuid NOT NULL,
  "net_quantity" numeric(28,8) NOT NULL,
  "average_cost" numeric(24,8),
  "realized_pnl" numeric(24,8) NOT NULL,
  "last_valuation_price" numeric(24,8),
  "last_valuation_at" timestamptz,
  "valuation_status" varchar(30) NOT NULL,
  "last_bot_event_sequence" bigint NOT NULL,
  "updated_at" timestamptz NOT NULL,
  CONSTRAINT "position_projection_average_cost_nonnegative" CHECK (average_cost IS NULL OR average_cost >= 0),
  CONSTRAINT "position_projection_valuation_price_positive" CHECK (last_valuation_price IS NULL OR last_valuation_price > 0),
  PRIMARY KEY ("partition_id", "instrument_id")
);

CREATE TABLE "trading"."bot_budget_projections" (
  "bot_id" uuid PRIMARY KEY,
  "currency_code" char(3) NOT NULL,
  "available_cash_amount" numeric(24,8) NOT NULL,
  "active_reservation_amount" numeric(24,8) NOT NULL,
  "invested_amount" numeric(24,8) NOT NULL,
  "segregated_short_proceeds_amount" numeric(24,8) NOT NULL,
  "short_collateral_amount" numeric(24,8) NOT NULL,
  "valuation_at" timestamptz NOT NULL,
  "valuation_status" varchar(30) NOT NULL,
  "last_event_sequence" bigint NOT NULL,
  "projection_hash" varchar(128) NOT NULL,
  "updated_at" timestamptz NOT NULL,
  CONSTRAINT "bot_budget_available_nonnegative" CHECK (available_cash_amount >= 0),
  CONSTRAINT "bot_budget_reservation_nonnegative" CHECK (active_reservation_amount >= 0),
  CONSTRAINT "bot_budget_invested_nonnegative" CHECK (invested_amount >= 0),
  CONSTRAINT "bot_budget_short_proceeds_nonnegative" CHECK (segregated_short_proceeds_amount >= 0),
  CONSTRAINT "bot_budget_short_collateral_nonnegative" CHECK (short_collateral_amount >= 0)
);

CREATE TABLE "trading"."partition_budget_projections" (
  "partition_id" uuid PRIMARY KEY,
  "bot_id" uuid NOT NULL,
  "currency_code" char(3) NOT NULL,
  "budget_cap_amount" numeric(24,8) NOT NULL,
  "active_reservation_amount" numeric(24,8) NOT NULL,
  "invested_amount" numeric(24,8) NOT NULL,
  "segregated_short_proceeds_amount" numeric(24,8) NOT NULL,
  "short_collateral_amount" numeric(24,8) NOT NULL,
  "valuation_at" timestamptz NOT NULL,
  "valuation_status" varchar(30) NOT NULL,
  "last_event_sequence" bigint NOT NULL,
  "projection_hash" varchar(128) NOT NULL,
  "updated_at" timestamptz NOT NULL,
  CONSTRAINT "partition_budget_cap_positive" CHECK (budget_cap_amount > 0),
  CONSTRAINT "partition_budget_reservation_nonnegative" CHECK (active_reservation_amount >= 0),
  CONSTRAINT "partition_budget_invested_nonnegative" CHECK (invested_amount >= 0),
  CONSTRAINT "partition_budget_short_proceeds_nonnegative" CHECK (segregated_short_proceeds_amount >= 0),
  CONSTRAINT "partition_budget_short_collateral_nonnegative" CHECK (short_collateral_amount >= 0)
);

CREATE TABLE "backtest"."runs" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "owner_account_id" uuid NOT NULL,
  "configuration_hash" varchar(128) NOT NULL,
  "status" backtest.run_status NOT NULL,
  "evaluation_start" date NOT NULL,
  "evaluation_end" date NOT NULL,
  "initial_cash_amount" numeric(24,8) NOT NULL,
  "market_rules_version" varchar(80) NOT NULL,
  "accounting_rules_version" varchar(80) NOT NULL,
  "precision_rules_version" varchar(80) NOT NULL,
  "fee_policy_id" uuid NOT NULL,
  "slippage_rate_bps" int NOT NULL,
  "buying_power_buffer_policy_id" uuid NOT NULL,
  "idempotency_key" varchar(160) UNIQUE NOT NULL,
  "queued_at" timestamptz NOT NULL,
  "started_at" timestamptz,
  "completed_at" timestamptz,
  "failure_code" varchar(80),
  "result_hash" varchar(128)
);

CREATE TABLE "backtest"."run_attempts" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "run_id" uuid NOT NULL,
  "attempt_number" int NOT NULL,
  "worker_execution_key" varchar(160) UNIQUE NOT NULL,
  "status" operations.work_status NOT NULL,
  "started_at" timestamptz NOT NULL,
  "completed_at" timestamptz,
  "failure_code" varchar(80)
);

CREATE TABLE "backtest"."input_datasets" (
  "input_bundle_id" uuid NOT NULL,
  "dataset_manifest_id" uuid NOT NULL,
  "purpose_code" varchar(80) NOT NULL,
  "locked_dataset_hash" varchar(128) NOT NULL,
  PRIMARY KEY ("input_bundle_id", "dataset_manifest_id", "purpose_code")
);

CREATE TABLE "backtest"."input_feature_materializations" (
  "input_bundle_id" uuid NOT NULL,
  "feature_materialization_id" uuid NOT NULL,
  "locked_result_hash" varchar(128) NOT NULL,
  PRIMARY KEY ("input_bundle_id", "feature_materialization_id")
);

CREATE TABLE "backtest"."input_bundles" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "run_id" uuid UNIQUE NOT NULL,
  "bundle_hash" varchar(128) NOT NULL,
  "as_of_at" timestamptz NOT NULL,
  "locked_at" timestamptz NOT NULL
);

CREATE TABLE "backtest"."monthly_judgment_summaries" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "run_id" uuid NOT NULL,
  "et_year_month" char(7) NOT NULL,
  "evaluation_count" bigint NOT NULL,
  "active_branch_count" bigint NOT NULL,
  "trade_event_count" bigint NOT NULL,
  "data_gap_count" bigint NOT NULL,
  "triggered_count" bigint NOT NULL,
  "rejected_count" bigint NOT NULL,
  "summary_document" jsonb NOT NULL,
  "summary_hash" varchar(128) NOT NULL
);

CREATE TABLE "backtest"."failure_condition_counts" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "monthly_summary_id" uuid NOT NULL,
  "flow_or_branch_key" varchar(160) NOT NULL,
  "first_failure_condition_key" varchar(160) NOT NULL,
  "occurrence_count" bigint NOT NULL
);

CREATE TABLE "backtest"."performance_summaries" (
  "run_id" uuid PRIMARY KEY,
  "metric_catalog_version" varchar(80) NOT NULL,
  "metrics_document" jsonb NOT NULL,
  "calculation_rules_version" varchar(80) NOT NULL,
  "source_set_hash" varchar(128) NOT NULL,
  "input_hash" varchar(128) NOT NULL,
  "result_hash" varchar(128) NOT NULL,
  "calculated_at" timestamptz NOT NULL
);

CREATE TABLE "backtest"."detail_manifests" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "run_id" uuid NOT NULL,
  "object_id" uuid NOT NULL,
  "record_type" varchar(50) NOT NULL,
  "week_start_date" date NOT NULL,
  "period_start" timestamptz NOT NULL,
  "period_end" timestamptz NOT NULL,
  "part_number" int NOT NULL,
  "row_count" bigint NOT NULL,
  "schema_version" varchar(40) NOT NULL,
  "source_set_hash" varchar(128) NOT NULL,
  "supersedes_manifest_id" uuid,
  "detail_hash" varchar(128) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "performance"."bot_current_projections" (
  "bot_id" uuid PRIMARY KEY,
  "equity_amount" numeric(24,8) NOT NULL,
  "total_return_pct" numeric(18,8) NOT NULL,
  "max_drawdown_pct" numeric(18,8) NOT NULL,
  "sharpe_ratio" numeric(18,8),
  "metrics_document" jsonb NOT NULL,
  "ledger_state_hash" varchar(128) NOT NULL,
  "position_state_hash" varchar(128) NOT NULL,
  "calculation_rules_version" varchar(80) NOT NULL,
  "last_event_sequence" bigint NOT NULL,
  "projection_hash" varchar(128) NOT NULL,
  "updated_at" timestamptz NOT NULL,
  CONSTRAINT "performance_current_event_sequence_nonnegative" CHECK (last_event_sequence >= 0)
);

CREATE TABLE "performance"."bot_snapshots" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "snapshot_type" performance.snapshot_type NOT NULL,
  "source_event_sequence" bigint NOT NULL,
  "evaluated_at" timestamptz NOT NULL,
  "equity_amount" numeric(24,8) NOT NULL,
  "total_return_pct" numeric(18,8) NOT NULL,
  "max_drawdown_pct" numeric(18,8) NOT NULL,
  "sharpe_ratio" numeric(18,8),
  "metrics_document" jsonb NOT NULL,
  "input_hash" varchar(128) NOT NULL,
  "calculation_rules_version" varchar(80) NOT NULL,
  "snapshot_hash" varchar(128) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "performance_snapshot_event_sequence_nonnegative" CHECK (source_event_sequence >= 0)
);

CREATE TABLE "performance"."series_manifests" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bot_id" uuid NOT NULL,
  "object_id" uuid NOT NULL,
  "series_type" varchar(50) NOT NULL,
  "week_start_date" date NOT NULL,
  "period_start" timestamptz NOT NULL,
  "period_end" timestamptz NOT NULL,
  "part_number" int NOT NULL,
  "revision_number" int NOT NULL DEFAULT 1,
  "row_count" bigint NOT NULL,
  "schema_version" varchar(40) NOT NULL,
  "calculation_rules_version" varchar(80) NOT NULL,
  "supersedes_manifest_id" uuid,
  "series_hash" varchar(128) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "available_at" timestamptz NOT NULL,
  CONSTRAINT "performance_series_period_order" CHECK (period_end > period_start),
  CONSTRAINT "performance_series_part_number_positive" CHECK (part_number >= 1),
  CONSTRAINT "performance_series_revision_number_positive" CHECK (revision_number >= 1),
  CONSTRAINT "performance_series_row_count_nonnegative" CHECK (row_count >= 0),
  CONSTRAINT "performance_series_week_starts_monday" CHECK (extract(isodow from week_start_date) = 1),
  CONSTRAINT "performance_series_availability_order" CHECK (available_at >= created_at)
);

CREATE TABLE "competition"."scoring_template_versions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "template_code" varchar(80) NOT NULL,
  "version" varchar(40) NOT NULL,
  "rules_document" jsonb NOT NULL,
  "rules_hash" varchar(128) UNIQUE NOT NULL,
  "published_at" timestamptz NOT NULL,
  "retired_at" timestamptz
);

CREATE TABLE "competition"."rooms" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "competition_type" competition.competition_type NOT NULL,
  "organizer_type" competition.organizer_type NOT NULL,
  "creator_account_id" uuid,
  "created_by_operator_id" uuid,
  "name" varchar(120) NOT NULL,
  "access_type" competition.room_access_type NOT NULL,
  "status" competition.room_status NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "ended_at" timestamptz,
  "invalidated_at" timestamptz,
  "invalidation_reason_code" varchar(80),
  CONSTRAINT "competition_room_organizer_actor" CHECK ((organizer_type = 'USER' AND creator_account_id IS NOT NULL AND created_by_operator_id IS NULL) OR (organizer_type = 'PLATFORM' AND creator_account_id IS NULL AND created_by_operator_id IS NOT NULL)),
  CONSTRAINT "competition_backtest_platform_only" CHECK (competition_type <> 'BACKTEST' OR organizer_type = 'PLATFORM')
);

CREATE TABLE "competition"."room_rules" (
  "room_id" uuid PRIMARY KEY,
  "scoring_template_version_id" uuid NOT NULL,
  "initial_cash_amount" numeric(24,8) NOT NULL,
  "currency_code" char(3) NOT NULL DEFAULT 'USD',
  "bot_participation_limit" int NOT NULL,
  "per_account_bot_limit" int NOT NULL,
  "eligibility_document" jsonb NOT NULL,
  "market_scope_document" jsonb NOT NULL,
  "scoring_parameters" jsonb NOT NULL,
  "fee_policy_id" uuid NOT NULL,
  "slippage_rate_bps" int NOT NULL,
  "buying_power_buffer_policy_id" uuid NOT NULL,
  "precision_rules_version" varchar(80) NOT NULL,
  "rules_hash" varchar(128) NOT NULL,
  "locked_at" timestamptz NOT NULL,
  CONSTRAINT "competition_initial_cash_positive" CHECK (initial_cash_amount > 0),
  CONSTRAINT "competition_bot_participation_limit_positive" CHECK (bot_participation_limit > 0),
  CONSTRAINT "competition_account_bot_limit_valid" CHECK (per_account_bot_limit > 0 AND per_account_bot_limit <= bot_participation_limit),
  CONSTRAINT "competition_fixed_slippage_five_bps" CHECK (slippage_rate_bps = 5)
);

CREATE TABLE "competition"."live_room_rules" (
  "room_id" uuid PRIMARY KEY,
  "stopped_bot_slot_policy" varchar(30) NOT NULL,
  "minimum_operation_seconds" bigint NOT NULL,
  "minimum_fill_count" int NOT NULL,
  CONSTRAINT "competition_live_minimum_operation_nonnegative" CHECK (minimum_operation_seconds >= 0),
  CONSTRAINT "competition_live_minimum_fill_nonnegative" CHECK (minimum_fill_count >= 0)
);

CREATE TABLE "competition"."room_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "room_id" uuid NOT NULL,
  "event_sequence" int NOT NULL,
  "event_type" varchar(60) NOT NULL,
  "resulting_status" competition.room_status NOT NULL,
  "reason_code" varchar(80),
  "occurred_at" timestamptz NOT NULL,
  "payload_document" jsonb NOT NULL
);

CREATE TABLE "competition"."room_invitations" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "room_id" uuid NOT NULL,
  "issued_by_account_id" uuid NOT NULL,
  "credential_type" competition.invitation_credential_type NOT NULL,
  "credential_digest" varchar(128) UNIQUE NOT NULL,
  "issued_at" timestamptz NOT NULL,
  "expires_at" timestamptz NOT NULL,
  "revoked_at" timestamptz,
  "revocation_reason_code" varchar(80)
);

CREATE TABLE "competition"."room_schedules" (
  "room_id" uuid PRIMARY KEY,
  "recruitment_opens_at" timestamptz NOT NULL,
  "participation_opens_at" timestamptz NOT NULL,
  "evaluation_starts_at" timestamptz NOT NULL,
  "participation_closes_at" timestamptz NOT NULL,
  "evaluation_ends_at" timestamptz NOT NULL,
  "finalization_deadline_at" timestamptz NOT NULL,
  "timezone_name" varchar(80) NOT NULL,
  CONSTRAINT "competition_recruitment_before_participation" CHECK (recruitment_opens_at <= participation_opens_at),
  CONSTRAINT "competition_participation_window_order" CHECK (participation_opens_at <= participation_closes_at),
  CONSTRAINT "competition_evaluation_window_order" CHECK (evaluation_starts_at <= evaluation_ends_at),
  CONSTRAINT "competition_participation_before_evaluation_end" CHECK (participation_closes_at <= evaluation_ends_at),
  CONSTRAINT "competition_finalization_after_evaluation" CHECK (evaluation_ends_at <= finalization_deadline_at)
);

CREATE TABLE "competition"."participations" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "room_id" uuid NOT NULL,
  "bot_id" uuid UNIQUE NOT NULL,
  "owner_account_id" uuid NOT NULL,
  "anonymous_alias" varchar(80) NOT NULL,
  "status" competition.participation_status NOT NULL,
  "joined_at" timestamptz NOT NULL,
  "evaluation_started_at" timestamptz,
  "evaluation_finished_at" timestamptz,
  "evaluation_failure_code" varchar(80),
  "withdrawn_at" timestamptz,
  "withdrawal_reason_code" varchar(80),
  "expelled_at" timestamptz,
  "expulsion_reason_code" varchar(80),
  "post_room_action" competition.post_room_action,
  "action_recorded_at" timestamptz,
  "action_locked_at" timestamptz,
  CONSTRAINT "competition_participation_evaluation_order" CHECK (evaluation_finished_at IS NULL OR evaluation_started_at IS NOT NULL),
  CONSTRAINT "competition_failed_participation_has_reason" CHECK (status <> 'EVALUATION_FAILED' OR (evaluation_finished_at IS NOT NULL AND evaluation_failure_code IS NOT NULL)),
  CONSTRAINT "competition_completed_participation_has_result" CHECK (status <> 'COMPLETED' OR (evaluation_finished_at IS NOT NULL AND evaluation_failure_code IS NULL)),
  CONSTRAINT "competition_withdrawn_has_time" CHECK (status <> 'WITHDRAWN' OR withdrawn_at IS NOT NULL),
  CONSTRAINT "competition_expelled_has_time" CHECK (status <> 'EXPELLED' OR expelled_at IS NOT NULL)
);

CREATE TABLE "competition"."participation_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "participation_id" uuid NOT NULL,
  "event_sequence" int NOT NULL,
  "event_type" varchar(50) NOT NULL,
  "reason_code" varchar(80),
  "occurred_at" timestamptz NOT NULL,
  "payload_document" jsonb NOT NULL
);

CREATE TABLE "competition"."backtest_evaluation_plans" (
  "room_id" uuid PRIMARY KEY,
  "plan_version" varchar(40) NOT NULL,
  "period_count" int NOT NULL,
  "plan_hash" varchar(128) UNIQUE NOT NULL,
  "commitment_hash" varchar(128) UNIQUE NOT NULL,
  "commitment_nonce_ciphertext" text NOT NULL,
  "nonce_key_version" smallint NOT NULL,
  "locked_at" timestamptz NOT NULL,
  "disclosed_at" timestamptz,
  CONSTRAINT "competition_backtest_period_count_minimum" CHECK (period_count >= 2),
  CONSTRAINT "competition_backtest_nonce_key_version_positive" CHECK (nonce_key_version > 0),
  CONSTRAINT "competition_backtest_plan_disclosure_order" CHECK (disclosed_at IS NULL OR disclosed_at >= locked_at)
);

CREATE TABLE "competition"."backtest_evaluation_periods" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "evaluation_plan_room_id" uuid NOT NULL,
  "period_sequence" int NOT NULL,
  "evaluation_start" date NOT NULL,
  "evaluation_end" date NOT NULL,
  "importance_weight" numeric(18,12) NOT NULL,
  "input_set_hash" varchar(128) NOT NULL,
  CONSTRAINT "competition_backtest_period_sequence_positive" CHECK (period_sequence >= 1),
  CONSTRAINT "competition_backtest_period_order" CHECK (evaluation_end >= evaluation_start),
  CONSTRAINT "competition_backtest_period_weight_range" CHECK (importance_weight > 0 AND importance_weight <= 1)
);

CREATE TABLE "competition"."backtest_period_datasets" (
  "evaluation_period_id" uuid NOT NULL,
  "dataset_manifest_id" uuid NOT NULL,
  "purpose_code" varchar(80) NOT NULL,
  "locked_dataset_hash" varchar(128) NOT NULL,
  PRIMARY KEY ("evaluation_period_id", "dataset_manifest_id", "purpose_code")
);

CREATE TABLE "competition"."backtest_period_feature_materializations" (
  "evaluation_period_id" uuid NOT NULL,
  "feature_materialization_id" uuid NOT NULL,
  "locked_result_hash" varchar(128) NOT NULL,
  PRIMARY KEY ("evaluation_period_id", "feature_materialization_id")
);

CREATE TABLE "competition"."backtest_period_runs" (
  "participation_id" uuid NOT NULL,
  "evaluation_period_id" uuid NOT NULL,
  "run_id" uuid NOT NULL,
  "verified_at" timestamptz,
  "verification_failure_code" varchar(80),
  "locked_result_hash" varchar(128),
  CONSTRAINT "competition_backtest_verified_run_has_hash" CHECK (verified_at IS NULL OR (verification_failure_code IS NULL AND locked_result_hash IS NOT NULL)),
  CONSTRAINT "competition_backtest_failed_verification_not_verified" CHECK (verification_failure_code IS NULL OR verified_at IS NULL),
  PRIMARY KEY ("participation_id", "evaluation_period_id")
);

CREATE TABLE "competition"."backtest_aggregate_results" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "participation_id" uuid UNIQUE NOT NULL,
  "evaluation_plan_room_id" uuid NOT NULL,
  "scoring_template_version_id" uuid NOT NULL,
  "weighted_return_pct" numeric(18,8) NOT NULL,
  "weighted_sharpe_ratio" numeric(18,8),
  "weighted_max_drawdown_pct" numeric(18,8) NOT NULL,
  "worst_period_max_drawdown_pct" numeric(18,8) NOT NULL,
  "final_score" numeric(24,10) NOT NULL,
  "metrics_document" jsonb NOT NULL,
  "period_result_set_hash" varchar(128) NOT NULL,
  "calculation_rules_version" varchar(80) NOT NULL,
  "aggregate_hash" varchar(128) UNIQUE NOT NULL,
  "calculated_at" timestamptz NOT NULL,
  "verified_at" timestamptz NOT NULL,
  "published_at" timestamptz NOT NULL,
  CONSTRAINT "competition_backtest_aggregate_verification_order" CHECK (verified_at >= calculated_at),
  CONSTRAINT "competition_backtest_aggregate_publication_order" CHECK (published_at >= verified_at)
);

CREATE TABLE "competition"."live_evaluation_segments" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "participation_id" uuid NOT NULL,
  "segment_type" varchar(40) NOT NULL,
  "starts_at" timestamptz NOT NULL,
  "ends_at" timestamptz NOT NULL,
  "start_event_sequence" bigint NOT NULL,
  "end_event_sequence" bigint,
  "initial_state_hash" varchar(128) NOT NULL,
  "final_state_hash" varchar(128),
  "source_set_hash" varchar(128),
  "virtual_liquidation_document" jsonb,
  "finalized_at" timestamptz
);

CREATE TABLE "competition"."leaderboard_snapshots" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "room_id" uuid NOT NULL,
  "scoring_template_version_id" uuid NOT NULL,
  "cutoff_at" timestamptz NOT NULL,
  "status" competition.leaderboard_status NOT NULL,
  "result_hash" varchar(128) NOT NULL,
  "created_at" timestamptz NOT NULL
);

CREATE TABLE "competition"."leaderboard_entries" (
  "snapshot_id" uuid NOT NULL,
  "participation_id" uuid NOT NULL,
  "performance_snapshot_id" uuid,
  "backtest_aggregate_result_id" uuid,
  "rank" int NOT NULL,
  "is_joint_rank" boolean NOT NULL DEFAULT false,
  "eligibility_status" varchar(30) NOT NULL,
  "eligibility_reason_code" varchar(80),
  "score" numeric(24,10) NOT NULL,
  "tie_break_document" jsonb NOT NULL,
  "calculation_document" jsonb NOT NULL,
  CONSTRAINT "competition_leaderboard_exactly_one_result_source" CHECK ((performance_snapshot_id IS NOT NULL AND backtest_aggregate_result_id IS NULL) OR (performance_snapshot_id IS NULL AND backtest_aggregate_result_id IS NOT NULL)),
  CONSTRAINT "competition_leaderboard_rank_positive" CHECK (rank > 0),
  PRIMARY KEY ("snapshot_id", "participation_id")
);

CREATE TABLE "operations"."operator_accounts" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "external_identity_key_hmac" varchar(128) UNIQUE NOT NULL,
  "status" varchar(30) NOT NULL,
  "mfa_enrolled_at" timestamptz NOT NULL,
  "last_mfa_verified_at" timestamptz,
  "created_at" timestamptz NOT NULL,
  "disabled_at" timestamptz
);

CREATE TABLE "operations"."roles" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "code" varchar(80) UNIQUE NOT NULL,
  "hierarchy_rank" int NOT NULL,
  "status" varchar(30) NOT NULL
);

CREATE TABLE "operations"."permissions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "code" varchar(120) UNIQUE NOT NULL,
  "description" varchar(500) NOT NULL,
  "sensitivity" varchar(30) NOT NULL
);

CREATE TABLE "operations"."role_permissions" (
  "role_id" uuid NOT NULL,
  "permission_id" uuid NOT NULL,
  PRIMARY KEY ("role_id", "permission_id")
);

CREATE TABLE "operations"."operator_role_assignments" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "operator_account_id" uuid NOT NULL,
  "role_id" uuid NOT NULL,
  "granted_by_operator_id" uuid NOT NULL,
  "granted_at" timestamptz NOT NULL,
  "expires_at" timestamptz,
  "revoked_by_operator_id" uuid,
  "revoked_at" timestamptz,
  "revocation_reason_code" varchar(80)
);

CREATE TABLE "operations"."outbox_messages" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "owner_domain" varchar(40) NOT NULL,
  "aggregate_id" uuid NOT NULL,
  "aggregate_sequence" bigint,
  "event_type" varchar(100) NOT NULL,
  "event_schema_version" varchar(40) NOT NULL,
  "payload_document" jsonb NOT NULL,
  "idempotency_key" varchar(160) UNIQUE NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "published_at" timestamptz,
  "publish_attempt_count" int NOT NULL DEFAULT 0,
  "next_attempt_at" timestamptz,
  "last_failure_code" varchar(80)
);

CREATE TABLE "operations"."projection_checkpoints" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "projection_name" varchar(100) NOT NULL,
  "target_store" varchar(40) NOT NULL,
  "shard_key" varchar(160) NOT NULL,
  "source_domain" varchar(40) NOT NULL,
  "last_source_sequence" bigint,
  "last_source_time" timestamptz,
  "projection_version" varchar(40) NOT NULL,
  "status" varchar(30) NOT NULL,
  "updated_at" timestamptz NOT NULL,
  "failure_code" varchar(80)
);

CREATE TABLE "operations"."audit_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "actor_type" varchar(30) NOT NULL,
  "actor_id" uuid NOT NULL,
  "delegated_authorization_id" uuid,
  "action_type" varchar(100) NOT NULL,
  "target_domain" varchar(40) NOT NULL,
  "target_id" uuid NOT NULL,
  "reason_code" varchar(80) NOT NULL,
  "correlation_id" uuid NOT NULL,
  "idempotency_key" varchar(160) UNIQUE NOT NULL,
  "before_hash" varchar(128),
  "after_hash" varchar(128),
  "evidence_object_id" uuid,
  "occurred_at" timestamptz NOT NULL,
  "recorded_at" timestamptz NOT NULL DEFAULT (now()),
  CONSTRAINT "audit_delegated_actor_reference_valid" CHECK ((actor_type = 'DELEGATED_AUTHORIZATION' AND delegated_authorization_id IS NOT NULL AND actor_id = delegated_authorization_id) OR (actor_type <> 'DELEGATED_AUTHORIZATION' AND delegated_authorization_id IS NULL))
);

CREATE TABLE "operations"."notification_preferences" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "bot_id" uuid,
  "event_type" varchar(80) NOT NULL,
  "channel" varchar(20) NOT NULL,
  "enabled" boolean NOT NULL,
  "updated_at" timestamptz NOT NULL
);

CREATE TABLE "operations"."notifications" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "bot_id" uuid,
  "notification_type" varchar(80) NOT NULL,
  "mandatory" boolean NOT NULL,
  "locale" varchar(5) NOT NULL,
  "template_version" varchar(40) NOT NULL,
  "payload_document" jsonb NOT NULL,
  "idempotency_key" varchar(160) UNIQUE NOT NULL,
  "created_at" timestamptz NOT NULL,
  "read_at" timestamptz,
  "expires_at" timestamptz
);

CREATE TABLE "operations"."delivery_attempts" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "notification_id" uuid NOT NULL,
  "channel" varchar(30) NOT NULL,
  "attempt_number" int NOT NULL,
  "status" operations.work_status NOT NULL,
  "attempted_at" timestamptz NOT NULL,
  "completed_at" timestamptz,
  "provider_message_key" varchar(200),
  "failure_code" varchar(80),
  "next_attempt_at" timestamptz
);

CREATE TABLE "operations"."cases" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "account_id" uuid NOT NULL,
  "case_type" varchar(60) NOT NULL,
  "status" varchar(30) NOT NULL,
  "subject" varchar(200) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "closed_at" timestamptz,
  "resolution_code" varchar(80)
);

CREATE TABLE "operations"."case_events" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "case_id" uuid NOT NULL,
  "event_sequence" int NOT NULL,
  "actor_type" varchar(30) NOT NULL,
  "actor_id" uuid NOT NULL,
  "event_type" varchar(60) NOT NULL,
  "payload_document" jsonb NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE INDEX ON "identity"."accounts" ("lifecycle_status", "created_at");

CREATE UNIQUE INDEX ON "identity"."account_lifecycle_events" ("account_id", "event_sequence");

CREATE INDEX ON "identity"."account_lifecycle_events" ("account_id", "occurred_at");

CREATE INDEX ON "identity"."account_emails" ("status", "created_at");

CREATE INDEX ON "identity"."email_verification_requests" ("account_id", "requested_at");

CREATE INDEX ON "identity"."email_verification_requests" ("expires_at", "consumed_at");

CREATE UNIQUE INDEX ON "identity"."login_identities" ("provider_id", "provider_subject_hmac");

CREATE INDEX ON "identity"."login_identities" ("account_id", "status");

CREATE UNIQUE INDEX ON "identity"."login_identities" ("account_id", "id");

CREATE INDEX ON "identity"."sessions" ("account_id", "expires_at");

CREATE INDEX ON "identity"."sessions" ("account_id", "revoked_at");

CREATE INDEX ON "identity"."password_reset_requests" ("account_id", "requested_at");

CREATE INDEX ON "identity"."password_reset_requests" ("login_identity_id", "consumed_at");

CREATE INDEX ON "identity"."password_reset_requests" ("expires_at", "consumed_at");

CREATE UNIQUE INDEX ON "identity"."authentication_events" ("account_id", "event_sequence");

CREATE UNIQUE INDEX ON "identity"."authentication_events" ("account_id", "idempotency_key");

CREATE INDEX ON "identity"."authentication_events" ("event_type", "occurred_at");

CREATE INDEX ON "identity"."authentication_events" ("correlation_id");

CREATE INDEX ON "identity"."recovery_code_sets" ("account_id", "purpose", "issued_at");

CREATE INDEX ON "identity"."recovery_codes" ("recovery_code_set_id", "used_at");

CREATE UNIQUE INDEX ON "identity"."policy_documents" ("policy_code", "version", "language_code");

CREATE INDEX ON "identity"."policy_documents" ("is_required", "published_at");

CREATE INDEX ON "identity"."account_consents" ("account_id", "policy_document_id", "recorded_at");

CREATE INDEX ON "identity"."delegated_authorizations" ("account_id", "status", "authorized_at");

CREATE INDEX ON "identity"."delegated_authorizations" ("status", "expires_at");

CREATE INDEX ON "identity"."delegated_credentials" ("authorization_id", "credential_type", "expires_at");

CREATE INDEX ON "identity"."delegated_credentials" ("expires_at", "revoked_at");

CREATE UNIQUE INDEX ON "identity"."delegated_authorization_events" ("authorization_id", "event_sequence");

CREATE UNIQUE INDEX ON "identity"."delegated_authorization_events" ("authorization_id", "idempotency_key");

CREATE INDEX ON "identity"."delegated_authorization_events" ("correlation_id");

CREATE INDEX ON "identity"."account_sanctions" ("account_id", "effective_at");

CREATE INDEX ON "identity"."account_sanctions" ("status", "expires_at");

CREATE UNIQUE INDEX ON "identity"."account_sanction_events" ("sanction_id", "event_sequence");

CREATE INDEX ON "identity"."account_sanction_events" ("occurred_at");

CREATE INDEX ON "strategy"."strategies" ("owner_account_id", "deleted_at", "archived_at", "updated_at");

CREATE INDEX ON "strategy"."strategy_documents" ("semantic_hash");

CREATE INDEX ON "strategy"."strategy_documents" ("updated_at");

CREATE INDEX ON "strategy"."strategy_edit_leases" ("expires_at");

CREATE INDEX ON "strategy"."validation_runs" ("strategy_id", "requested_at");

CREATE INDEX ON "strategy"."validation_runs" ("strategy_id", "requested_edit_sequence", "semantic_hash", "status");

CREATE INDEX ON "strategy"."validation_runs" ("delegated_authorization_id", "requested_at");

CREATE UNIQUE INDEX ON "strategy"."element_catalog_versions" ("language_version", "schema_version", "catalog_version");

CREATE UNIQUE INDEX ON "strategy"."element_definitions" ("element_catalog_version_id", "element_code");

CREATE UNIQUE INDEX ON "strategy"."package_versions" ("package_id", "version");

CREATE UNIQUE INDEX ON "strategy"."template_versions" ("template_id", "version");

CREATE UNIQUE INDEX ON "strategy"."compiled_flow_plans" ("element_catalog_version_id", "semantic_hash", "compiler_version");

CREATE INDEX ON "strategy"."compiled_flow_plans" ("required_feature_set_hash");

CREATE INDEX ON "bot"."bots" ("owner_account_id", "lifecycle_status", "created_at");

CREATE INDEX ON "bot"."bots" ("lifecycle_status", "execution_blocked_at", "created_at");

CREATE INDEX ON "bot"."bots" ("lifecycle_status", "execution_eligible_from", "created_at");

CREATE INDEX ON "bot"."bots" ("owner_account_id", "deleted_at", "archived_at", "created_at");

CREATE INDEX ON "bot"."launch_snapshots" ("semantic_hash");

CREATE INDEX ON "bot"."launch_snapshots" ("snapshot_hash");

CREATE INDEX ON "bot"."bot_partitions" ("bot_id", "position_y", "position_x", "id");

CREATE UNIQUE INDEX ON "bot"."bot_partitions" ("bot_id", "id");

CREATE INDEX ON "bot"."flows" ("partition_id", "position_y", "position_x", "id");

CREATE UNIQUE INDEX ON "bot"."flows" ("partition_id", "id");

CREATE INDEX ON "bot"."flows" ("semantic_hash");

CREATE INDEX ON "bot"."flow_feature_requirements" ("feature_definition_id", "instrument_id", "flow_id");

CREATE UNIQUE INDEX ON "bot"."bot_events" ("bot_id", "event_sequence");

CREATE UNIQUE INDEX ON "bot"."bot_events" ("bot_id", "id");

CREATE UNIQUE INDEX ON "bot"."bot_events" ("bot_id", "idempotency_key");

CREATE INDEX ON "bot"."bot_events" ("event_type", "committed_at");

CREATE INDEX ON "bot"."bot_events" ("correlation_id");

CREATE INDEX ON "bot"."flow_time_triggers" ("trigger_type", "schedule_key", "flow_id");

CREATE UNIQUE INDEX ON "bot"."evaluation_runs" ("trigger_event_id", "flow_id");

CREATE UNIQUE INDEX ON "bot"."evaluation_runs" ("bot_id", "id");

CREATE INDEX ON "bot"."evaluation_runs" ("flow_id", "queued_at");

CREATE INDEX ON "bot"."evaluation_runs" ("bot_id", "queued_at");

CREATE INDEX ON "bot"."evaluation_runs" ("status", "lease_expires_at");

CREATE INDEX ON "bot"."evaluation_runs" ("feature_snapshot_batch_id", "feature_snapshot_key");

CREATE UNIQUE INDEX ON "bot"."runtime_state_values" ("bot_id", "id");

CREATE UNIQUE INDEX ON "bot"."runtime_state_values" ("bot_id", "partition_id", "flow_id", "element_instance_key", "state_definition_key", "instrument_id");

CREATE INDEX ON "bot"."runtime_state_values" ("bot_id", "last_event_sequence");

CREATE UNIQUE INDEX ON "storage"."objects" ("storage_provider", "bucket_name", "object_key", "provider_version_id");

CREATE INDEX ON "storage"."objects" ("content_hash", "byte_size");

CREATE INDEX ON "storage"."objects" ("status", "created_at");

CREATE INDEX ON "storage"."objects" ("retention_until");

CREATE INDEX ON "market_data"."instruments" ("asset_type", "primary_exchange_mic");

CREATE UNIQUE INDEX ON "market_data"."instrument_symbols" ("exchange_mic", "symbol", "effective_from");

CREATE INDEX ON "market_data"."instrument_symbols" ("instrument_id", "effective_from");

CREATE UNIQUE INDEX ON "market_data"."trading_sessions" ("exchange_mic", "session_date", "calendar_version");

CREATE UNIQUE INDEX ON "market_data"."feeds" ("provider_id", "code", "feed_version");

CREATE UNIQUE INDEX ON "market_data"."dataset_manifests" ("feed_id", "instrument_id", "data_layer", "resolution", "period_start", "revision_number");

CREATE INDEX ON "market_data"."dataset_manifests" ("status", "period_start", "period_end");

CREATE UNIQUE INDEX ON "market_data"."dataset_manifests" ("dataset_hash");

CREATE UNIQUE INDEX ON "market_data"."dataset_objects" ("dataset_manifest_id", "object_kind", "partition_granularity", "partition_start", "partition_end", "shard_key", "part_number");

CREATE INDEX ON "market_data"."dataset_objects" ("partition_granularity", "partition_start", "partition_end");

CREATE INDEX ON "market_data"."dataset_objects" ("dataset_manifest_id", "period_start", "period_end");

CREATE INDEX ON "market_data"."dataset_object_lineage" ("source_dataset_object_id");

CREATE INDEX ON "market_data"."dataset_object_lineage" ("pipeline_run_id");

CREATE UNIQUE INDEX ON "market_data"."feature_definitions" ("element_catalog_version_id", "feature_code", "calculator_version", "resolution", "definition_hash");

CREATE UNIQUE INDEX ON "market_data"."feature_materializations" ("feature_definition_id", "instrument_id", "input_dataset_set_hash", "period_start", "period_end");

CREATE INDEX ON "market_data"."feature_materializations" ("instrument_id", "period_end", "status");

CREATE UNIQUE INDEX ON "market_data"."feature_materializations" ("output_dataset_manifest_id");

CREATE UNIQUE INDEX ON "market_data"."feature_snapshot_batches" ("feature_set_hash", "input_market_set_hash", "period_start", "period_end");

CREATE INDEX ON "market_data"."feature_snapshot_batches" ("status", "period_end");

CREATE UNIQUE INDEX ON "market_data"."corporate_actions" ("source_manifest_id", "provider_event_key");

CREATE INDEX ON "market_data"."corporate_actions" ("instrument_id", "effective_at");

CREATE INDEX ON "market_data"."quality_incidents" ("status", "severity", "detected_at");

CREATE INDEX ON "market_data"."quality_incidents" ("dataset_manifest_id", "period_start");

CREATE INDEX ON "market_data"."pipeline_runs" ("pipeline_code", "status", "started_at");

CREATE UNIQUE INDEX ON "trading"."buying_power_buffer_policy_versions" ("policy_code", "version");

CREATE INDEX ON "trading"."buying_power_buffer_policy_versions" ("policy_code", "effective_from");

CREATE UNIQUE INDEX ON "trading"."fee_policy_versions" ("policy_code", "version");

CREATE INDEX ON "trading"."fee_policy_versions" ("policy_code", "effective_from");

CREATE UNIQUE INDEX ON "trading"."short_risk_policy_versions" ("policy_code", "version");

CREATE INDEX ON "trading"."short_risk_policy_versions" ("policy_code", "effective_from");

CREATE UNIQUE INDEX ON "trading"."short_borrow_fee_policy_versions" ("policy_code", "version");

CREATE INDEX ON "trading"."short_borrow_fee_policy_versions" ("policy_code", "effective_from");

CREATE UNIQUE INDEX ON "trading"."order_intent_batches" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."order_intent_batches" ("bot_id", "partition_id", "source_event_id");

CREATE INDEX ON "trading"."order_intent_batches" ("bot_id", "partition_id", "finalized_at");

CREATE UNIQUE INDEX ON "trading"."order_intents" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."order_intents" ("batch_id", "intent_key");

CREATE INDEX ON "trading"."order_intents" ("bot_id", "partition_id", "batch_id", "instrument_id", "side");

CREATE INDEX ON "trading"."order_intents" ("partition_id", "flow_id", "instrument_id");

CREATE INDEX ON "trading"."order_intents" ("evaluation_run_id");

CREATE UNIQUE INDEX ON "trading"."orders" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."orders" ("bot_id", "partition_id", "order_key");

CREATE INDEX ON "trading"."orders" ("bot_id", "partition_id", "accepted_at");

CREATE INDEX ON "trading"."orders" ("partition_id", "instrument_id", "accepted_at");

CREATE INDEX ON "trading"."orders" ("bot_id", "partition_id", "contract_hash");

CREATE UNIQUE INDEX ON "trading"."order_groups" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."order_groups" ("bot_id", "partition_id", "group_key");

CREATE UNIQUE INDEX ON "trading"."order_group_members" ("order_group_id", "leg_sequence");

CREATE UNIQUE INDEX ON "trading"."order_group_events" ("order_group_id", "group_sequence");

CREATE UNIQUE INDEX ON "trading"."order_components" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."order_components" ("order_id", "intent_id");

CREATE UNIQUE INDEX ON "trading"."order_components" ("order_id", "component_sequence");

CREATE INDEX ON "trading"."order_components" ("intent_id");

CREATE UNIQUE INDEX ON "trading"."resource_reservations" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."resource_reservations" ("bot_id", "partition_id", "flow_id", "id");

CREATE UNIQUE INDEX ON "trading"."resource_reservations" ("intent_id", "reservation_key");

CREATE INDEX ON "trading"."resource_reservations" ("bot_id", "partition_id", "status", "created_at");

CREATE INDEX ON "trading"."resource_reservations" ("partition_id", "flow_id", "status");

CREATE INDEX ON "trading"."position_lot_reservations" ("position_lot_id");

CREATE INDEX ON "trading"."order_component_reservations" ("order_component_id");

CREATE UNIQUE INDEX ON "trading"."reservation_events" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."reservation_events" ("reservation_id", "reservation_sequence");

CREATE UNIQUE INDEX ON "trading"."reservation_events" ("reservation_id", "event_key");

CREATE INDEX ON "trading"."reservation_events" ("source_fill_id", "reservation_id");

CREATE UNIQUE INDEX ON "trading"."order_events" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."order_events" ("order_id", "order_sequence");

CREATE UNIQUE INDEX ON "trading"."order_events" ("bot_id", "partition_id", "bot_event_id");

CREATE UNIQUE INDEX ON "trading"."order_state_projections" ("bot_id", "partition_id", "order_id");

CREATE INDEX ON "trading"."order_state_projections" ("bot_id", "partition_id", "status", "updated_at");

CREATE UNIQUE INDEX ON "trading"."fills" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."fills" ("order_id");

CREATE UNIQUE INDEX ON "trading"."fills" ("bot_id", "partition_id", "provider_fill_key");

CREATE INDEX ON "trading"."fills" ("bot_id", "partition_id", "occurred_at");

CREATE INDEX ON "trading"."fills" ("partition_id", "occurred_at");

CREATE UNIQUE INDEX ON "trading"."fill_adjustments" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."fill_adjustments" ("fill_id", "adjustment_key");

CREATE UNIQUE INDEX ON "trading"."fill_adjustments" ("bot_id", "partition_id", "bot_event_id");

CREATE UNIQUE INDEX ON "trading"."ledger_accounts" ("bot_id", "id");

CREATE UNIQUE INDEX ON "trading"."ledger_accounts" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."ledger_accounts" ("bot_id", "account_key");

CREATE INDEX ON "trading"."ledger_accounts" ("bot_id", "partition_id", "flow_id", "account_type");

CREATE UNIQUE INDEX ON "trading"."ledger_transactions" ("bot_id", "id");

CREATE UNIQUE INDEX ON "trading"."ledger_transactions" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."ledger_transactions" ("bot_id", "transaction_key");

CREATE UNIQUE INDEX ON "trading"."ledger_transactions" ("bot_id", "source_type", "source_id");

CREATE INDEX ON "trading"."ledger_transactions" ("bot_id", "occurred_at");

CREATE UNIQUE INDEX ON "trading"."ledger_entries" ("transaction_id", "entry_sequence");

CREATE INDEX ON "trading"."ledger_entries" ("bot_id", "partition_id", "ledger_account_id", "transaction_id");

CREATE INDEX ON "trading"."ledger_entries" ("order_component_id", "transaction_id");

CREATE UNIQUE INDEX ON "trading"."position_lots" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."position_lots" ("bot_id", "partition_id", "flow_id", "id");

CREATE INDEX ON "trading"."position_lots" ("partition_id", "flow_id", "instrument_id", "opened_at");

CREATE INDEX ON "trading"."position_lots" ("bot_id", "partition_id", "instrument_id", "opened_at");

CREATE UNIQUE INDEX ON "trading"."lot_movements" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."lot_movements" ("position_lot_id", "id");

CREATE UNIQUE INDEX ON "trading"."lot_movements" ("position_lot_id", "bot_event_id");

CREATE INDEX ON "trading"."lot_movements" ("source_order_component_id", "position_lot_id");

CREATE INDEX ON "trading"."lot_movements" ("source_fill_adjustment_id", "position_lot_id");

CREATE UNIQUE INDEX ON "trading"."system_close_actions" ("bot_id", "source_event_id", "instrument_id", "reason_type");

CREATE INDEX ON "trading"."system_close_actions" ("flow_id", "created_at");

CREATE UNIQUE INDEX ON "trading"."short_borrow_fee_accruals" ("bot_id", "partition_id", "id");

CREATE UNIQUE INDEX ON "trading"."short_borrow_fee_accruals" ("position_lot_id", "period_start", "period_end");

CREATE INDEX ON "trading"."flow_position_projections" ("bot_id", "instrument_id");

CREATE INDEX ON "trading"."flow_position_projections" ("partition_id", "instrument_id");

CREATE UNIQUE INDEX ON "trading"."partition_position_projections" ("bot_id", "partition_id", "instrument_id");

CREATE INDEX ON "trading"."partition_position_projections" ("bot_id", "instrument_id");

CREATE UNIQUE INDEX ON "trading"."partition_budget_projections" ("bot_id", "partition_id");

CREATE INDEX ON "backtest"."runs" ("bot_id", "queued_at");

CREATE INDEX ON "backtest"."runs" ("status", "queued_at");

CREATE INDEX ON "backtest"."runs" ("owner_account_id", "queued_at");

CREATE UNIQUE INDEX ON "backtest"."run_attempts" ("run_id", "attempt_number");

CREATE UNIQUE INDEX ON "backtest"."monthly_judgment_summaries" ("run_id", "et_year_month");

CREATE UNIQUE INDEX ON "backtest"."failure_condition_counts" ("monthly_summary_id", "flow_or_branch_key", "first_failure_condition_key");

CREATE UNIQUE INDEX ON "backtest"."detail_manifests" ("run_id", "record_type", "week_start_date", "part_number");

CREATE UNIQUE INDEX ON "backtest"."detail_manifests" ("object_id");

CREATE INDEX ON "performance"."bot_current_projections" ("total_return_pct", "bot_id");

CREATE INDEX ON "performance"."bot_current_projections" ("max_drawdown_pct", "bot_id");

CREATE INDEX ON "performance"."bot_current_projections" ("sharpe_ratio", "bot_id");

CREATE UNIQUE INDEX ON "performance"."bot_snapshots" ("bot_id", "snapshot_type", "source_event_sequence");

CREATE INDEX ON "performance"."bot_snapshots" ("bot_id", "evaluated_at");

CREATE UNIQUE INDEX ON "performance"."series_manifests" ("bot_id", "series_type", "week_start_date", "part_number", "revision_number");

CREATE INDEX ON "performance"."series_manifests" ("bot_id", "series_type", "week_start_date", "part_number");

CREATE UNIQUE INDEX ON "performance"."series_manifests" ("object_id");

CREATE UNIQUE INDEX ON "performance"."series_manifests" ("supersedes_manifest_id");

CREATE UNIQUE INDEX ON "competition"."scoring_template_versions" ("template_code", "version");

CREATE INDEX ON "competition"."rooms" ("competition_type", "organizer_type", "status", "created_at");

CREATE INDEX ON "competition"."rooms" ("creator_account_id", "created_at");

CREATE UNIQUE INDEX ON "competition"."room_events" ("room_id", "event_sequence");

CREATE INDEX ON "competition"."room_invitations" ("room_id", "revoked_at", "expires_at");

CREATE INDEX ON "competition"."participations" ("room_id", "owner_account_id", "status");

CREATE UNIQUE INDEX ON "competition"."participations" ("room_id", "anonymous_alias");

CREATE INDEX ON "competition"."participations" ("room_id", "status");

CREATE UNIQUE INDEX ON "competition"."participation_events" ("participation_id", "event_sequence");

CREATE UNIQUE INDEX ON "competition"."backtest_evaluation_periods" ("evaluation_plan_room_id", "period_sequence");

CREATE UNIQUE INDEX ON "competition"."backtest_evaluation_periods" ("evaluation_plan_room_id", "evaluation_start", "evaluation_end");

CREATE UNIQUE INDEX ON "competition"."backtest_period_runs" ("run_id");

CREATE INDEX ON "competition"."backtest_aggregate_results" ("evaluation_plan_room_id", "published_at");

CREATE UNIQUE INDEX ON "competition"."live_evaluation_segments" ("participation_id", "starts_at");

CREATE UNIQUE INDEX ON "competition"."leaderboard_snapshots" ("room_id", "cutoff_at");

CREATE INDEX ON "competition"."leaderboard_entries" ("snapshot_id", "rank");

CREATE UNIQUE INDEX ON "operations"."operator_role_assignments" ("operator_account_id", "role_id", "granted_at");

CREATE INDEX ON "operations"."operator_role_assignments" ("expires_at");

CREATE INDEX ON "operations"."outbox_messages" ("published_at", "next_attempt_at");

CREATE INDEX ON "operations"."outbox_messages" ("owner_domain", "aggregate_id", "aggregate_sequence");

CREATE UNIQUE INDEX ON "operations"."projection_checkpoints" ("projection_name", "target_store", "shard_key");

CREATE INDEX ON "operations"."projection_checkpoints" ("status", "updated_at");

CREATE INDEX ON "operations"."audit_events" ("target_domain", "target_id", "occurred_at");

CREATE INDEX ON "operations"."audit_events" ("actor_type", "actor_id", "occurred_at");

CREATE INDEX ON "operations"."audit_events" ("delegated_authorization_id", "occurred_at");

CREATE INDEX ON "operations"."audit_events" ("correlation_id");

CREATE UNIQUE INDEX ON "operations"."notification_preferences" ("account_id", "bot_id", "event_type", "channel");

CREATE INDEX ON "operations"."notifications" ("account_id", "read_at", "created_at");

CREATE UNIQUE INDEX ON "operations"."delivery_attempts" ("notification_id", "channel", "attempt_number");

CREATE INDEX ON "operations"."delivery_attempts" ("status", "next_attempt_at");

CREATE INDEX ON "operations"."cases" ("account_id", "status", "created_at");

CREATE UNIQUE INDEX ON "operations"."case_events" ("case_id", "event_sequence");

COMMENT ON TABLE "identity"."accounts" IS '최소 계정 루트. 환경설정·이메일·인증·동의·제재는 별도 집합체. 계정 생성은 이메일·환경설정을 같은 트랜잭션으로 삽입하고, 활성화에는 단일 이메일의 VERIFIED가 필요. 제재를 lifecycle_status에 겹쳐 싣지 않는다.';

COMMENT ON TABLE "identity"."account_security_states" IS '계정당 정확히 하나인 인증 보안 현재 상태. 비밀번호 변경, 로그인 수단 교체, 계정 복구 또는 전체 로그아웃 시 auth_epoch를 증가시켜 이전 세션과 캐시를 일괄 무효화한다.';

COMMENT ON TABLE "identity"."account_lifecycle_events" IS '추가 전용 생명주기 증적. accounts.lifecycle_status는 트랜잭션으로 유지되는 현재 Projection.';

COMMENT ON TABLE "identity"."account_preferences" IS '계정과 원자적으로 생성. 알림 수신 설정은 operations.notification_preferences, 마케팅 법적 동의는 account_consents에 유지.';

COMMENT ON COLUMN "identity"."account_preferences"."language_code" IS '현재 지원 값은 ko와 en.';

COMMENT ON COLUMN "identity"."account_preferences"."timezone_name" IS '표시 전용 IANA 시간대 이름. 시장 계산은 거래소 캘린더 사용.';

COMMENT ON TABLE "identity"."account_emails" IS '공유 PK로 계정당 이메일 최대 1행. 지연 생명주기 가드가 활성화 가능한 계정에 이 행 소유와 활성화 전 VERIFIED를 요구. 애플리케이션은 정규화 후 키 기반 조회하고 평문 인덱스를 두지 않으며, 회수된 이메일의 재사용 허용 여부를 정의해야 한다.';

COMMENT ON TABLE "identity"."email_verification_requests" IS '추가 전용 인증 시도. 새 요청 발급이 이전 활성 요청을 회수할 수 있으며, 검증과 소진은 원자적.';

COMMENT ON TABLE "identity"."auth_providers" IS '시드되는 인증 제공자 카탈로그. PASSWORD는 issuer가 없고, OIDC는 정확한 issuer와 불변 subject 검증을 요구.';

COMMENT ON TABLE "identity"."login_identities" IS '계정에는 로그인 가능한 ACTIVE 행을 최대 1개만 허용하며 PostgreSQL 마이그레이션에서 WHERE status = ACTIVE partial unique index로 강제한다. PENDING도 계정당 최대 1개로 제한한다. PENDING은 아직 연결된 로그인 수단이 아니고, 과거 REPLACED/DISABLED 행은 발급 세션과 보안 감사를 위해 보존한다. PASSWORD는 provider subject와 subject_key_version이 null이어야 하고 OIDC는 둘 다 필요하다. 제공자 이메일로 계정을 자동 연결하지 않는다. 로그인 수단 교체는 기존 ACTIVE를 REPLACED로, 검증된 PENDING을 ACTIVE로 바꾸고 auth_epoch 증가와 기존 세션·재설정 요청 회수를 같은 트랜잭션에서 수행한다.';

COMMENT ON TABLE "identity"."password_credentials" IS '오직 PASSWORD 로그인 ID에만 허용. 비밀번호 변경은 credential_version을 증가시키고 같은 워크플로에서 관련 세션을 회수.';

COMMENT ON TABLE "identity"."sessions" IS '서버 소유 불투명 세션. 발급 당시 로그인 ID와 auth_epoch를 고정하며 PASSWORD 세션은 credential_version도 고정한다. 현재 계정 보안 상태와 값이 다르면 세션은 무효다. 발급·회수는 PostgreSQL 소유이고 캐시는 조회만 가속하며 회수된 세션을 인가할 수 없다.';

COMMENT ON TABLE "identity"."password_reset_requests" IS '계정 이메일이 하나이므로 요청은 발급 당시 ACTIVE PASSWORD 로그인 ID, auth_epoch, credential_version에 바인딩한다. 어느 값이든 바뀌면 이전 요청은 무효다. 토큰 검증, 비밀번호 교체, credential_version·auth_epoch 증가, 요청 소진, 기존 세션과 다른 활성 요청 회수는 원자적이다.';

COMMENT ON TABLE "identity"."authentication_events" IS '계정 인증 보안의 추가 전용 감사 스트림. 로그인 수단 전환 시 이전·새 ID를 함께 기록하며 모든 참조 로그인 ID가 같은 account_id에 속하는지는 지연 제약으로 검증한다. 비밀번호·토큰·복구 코드·OIDC 원문 subject는 기록하지 않는다.';

COMMENT ON COLUMN "identity"."authentication_events"."event_type" IS 'LOGIN_IDENTITY_CREATED, VERIFIED, ACTIVATED, REPLACED, DISABLED, PASSWORD_CHANGED, SESSIONS_REVOKED 등.';

COMMENT ON COLUMN "identity"."authentication_events"."actor_type" IS 'ACCOUNT, OPERATOR 또는 SYSTEM.';

COMMENT ON TABLE "identity"."recovery_code_sets" IS '계정·용도별 활성 세트는 1개만 허용(마이그레이션의 partial unique index).';

COMMENT ON COLUMN "identity"."recovery_code_sets"."purpose" IS '현재 제품에서는 ACCOUNT_RECOVERY.';

COMMENT ON TABLE "identity"."recovery_codes" IS '복구 코드 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "identity"."policy_documents" IS '정책 본문은 작은 불변 관계형 콘텐츠. 대용량 증적 첨부가 도입되면 이 정본 텍스트를 대체하지 않고 storage.objects를 사용.';

COMMENT ON TABLE "identity"."account_consents" IS '추가 전용 동의 결정 이력. 철회·재동의는 기존 법적 증적을 수정하지 않고 새 행을 생성.';

COMMENT ON TABLE "identity"."delegated_authorizations" IS 'User-approved external AI/tool delegation. The delegate is never the account owner or final approver. A mismatched account auth epoch, sanction, expiry, or revocation blocks every new call without affecting committed server work or running bots.';

COMMENT ON TABLE "identity"."delegated_authorization_scopes" IS 'Immutable after authorization activation. Release, bot lifecycle, room final actions, continuation renewal, and order mutation scopes intentionally do not exist; changing permissions requires a new explicit user grant.';

COMMENT ON TABLE "identity"."delegated_credentials" IS 'Opaque CLI/MCP credential metadata. Only a keyed digest is stored. A credential can exercise only the current scopes of its active authorization and can never elevate itself.';

COMMENT ON TABLE "identity"."delegated_authorization_events" IS 'Append-only delegation lifecycle evidence. Payloads may identify policy and scopes but never contain tokens, private strategy source, holdings, or result data.';

COMMENT ON COLUMN "identity"."delegated_authorization_events"."event_type" IS 'AUTHORIZED, CREDENTIAL_ISSUED, CREDENTIAL_REVOKED, EXPIRED, or REVOKED.';

COMMENT ON COLUMN "identity"."delegated_authorization_events"."actor_type" IS 'ACCOUNT or SYSTEM.';

COMMENT ON TABLE "identity"."account_sanctions" IS '현재 제재 집합체. status는 불변 제재 이벤트의 트랜잭션 유지 Projection.';

COMMENT ON COLUMN "identity"."account_sanctions"."sanction_type" IS '값은 SUSPENSION 또는 PERMANENT.';

COMMENT ON TABLE "identity"."account_sanction_events" IS '추가 전용 공식 제재 이력. actor null은 시스템 생성 만료 이벤트에서만 허용.';

COMMENT ON COLUMN "identity"."account_sanction_events"."event_type" IS '값은 APPLIED, LIFTED, EXPIRED.';

COMMENT ON TABLE "strategy"."strategies" IS '사용자가 계속 수정할 수 있는 Strategy 설계 원본의 식별·표시·수명주기 메타데이터. 실행 Bot을 소유하거나 연결하지 않는다. 출시 시 strategy_documents의 검증된 당시 상태를 독립 Bot 스냅샷으로 복사하며 Bot에는 원본 Strategy 식별자·출처·계보를 남기지 않는다. 이후 Strategy 수정은 기존 Bot에 전파되지 않는다.';

COMMENT ON TABLE "strategy"."strategy_documents" IS 'Strategy 편집기의 현재 문서 1개를 저장하는 1:1 집합체. 버전 계보가 아니라 낙관적 동시성으로 갱신되는 현재 설계다. 출시 서비스는 완전성·포트 타입·DAG·예산 합·필수 주문 경로를 검증한 동일 트랜잭션에서 독립 bot.bots, bot.launch_snapshots, bot.launch_configurations, bot.bot_partitions, bot.flows 및 파생 의존성 행을 생성한다. 생성 후 Strategy와 Bot 사이에는 어떤 참조도 없다.';

COMMENT ON COLUMN "strategy"."strategy_documents"."semantic_document" IS '파티션 예산 상한, Flow, Element, edge, 매개변수, 선택 종목을 포함하는 수정 가능한 Strategy 설계 의미. 편집 중에는 미완성 구조를 허용하되 schema에 맞게 파싱 가능해야 한다.';

COMMENT ON COLUMN "strategy"."strategy_documents"."presentation_document" IS '파티션·Flow·Element 좌표, 크기, edge route, viewport 같은 UI 배치 정보. semantic_document와 동일한 안정 키를 참조한다.';

COMMENT ON TABLE "strategy"."strategy_edit_leases" IS 'Allows exactly one active editor across the web, direct user CLI, and delegated external AI. Revoked or expired credentials invalidate the lease, and a stale edit_sequence or lease token rejects late saves.';

COMMENT ON TABLE "strategy"."validation_runs" IS 'Deterministic validation of one exact mutable Strategy document state. delegated_authorization_id identifies an external AI request; null means the account acted directly. Validation never releases a Strategy, launches a Bot, or starts a backtest.';

COMMENT ON COLUMN "strategy"."validation_runs"."status" IS 'RUNNING, VALID, INVALID, or FAILED.';

COMMENT ON TABLE "strategy"."element_catalog_versions" IS 'Flow를 구성할 수 있는 Element 정의 집합의 불변 카탈로그 버전. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "strategy"."element_definitions" IS 'PRICE_DATA, RSI, CONDITION, ORDER, RISK_POLICY처럼 Flow에 배치할 수 있는 Element의 타입·포트·매개변수·실행 계약을 정의한다. 사용자 Flow 안의 Element 인스턴스와 분리된 플랫폼 정의다.';

COMMENT ON TABLE "strategy"."packages" IS 'Basic 사용자에게 플랫폼이 완성된 형태로 제공하는 Flow Package의 식별자. 사용 시 독립 Flow로 복사되며 원본 Package FK를 남기지 않는다.';

COMMENT ON TABLE "strategy"."package_versions" IS 'Basic Package의 불변 완성 Flow 문서 버전. Package를 선택하면 flow_document를 수정 가능한 strategy.strategy_documents 안의 새 독립 Flow로 복사하고 Package 출처나 계보 연결은 저장하지 않는다.';

COMMENT ON TABLE "strategy"."templates" IS 'Pro 사용자에게 Pair Trading 같은 시작 구조로 제공하는 Flow Template의 식별자. 사용 후 만들어진 Flow는 Template과 연결되지 않는 독립 객체다.';

COMMENT ON TABLE "strategy"."template_versions" IS 'Pro Template의 불변 시작 골격 버전. 사용하면 수정 가능한 strategy.strategy_documents 안의 새 독립 Flow 골격으로 복사되며 Template 버전이나 복사 출처를 참조하지 않는다. 이후 사용자가 완성한 Strategy를 출시해야 독립 Bot 스냅샷이 생성된다.';

COMMENT ON TABLE "strategy"."compiled_flow_plans" IS '의미상 동일한 Flow들이 공유하는 content-addressing 서버 실행 계획. 재사용 사용자 Flow·버전 계보·복사 관계가 아닌 인프라 캐시. 컴파일러는 타입이 지정된 Element를 검증해 봇별 최소 명령만 산출하고, 공통 시장 계산은 required_feature_set_hash로 표현되어 봇 Worker 밖에서 실행된다.';

COMMENT ON TABLE "bot"."bots" IS '검증된 Strategy 당시 상태를 복사해 생성한 완전 독립 실행 Bot. 원본 Strategy 식별자·출처·계보·버전 관계를 저장하지 않아 어느 Strategy에서 출시됐는지 조회할 수 없다. 출시된 실행 의미와 mode는 불변이고 Bot 이름, 파티션·Flow 설명과 좌표 및 Flow 내부 layout 같은 presentation만 수정 가능하다. RUNNING이어도 now()가 execution_eligible_from보다 이르면 평가하지 않으며 별도 waiting·scheduled 상태는 만들지 않는다. 개인 Bot은 즉시, 평가 전에 생성된 대회 Bot은 대회 평가 시작부터 실행 가능하고, 이미 진행 중인 공식 BACKTEST 대회 Bot은 입력 잠금 완료 뒤 Competition 백테스트 실행기로만 보낸다. Competition 관계가 BACKTEST인 Bot은 라이브 Trigger Router가 절대 평가하지 않는다. started_at은 실제 첫 실행이 시작될 때만 설정한다. STOPPING은 신규 평가·신규 주문 등록만 막고 기존 미체결 주문을 취소하지 않은 채 결과·예약 해제·정산을 마무리하며 STOPPED는 영구다. 파티션 1개 이상과 각 파티션의 완성 Flow 1개 이상을 검증한 뒤 Bot 스냅샷 계층을 원자적으로 생성한다. archived_at은 STOPPED Bot의 가역 숨김이고 deleted_at은 정산 완료 뒤의 논리 삭제다.';

COMMENT ON COLUMN "bot"."bots"."execution_blocked_at" IS 'nullable 실행 차단 Projection. NULL이면 정상. 이 봇에만 국한된 손상(런타임 상태 손상, 이벤트 시퀀스 갭, 예약·원장 불일치, 정산 실패, 복구 불가 Element 평가 오류)에서만 설정.';

COMMENT ON TABLE "bot"."launch_snapshots" IS 'Bot 출시 당시 상태의 불변 1:1 증적. 정규화된 bot_partitions·flows·의존성·launch_configurations와 같은 트랜잭션에서 생성하며 snapshot_hash는 의미 스냅샷과 launch configuration을 함께 바인딩한다. 동일 Strategy에서 여러 번 출시해도 각 Bot은 독립 스냅샷만 가지며 원본 Strategy를 역추적할 수 없다. 현재 좌표·레이아웃 수정은 presentation_snapshot을 덮어쓰지 않는다.';

COMMENT ON COLUMN "bot"."launch_snapshots"."semantic_snapshot" IS '출시 시점의 mode, 파티션 예산 상한, Flow, Element, edge, 매개변수, 선택 종목 및 실행 규칙을 포함한다. Strategy 식별자나 출처 정보는 포함할 수 없다.';

COMMENT ON COLUMN "bot"."launch_snapshots"."presentation_snapshot" IS '출시 시점의 이름·설명·파티션·Flow·Element 배치를 보존한다. 출시 후 현재 presentation은 수정될 수 있지만 이 증적은 불변이다.';

COMMENT ON TABLE "bot"."launch_configurations" IS 'bot.launch_snapshots·파티션·완성 Flow와 원자적으로 삽입. 초기 가상 자본은 양수 USD, 봇별 격리이며 입금·출금·증액 불가. 사용자 정의 위험 통제는 Flow의 RISK_POLICY Element에만 존재. 실행 설정은 생성 시점부터 불변이며 의미 변경·삭제는 항상 거부.';

COMMENT ON COLUMN "bot"."launch_configurations"."slippage_rate_bps" IS '고정 5 bps. 매수는 +, 매도는 -.';

COMMENT ON TABLE "bot"."bot_partitions" IS '완성된 파티션은 최대 100%의 불변 양수 예산 상한과 1개 이상의 Flow를 소유하며, 형제 상한 합은 지연 집계 제약으로 100% 이하 검증. 종목이나 별도 위험 정책 문서는 소유하지 않는다. 파티션이 최하위 예산 경계라 자식 Flow들은 이 상한을 공유하고 개별 할당은 없다. 위험 통제는 각 Flow semantic_document의 RISK_POLICY Element. 형제 파티션 간 차입 금지. name, description, position_x, position_y는 configuration_hash에서 제외되는 편집 필드이고 좌표 겹침 허용, id는 결정적 조회 타이브레이커. edit_sequence는 0에서 시작해 편집 필드 갱신 성공마다 정확히 1 증가(낙관적 동시성), updated_at은 그 커밋 시각. (bot_id, id)는 복합 PK나 버전이 아닌 대체 소유 키. 복사/붙여넣기는 원본 참조 없는 독립 새 행과 자식을 생성.';

COMMENT ON COLUMN "bot"."bot_partitions"."budget_cap_bps" IS '봇 초기 자본의 0..10000 bps. 형제 합은 10000 이하.';

COMMENT ON TABLE "bot"."flows" IS 'Flow는 정확히 하나의 파티션이 소유하는 완결 Element 그래프이며 재사용 라이브러리 항목이나 버전 엔티티가 아니다. BASIC/PRO 모드는 봇에서 상속. 예산 할당 경계는 파티션뿐이고 런타임 행의 flow_id는 귀속 기록용. 매수·매도 Element의 주문 규모 단위는 퍼센트이며 semantic_document에 orderSizePercent(0 초과 100 이하)와 minReactivationIntervalSeconds(0 이상)를 고정한다. 매수는 실행 시점 Partition 가용 현금, 매도는 해당 Flow의 예약되지 않은 매도 가능 수량에 퍼센트를 적용한다. name, description, position_x, position_y, layout_document와 layout_schema_version은 semantic_hash·configuration_hash에서 제외되는 편집 필드, 좌표 겹침 허용, id는 결정적 조회 타이브레이커. edit_sequence는 0에서 시작해 이름·설명·좌표·레이아웃 같은 편집 필드 갱신 성공마다 정확히 1 증가, updated_at은 그 커밋 시각. Element·포트·안정 키를 가진 엣지·매개변수·의미 그룹·RISK_POLICY Element는 semantic_document 하나의 불변 실행 의미 JSONB 집합체다. layout_document는 같은 안정 Element·엣지 키를 참조하는 UI 전용 JSONB이며 layout_schema_version으로 해석 규칙을 선택하고 layout_hash로 무결성을 확인한다. 레이아웃 변경은 실행 계획, 의미 검증, 백테스트 또는 configuration_hash를 변경하지 않는다. configuration_hash는 Element 카탈로그 버전과 semantic_hash만 바인딩. (partition_id, id)는 복합 런타임 FK용 대체 소유 키. 복사/붙여넣기는 원본 참조 없는 독립 새 행 생성.';

COMMENT ON COLUMN "bot"."flows"."layout_document" IS '요소별 좌표·크기, 그룹 배치·접힘, 선택 상태, edge routing hint, viewport와 zoom을 저장하는 UI 전용 문서. 요소 키와 엣지 키는 semantic_document의 안정 식별자를 참조해야 한다.';

COMMENT ON TABLE "bot"."flow_instruments" IS '완성된 Flow semantic_document가 요구하는 명시적 종목의 불변 집합. 종목의 매매/참조 역할은 그 문서의 타입 Element과 엣지로 한 번 정의되며 여기에 가변 역할로 중복 저장하지 않는다. Flow와 원자적으로 삽입. 시작 검증은 종목 1개 이상과 추출된 의존성-행의 정확한 일치를 요구. 향후 유니버스 선택은 현재 범위 밖이며 제품 지원 시 별도 검토된 모델·마이그레이션으로 도입해야 한다.';

COMMENT ON TABLE "bot"."flow_feature_requirements" IS '완성 시 Flow semantic_document에서 추출한 불변 의존성 집합. 사용자 작성 상태가 아니며 예산도 부여하지 않는다. 역방향 인덱스로 서버가 동일 피처·종목 기준으로 활성 Flow을 묶어 공통 계산을 한 번 수행하고 여러 봇 평가로 팬아웃.';

COMMENT ON TABLE "bot"."bot_events" IS '봇별 추가 전용 순서 보장 공식 스트림이자 라우팅된 트리거 이벤트의 유일한 봇별 구체화. Trigger Router가 전역 이벤트 식별자를 담은 결정적 idempotency_key(예: PRICE:AAPL:bar-close-timestamp, SCHEDULE:ONE_MINUTE:minute)로 라우팅 이벤트당 1행을 적재하므로 (bot_id, idempotency_key)가 별도 전역 트리거 테이블 없이 at-least-once 재전달을 흡수. event_sequence는 런타임 감사 순서이지 봇 버전이 아니며 갭 허용. 실행 차단 생명주기는 문서화된 이벤트 타입 BOT_EXECUTION_BLOCKED, BOT_EXECUTION_UNBLOCKED, SETTLEMENT_FAILED, LEDGER_INVARIANT_VIOLATED, STATE_REBUILD_COMPLETED 사용. 의사결정에 쓴 정확한 시장 관측치는 값/버전/해시로 고정.';

COMMENT ON TABLE "bot"."flow_time_triggers" IS '완성된 Flow semantic_document에서 서버가 추출한 시간·세션 트리거 의존성 Projection. 사용자 작성이 아니고 제2의 정본도 아니다. 종목·피처 트리거 의존성은 flow_instruments와 flow_feature_requirements에 유지(중복 테이블 없음). 역방향 인덱스가 Trigger Router 조회에 답한다: MARKET_OPEN이나 ONE_MINUTE 이벤트는 구독한 Flow만 찾아 RUNNING 비차단 봇과 조인하며, 시장 전체 이벤트가 전체 봇을 스캔하지 않는다.';

COMMENT ON COLUMN "bot"."flow_time_triggers"."schedule_key" IS '값은 SCHEDULE이면 ONE_MINUTE 같은 Interval 키, 세션 트리거면 고정값 NONE.';

COMMENT ON TABLE "bot"."evaluation_runs" IS '트리거 이벤트당 Flow당 1행: 평가 큐, 사용자 노출 판단 로그, idempotency의 단위. 유일한 (trigger_event_id, flow_id) 쌍이 상류 bot_events와 하류 파티션별 order_intent_batches를 이어 at-least-once 재전달을 안전하게 만든다. 같은 파티션 Flow 평가는 병렬 가능하지만 예산·보유수량·충돌·상계 적용은 (bot_id, partition_id) advisory transaction lock과 파티션 Projection 행 잠금 아래 직렬화한다. 시장 데이터 평가는 불변 공유 피처 스냅샷을 고정하고 공통 지표를 봇별 재계산하지 않는다.';

COMMENT ON COLUMN "bot"."evaluation_runs"."lease_expires_at" IS 'at-least-once 인계용 워커 lease. 만료되면 다른 공용 워커가 이어서 수행.';

COMMENT ON COLUMN "bot"."evaluation_runs"."input_market_hash" IS '스냅샷이 고정된 경우 참조한 공유 피처 스냅샷 입력 해시와 같아야 한다.';

COMMENT ON TABLE "bot"."runtime_state_values" IS '평가 간 유지가 필요한 공식 봇 전용 Flow 상태만 PostgreSQL이 소유. 주문 Element의 LAST_SUCCESSFUL_FILL_AT 상태는 마지막 정상 전량 Fill 시각을 저장하며, 현재 시각이 이 값과 minReactivationIntervalSeconds를 지난 경우에만 같은 Element가 새 Intent를 만들 수 있다. 거절·만료와 미체결 Order 생성은 이 값을 갱신하지 않는다. 명시적 봇/파티션/Flow 소유가 봇 간 누출을 방지하고, instrument_id는 Flow 전역 상태에서만 null. 공유 가격·캔들·지표·캘린더·피처 값은 여기 금지이며 market_data 공유 계산이나 일회성 캐시 소관. instrument_id의 null-safe 유일성은 마이그레이션에서 강제.';

COMMENT ON TABLE "bot"."runtime_state_changes" IS '봇 전용 상태 변경의 추가 전용 before/after 증적. bot_id가 두 복합 참조에 모두 포함되어 이벤트가 다른 봇 소유 상태 행을 변경할 수 없다.';

COMMENT ON COLUMN "bot"."runtime_state_changes"."previous_value_hash" IS '상태 키 최초 생성 시에만 null.';

COMMENT ON TABLE "storage"."objects" IS '크기·해시·스키마·Parquet footer·코덱 검증 후에만 AVAILABLE. 새 리비전은 정본 오브젝트 버전을 덮어쓰지 않으며, 삭제는 보존기간 경과와 legal hold 부재를 요구.';

COMMENT ON COLUMN "storage"."objects"."file_format" IS '이 초안에서 대용량 표 데이터는 PARQUET.';

COMMENT ON COLUMN "storage"."objects"."compression_codec" IS '현재 Parquet 오브젝트는 명시적 UNCOMPRESSED.';

COMMENT ON TABLE "market_data"."instruments" IS '종목 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "market_data"."instrument_symbols" IS '마이그레이션은 심볼 유효기간 겹침을 방지해야 한다.';

COMMENT ON TABLE "market_data"."trading_sessions" IS '캘린더 버전이 백테스트, 실시간 평가, ET 마감 스냅샷, 주간 오브젝트 검증에 쓰는 세션 경계를 고정.';

COMMENT ON COLUMN "market_data"."trading_sessions"."session_type" IS '값은 REGULAR, EARLY_CLOSE, CLOSED.';

COMMENT ON TABLE "market_data"."providers" IS '시장 데이터 제공자 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON COLUMN "market_data"."providers"."rights_version" IS '정확한 제공자와 라이선스 권리는 외부 승인 증적 필요.';

COMMENT ON TABLE "market_data"."feeds" IS '시장 데이터 피드 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "market_data"."dataset_manifests" IS '다중 종목 데이터셋의 null-safe 유일성은 마이그레이션에서 강제해야 한다.';

COMMENT ON COLUMN "market_data"."dataset_manifests"."data_layer" IS '값은 RAW, NORMALIZED, ADJUSTED, DERIVED.';

COMMENT ON TABLE "market_data"."dataset_objects" IS '오브젝트는 ET 기준 일·주·월·연 파티션을 지원한다. 주 경계는 월요일, 월 경계는 매월 1일, 연 경계는 1월 1일이며 partition_end는 미포함이다. 마이크로배치나 작은 파티션을 더 큰 파티션으로 컴팩션할 때 원본을 덮어쓰지 않고 새 오브젝트·새 데이터셋 리비전·명시적 오브젝트 계보를 만든다. 하나의 공개 Manifest는 같은 shard와 시간 범위에 겹치는 표현을 동시에 포함하지 않는다.';

COMMENT ON COLUMN "market_data"."dataset_objects"."partition_start" IS 'ET 달력 기준 포함 시작일.';

COMMENT ON COLUMN "market_data"."dataset_objects"."partition_end" IS 'ET 달력 기준 미포함 종료일.';

COMMENT ON TABLE "market_data"."dataset_lineage" IS '데이터셋 계보 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "market_data"."dataset_object_lineage" IS '일·주·월 파티션에서 주·월·연 파티션을 생성한 정확한 파일 단위 계보를 보존한다. 컴팩션 결과는 불변 새 오브젝트이며 이미 잠긴 백테스트 Manifest의 기존 오브젝트 선택을 바꾸지 않는다.';

COMMENT ON COLUMN "market_data"."dataset_object_lineage"."relation_type" IS '컴팩션은 COMPACTED_FROM.';

COMMENT ON TABLE "market_data"."feature_definitions" IS '봇과 무관한 결정적 시장 계산(예: SMA(20))의 불변 정본 정의. definition_hash는 계산기 코드 버전, 정규화 매개변수, resolution, 출력 타입, 히스토리 요구량, 캘린더·정밀도 의미를 포함. 사용자 예산·포지션·런타임 상태·비공개 전략 식별자는 이 해시와 공유 계산 경계에 절대 들어가지 않는다.';

COMMENT ON TABLE "market_data"."feature_materializations" IS '정본 정의·종목·정확한 입력 집합·기간당 과거 공유 계산 결과 1건. 대용량 시계열 값은 S3 호환 스토리지의 DERIVED 데이터셋 오브젝트에 남고, PostgreSQL은 식별자·상태·해시·watermark·출력 매니페스트만 저장. 유일 계산 키와 파이프라인 idempotency가 중복 서버 작업을 방지.';

COMMENT ON TABLE "market_data"."feature_snapshot_batches" IS '한 번 계산되어 대상 봇 전체로 팬아웃되는 공유 실시간 피처 스냅샷 불변 마이크로배치의 메타데이터. 스냅샷 본문은 스트림/캐시에 버퍼링 후 하나의 오브젝트로 봉인해 틱당 PostgreSQL 행이나 S3 오브젝트 생성을 피한다. 본문 각 행은 배치 로컬 스냅샷 키와 해시를 가지며 평가는 그 키와 정확한 해시를 저장. SUCCEEDED는 오브젝트, batch_hash, row_count, available_at을 요구. 캐시 만료가 정본 증적을 지우지 않는다.';

COMMENT ON TABLE "market_data"."corporate_actions" IS '기업행사 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "market_data"."quality_incidents" IS '데이터 품질 인시던트 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "market_data"."pipeline_runs" IS '파이프라인 실행 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "market_data"."stream_watermarks" IS '재구축 가능한 시장 데이터 신선도 Projection(market_data 소유, 실시간 피드당 1행). 평가 전 실행 게이트가 quality_incidents와 함께 읽어 시장 데이터 평가 진행 여부를 결정. 전역 지연·장애는 여기와 operations 관측성에만 존재하며 봇 행을 대량 갱신하지 않는다. 컨슈머 lag, 유실 이벤트, outbox 적체는 같은 파이프라인 범위 문제이고 봇은 자신의 execution_blocked_at만 가진다.';

COMMENT ON TABLE "trading"."buying_power_buffer_policy_versions" IS '플랫폼 관리 불변 정책. 정확한 buffer_bps는 운영 전 근거 필요.';

COMMENT ON TABLE "trading"."fee_policy_versions" IS '모든 롱·숏 매수·매도의 정상 전량 Fill에 동일하게 한 번 적용하는 불변 플랫폼 정책. 사용자가 변경할 수 없고 과거 체결은 당시 policy id를 고정한다.';

COMMENT ON COLUMN "trading"."fee_policy_versions"."fee_rate_bps" IS '공식 통합 가상 거래 수수료 0.2% = 20 bps.';

COMMENT ON TABLE "trading"."short_risk_policy_versions" IS '가상 SHORT 포지션의 최초·유지 담보, 최대 노출·손실, Regulation SHO Rule 201 가격 제한과 시스템 청산 기준을 고정하는 불변 플랫폼 버전. 실제 주식 차입, 대여 가능 수량과 대여기관 회수는 모델링하지 않는다. 미결정 수치는 rules_document의 승인된 새 버전으로만 도입한다.';

COMMENT ON TABLE "trading"."short_borrow_fee_policy_versions" IS '실제 대차시장의 변동 금리가 아니라 플랫폼이 모든 가상 SHORT lot에 일관되게 적용하는 고정 연간 보유 비용 정책. 정확한 bps는 승인된 정책 버전으로만 도입하고 과거 비용 계산은 당시 policy id를 고정한다.';

COMMENT ON COLUMN "trading"."short_borrow_fee_policy_versions"."day_count_basis" IS 'ACT_365 등 승인된 연환산 기준.';

COMMENT ON TABLE "trading"."order_intent_batches" IS '한 Bot Event에서 정확히 한 파티션의 Flow 의도만 수집하는 거래 격리 경계. 충돌 처리·상계·통합과 자원 잠금은 (bot_id, partition_id) 안에서만 수행한다. 복합 멱등 키가 같은 이벤트의 파티션별 at-least-once 재전달을 안전하게 흡수한다.';

COMMENT ON TABLE "trading"."order_intents" IS 'Flow 또는 시스템 안전 절차가 만든 원래 의도와 승인·파티션 내부 상계·최종 잔여 결과의 불변 기록. Flow 주문 Element는 최소 재활성화 기간 경과와 동일 Element·종목의 OPEN Order/ACTIVE Reservation 부재를 먼저 검사한다. 매수 requested_notional은 실행 시점 Partition 가용 현금에 orderSizePercent를 적용한 상한이고, 매도 requested_quantity는 해당 Flow의 예약되지 않은 매도 가능 소수점 수량에 같은 퍼센트를 적용한 결과다. 같은 (bot_id, partition_id, batch_id)의 호환 가능한 종목·방향·주문 계약만 하나의 Order로 결합하며 다른 파티션이나 사용자와 절대 통합하지 않는다.';

COMMENT ON COLUMN "trading"."order_intents"."evaluation_run_id" IS 'FLOW_EVALUATION에서만 필수. 시스템 강제 청산·강제 바이인은 평가 실행 없이 공식 사건에서 생성한다.';

COMMENT ON COLUMN "trading"."order_intents"."post_netting_quantity" IS '상계로 제거된 양이 아니라 상계 후 실제 주문 대상으로 남은 수량.';

COMMENT ON TABLE "trading"."orders" IS '파티션 내부 상계 후 제출되는 불변 파티션 전용 가상 주문 계약. 요청 수량은 접수 뒤 변경하지 않는다. CANCELLED는 사용자·봇 중지·운영자 조작으로 만들 수 없고, 이미 OPEN인 주문에 자동 replacement 정책을 적용할 때 원본을 철회하는 시스템 전이로만 사용한다. 더 작은 소수점 수량이 필요하면 원본 예약을 전액 해제하고 같은 파티션의 새 order component·reservation을 가진 replacement Order를 만든다. 현재 상태는 추가 전용 order_events와 projection에서만 얻는다.';

COMMENT ON TABLE "trading"."order_groups" IS 'OCO·브래킷·Pro 연계 주문의 관계만 표현하는 파티션 전용 그룹. 다른 파티션 주문은 멤버가 될 수 없고 전량 체결 또는 미체결 결과만 처리한다.';

COMMENT ON TABLE "trading"."order_group_members" IS 'OCO·브래킷·멀티레그에서 각 주문의 역할, 순서, 활성화와 상호 취소 조건을 고정한다. 주문 하나는 동시에 둘 이상의 그룹에 속하지 않는다.';

COMMENT ON TABLE "trading"."order_group_events" IS '그룹의 활성화·상호 취소·완료·실패를 추가 전용으로 보존한다. order_groups.status는 이 이벤트의 현재 Projection이다.';

COMMENT ON TABLE "trading"."order_components" IS '하나의 파티션 전용 Order를 구성하는 Flow별 주문 의도 내역. 각 행은 어떤 Intent가 최종 Order 수량 중 얼마를 구성하는지 고정하며, Order의 component_quantity 합계는 requested_quantity와 같아야 한다. 정확한 Intent·position_effect·구성 규칙 버전을 보존하고 합계 불변식은 PostgreSQL 지연 제약 트리거로 강제한다.';

COMMENT ON TABLE "trading"."resource_reservations" IS '파티션·Flow 주문 의도별 자원을 나타내는 mutable 현재 Projection. ACTIVE 상태에서는 소비·해제가 모두 0이다. 전량 Fill 시 한 번만 SETTLED로 전환해 실제 사용액을 소비하고 Buying Power 완충액·잔액을 동시에 해제한다. 취소·만료·거절·replacement 시 전액 RELEASED다. 금액·수량 모두 최종 consumed + released = reserved를 행 CHECK와 사건 합계 지연 트리거로 이중 강제한다.';

COMMENT ON COLUMN "trading"."resource_reservations"."reservation_key" IS '의도·자원종류·통화 또는 종목을 정규화한 null 없는 멱등 키.';

COMMENT ON TABLE "trading"."position_lot_reservations" IS 'POSITION_QUANTITY 예약이 같은 Bot·Partition·Flow의 FIFO lot 중 어떤 잔량을 잠갔는지 고정한다. 복합 FK가 다른 파티션 또는 다른 Flow의 lot 매도를 차단하고, 활성 예약 합계는 지연 트리거가 현재 잔량 이하로 제한한다.';

COMMENT ON TABLE "trading"."order_component_reservations" IS '최종 Order의 각 구성 내역을 실제 현금·Position 수량 예약과 연결한다. 부분 체결과 예약 재사용을 지원하지 않으므로 하나의 resource reservation은 하나의 order component만 뒷받침하며 replacement Order는 새 예약을 만든다.';

COMMENT ON TABLE "trading"."reservation_events" IS '예약 생성과 정확히 한 번의 최종 정산을 추가 전용으로 기록한다. Fill 정산 사건 한 건은 실제 사용액 소비와 완충액·잔액 해제를 함께 기록한다. 취소·만료·거절·replacement는 전액 해제하며 event_key와 sequence가 중복 효과를 차단한다.';

COMMENT ON TABLE "trading"."order_events" IS '주문 상태 전이의 추가 전용 정본. 정상 경로는 PENDING/OPEN에서 FILLED, CANCELLED, EXPIRED 또는 REJECTED 중 하나로만 끝난다. CANCELLED는 사용자·봇 중지·운영자 강제 취소가 아니라 자동 replacement에서 원본 주문을 철회할 때만 허용한다. 부분 체결 상태는 없고 replacement 전 원본은 CANCELLED 사건을 먼저 가져야 한다.';

COMMENT ON TABLE "trading"."order_state_projections" IS '재구축 가능한 현재 주문 읽기 모델. filled_quantity는 0 또는 Order 전량뿐이며 중간값을 허용하지 않는다. 정본은 order_events와 정상 Fill이다.';

COMMENT ON TABLE "trading"."fills" IS 'Order당 최대 한 건인 불변 정상 전량 체결 증적. quantity는 연결 Order.requested_quantity와 정확히 같아야 한다. 최신 유효 참조가격에 고정 5 bps 슬리피지와 공식 20 bps 수수료를 한 번 적용하며 Buying Power 버퍼는 기록하거나 체결가·손익에 반영하지 않는다. 교차 행 수량·상태·계산 일치는 지연 제약 트리거로 검증한다.';

COMMENT ON COLUMN "trading"."fills"."settlement_cash_delta" IS '매수는 음수, 매도는 양수인 공식 현금 변동.';

COMMENT ON TABLE "trading"."fill_adjustments" IS '정상 Fill을 복제하지 않고 사후 정정·반전을 명시적으로 남기는 추가 전용 사건. CORRECTION은 가격·금액·수수료만 조정하고, REVERSAL은 migration trigger가 원 Fill의 경제 효과와 정확히 반대인지 검증한다. 정상 Fill의 Order당 1건 불변식에는 포함되지 않는다.';

COMMENT ON TABLE "trading"."ledger_accounts" IS '복식 원장의 계정 차원. 거래용 계정은 반드시 Partition에 속하고 Flow 귀속 자산 계정은 flow_id도 가진다. OPEN_SHORT Fill 매도대금은 일반 CASH가 아니라 SEGREGATED_SHORT_PROCEEDS 계정에 기록하며 CLOSE_SHORT 정산 전까지 새 주문의 Buying Power로 사용할 수 없다. Bot 전체 초기자본·미배정 현금 계정만 partition_id가 없을 수 있다. account_key와 제약 트리거가 scope 컬럼 일치를 검증한다.';

COMMENT ON COLUMN "trading"."ledger_accounts"."account_key" IS '봇 안에서 범위·계정유형·통화·종목을 정규화한 null 없는 안정 키.';

COMMENT ON TABLE "trading"."ledger_transactions" IS '추가 전용 회계 사건 헤더. FILL·FILL_ADJUSTMENT·차입비용·기업행사·초기자본을 멱등 source로 식별한다. FILL과 그 조정은 partition_id가 필수이며 같은 파티션 Ledger Account만 사용할 수 있다. 초기자본처럼 Bot 전체 사건만 partition_id가 없다.';

COMMENT ON TABLE "trading"."ledger_entries" IS '추가 전용 차변·대변 분개. Fill 거래의 Flow별 귀속은 order_component_id로 직접 이어지고 Flow 자체는 component의 Intent에서 유도한다. 지연 트리거가 Fill 없는 체결 분개, 파티션 불일치, 구성별 금액·수수료 합계 불일치와 불균형 분개를 커밋 시 차단한다.';

COMMENT ON TABLE "trading"."position_lots" IS '전량 Fill 뒤 각 Order 구성 내역으로 생성되는 불변 Flow별 FIFO 원가 묶음. 별도 Fill 배분 테이블 없이 opening_order_component_id에서 Order와 유일 정상 Fill을 추적한다. 지연 트리거가 해당 Fill 존재·동일 Partition·OPEN position_effect를 강제한다.';

COMMENT ON TABLE "trading"."lot_movements" IS '개별 로트의 OPEN·FIFO CLOSE·기업행사·정정·반전을 추가 전용으로 보존한다. 정상 거래 이동은 정확한 order component를 가리키며 그 Order의 유일 Fill을 통해 체결을 증명한다. 다른 Partition·Flow lot 소비와 Fill 없는 이동은 복합 FK와 지연 트리거가 차단한다.';

COMMENT ON TABLE "trading"."position_lot_projections" IS '재구축 가능한 로트 현재 상태. 동일 Flow의 FIFO 예약과 청산 조회를 빠르게 하며 정본은 position_lots와 lot_movements다.';

COMMENT ON TABLE "trading"."short_trade_checks" IS 'OPEN_SHORT 의도 승인에 사용한 가상 Short 노출, 최초·유지 담보, Rule 201 가격 제한과 청산 기준의 불변 판단 증적. 전일 정규장 종가 대비 장중 10% 이상 하락해 Rule 201이 발동하면 유효한 national best bid보다 높은 가격에서만 가상 공매도 Fill을 허용하며, 고정 매도 슬리피지를 적용한 Fill 가격도 이 조건을 만족해야 한다. 실제 주식 차입, 대여 가능 수량과 대여기관 회수는 판단하거나 저장하지 않는다.';

COMMENT ON TABLE "trading"."system_close_actions" IS '가상 Position의 위험 한도 위반, Bot 중단, 대회 종료 또는 데이터 무결성 차단에 따라 플랫폼이 생성한 강제 청산 근거. 실제 대여기관 회수 사건은 만들지 않는다. 데이터 무결성 차단은 청산 필요성을 기록하되 유효한 최신 가격 전에는 Fill을 만들지 않는다. 사용자 Flow 판단과 구분하며 생성된 SYSTEM_* 주문 의도부터 파티션 전용 Order·전량 Fill·원장까지 동일 경로로 추적한다.';

COMMENT ON TABLE "trading"."short_borrow_fee_accruals" IS '열린 가상 SHORT lot에 플랫폼 고정 연간 대차료를 기간별로 추가 전용 계산하고 공식 원장과 1:1 연결한다. 실제 대차시장 금리가 아니며 policy id, 적용 bps, day-count와 계산 해시를 고정한다. PostgreSQL 마이그레이션은 같은 lot의 비용 기간이 겹치지 않도록 exclusion constraint를 둔다.';

COMMENT ON TABLE "trading"."flow_position_projections" IS '재구축 가능한 PostgreSQL 현재 Projection. 공식 이력은 체결, 로트 변동, 원장 분개.';

COMMENT ON TABLE "trading"."partition_position_projections" IS '주문 가능 보유량과 순포지션 검사에 사용하는 재구축 가능한 파티션별 현재 상태. 서로 다른 파티션 포지션을 상계하지 않으며 Bot 전체 화면은 이 행들을 읽기 전용으로 합산한다. 원장·로트 기록이 정본.';

COMMENT ON TABLE "trading"."bot_budget_projections" IS '공식 원장·활성 resource_reservations·현재 청산가능 호가 평가에서 재구축하는 봇 예산 Projection. 가용현금은 격리 숏 매도대금과 담보를 제외하며 정본으로 사용하지 않는다.';

COMMENT ON TABLE "trading"."partition_budget_projections" IS '파티션 상한 사용량의 재구축 가능한 Projection. bot_id를 명시해 테넌트·소유 범위를 보존하고, 현재 청산가능 가격의 보유액·활성 예약·격리 숏 대금·담보를 공식 계산 규칙대로 분리한다.';

COMMENT ON TABLE "backtest"."runs" IS '봇 생성 트랜잭션에서 최초 자동 백테스트 한 건을 원자적으로 생성하고, 이후 같은 봇에 사용자가 선택한 기간 또는 공식 BACKTEST 대회의 잠긴 기간마다 실행을 추가할 수 있다. 대회 실행 소유권은 backtest.runs에 nullable competition 컬럼을 섞지 않고 competition.backtest_period_runs가 관리한다. 각 실행은 configuration_hash, 평가 기간, 초기 자금과 정책 버전을 독립적으로 고정하며 idempotency_key는 동일 요청의 중복 생성만 막는다. 백테스트 지연·실패는 라이브 봇 생명주기와 원장을 절대 바꾸지 않는다.';

COMMENT ON TABLE "backtest"."run_attempts" IS '백테스트 실행 시도 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "backtest"."input_datasets" IS '백테스트 입력 데이터셋 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "backtest"."input_feature_materializations" IS '공식 백테스트가 재사용하는 공유 과거 피처 결과를 고정. 잠금 해시는 AVAILABLE 구체화 결과 해시와 일치해야 하며, 누락·불일치 피처는 숨은 봇별 재계산 대신 입력 잠금 실패로 처리.';

COMMENT ON TABLE "backtest"."input_bundles" IS '공식 전체 봇 실행 1건의 완전한 재현성 경계를 고정.';

COMMENT ON TABLE "backtest"."monthly_judgment_summaries" IS '월별 판정 요약 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "backtest"."failure_condition_counts" IS '실패 조건 집계 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "backtest"."performance_summaries" IS '백테스트 성과 요약 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "backtest"."detail_manifests" IS '백테스트 상세 Parquet 오브젝트는 명시적 UNCOMPRESSED이며 ET 월요일 주 경계를 넘지 않는다.';

COMMENT ON TABLE "performance"."bot_current_projections" IS '봇별 최신 성과를 저장하는 mutable Projection. equity_amount, total_return_pct, max_drawdown_pct, sharpe_ratio는 정렬·필터용 핵심 지표이고 metrics_document는 중복되지 않는 확장 지표만 담는다. 갱신은 PostgreSQL 조건부 UPSERT 또는 전용 함수로 기존 last_event_sequence보다 큰 사건만 허용하여 늦게 끝난 과거 계산이 최신 상태를 덮지 못하게 한다. 직접 UPDATE 권한은 애플리케이션 역할에서 제거한다. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "performance"."bot_snapshots" IS '불변 공식 경계 스냅샷. 핵심 지표는 타입 컬럼에 고정하고 metrics_document에는 중복되지 않는 확장 지표만 둔다. 생성 후 UPDATE·DELETE를 금지하고 정정은 새로운 스냅샷으로 남긴다. NoSQL 리더보드·대시보드 문서는 절대 채점 증거가 아니다.';

COMMENT ON TABLE "performance"."series_manifests" IS '주 단위 성과 시계열 Parquet 객체의 PostgreSQL 매니페스트. 실제 시계열은 S3 storage.objects가 소유하고 이 행은 기간, 행 수, 스키마·계산 버전, 해시와 교체 계보를 검증한다. 객체 업로드와 해시 검증이 모두 끝난 뒤 available_at을 포함한 완성 행을 한 번만 삽입한다. ET 월요일 주 경계를 넘지 않는지는 PostgreSQL migration trigger로 검증한다. 기존 행을 덮어쓰지 않고 수정 파일은 같은 논리 파트의 revision_number를 증가시킨 새 행으로 추가하며 supersedes_manifest_id로 직전 행을 가리킨다. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "competition"."scoring_template_versions" IS '채점 템플릿 버전 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "competition"."rooms" IS '라이브와 백테스트 대회의 공통 루트. BACKTEST는 플랫폼 공식 대회만 허용한다. 플랫폼 대회는 고객 계정을 소유자로 가장하지 않고 실제 개설 운영자를 감사 FK로 남긴다. status는 append-only room_events에서 재구축 가능한 현재 Projection이다.';

COMMENT ON TABLE "competition"."room_rules" IS '모든 대회가 공유하는 잠긴 공개 규칙. 초기 자금, 수수료·고정 슬리피지 정책 버전, 채점 공식과 계산 규칙은 모집·평가·종료 상태와 관계없이 공개한다. 진행 중 참가 허용은 late_submission 문자열이 아니라 Room 유형과 잠긴 일정으로 결정한다.';

COMMENT ON COLUMN "competition"."room_rules"."slippage_rate_bps" IS '고정 5 bps.';

COMMENT ON TABLE "competition"."live_room_rules" IS 'LIVE_PAPER 대회에만 존재하는 운영·채점 자격 규칙. room_id가 LIVE_PAPER인지 PostgreSQL deferred constraint trigger가 검증한다.';

COMMENT ON TABLE "competition"."room_events" IS '추가 전용 생명주기 증적. rooms.status는 가드된 현재 Projection일 뿐이다.';

COMMENT ON TABLE "competition"."room_invitations" IS '평문 초대 비밀값은 저장하지 않는다. 활성 초대는 participation_closes_at 또는 더 이른 방 종료 시점에 만료. PLATFORM 공식 대회에서 초대를 사용할 수 있는지는 Room access policy가 결정한다.';

COMMENT ON TABLE "competition"."room_schedules" IS '잠긴 공통 일정. participation_closes_at 미입력의 논리적 기본값은 evaluation_ends_at이며 PostgreSQL DEFAULT가 형제 컬럼을 참조할 수 없으므로 생성 함수가 복사한다. LIVE_PAPER는 participation_closes_at <= evaluation_starts_at, 공식 BACKTEST는 participation_closes_at <= evaluation_ends_at을 유형별 deferred trigger가 강제한다. 마감 전에 승인된 BACKTEST Participation은 evaluation_ends_at 뒤에도 finalization_deadline_at까지 완료한다.';

COMMENT ON TABLE "competition"."participations" IS '사용자가 기존 Bot을 제출하는 행이 아니다. Strategy 선택 요청이 성공하면 출처 관계 없는 독립 새 Bot, Bot 스냅샷 계층, Participation, 최초 사건과 Outbox를 한 트랜잭션으로 생성한다. 같은 계정은 per_account_bot_limit까지 여러 행을 가질 수 있다. LIVE_PAPER는 Room 평가 시작 뒤 신규 참가 금지. 공식 BACKTEST는 participation_closes_at 전까지 진행 중 참가 가능하지만 EVALUATING 중 승인된 행은 사용자 취소·교체 불가하고 성공·실패와 관계없이 슬롯을 계속 점유한다.';

COMMENT ON COLUMN "competition"."participations"."post_room_action" IS 'null이면 결정 마감 시 STOP 처리.';

COMMENT ON TABLE "competition"."participation_events" IS '참가 이벤트 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "competition"."backtest_evaluation_plans" IS '플랫폼 공식 BACKTEST Room의 1:1 불변 비공개 평가 계획. 초기 자금·수수료·슬리피지·채점 공식은 room_rules로 항상 공개하고, 실제 기간·가중치·Dataset Manifest는 ENDED 전까지 권한 분리한다. 잠금 시 비밀 nonce를 포함한 commitment_hash만 공개하고 ENDED 뒤 계획과 nonce를 공개해 중간 변경이 없었음을 검증한다. nonce 평문은 저장하지 않는다.';

COMMENT ON TABLE "competition"."backtest_evaluation_periods" IS '서로 독립 초기 상태로 실행하는 숨은 기간. 같은 계획의 기간 범위 비중복, 행 수 = period_count, importance_weight 합계 = 1은 잠금 시 PostgreSQL deferred trigger와 daterange exclusion constraint로 강제한다. 기간 길이로 자동 가중하지 않고 플랫폼이 시장 중요도를 직접 설정한다.';

COMMENT ON TABLE "competition"."backtest_period_datasets" IS '모든 참가 Bot의 동일 기간 Run이 재사용하는 잠긴 시장 데이터 입력. 원본 S3 객체는 공개하지 않고 ENDED 뒤 Manifest 식별자·버전·해시만 공개한다.';

COMMENT ON TABLE "competition"."backtest_period_feature_materializations" IS '공통 서버 계산 결과를 참가 Bot마다 다시 계산하지 않도록 평가 기간이 잠근 공유 Feature Materialization 입력.';

COMMENT ON TABLE "competition"."backtest_period_runs" IS '참가 Bot·숨은 기간 하나와 기존 backtest.runs 하나를 정확히 연결한다. 각 Run은 동일 Bot 구성에서 동일 초기 자금, 빈 포지션·주문·예약·원장 변동·Flow 상태로 독립 시작한다. 실패 기간만 같은 Run의 run_attempts로 재시도하고 성공 기간은 다시 계산하지 않는다.';

COMMENT ON TABLE "competition"."backtest_aggregate_results" IS '모든 필수 기간 Run이 성공·검증된 Participation에만 생성되는 불변 최종 집계. 기간별 0~100 점수는 만들지 않고 원래 지표에 importance_weight를 적용하며 weighted와 worst-period 위험을 함께 보존한다. published_at부터 최종 점수와 현재 순위를 즉시 공개하지만 기간별 결과는 ENDED 전까지 숨긴다. 한 기간이라도 최종 실패하면 이 행을 만들지 않고 Participation을 EVALUATION_FAILED로 종료한다.';

COMMENT ON TABLE "competition"."live_evaluation_segments" IS 'LIVE_PAPER Participation에만 존재하는 공식 평가 구간. 가상 청산은 채점 전용 증거이며 라이브 체결·예약·원장 분개를 생성하지 않는다. Participation의 Room 유형은 deferred trigger가 검증한다.';

COMMENT ON TABLE "competition"."leaderboard_snapshots" IS '불변 공개 리더보드 스냅샷. 공식 BACKTEST는 새 aggregate result가 published_at에 공개될 때마다 현재 완료 Bot만 포함한 PUBLISHED 스냅샷을 만들고 별도 임시 표시는 하지 않는다. 모든 Participation terminal 뒤 FINAL 스냅샷을 만든다.';

COMMENT ON TABLE "competition"."leaderboard_entries" IS 'LIVE_PAPER는 불변 performance_snapshot_id, BACKTEST는 검증된 backtest_aggregate_result_id 중 정확히 하나를 공식 점수 근거로 사용한다. Snapshot Room 유형, Participation Room과 결과 소유권 일치는 deferred trigger가 검증한다.';

COMMENT ON TABLE "operations"."operator_accounts" IS '운영자 계정 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "operations"."roles" IS '운영자 역할 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "operations"."permissions" IS '운영 권한 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "operations"."role_permissions" IS '역할-권한 매핑 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "operations"."operator_role_assignments" IS '운영자 역할 부여 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "operations"."outbox_messages" IS '도메인 변경과 원자적으로 삽입. 퍼블리셔는 at-least-once 전달일 수 있으므로 모든 컨슈머가 idempotency_key를 사용.';

COMMENT ON TABLE "operations"."projection_checkpoints" IS '일회성인 NoSQL·검색·캐시 콘텐츠는 PostgreSQL과 검증된 S3 오브젝트로부터 재구축 가능해야 한다.';

COMMENT ON COLUMN "operations"."projection_checkpoints"."target_store" IS '값은 NOSQL, SEARCH, CACHE, POSTGRES_READ_MODEL.';

COMMENT ON TABLE "operations"."audit_events" IS '추가 전용 보안 증적. 외부 AI 호출은 actor_type DELEGATED_AUTHORIZATION과 delegated_authorization_id로 위임 승인을 명시한다. 페이로드·오브젝트 증거에 자격증명, 비공개 전략 소스, 불필요한 보유 정보를 중복 저장하지 않는다.';

COMMENT ON TABLE "operations"."notification_preferences" IS '필수 운영 공지는 수신 거부를 무시. 계정 전역 설정의 null-safe 유일성은 마이그레이션에서 강제.';

COMMENT ON TABLE "operations"."notifications" IS '알림 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "operations"."delivery_attempts" IS '알림 발송 시도 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "operations"."cases" IS '고객 문의 케이스 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

COMMENT ON TABLE "operations"."case_events" IS '케이스 이벤트 저장. Records는 검토용 가상 데이터이며 운영 시드나 마이그레이션이 아니다.';

ALTER TABLE "identity"."account_lifecycle_events" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_security_states" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_preferences" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_emails" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."email_verification_requests" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."account_emails" ("account_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."login_identities" ADD FOREIGN KEY ("provider_id") REFERENCES "identity"."auth_providers" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."login_identities" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."password_credentials" ADD FOREIGN KEY ("login_identity_id") REFERENCES "identity"."login_identities" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."sessions" ADD FOREIGN KEY ("account_id", "authenticated_by_login_identity_id") REFERENCES "identity"."login_identities" ("account_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_consents" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_consents" ADD FOREIGN KEY ("policy_document_id") REFERENCES "identity"."policy_documents" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_consents" ADD FOREIGN KEY ("supersedes_consent_id") REFERENCES "identity"."account_consents" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."delegated_authorizations" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."delegated_authorizations" ADD FOREIGN KEY ("disclosure_policy_document_id") REFERENCES "identity"."policy_documents" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."delegated_authorization_scopes" ADD FOREIGN KEY ("authorization_id") REFERENCES "identity"."delegated_authorizations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."delegated_credentials" ADD FOREIGN KEY ("authorization_id") REFERENCES "identity"."delegated_authorizations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."delegated_credentials" ADD FOREIGN KEY ("superseded_by_credential_id") REFERENCES "identity"."delegated_credentials" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."delegated_authorization_events" ADD FOREIGN KEY ("authorization_id") REFERENCES "identity"."delegated_authorizations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."password_reset_requests" ADD FOREIGN KEY ("account_id", "login_identity_id") REFERENCES "identity"."login_identities" ("account_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."authentication_events" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."authentication_events" ADD FOREIGN KEY ("subject_login_identity_id") REFERENCES "identity"."login_identities" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."authentication_events" ADD FOREIGN KEY ("previous_login_identity_id") REFERENCES "identity"."login_identities" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."authentication_events" ADD FOREIGN KEY ("new_login_identity_id") REFERENCES "identity"."login_identities" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."recovery_code_sets" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."recovery_codes" ADD FOREIGN KEY ("recovery_code_set_id") REFERENCES "identity"."recovery_code_sets" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_sanctions" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_sanctions" ADD FOREIGN KEY ("applied_by_operator_id") REFERENCES "operations"."operator_accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_sanctions" ADD FOREIGN KEY ("source_case_id") REFERENCES "operations"."cases" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_sanction_events" ADD FOREIGN KEY ("sanction_id") REFERENCES "identity"."account_sanctions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_sanction_events" ADD FOREIGN KEY ("actor_operator_id") REFERENCES "operations"."operator_accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "identity"."account_sanction_events" ADD FOREIGN KEY ("evidence_object_id") REFERENCES "storage"."objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."strategies" ADD FOREIGN KEY ("owner_account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."strategy_documents" ADD FOREIGN KEY ("strategy_id") REFERENCES "strategy"."strategies" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."strategy_edit_leases" ADD FOREIGN KEY ("strategy_id") REFERENCES "strategy"."strategies" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."strategy_edit_leases" ADD FOREIGN KEY ("session_id") REFERENCES "identity"."sessions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."strategy_edit_leases" ADD FOREIGN KEY ("delegated_credential_id") REFERENCES "identity"."delegated_credentials" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."validation_runs" ADD FOREIGN KEY ("strategy_id") REFERENCES "strategy"."strategies" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."validation_runs" ADD FOREIGN KEY ("requested_by_account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."validation_runs" ADD FOREIGN KEY ("delegated_authorization_id") REFERENCES "identity"."delegated_authorizations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."validation_runs" ADD FOREIGN KEY ("element_catalog_version_id") REFERENCES "strategy"."element_catalog_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."element_definitions" ADD FOREIGN KEY ("element_catalog_version_id") REFERENCES "strategy"."element_catalog_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."package_versions" ADD FOREIGN KEY ("package_id") REFERENCES "strategy"."packages" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."package_versions" ADD FOREIGN KEY ("element_catalog_version_id") REFERENCES "strategy"."element_catalog_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."template_versions" ADD FOREIGN KEY ("template_id") REFERENCES "strategy"."templates" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."template_versions" ADD FOREIGN KEY ("element_catalog_version_id") REFERENCES "strategy"."element_catalog_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "strategy"."compiled_flow_plans" ADD FOREIGN KEY ("element_catalog_version_id") REFERENCES "strategy"."element_catalog_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."instrument_symbols" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."feeds" ADD FOREIGN KEY ("provider_id") REFERENCES "market_data"."providers" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_manifests" ADD FOREIGN KEY ("feed_id") REFERENCES "market_data"."feeds" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_manifests" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_manifests" ADD FOREIGN KEY ("supersedes_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_objects" ADD FOREIGN KEY ("dataset_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_objects" ADD FOREIGN KEY ("object_id") REFERENCES "storage"."objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_lineage" ADD FOREIGN KEY ("derived_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_lineage" ADD FOREIGN KEY ("source_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_object_lineage" ADD FOREIGN KEY ("derived_dataset_object_id") REFERENCES "market_data"."dataset_objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_object_lineage" ADD FOREIGN KEY ("source_dataset_object_id") REFERENCES "market_data"."dataset_objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."dataset_object_lineage" ADD FOREIGN KEY ("pipeline_run_id") REFERENCES "market_data"."pipeline_runs" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."feature_definitions" ADD FOREIGN KEY ("element_catalog_version_id") REFERENCES "strategy"."element_catalog_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."feature_materializations" ADD FOREIGN KEY ("feature_definition_id") REFERENCES "market_data"."feature_definitions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."feature_materializations" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."feature_materializations" ADD FOREIGN KEY ("pipeline_run_id") REFERENCES "market_data"."pipeline_runs" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."feature_materializations" ADD FOREIGN KEY ("output_dataset_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."feature_snapshot_batches" ADD FOREIGN KEY ("snapshot_object_id") REFERENCES "storage"."objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."corporate_actions" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."corporate_actions" ADD FOREIGN KEY ("source_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."corporate_actions" ADD FOREIGN KEY ("supersedes_action_id") REFERENCES "market_data"."corporate_actions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."quality_incidents" ADD FOREIGN KEY ("dataset_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."quality_incidents" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."quality_incidents" ADD FOREIGN KEY ("evidence_object_id") REFERENCES "storage"."objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "market_data"."stream_watermarks" ADD FOREIGN KEY ("feed_id") REFERENCES "market_data"."feeds" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."bots" ADD FOREIGN KEY ("owner_account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."launch_snapshots" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."launch_configurations" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."launch_configurations" ADD FOREIGN KEY ("buying_power_buffer_policy_id") REFERENCES "trading"."buying_power_buffer_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."launch_configurations" ADD FOREIGN KEY ("fee_policy_id") REFERENCES "trading"."fee_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."bot_partitions" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flows" ADD FOREIGN KEY ("partition_id") REFERENCES "bot"."bot_partitions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flows" ADD FOREIGN KEY ("element_catalog_version_id") REFERENCES "strategy"."element_catalog_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flows" ADD FOREIGN KEY ("compiled_flow_plan_id") REFERENCES "strategy"."compiled_flow_plans" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flow_instruments" ADD FOREIGN KEY ("flow_id") REFERENCES "bot"."flows" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flow_instruments" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flow_feature_requirements" ADD FOREIGN KEY ("flow_id") REFERENCES "bot"."flows" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flow_feature_requirements" ADD FOREIGN KEY ("flow_id", "instrument_id") REFERENCES "bot"."flow_instruments" ("flow_id", "instrument_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flow_feature_requirements" ADD FOREIGN KEY ("feature_definition_id") REFERENCES "market_data"."feature_definitions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."bots" ADD FOREIGN KEY ("execution_block_event_id") REFERENCES "bot"."bot_events" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."bot_events" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."bot_events" ADD FOREIGN KEY ("causation_event_id") REFERENCES "bot"."bot_events" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."bot_events" ADD FOREIGN KEY ("market_dataset_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."bot_events" ADD FOREIGN KEY ("evidence_object_id") REFERENCES "storage"."objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."flow_time_triggers" ADD FOREIGN KEY ("flow_id") REFERENCES "bot"."flows" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."evaluation_runs" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."evaluation_runs" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."evaluation_runs" ADD FOREIGN KEY ("partition_id", "flow_id") REFERENCES "bot"."flows" ("partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."evaluation_runs" ADD FOREIGN KEY ("bot_id", "trigger_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."evaluation_runs" ADD FOREIGN KEY ("bot_id", "result_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."evaluation_runs" ADD FOREIGN KEY ("feature_snapshot_batch_id") REFERENCES "market_data"."feature_snapshot_batches" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."runtime_state_values" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."runtime_state_values" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."runtime_state_values" ADD FOREIGN KEY ("partition_id", "flow_id") REFERENCES "bot"."flows" ("partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."runtime_state_values" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."runtime_state_changes" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "bot"."runtime_state_changes" ADD FOREIGN KEY ("bot_id", "runtime_state_value_id") REFERENCES "bot"."runtime_state_values" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intent_batches" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intent_batches" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intent_batches" ADD FOREIGN KEY ("bot_id", "source_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intents" ADD FOREIGN KEY ("bot_id", "partition_id", "batch_id") REFERENCES "trading"."order_intent_batches" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intents" ADD FOREIGN KEY ("bot_id", "source_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intents" ADD FOREIGN KEY ("bot_id", "evaluation_run_id") REFERENCES "bot"."evaluation_runs" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intents" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intents" ADD FOREIGN KEY ("partition_id", "flow_id") REFERENCES "bot"."flows" ("partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_intents" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."orders" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."orders" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."orders" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."orders" ADD FOREIGN KEY ("bot_id", "partition_id", "replaces_order_id") REFERENCES "trading"."orders" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."orders" ADD FOREIGN KEY ("fee_policy_id") REFERENCES "trading"."fee_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."orders" ADD FOREIGN KEY ("bot_id", "accepted_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_groups" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_groups" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_groups" ADD FOREIGN KEY ("bot_id", "created_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_groups" ADD FOREIGN KEY ("bot_id", "closed_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_group_members" ADD FOREIGN KEY ("bot_id", "partition_id", "order_group_id") REFERENCES "trading"."order_groups" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_group_members" ADD FOREIGN KEY ("bot_id", "partition_id", "order_id") REFERENCES "trading"."orders" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_group_events" ADD FOREIGN KEY ("bot_id", "partition_id", "order_group_id") REFERENCES "trading"."order_groups" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_group_events" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_components" ADD FOREIGN KEY ("bot_id", "partition_id", "order_id") REFERENCES "trading"."orders" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_components" ADD FOREIGN KEY ("bot_id", "partition_id", "intent_id") REFERENCES "trading"."order_intents" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("partition_id", "flow_id") REFERENCES "bot"."flows" ("partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("bot_id", "partition_id", "intent_id") REFERENCES "trading"."order_intents" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("buffer_policy_id") REFERENCES "trading"."buying_power_buffer_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("fee_policy_id") REFERENCES "trading"."fee_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("short_risk_policy_id") REFERENCES "trading"."short_risk_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."resource_reservations" ADD FOREIGN KEY ("bot_id", "created_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lot_reservations" ADD FOREIGN KEY ("bot_id", "partition_id", "flow_id", "reservation_id") REFERENCES "trading"."resource_reservations" ("bot_id", "partition_id", "flow_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lot_reservations" ADD FOREIGN KEY ("bot_id", "partition_id", "flow_id", "position_lot_id") REFERENCES "trading"."position_lots" ("bot_id", "partition_id", "flow_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_component_reservations" ADD FOREIGN KEY ("bot_id", "partition_id", "reservation_id") REFERENCES "trading"."resource_reservations" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_component_reservations" ADD FOREIGN KEY ("bot_id", "partition_id", "order_component_id") REFERENCES "trading"."order_components" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."reservation_events" ADD FOREIGN KEY ("bot_id", "partition_id", "reservation_id") REFERENCES "trading"."resource_reservations" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."reservation_events" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."reservation_events" ADD FOREIGN KEY ("bot_id", "partition_id", "source_fill_id") REFERENCES "trading"."fills" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_events" ADD FOREIGN KEY ("bot_id", "partition_id", "order_id") REFERENCES "trading"."orders" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_events" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."order_state_projections" ADD FOREIGN KEY ("bot_id", "partition_id", "order_id") REFERENCES "trading"."orders" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."fills" ADD FOREIGN KEY ("bot_id", "partition_id", "order_id") REFERENCES "trading"."orders" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."fills" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."fills" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."fills" ADD FOREIGN KEY ("fee_policy_id") REFERENCES "trading"."fee_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."fill_adjustments" ADD FOREIGN KEY ("bot_id", "partition_id", "fill_id") REFERENCES "trading"."fills" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."fill_adjustments" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_accounts" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_accounts" ADD FOREIGN KEY ("partition_id") REFERENCES "bot"."bot_partitions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_accounts" ADD FOREIGN KEY ("flow_id") REFERENCES "bot"."flows" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_accounts" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_accounts" ADD FOREIGN KEY ("partition_id", "flow_id") REFERENCES "bot"."flows" ("partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_accounts" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_transactions" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_transactions" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_transactions" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_transactions" ADD FOREIGN KEY ("bot_id", "reversal_of_transaction_id") REFERENCES "trading"."ledger_transactions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_entries" ADD FOREIGN KEY ("bot_id", "partition_id", "transaction_id") REFERENCES "trading"."ledger_transactions" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_entries" ADD FOREIGN KEY ("bot_id", "partition_id", "ledger_account_id") REFERENCES "trading"."ledger_accounts" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."ledger_entries" ADD FOREIGN KEY ("bot_id", "partition_id", "order_component_id") REFERENCES "trading"."order_components" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lots" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lots" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lots" ADD FOREIGN KEY ("partition_id", "flow_id") REFERENCES "bot"."flows" ("partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lots" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lots" ADD FOREIGN KEY ("bot_id", "partition_id", "opening_order_component_id") REFERENCES "trading"."order_components" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."lot_movements" ADD FOREIGN KEY ("bot_id", "partition_id", "position_lot_id") REFERENCES "trading"."position_lots" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."lot_movements" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."lot_movements" ADD FOREIGN KEY ("bot_id", "partition_id", "source_order_component_id") REFERENCES "trading"."order_components" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."lot_movements" ADD FOREIGN KEY ("bot_id", "partition_id", "source_fill_adjustment_id") REFERENCES "trading"."fill_adjustments" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."lot_movements" ADD FOREIGN KEY ("corporate_action_id") REFERENCES "market_data"."corporate_actions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."lot_movements" ADD FOREIGN KEY ("position_lot_id", "reverses_movement_id") REFERENCES "trading"."lot_movements" ("position_lot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lot_projections" ADD FOREIGN KEY ("position_lot_id") REFERENCES "trading"."position_lots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."position_lot_projections" ADD FOREIGN KEY ("position_lot_id", "last_movement_id") REFERENCES "trading"."lot_movements" ("position_lot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."short_trade_checks" ADD FOREIGN KEY ("intent_id") REFERENCES "trading"."order_intents" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."short_trade_checks" ADD FOREIGN KEY ("short_risk_policy_id") REFERENCES "trading"."short_risk_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."system_close_actions" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."system_close_actions" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."system_close_actions" ADD FOREIGN KEY ("partition_id", "flow_id") REFERENCES "bot"."flows" ("partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."system_close_actions" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."system_close_actions" ADD FOREIGN KEY ("bot_id", "source_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."system_close_actions" ADD FOREIGN KEY ("bot_id", "partition_id", "generated_intent_id") REFERENCES "trading"."order_intents" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."short_borrow_fee_accruals" ADD FOREIGN KEY ("bot_id", "partition_id", "position_lot_id") REFERENCES "trading"."position_lots" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."short_borrow_fee_accruals" ADD FOREIGN KEY ("bot_id", "bot_event_id") REFERENCES "bot"."bot_events" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."short_borrow_fee_accruals" ADD FOREIGN KEY ("short_borrow_fee_policy_id") REFERENCES "trading"."short_borrow_fee_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."short_borrow_fee_accruals" ADD FOREIGN KEY ("bot_id", "partition_id", "ledger_transaction_id") REFERENCES "trading"."ledger_transactions" ("bot_id", "partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."flow_position_projections" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."flow_position_projections" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."flow_position_projections" ADD FOREIGN KEY ("partition_id", "flow_id") REFERENCES "bot"."flows" ("partition_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."flow_position_projections" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."partition_position_projections" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."partition_position_projections" ADD FOREIGN KEY ("instrument_id") REFERENCES "market_data"."instruments" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."bot_budget_projections" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "trading"."partition_budget_projections" ADD FOREIGN KEY ("bot_id", "partition_id") REFERENCES "bot"."bot_partitions" ("bot_id", "id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."runs" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."runs" ADD FOREIGN KEY ("owner_account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."runs" ADD FOREIGN KEY ("buying_power_buffer_policy_id") REFERENCES "trading"."buying_power_buffer_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."runs" ADD FOREIGN KEY ("fee_policy_id") REFERENCES "trading"."fee_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."run_attempts" ADD FOREIGN KEY ("run_id") REFERENCES "backtest"."runs" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."input_bundles" ADD FOREIGN KEY ("run_id") REFERENCES "backtest"."runs" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."input_datasets" ADD FOREIGN KEY ("input_bundle_id") REFERENCES "backtest"."input_bundles" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."input_datasets" ADD FOREIGN KEY ("dataset_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."input_feature_materializations" ADD FOREIGN KEY ("input_bundle_id") REFERENCES "backtest"."input_bundles" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."input_feature_materializations" ADD FOREIGN KEY ("feature_materialization_id") REFERENCES "market_data"."feature_materializations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."monthly_judgment_summaries" ADD FOREIGN KEY ("run_id") REFERENCES "backtest"."runs" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."failure_condition_counts" ADD FOREIGN KEY ("monthly_summary_id") REFERENCES "backtest"."monthly_judgment_summaries" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."performance_summaries" ADD FOREIGN KEY ("run_id") REFERENCES "backtest"."runs" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."detail_manifests" ADD FOREIGN KEY ("run_id") REFERENCES "backtest"."runs" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."detail_manifests" ADD FOREIGN KEY ("object_id") REFERENCES "storage"."objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "backtest"."detail_manifests" ADD FOREIGN KEY ("supersedes_manifest_id") REFERENCES "backtest"."detail_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "performance"."bot_current_projections" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "performance"."bot_snapshots" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "performance"."series_manifests" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "performance"."series_manifests" ADD FOREIGN KEY ("object_id") REFERENCES "storage"."objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "performance"."series_manifests" ADD FOREIGN KEY ("supersedes_manifest_id") REFERENCES "performance"."series_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."rooms" ADD FOREIGN KEY ("creator_account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."rooms" ADD FOREIGN KEY ("created_by_operator_id") REFERENCES "operations"."operator_accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."room_rules" ADD FOREIGN KEY ("room_id") REFERENCES "competition"."rooms" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."room_rules" ADD FOREIGN KEY ("scoring_template_version_id") REFERENCES "competition"."scoring_template_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."room_rules" ADD FOREIGN KEY ("buying_power_buffer_policy_id") REFERENCES "trading"."buying_power_buffer_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."room_rules" ADD FOREIGN KEY ("fee_policy_id") REFERENCES "trading"."fee_policy_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."live_room_rules" ADD FOREIGN KEY ("room_id") REFERENCES "competition"."rooms" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."room_events" ADD FOREIGN KEY ("room_id") REFERENCES "competition"."rooms" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."room_invitations" ADD FOREIGN KEY ("room_id") REFERENCES "competition"."rooms" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."room_invitations" ADD FOREIGN KEY ("issued_by_account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."room_schedules" ADD FOREIGN KEY ("room_id") REFERENCES "competition"."rooms" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."participations" ADD FOREIGN KEY ("room_id") REFERENCES "competition"."rooms" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."participations" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."participations" ADD FOREIGN KEY ("owner_account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."participation_events" ADD FOREIGN KEY ("participation_id") REFERENCES "competition"."participations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_evaluation_plans" ADD FOREIGN KEY ("room_id") REFERENCES "competition"."rooms" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_evaluation_periods" ADD FOREIGN KEY ("evaluation_plan_room_id") REFERENCES "competition"."backtest_evaluation_plans" ("room_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_period_datasets" ADD FOREIGN KEY ("evaluation_period_id") REFERENCES "competition"."backtest_evaluation_periods" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_period_datasets" ADD FOREIGN KEY ("dataset_manifest_id") REFERENCES "market_data"."dataset_manifests" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_period_feature_materializations" ADD FOREIGN KEY ("evaluation_period_id") REFERENCES "competition"."backtest_evaluation_periods" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_period_feature_materializations" ADD FOREIGN KEY ("feature_materialization_id") REFERENCES "market_data"."feature_materializations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_period_runs" ADD FOREIGN KEY ("participation_id") REFERENCES "competition"."participations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_period_runs" ADD FOREIGN KEY ("evaluation_period_id") REFERENCES "competition"."backtest_evaluation_periods" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_period_runs" ADD FOREIGN KEY ("run_id") REFERENCES "backtest"."runs" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_aggregate_results" ADD FOREIGN KEY ("participation_id") REFERENCES "competition"."participations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_aggregate_results" ADD FOREIGN KEY ("evaluation_plan_room_id") REFERENCES "competition"."backtest_evaluation_plans" ("room_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."backtest_aggregate_results" ADD FOREIGN KEY ("scoring_template_version_id") REFERENCES "competition"."scoring_template_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."live_evaluation_segments" ADD FOREIGN KEY ("participation_id") REFERENCES "competition"."participations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."leaderboard_snapshots" ADD FOREIGN KEY ("room_id") REFERENCES "competition"."rooms" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."leaderboard_snapshots" ADD FOREIGN KEY ("scoring_template_version_id") REFERENCES "competition"."scoring_template_versions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."leaderboard_entries" ADD FOREIGN KEY ("snapshot_id") REFERENCES "competition"."leaderboard_snapshots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."leaderboard_entries" ADD FOREIGN KEY ("participation_id") REFERENCES "competition"."participations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."leaderboard_entries" ADD FOREIGN KEY ("performance_snapshot_id") REFERENCES "performance"."bot_snapshots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "competition"."leaderboard_entries" ADD FOREIGN KEY ("backtest_aggregate_result_id") REFERENCES "competition"."backtest_aggregate_results" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."role_permissions" ADD FOREIGN KEY ("role_id") REFERENCES "operations"."roles" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."role_permissions" ADD FOREIGN KEY ("permission_id") REFERENCES "operations"."permissions" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."operator_role_assignments" ADD FOREIGN KEY ("operator_account_id") REFERENCES "operations"."operator_accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."operator_role_assignments" ADD FOREIGN KEY ("role_id") REFERENCES "operations"."roles" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."operator_role_assignments" ADD FOREIGN KEY ("granted_by_operator_id") REFERENCES "operations"."operator_accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."operator_role_assignments" ADD FOREIGN KEY ("revoked_by_operator_id") REFERENCES "operations"."operator_accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."audit_events" ADD FOREIGN KEY ("evidence_object_id") REFERENCES "storage"."objects" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."audit_events" ADD FOREIGN KEY ("delegated_authorization_id") REFERENCES "identity"."delegated_authorizations" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."notification_preferences" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."notification_preferences" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."notifications" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."notifications" ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."delivery_attempts" ADD FOREIGN KEY ("notification_id") REFERENCES "operations"."notifications" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."cases" ADD FOREIGN KEY ("account_id") REFERENCES "identity"."accounts" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "operations"."case_events" ADD FOREIGN KEY ("case_id") REFERENCES "operations"."cases" ("id") DEFERRABLE INITIALLY IMMEDIATE;
