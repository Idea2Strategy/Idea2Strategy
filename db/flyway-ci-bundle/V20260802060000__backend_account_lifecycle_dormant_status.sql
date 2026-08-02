-- A12 must commit this enum value before a later Flyway migration uses it.
ALTER TYPE identity.account_lifecycle_status
    ADD VALUE IF NOT EXISTS 'DORMANT' BEFORE 'CLOSING';
