-- One customer-facing switch controls every optional notification email.
CREATE TABLE operations.account_email_notification_preferences (
    account_id uuid PRIMARY KEY,
    enabled boolean NOT NULL DEFAULT false,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT account_email_notification_preference_account_fk
        FOREIGN KEY (account_id) REFERENCES identity.accounts(id) ON DELETE CASCADE
);

COMMENT ON TABLE operations.account_email_notification_preferences IS
    'Account-wide opt-in for optional notification emails. Missing rows mean disabled; mandatory delivery is policy-controlled.';
