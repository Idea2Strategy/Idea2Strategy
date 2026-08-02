CREATE TYPE identity.theme_preference AS ENUM ('LIGHT', 'DARK', 'SYSTEM');

ALTER TABLE identity.account_preferences
    ADD COLUMN theme_preference identity.theme_preference;

UPDATE identity.account_preferences
SET theme_preference = 'SYSTEM'
WHERE theme_preference IS NULL;

ALTER TABLE identity.account_preferences
    ALTER COLUMN theme_preference SET DEFAULT 'SYSTEM',
    ALTER COLUMN theme_preference SET NOT NULL;

INSERT INTO identity.account_preferences (
    account_id,
    language_code,
    timezone_name,
    theme_preference,
    created_at,
    updated_at
)
SELECT
    account.id,
    'ko',
    'America/New_York',
    'SYSTEM',
    account.created_at,
    now()
FROM identity.accounts account
LEFT JOIN identity.account_preferences preferences
    ON preferences.account_id = account.id
WHERE preferences.account_id IS NULL;

COMMENT ON TYPE identity.theme_preference IS
    'Account-synchronized display preference. It does not affect trading, market-time calculations, or authorization.';

COMMENT ON COLUMN identity.account_preferences.theme_preference IS
    'LIGHT, DARK, or SYSTEM. Existing and repaired accounts default to SYSTEM.';
