-- A18 notification policy, preference, inbox, and delivery-attempt persistence.
CREATE TABLE operations.notification_policies (
    type_code varchar(80) NOT NULL,
    policy_version varchar(80) NOT NULL,
    mandatory boolean NOT NULL,
    default_channels jsonb NOT NULL,
    active boolean NOT NULL DEFAULT false,
    activated_at timestamptz,
    PRIMARY KEY (type_code, policy_version),
    CONSTRAINT notification_policy_channels_array CHECK (jsonb_typeof(default_channels) = 'array'),
    CONSTRAINT notification_policy_activation_consistent CHECK (active = (activated_at IS NOT NULL))
);

CREATE UNIQUE INDEX notification_policy_one_active_per_type
    ON operations.notification_policies (type_code) WHERE active;

ALTER TABLE operations.notification_preferences
    ADD COLUMN policy_version varchar(80) NOT NULL DEFAULT 'legacy';

DO $$
DECLARE legacy_index_name text;
BEGIN
    SELECT indexname INTO legacy_index_name
    FROM pg_indexes
    WHERE schemaname = 'operations'
      AND tablename = 'notification_preferences'
      AND indexdef LIKE '%(account_id, bot_id, event_type, channel)%';
    IF legacy_index_name IS NOT NULL THEN
        EXECUTE format('DROP INDEX operations.%I', legacy_index_name);
    END IF;
END $$;
CREATE UNIQUE INDEX notification_preference_versioned_scope_unique
    ON operations.notification_preferences
       (account_id, coalesce(bot_id, '00000000-0000-0000-0000-000000000000'::uuid),
        event_type, policy_version, channel);

ALTER TABLE operations.notifications
    ADD COLUMN source_event_id varchar(160),
    ADD COLUMN source_event_hash varchar(128),
    ADD COLUMN policy_version varchar(80),
    ADD COLUMN selected_channels jsonb,
    ADD COLUMN correlation_id uuid;

ALTER TABLE operations.notifications
    ADD CONSTRAINT notification_source_evidence_pair CHECK (
        (source_event_id IS NULL) = (source_event_hash IS NULL)),
    ADD CONSTRAINT notification_selected_channels_array CHECK (
        selected_channels IS NULL OR jsonb_typeof(selected_channels) = 'array');

CREATE UNIQUE INDEX notification_source_event_unique
    ON operations.notifications (account_id, notification_type, source_event_id)
    WHERE source_event_id IS NOT NULL;

ALTER TABLE operations.delivery_attempts
    ADD COLUMN outbox_message_id uuid,
    ADD COLUMN runtime_policy_version varchar(80),
    ADD CONSTRAINT notification_delivery_outbox_fk FOREIGN KEY (outbox_message_id)
        REFERENCES operations.outbox_messages(id) DEFERRABLE INITIALLY IMMEDIATE;

CREATE UNIQUE INDEX notification_delivery_outbox_attempt_unique
    ON operations.delivery_attempts (outbox_message_id, attempt_number)
    WHERE outbox_message_id IS NOT NULL;

COMMENT ON TABLE operations.notification_policies IS
    'A18 notification policy versions; product-owned values are configured separately and are not seeded here.';
COMMENT ON COLUMN operations.notifications.source_event_hash IS
    'Immutable source-event evidence used to fail closed on an idempotency-key payload mismatch.';
