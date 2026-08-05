-- Upgrade only the exact empty schema left by the retired market-loader V001.
--
-- Fresh installations already contain the canonical V1 shape and take the no-op
-- path.  An occupied or unrecognised legacy shape fails before any DDL is executed;
-- there is no product-safe way to invent partition, lineage or evidence meaning.

SET LOCAL search_path = market_data, operations, storage, public;

DO $migration$
DECLARE
    legacy_shape boolean;
    canonical_shape boolean;
    legacy_rows bigint;
    legacy_lineage_unique name;
BEGIN
    SELECT
        EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'dataset_objects'
              AND column_name = 'partition_key'
        )
        AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'dataset_objects'
              AND column_name = 'partition_granularity'
        )
        AND EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'dataset_lineage'
              AND column_name = 'dataset_manifest_id'
        )
        AND EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'dataset_lineage'
              AND column_name = 'relationship_type'
        )
        AND EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'quality_incidents'
              AND column_name = 'incident_type'
        )
        AND EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'quality_incidents'
              AND column_name = 'detail'
        )
        AND to_regclass('market_data.corporate_actions') IS NULL
        AND to_regclass('market_data.feature_materializations') IS NULL
        AND to_regclass('market_data.dataset_object_lineage') IS NULL
    INTO legacy_shape;

    SELECT
        to_regclass('market_data.corporate_actions') IS NOT NULL
        AND to_regclass('market_data.feature_materializations') IS NOT NULL
        AND to_regclass('market_data.dataset_object_lineage') IS NOT NULL
        AND EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'dataset_objects'
              AND column_name = 'partition_granularity'
        )
        AND EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'dataset_lineage'
              AND column_name = 'derived_manifest_id'
        )
        AND EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'market_data' AND table_name = 'quality_incidents'
              AND column_name = 'incident_code'
        )
    INTO canonical_shape;

    IF canonical_shape AND NOT legacy_shape THEN
        RETURN;
    END IF;
    IF NOT legacy_shape THEN
        RAISE EXCEPTION
            'market_data schema is neither the exact retired V001 shape nor the canonical shape';
    END IF;

    LOCK TABLE market_data.dataset_objects,
               market_data.dataset_lineage,
               market_data.quality_incidents
        IN ACCESS EXCLUSIVE MODE;

    SELECT count(*) INTO legacy_rows FROM market_data.dataset_objects;
    IF legacy_rows <> 0 THEN
        RAISE EXCEPTION 'dataset_objects contains % legacy row(s); refusing semantic conversion', legacy_rows;
    END IF;
    SELECT count(*) INTO legacy_rows FROM market_data.dataset_lineage;
    IF legacy_rows <> 0 THEN
        RAISE EXCEPTION 'dataset_lineage contains % legacy row(s); refusing semantic conversion', legacy_rows;
    END IF;
    SELECT count(*) INTO legacy_rows FROM market_data.quality_incidents;
    IF legacy_rows <> 0 THEN
        RAISE EXCEPTION 'quality_incidents contains % legacy row(s); refusing semantic conversion', legacy_rows;
    END IF;

    ALTER TABLE market_data.dataset_objects
        ALTER COLUMN object_kind TYPE varchar(40),
        ALTER COLUMN partition_key DROP NOT NULL,
        ADD COLUMN partition_granularity market_data.partition_granularity NOT NULL,
        ADD COLUMN partition_start date NOT NULL,
        ADD COLUMN partition_end date NOT NULL,
        ADD COLUMN period_start timestamptz NOT NULL,
        ADD COLUMN period_end timestamptz NOT NULL,
        ADD COLUMN shard_key varchar(120) NOT NULL,
        ADD COLUMN part_number integer NOT NULL,
        ADD COLUMN min_instrument_id uuid,
        ADD COLUMN max_instrument_id uuid,
        DROP CONSTRAINT dataset_objects_object_kind_check,
        DROP CONSTRAINT dataset_objects_dataset_manifest_id_object_id_key,
        DROP CONSTRAINT dataset_objects_dataset_manifest_id_partition_key_key,
        ADD CONSTRAINT dataset_object_partition_order CHECK (partition_end > partition_start),
        ADD CONSTRAINT dataset_object_period_order CHECK (period_end > period_start);

    CREATE UNIQUE INDEX uq_dataset_objects_manifest_kind_granularity_partition_shard_part
        ON market_data.dataset_objects
        (dataset_manifest_id, object_kind, partition_granularity, partition_start,
         partition_end, shard_key, part_number);
    CREATE INDEX ix_dataset_objects_granularity_partition
        ON market_data.dataset_objects (partition_granularity, partition_start, partition_end);
    CREATE INDEX ix_dataset_objects_manifest_period
        ON market_data.dataset_objects (dataset_manifest_id, period_start, period_end);

    SELECT constraint_name
      INTO legacy_lineage_unique
      FROM information_schema.table_constraints
     WHERE table_schema = 'market_data'
       AND table_name = 'dataset_lineage'
       AND constraint_type = 'UNIQUE'
       AND constraint_name IN (
           SELECT tc.constraint_name
             FROM information_schema.table_constraints tc
             JOIN information_schema.key_column_usage kcu
               ON kcu.constraint_schema = tc.constraint_schema
              AND kcu.constraint_name = tc.constraint_name
              AND kcu.table_schema = tc.table_schema
              AND kcu.table_name = tc.table_name
            WHERE tc.table_schema = 'market_data'
              AND tc.table_name = 'dataset_lineage'
              AND tc.constraint_type = 'UNIQUE'
            GROUP BY tc.constraint_name
           HAVING array_agg(kcu.column_name::text ORDER BY kcu.column_name) =
                  ARRAY['dataset_manifest_id', 'relationship_type', 'source_manifest_id']
       );
    IF legacy_lineage_unique IS NULL THEN
        RAISE EXCEPTION 'legacy dataset_lineage three-column unique constraint is missing';
    END IF;
    EXECUTE format(
        'ALTER TABLE market_data.dataset_lineage DROP CONSTRAINT %I',
        legacy_lineage_unique
    );

    ALTER TABLE market_data.dataset_lineage
        RENAME COLUMN dataset_manifest_id TO derived_manifest_id;
    ALTER TABLE market_data.dataset_lineage
        RENAME COLUMN relationship_type TO relation_type;
    ALTER TABLE market_data.dataset_lineage
        ALTER COLUMN id SET DEFAULT gen_random_uuid(),
        ALTER COLUMN relation_type TYPE varchar(40),
        DROP CONSTRAINT dataset_lineage_relationship_type_check,
        DROP CONSTRAINT dataset_lineage_check,
        ADD CONSTRAINT uq_dataset_lineage_derived_source_relation
            UNIQUE (derived_manifest_id, source_manifest_id, relation_type);

    ALTER TABLE market_data.quality_incidents
        RENAME COLUMN incident_type TO incident_code;
    ALTER TABLE market_data.quality_incidents
        ALTER COLUMN incident_code TYPE varchar(80),
        ALTER COLUMN period_start SET NOT NULL,
        ALTER COLUMN detail DROP NOT NULL,
        ADD COLUMN evidence_object_id uuid,
        DROP CONSTRAINT quality_incidents_status_check,
        ADD CONSTRAINT quality_incidents_evidence_object_id_fkey
            FOREIGN KEY (evidence_object_id) REFERENCES storage.objects(id)
            DEFERRABLE INITIALLY IMMEDIATE;
    CREATE INDEX ix_quality_incidents_status_severity_detected
        ON market_data.quality_incidents (status, severity, detected_at);
    CREATE INDEX ix_quality_incidents_manifest_period
        ON market_data.quality_incidents (dataset_manifest_id, period_start);

    CREATE TABLE market_data.corporate_actions (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        instrument_id uuid NOT NULL REFERENCES market_data.instruments(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        source_manifest_id uuid NOT NULL REFERENCES market_data.dataset_manifests(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        provider_event_key varchar(160) NOT NULL,
        action_type varchar(60) NOT NULL,
        effective_at timestamptz NOT NULL,
        terms_document jsonb NOT NULL,
        terms_hash varchar(128) NOT NULL,
        supersedes_action_id uuid REFERENCES market_data.corporate_actions(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE UNIQUE INDEX uq_corporate_actions_source_manifest_event
        ON market_data.corporate_actions (source_manifest_id, provider_event_key);
    CREATE INDEX ix_corporate_actions_instrument_effective
        ON market_data.corporate_actions (instrument_id, effective_at);

    CREATE TABLE market_data.feature_materializations (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        feature_definition_id uuid NOT NULL REFERENCES market_data.feature_definitions(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        instrument_id uuid NOT NULL REFERENCES market_data.instruments(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        pipeline_run_id uuid NOT NULL UNIQUE REFERENCES market_data.pipeline_runs(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        input_dataset_set_hash varchar(128) NOT NULL,
        period_start timestamptz NOT NULL,
        period_end timestamptz NOT NULL,
        source_watermark varchar(300) NOT NULL,
        output_dataset_manifest_id uuid REFERENCES market_data.dataset_manifests(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        result_hash varchar(128),
        status work_status NOT NULL,
        available_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT feature_materialization_period_order CHECK (period_end > period_start),
        CONSTRAINT feature_materialization_success_complete CHECK (
            status <> 'SUCCEEDED'
            OR (output_dataset_manifest_id IS NOT NULL AND result_hash IS NOT NULL AND available_at IS NOT NULL)
        )
    );
    CREATE UNIQUE INDEX uq_feature_materializations_definition_instrument_inputs_period
        ON market_data.feature_materializations
        (feature_definition_id, instrument_id, input_dataset_set_hash, period_start, period_end);
    CREATE INDEX ix_feature_materializations_instrument_period_status
        ON market_data.feature_materializations (instrument_id, period_end, status);
    CREATE UNIQUE INDEX uq_feature_materializations_output_manifest
        ON market_data.feature_materializations (output_dataset_manifest_id);

    CREATE TABLE market_data.dataset_object_lineage (
        derived_dataset_object_id uuid NOT NULL REFERENCES market_data.dataset_objects(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        source_dataset_object_id uuid NOT NULL REFERENCES market_data.dataset_objects(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        pipeline_run_id uuid NOT NULL REFERENCES market_data.pipeline_runs(id)
            DEFERRABLE INITIALLY IMMEDIATE,
        relation_type varchar(40) NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT dataset_object_lineage_no_self_reference CHECK (
            derived_dataset_object_id <> source_dataset_object_id
        ),
        PRIMARY KEY (derived_dataset_object_id, source_dataset_object_id, relation_type)
    );
    CREATE INDEX ix_dataset_object_lineage_source
        ON market_data.dataset_object_lineage (source_dataset_object_id);
    CREATE INDEX ix_dataset_object_lineage_pipeline_run
        ON market_data.dataset_object_lineage (pipeline_run_id);
END
$migration$;
