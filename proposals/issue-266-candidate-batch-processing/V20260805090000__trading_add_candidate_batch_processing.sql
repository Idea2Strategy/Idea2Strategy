-- ISOLATED PROPOSAL ONLY. Do not copy to the canonical contribution directory
-- without the exact authority approval described in README.md.
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
