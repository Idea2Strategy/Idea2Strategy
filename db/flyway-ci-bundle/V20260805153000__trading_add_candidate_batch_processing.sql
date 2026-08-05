-- Root #266: trading-worker's only JPA entity validates trading.candidate_batch_processing
-- (F90's exactly-once candidate batch receipt), but the table existed only in the test-only
-- private compatibility migrations, so the worker could not start on any canonically migrated
-- database. This promotes the receipt to a canonical trading-owned table. The private
-- V2026080101 stays as a tolerated no-op wherever this migration has already applied.
CREATE TABLE trading.candidate_batch_processing (
    batch_id uuid PRIMARY KEY,
    evaluation_id uuid NOT NULL,
    source_created_at timestamptz NOT NULL,
    status varchar(16) NOT NULL,
    claim_token uuid NOT NULL,
    lease_expires_at timestamptz NOT NULL,
    failure_reason varchar(512),
    started_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT candidate_batch_processing_status_check
        CHECK (status IN ('PROCESSING', 'COMPLETED', 'FAILED'))
);

CREATE INDEX candidate_batch_processing_evaluation_idx
    ON trading.candidate_batch_processing (evaluation_id);
