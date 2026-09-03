-- The backtest worker must compensate only its own uncommitted object versions.
-- It deliberately has no DELETE on storage.objects and no SELECT on every table
-- that may acquire a future FK to storage.objects.  This transaction-scoped
-- capability performs that narrow operation with migration-owner privileges.

CREATE OR REPLACE FUNCTION storage.prepare_backtest_object_cleanup(p_candidates jsonb)
RETURNS SETOF storage.objects
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
SET lock_timeout = '5s'
AS $cleanup$
DECLARE
    v_after jsonb;
    v_before jsonb;
    v_candidate_count integer;
    v_candidate_ids uuid[];
    v_deleted_count integer;
    v_existing_count integer;
    v_reference_exists boolean;
    v_source record;
    v_unique_count integer;
BEGIN
    IF jsonb_typeof(p_candidates) IS DISTINCT FROM 'array'
       OR jsonb_array_length(p_candidates) = 0 THEN
        RAISE EXCEPTION 'backtest object cleanup candidates must be a non-empty JSON array';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_candidates) AS offered(candidate)
        WHERE jsonb_typeof(offered.candidate) IS DISTINCT FROM 'object'
           OR (
                SELECT array_agg(key ORDER BY key)
                FROM jsonb_object_keys(offered.candidate) AS keys(key)
              ) IS DISTINCT FROM ARRAY[
                  'bucket_name',
                  'content_hash',
                  'object_id',
                  'object_key',
                  'provider_version_id',
                  'storage_provider'
              ]::text[]
    ) THEN
        RAISE EXCEPTION 'backtest object cleanup candidate shape is invalid';
    END IF;

    SELECT count(*), count(DISTINCT candidate.object_id),
           array_agg(candidate.object_id ORDER BY candidate.object_id)
    INTO v_candidate_count, v_unique_count, v_candidate_ids
    FROM jsonb_to_recordset(p_candidates) AS candidate(
        object_id uuid,
        storage_provider text,
        bucket_name text,
        object_key text,
        provider_version_id text,
        content_hash text
    );

    IF v_candidate_count IS DISTINCT FROM v_unique_count THEN
        RAISE EXCEPTION 'backtest object cleanup candidate ids must be unique';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_to_recordset(p_candidates) AS candidate(
            object_id uuid,
            storage_provider text,
            bucket_name text,
            object_key text,
            provider_version_id text,
            content_hash text
        )
        WHERE candidate.object_id IS NULL
           OR nullif(candidate.storage_provider, '') IS NULL
           OR nullif(candidate.bucket_name, '') IS NULL
           OR nullif(candidate.object_key, '') IS NULL
           OR nullif(candidate.provider_version_id, '') IS NULL
           OR candidate.content_hash !~ '^[0-9a-f]{64}$'
           OR NOT (
                (
                    candidate.object_key ~
                    '^backtest-results/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{64}[.]json$'
                    AND candidate.object_key LIKE '%/' || candidate.content_hash || '.json'
                )
                OR
                (
                    candidate.object_key ~
                    '^backtest-results/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Z][A-Z0-9_]{0,49}/week_start=[0-9]{4}-[0-9]{2}-[0-9]{2}/part=[0-9]{4}/[0-9a-f]{64}[.]parquet$'
                    AND candidate.object_key LIKE '%/' || candidate.content_hash || '.parquet'
                )
           )
    ) THEN
        RAISE EXCEPTION
            'backtest object cleanup requires exact identities in the canonical backtest object namespace';
    END IF;

    WITH foreign_keys AS (
        SELECT fk.oid AS constraint_oid,
               fk.conname AS constraint_name,
               source.oid AS source_oid,
               source_namespace.nspname AS source_schema,
               source.relname AS source_table,
               source.relkind AS source_relkind,
               source.relispartition AS source_is_partition,
               EXISTS (
                   SELECT 1
                   FROM pg_inherits AS inheritance
                   WHERE inheritance.inhrelid = source.oid
                      OR inheritance.inhparent = source.oid
               ) AS source_has_inheritance,
               ARRAY(
                   SELECT source_column.attname
                   FROM unnest(fk.conkey) WITH ORDINALITY AS source_key(attnum, ordinality)
                   JOIN pg_attribute AS source_column
                     ON source_column.attrelid = source.oid
                    AND source_column.attnum = source_key.attnum
                   ORDER BY source_key.ordinality
               ) AS source_columns,
               target.oid AS target_oid,
               target.relkind AS target_relkind,
               target.relispartition AS target_is_partition,
               EXISTS (
                   SELECT 1
                   FROM pg_inherits AS inheritance
                   WHERE inheritance.inhrelid = target.oid
                      OR inheritance.inhparent = target.oid
               ) AS target_has_inheritance,
               ARRAY(
                   SELECT target_column.attname
                   FROM unnest(fk.confkey) WITH ORDINALITY AS target_key(attnum, ordinality)
                   JOIN pg_attribute AS target_column
                     ON target_column.attrelid = target.oid
                    AND target_column.attnum = target_key.attnum
                   ORDER BY target_key.ordinality
               ) AS target_columns,
               fk.convalidated AS validated,
               fk.condeferrable AS deferrable,
               fk.confdeltype AS delete_action
        FROM pg_constraint AS fk
        JOIN pg_class AS source ON source.oid = fk.conrelid
        JOIN pg_namespace AS source_namespace
          ON source_namespace.oid = source.relnamespace
        JOIN pg_class AS target ON target.oid = fk.confrelid
        WHERE fk.contype = 'f'
          AND fk.confrelid = 'storage.objects'::regclass
    )
    SELECT coalesce(
        jsonb_agg(to_jsonb(foreign_key) ORDER BY
            foreign_key.source_schema,
            foreign_key.source_table,
            foreign_key.constraint_name,
            foreign_key.constraint_oid),
        '[]'::jsonb
    )
    INTO v_before
    FROM foreign_keys AS foreign_key;

    FOR v_source IN
        SELECT reference
        FROM jsonb_array_elements(v_before) AS reference_rows(reference)
    LOOP
        IF jsonb_array_length(v_source.reference->'source_columns') <> 1
           OR v_source.reference->'target_columns' <> '["id"]'::jsonb
           OR v_source.reference->>'source_relkind' <> 'r'
           OR (v_source.reference->>'source_is_partition')::boolean
           OR (v_source.reference->>'source_has_inheritance')::boolean
           OR v_source.reference->>'target_relkind' <> 'r'
           OR (v_source.reference->>'target_is_partition')::boolean
           OR (v_source.reference->>'target_has_inheritance')::boolean
           OR v_source.reference->>'delete_action' <> 'a' THEN
            RAISE EXCEPTION
                'unsupported storage.objects foreign-key shape at %.% (constraint %); cleanup fails closed',
                v_source.reference->>'source_schema',
                v_source.reference->>'source_table',
                v_source.reference->>'constraint_name';
        END IF;
    END LOOP;

    -- Source relations come first.  An ALTER TABLE that already owns a source
    -- lock may then acquire the target and finish; cleanup never holds the target
    -- while waiting for that source, so the inverse ordering cannot deadlock.
    FOR v_source IN
        SELECT DISTINCT reference->>'source_schema' AS source_schema,
                        reference->>'source_table' AS source_table,
                        (reference->>'source_oid')::oid AS source_oid
        FROM jsonb_array_elements(v_before) AS reference_rows(reference)
        ORDER BY source_schema, source_table, source_oid
    LOOP
        BEGIN
            EXECUTE format(
                'LOCK TABLE %I.%I IN ACCESS SHARE MODE',
                v_source.source_schema,
                v_source.source_table
            );
        EXCEPTION
            WHEN undefined_table THEN
                RAISE EXCEPTION
                    'storage.objects foreign-key catalog changed while cleanup acquired source locks';
        END;
    END LOOP;

    LOCK TABLE storage.objects IN SHARE UPDATE EXCLUSIVE MODE;

    WITH foreign_keys AS (
        SELECT fk.oid AS constraint_oid,
               fk.conname AS constraint_name,
               source.oid AS source_oid,
               source_namespace.nspname AS source_schema,
               source.relname AS source_table,
               source.relkind AS source_relkind,
               source.relispartition AS source_is_partition,
               EXISTS (
                   SELECT 1
                   FROM pg_inherits AS inheritance
                   WHERE inheritance.inhrelid = source.oid
                      OR inheritance.inhparent = source.oid
               ) AS source_has_inheritance,
               ARRAY(
                   SELECT source_column.attname
                   FROM unnest(fk.conkey) WITH ORDINALITY AS source_key(attnum, ordinality)
                   JOIN pg_attribute AS source_column
                     ON source_column.attrelid = source.oid
                    AND source_column.attnum = source_key.attnum
                   ORDER BY source_key.ordinality
               ) AS source_columns,
               target.oid AS target_oid,
               target.relkind AS target_relkind,
               target.relispartition AS target_is_partition,
               EXISTS (
                   SELECT 1
                   FROM pg_inherits AS inheritance
                   WHERE inheritance.inhrelid = target.oid
                      OR inheritance.inhparent = target.oid
               ) AS target_has_inheritance,
               ARRAY(
                   SELECT target_column.attname
                   FROM unnest(fk.confkey) WITH ORDINALITY AS target_key(attnum, ordinality)
                   JOIN pg_attribute AS target_column
                     ON target_column.attrelid = target.oid
                    AND target_column.attnum = target_key.attnum
                   ORDER BY target_key.ordinality
               ) AS target_columns,
               fk.convalidated AS validated,
               fk.condeferrable AS deferrable,
               fk.confdeltype AS delete_action
        FROM pg_constraint AS fk
        JOIN pg_class AS source ON source.oid = fk.conrelid
        JOIN pg_namespace AS source_namespace
          ON source_namespace.oid = source.relnamespace
        JOIN pg_class AS target ON target.oid = fk.confrelid
        WHERE fk.contype = 'f'
          AND fk.confrelid = 'storage.objects'::regclass
    )
    SELECT coalesce(
        jsonb_agg(to_jsonb(foreign_key) ORDER BY
            foreign_key.source_schema,
            foreign_key.source_table,
            foreign_key.constraint_name,
            foreign_key.constraint_oid),
        '[]'::jsonb
    )
    INTO v_after
    FROM foreign_keys AS foreign_key;

    IF v_before IS DISTINCT FROM v_after THEN
        RAISE EXCEPTION
            'storage.objects foreign-key catalog changed while cleanup acquired locks';
    END IF;

    FOR v_source IN
        SELECT reference
        FROM jsonb_array_elements(v_after) AS reference_rows(reference)
    LOOP
        IF jsonb_array_length(v_source.reference->'source_columns') <> 1
           OR v_source.reference->'target_columns' <> '["id"]'::jsonb
           OR v_source.reference->>'source_relkind' <> 'r'
           OR (v_source.reference->>'source_is_partition')::boolean
           OR (v_source.reference->>'source_has_inheritance')::boolean
           OR v_source.reference->>'target_relkind' <> 'r'
           OR (v_source.reference->>'target_is_partition')::boolean
           OR (v_source.reference->>'target_has_inheritance')::boolean
           OR v_source.reference->>'delete_action' <> 'a' THEN
            RAISE EXCEPTION
                'unsupported storage.objects foreign-key shape at %.% (constraint %); cleanup fails closed',
                v_source.reference->>'source_schema',
                v_source.reference->>'source_table',
                v_source.reference->>'constraint_name';
        END IF;
    END LOOP;

    -- The row locks serialize every immediate FK KEY SHARE check.  They are
    -- acquired before the reference scan so a writer that commits while cleanup
    -- waits is visible to the following READ COMMITTED statements.
    PERFORM object_row.id
    FROM storage.objects AS object_row
    JOIN jsonb_to_recordset(p_candidates) AS candidate(
        object_id uuid,
        storage_provider text,
        bucket_name text,
        object_key text,
        provider_version_id text,
        content_hash text
    ) ON candidate.object_id = object_row.id
    ORDER BY object_row.id
    FOR UPDATE OF object_row;

    SELECT count(*)
    INTO v_existing_count
    FROM storage.objects AS object_row
    JOIN jsonb_to_recordset(p_candidates) AS candidate(
        object_id uuid,
        storage_provider text,
        bucket_name text,
        object_key text,
        provider_version_id text,
        content_hash text
    ) ON candidate.object_id = object_row.id;

    IF EXISTS (
        SELECT 1
        FROM storage.objects AS object_row
        JOIN jsonb_to_recordset(p_candidates) AS candidate(
            object_id uuid,
            storage_provider text,
            bucket_name text,
            object_key text,
            provider_version_id text,
            content_hash text
        ) ON candidate.object_id = object_row.id
        WHERE object_row.storage_provider IS DISTINCT FROM candidate.storage_provider
           OR object_row.bucket_name IS DISTINCT FROM candidate.bucket_name
           OR object_row.object_key IS DISTINCT FROM candidate.object_key
           OR object_row.provider_version_id IS DISTINCT FROM candidate.provider_version_id
           OR object_row.content_hash IS DISTINCT FROM candidate.content_hash
    ) THEN
        RAISE EXCEPTION
            'refusing to clean a storage object whose provider, bucket, key, provider version, or hash changed';
    END IF;

    FOR v_source IN
        SELECT reference->>'source_schema' AS source_schema,
               reference->>'source_table' AS source_table,
               reference->>'constraint_name' AS constraint_name,
               reference->'source_columns'->>0 AS source_column
        FROM jsonb_array_elements(v_after) AS reference_rows(reference)
        ORDER BY source_schema, source_table, constraint_name
    LOOP
        EXECUTE format(
            'SELECT EXISTS ('
            'SELECT 1 FROM %I.%I AS source_row '
            'WHERE source_row.%I = ANY ($1))',
            v_source.source_schema,
            v_source.source_table,
            v_source.source_column
        )
        INTO v_reference_exists
        USING v_candidate_ids;

        IF v_reference_exists THEN
            RAISE EXCEPTION
                'storage object cleanup is referenced by %.%.% (constraint %)',
                v_source.source_schema,
                v_source.source_table,
                v_source.source_column,
                v_source.constraint_name;
        END IF;
    END LOOP;

    -- DELETE is deliberately before the external-object boundary.  The caller's
    -- transaction remains open while bytes are removed: an external failure rolls
    -- this deletion back, while a trigger/FK rejection arrives before any bytes go.
    RETURN QUERY
    DELETE FROM storage.objects AS object_row
    USING jsonb_to_recordset(p_candidates) AS candidate(
        object_id uuid,
        storage_provider text,
        bucket_name text,
        object_key text,
        provider_version_id text,
        content_hash text
    )
    WHERE object_row.id = candidate.object_id
      AND object_row.storage_provider = candidate.storage_provider
      AND object_row.bucket_name = candidate.bucket_name
      AND object_row.object_key = candidate.object_key
      AND object_row.provider_version_id = candidate.provider_version_id
      AND object_row.content_hash = candidate.content_hash
    RETURNING object_row.*;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF v_deleted_count IS DISTINCT FROM v_existing_count THEN
        RAISE EXCEPTION 'a storage object changed before transactional cleanup deletion';
    END IF;

    SET CONSTRAINTS ALL IMMEDIATE;
    RETURN;
END;
$cleanup$;

REVOKE ALL ON FUNCTION storage.prepare_backtest_object_cleanup(jsonb) FROM PUBLIC;

COMMENT ON FUNCTION storage.prepare_backtest_object_cleanup(jsonb) IS
'Transaction-scoped, SECURITY DEFINER compensation for exact unreferenced objects in the canonical backtest-results namespace. Source FK locks precede the storage.objects target lock; exact rows are deleted before the external-object boundary and remain rollbackable until the caller commits.';
