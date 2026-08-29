ALTER TABLE market_data.dataset_manifests
    ADD COLUMN actual_start_at timestamptz,
    ADD COLUMN actual_end_at timestamptz,
    ADD CONSTRAINT dataset_manifest_actual_range_valid CHECK (
        (actual_start_at IS NULL AND actual_end_at IS NULL)
        OR (
            actual_start_at IS NOT NULL
            AND actual_end_at IS NOT NULL
            AND actual_start_at <= actual_end_at
            AND actual_start_at >= period_start
            AND actual_end_at < period_end
        )
    );

COMMENT ON COLUMN market_data.dataset_manifests.actual_start_at IS
    'Inclusive minimum bar_start_at independently verified from published Parquet; NULL means legacy evidence is not backfilled.';
COMMENT ON COLUMN market_data.dataset_manifests.actual_end_at IS
    'Inclusive maximum bar_start_at independently verified from published Parquet; distinct from the half-open coverage period_end.';

ALTER TABLE market_data.dataset_objects
    ADD COLUMN actual_start_at timestamptz,
    ADD COLUMN actual_end_at timestamptz,
    ADD CONSTRAINT dataset_object_actual_range_valid CHECK (
        (actual_start_at IS NULL AND actual_end_at IS NULL)
        OR (
            actual_start_at IS NOT NULL
            AND actual_end_at IS NOT NULL
            AND actual_start_at <= actual_end_at
            AND actual_start_at >= period_start
            AND actual_end_at < period_end
        )
    );

COMMENT ON COLUMN market_data.dataset_objects.actual_start_at IS
    'Inclusive minimum bar_start_at independently verified from this Parquet object.';
COMMENT ON COLUMN market_data.dataset_objects.actual_end_at IS
    'Inclusive maximum bar_start_at independently verified from this Parquet object.';
