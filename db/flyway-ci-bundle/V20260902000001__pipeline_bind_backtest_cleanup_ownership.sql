-- Backtest compensation is allowed only for rows that were atomically bound to
-- the live producing attempt when the storage row was first registered.  This
-- forward migration also closes the ADD FOREIGN KEY ... NOT VALID race left by
-- V20260902000000 without rewriting that already-applied migration.

CREATE TABLE storage.backtest_attempt_cleanup_capabilities (
    attempt_id uuid PRIMARY KEY
        REFERENCES backtest.run_attempts(id) ON DELETE CASCADE,
    run_id uuid NOT NULL
        REFERENCES backtest.runs(id),
    claim_token uuid NOT NULL,
    capability_hash character varying(64) NOT NULL UNIQUE
        CHECK (capability_hash ~ '^[0-9a-f]{64}$'),
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);

COMMENT ON TABLE storage.backtest_attempt_cleanup_capabilities IS
'Protected non-forgeable cleanup identity generated inside the transaction that creates an attempt. Application roles receive no direct read or mutation privilege.';

CREATE OR REPLACE FUNCTION storage.capture_backtest_attempt_cleanup_capability()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $attempt_capability$
DECLARE
    v_capability text;
BEGIN
    IF NEW.claim_token IS NULL THEN
        RETURN NEW;
    END IF;

    v_capability := encode(public.gen_random_bytes(32), 'hex');
    INSERT INTO storage.backtest_attempt_cleanup_capabilities(
        attempt_id,
        run_id,
        claim_token,
        capability_hash
    ) VALUES (
        NEW.id,
        NEW.run_id,
        NEW.claim_token,
        encode(public.digest(v_capability, 'sha256'), 'hex')
    );
    PERFORM set_config(
        'idea2strategy.backtest_attempt_cleanup_capability',
        v_capability,
        true
    );
    RETURN NEW;
END;
$attempt_capability$;

REVOKE ALL ON FUNCTION storage.capture_backtest_attempt_cleanup_capability() FROM PUBLIC;

CREATE TRIGGER capture_backtest_attempt_cleanup_capability
AFTER INSERT ON backtest.run_attempts
FOR EACH ROW
EXECUTE FUNCTION storage.capture_backtest_attempt_cleanup_capability();

CREATE TABLE storage.backtest_object_ownerships (
    object_id uuid PRIMARY KEY
        REFERENCES storage.objects(id) ON DELETE CASCADE,
    -- Do not add a redundant FK from run_id to backtest.runs.  Terminal
    -- publication holds that run row FOR UPDATE while this ownership row is
    -- registered and committed through its narrow storage transaction; an FK
    -- check on the second connection would self-deadlock.  The producing-attempt
    -- FK plus the definer trigger's exact attempt.run_id check proves the same
    -- relationship without a second lock edge.
    run_id uuid NOT NULL,
    producing_attempt_id uuid NOT NULL
        REFERENCES backtest.run_attempts(id),
    producing_claim_token uuid NOT NULL,
    cleanup_token_hash character varying(64) NOT NULL UNIQUE
        CHECK (cleanup_token_hash ~ '^[0-9a-f]{64}$'),
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);

CREATE INDEX ix_backtest_object_ownerships_run_attempt
    ON storage.backtest_object_ownerships(run_id, producing_attempt_id);

COMMENT ON TABLE storage.backtest_object_ownerships IS
'Migration-owner ledger binding a newly registered canonical backtest object to its exact producing run and attempt. Application roles receive no direct mutation privilege.';

CREATE OR REPLACE FUNCTION storage.capture_backtest_object_ownership()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $capture$
DECLARE
    v_attempt_id uuid;
    v_attempt_text text;
    v_claim_token uuid;
    v_claim_text text;
    v_attempt_capability text;
    v_cleanup_token_hash text;
    v_key_run_id uuid;
    v_run_id uuid;
    v_run_text text;
BEGIN
    v_run_text := nullif(current_setting('idea2strategy.backtest_run_id', true), '');
    v_attempt_text := nullif(current_setting('idea2strategy.backtest_attempt_id', true), '');
    v_claim_text := nullif(current_setting('idea2strategy.backtest_claim_token', true), '');
    v_attempt_capability := nullif(
        current_setting('idea2strategy.backtest_attempt_cleanup_capability', true),
        ''
    );
    v_cleanup_token_hash := nullif(
        current_setting('idea2strategy.backtest_cleanup_token_hash', true),
        ''
    );

    -- Other producers still register storage rows through their own policy.  A
    -- backtest row is cleanup-owned only when the engine deliberately supplies
    -- all four transaction-local ownership values before the INSERT.
    IF v_run_text IS NULL
       AND v_attempt_text IS NULL
       AND v_claim_text IS NULL
       AND v_attempt_capability IS NULL
       AND v_cleanup_token_hash IS NULL THEN
        RETURN NEW;
    END IF;
    IF v_run_text IS NULL
       OR v_attempt_text IS NULL
       OR v_claim_text IS NULL
       OR v_attempt_capability IS NULL
       OR v_cleanup_token_hash IS NULL THEN
        RAISE EXCEPTION
            'backtest object producer ownership requires run, attempt, claim, and cleanup token together';
    END IF;
    IF v_cleanup_token_hash !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION
            'backtest object producer cleanup token hash is invalid';
    END IF;

    BEGIN
        v_run_id := v_run_text::uuid;
        v_attempt_id := v_attempt_text::uuid;
        v_claim_token := v_claim_text::uuid;
        v_key_run_id := substring(
            NEW.object_key FROM
            '^backtest-results/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/'
        )::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION
                'backtest object producer ownership contains an invalid UUID';
    END;

    IF v_key_run_id IS NULL OR v_key_run_id IS DISTINCT FROM v_run_id THEN
        RAISE EXCEPTION
            'backtest object producer run does not match its canonical object key';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM backtest.run_attempts AS attempt
        WHERE attempt.id = v_attempt_id
          AND attempt.run_id = v_run_id
          AND attempt.claim_token = v_claim_token
          AND attempt.status = 'RUNNING'
          AND attempt.claim_expires_at > clock_timestamp()
          AND EXISTS (
                SELECT 1
                FROM storage.backtest_attempt_cleanup_capabilities AS capability
                WHERE capability.attempt_id = attempt.id
                  AND capability.run_id = attempt.run_id
                  AND capability.claim_token = attempt.claim_token
                  AND capability.capability_hash = encode(
                        public.digest(v_attempt_capability, 'sha256'),
                        'hex'
                  )
          )
    ) THEN
        RAISE EXCEPTION
            'backtest object producer ownership requires the current live attempt claim';
    END IF;

    INSERT INTO storage.backtest_object_ownerships(
        object_id,
        run_id,
        producing_attempt_id,
        producing_claim_token,
        cleanup_token_hash
    ) VALUES (
        NEW.id,
        v_run_id,
        v_attempt_id,
        v_claim_token,
        v_cleanup_token_hash
    );
    RETURN NEW;
END;
$capture$;

REVOKE ALL ON FUNCTION storage.capture_backtest_object_ownership() FROM PUBLIC;

CREATE TRIGGER capture_backtest_object_ownership
AFTER INSERT ON storage.objects
FOR EACH ROW
EXECUTE FUNCTION storage.capture_backtest_object_ownership();

-- PostgreSQL reserves event-trigger administration to superusers.  The deployed
-- Flyway identity is the RDS-managed main user (`idea2strategy_admin`), which AWS
-- assigns `rds_superuser`; local/rehearsal PostgreSQL uses a real superuser.  Fail
-- here with an actionable contract message if deployment ever drifts to a weaker
-- migration identity rather than reaching CREATE EVENT TRIGGER ambiguously.
DO $event_trigger_capability$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS caller
        WHERE caller.rolname = current_user
          AND (
                caller.rolsuper
                OR EXISTS (
                    SELECT 1
                    FROM pg_roles AS rds_role
                    WHERE rds_role.rolname = 'rds_superuser'
                      AND pg_has_role(caller.oid, rds_role.oid, 'MEMBER')
                )
          )
    ) THEN
        RAISE EXCEPTION
            'storage FK safety requires Flyway to use a PostgreSQL superuser or the RDS main/rds_superuser role';
    END IF;
END;
$event_trigger_capability$;

CREATE OR REPLACE FUNCTION storage.reject_unvalidated_storage_object_fks()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $reject$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_event_trigger_ddl_commands() AS command
        JOIN pg_constraint AS fk
          ON fk.oid = command.objid
          OR fk.conrelid = command.objid
        WHERE fk.contype = 'f'
          AND fk.confrelid = 'storage.objects'::regclass
          AND NOT fk.convalidated
    ) THEN
        RAISE EXCEPTION
            'unvalidated foreign keys targeting storage.objects are forbidden';
    END IF;
END;
$reject$;

REVOKE ALL ON FUNCTION storage.reject_unvalidated_storage_object_fks() FROM PUBLIC;

CREATE EVENT TRIGGER storage_reject_unvalidated_object_fks
ON ddl_command_end
WHEN TAG IN ('ALTER TABLE', 'CREATE TABLE', 'CREATE TABLE AS')
EXECUTE FUNCTION storage.reject_unvalidated_storage_object_fks();

COMMENT ON EVENT TRIGGER storage_reject_unvalidated_object_fks IS
'Rejects only DDL that leaves an unvalidated foreign key targeting storage.objects. AWS RDS major upgrades require this event trigger to be dropped before upgrade and recreated immediately afterwards; see db migration README.';

CREATE OR REPLACE FUNCTION storage.reissue_backtest_object_cleanup(
    p_candidate jsonb,
    p_new_cleanup_token_hash text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
SET lock_timeout = '5s'
AS $reissue$
DECLARE
    v_attempt_capability text;
    v_attempt_id uuid;
    v_attempt_text text;
    v_candidate record;
    v_claim_text text;
    v_claim_token uuid;
    v_reference_exists boolean;
    v_run_id uuid;
    v_run_text text;
    v_source record;
BEGIN
    IF jsonb_typeof(p_candidate) IS DISTINCT FROM 'object'
       OR (
            SELECT array_agg(key ORDER BY key)
            FROM jsonb_object_keys(p_candidate) AS keys(key)
          ) IS DISTINCT FROM ARRAY[
              'bucket_name',
              'content_hash',
              'object_id',
              'object_key',
              'provider_version_id',
              'storage_provider'
          ]::text[] THEN
        RAISE EXCEPTION 'backtest object cleanup reissue candidate shape is invalid';
    END IF;
    IF p_new_cleanup_token_hash !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'backtest object cleanup reissue token hash is invalid';
    END IF;

    SELECT *
    INTO v_candidate
    FROM jsonb_to_record(p_candidate) AS candidate(
        object_id uuid,
        storage_provider text,
        bucket_name text,
        object_key text,
        provider_version_id text,
        content_hash text
    );
    IF v_candidate.object_id IS NULL
       OR nullif(v_candidate.storage_provider, '') IS NULL
       OR nullif(v_candidate.bucket_name, '') IS NULL
       OR nullif(v_candidate.object_key, '') IS NULL
       OR nullif(v_candidate.provider_version_id, '') IS NULL
       OR v_candidate.content_hash !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'backtest object cleanup reissue requires an exact object identity';
    END IF;

    v_run_text := nullif(current_setting('idea2strategy.backtest_run_id', true), '');
    v_attempt_text := nullif(current_setting('idea2strategy.backtest_attempt_id', true), '');
    v_claim_text := nullif(current_setting('idea2strategy.backtest_claim_token', true), '');
    v_attempt_capability := nullif(
        current_setting('idea2strategy.backtest_attempt_cleanup_capability', true),
        ''
    );
    IF v_run_text IS NULL
       OR v_attempt_text IS NULL
       OR v_claim_text IS NULL
       OR v_attempt_capability IS NULL THEN
        RAISE EXCEPTION 'backtest object cleanup reissue requires current attempt capability context';
    END IF;
    BEGIN
        v_run_id := v_run_text::uuid;
        v_attempt_id := v_attempt_text::uuid;
        v_claim_token := v_claim_text::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'backtest object cleanup reissue attempt context is invalid';
    END;

    -- Lock the live successor attempt, rather than its run row.  Attempt creation
    -- always locks the run and then the previous latest attempt; therefore this
    -- lock serializes expiry/reclaim and successor insertion without deadlocking
    -- terminal publication, which already owns the run row on its outer UOW while
    -- storage registration commits through a separate narrow UOW.
    PERFORM caller.id
    FROM backtest.run_attempts AS caller
    JOIN storage.backtest_attempt_cleanup_capabilities AS capability
      ON capability.attempt_id = caller.id
     AND capability.run_id = caller.run_id
     AND capability.claim_token = caller.claim_token
    WHERE caller.id = v_attempt_id
      AND caller.run_id = v_run_id
      AND caller.claim_token = v_claim_token
      AND caller.status = 'RUNNING'
      AND caller.claim_expires_at > clock_timestamp()
      AND capability.capability_hash = encode(
            public.digest(v_attempt_capability, 'sha256'),
            'hex'
      )
      AND NOT EXISTS (
            SELECT 1
            FROM backtest.run_attempts AS newer
            WHERE newer.run_id = caller.run_id
              AND newer.attempt_number > caller.attempt_number
      )
    FOR UPDATE OF caller;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'backtest object cleanup reissue claim is wrong, expired, or superseded';
    END IF;

    PERFORM object_row.id
    FROM storage.objects AS object_row
    WHERE object_row.id = v_candidate.object_id
      AND object_row.storage_provider = v_candidate.storage_provider
      AND object_row.bucket_name = v_candidate.bucket_name
      AND object_row.object_key = v_candidate.object_key
      AND object_row.provider_version_id = v_candidate.provider_version_id
      AND object_row.content_hash = v_candidate.content_hash
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'backtest object cleanup reissue identity changed';
    END IF;

    IF NOT EXISTS (
        WITH RECURSIVE caller_lineage AS (
            SELECT attempt.id, attempt.previous_attempt_id, 0 AS depth
            FROM backtest.run_attempts AS attempt
            WHERE attempt.id = v_attempt_id
            UNION ALL
            SELECT predecessor.id, predecessor.previous_attempt_id, lineage.depth + 1
            FROM backtest.run_attempts AS predecessor
            JOIN caller_lineage AS lineage
              ON predecessor.id = lineage.previous_attempt_id
        )
        SELECT 1
        FROM storage.backtest_object_ownerships AS ownership
        JOIN backtest.run_attempts AS producer
          ON producer.id = ownership.producing_attempt_id
         AND producer.run_id = ownership.run_id
         AND producer.claim_token = ownership.producing_claim_token
        JOIN caller_lineage AS lineage
          ON lineage.id = producer.id
        WHERE ownership.object_id = v_candidate.object_id
          AND ownership.run_id = v_run_id
          AND (
                lineage.depth = 0
                OR producer.status IN ('FAILED', 'CANCELLED', 'SKIPPED')
          )
    ) THEN
        -- Exact immutable objects are intentionally reusable across runs.  No
        -- ownership mutation and a NULL result means this caller may publish a
        -- reference, but receives no capability to compensate someone else's
        -- bytes.  This also covers pre-migration/unowned reconciliations.
        RETURN NULL;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM storage.objects AS object_row
        WHERE object_row.id = v_candidate.object_id
          AND (
                object_row.legal_hold
                OR (
                    object_row.retention_until IS NOT NULL
                    AND object_row.retention_until > clock_timestamp()
                )
          )
    ) THEN
        RETURN NULL;
    END IF;

    FOR v_source IN
        SELECT source_namespace.nspname AS source_schema,
               source.relname AS source_table,
               source_column.attname AS source_column,
               fk.conname AS constraint_name,
               fk.convalidated AS validated,
               cardinality(fk.conkey) AS source_column_count,
               target_column.attname AS target_column,
               source.relkind AS source_relkind,
               source.relispartition AS source_is_partition
        FROM pg_constraint AS fk
        JOIN pg_class AS source ON source.oid = fk.conrelid
        JOIN pg_namespace AS source_namespace
          ON source_namespace.oid = source.relnamespace
        JOIN pg_attribute AS source_column
          ON source_column.attrelid = source.oid
         AND source_column.attnum = fk.conkey[1]
        JOIN pg_attribute AS target_column
          ON target_column.attrelid = fk.confrelid
         AND target_column.attnum = fk.confkey[1]
        WHERE fk.contype = 'f'
          AND fk.confrelid = 'storage.objects'::regclass
        ORDER BY source_namespace.nspname, source.relname, fk.conname
    LOOP
        IF NOT v_source.validated THEN
            RAISE EXCEPTION 'unvalidated foreign key targets storage.objects; reissue fails closed';
        END IF;
        IF v_source.source_schema = 'storage'
           AND v_source.source_table = 'backtest_object_ownerships'
           AND v_source.source_column = 'object_id' THEN
            CONTINUE;
        END IF;
        IF v_source.source_column_count <> 1
           OR v_source.target_column <> 'id'
           OR v_source.source_relkind <> 'r'
           OR v_source.source_is_partition THEN
            RAISE EXCEPTION 'unsupported storage.objects foreign-key shape; reissue fails closed';
        END IF;
        EXECUTE format(
            'SELECT EXISTS (SELECT 1 FROM %I.%I WHERE %I = $1)',
            v_source.source_schema,
            v_source.source_table,
            v_source.source_column
        ) INTO v_reference_exists USING v_candidate.object_id;
        IF v_reference_exists THEN
            -- A committed reference makes the existing object non-compensable.
            -- Preserve it and do not rotate its cleanup capability.
            RETURN NULL;
        END IF;
    END LOOP;

    UPDATE storage.backtest_object_ownerships
    SET producing_attempt_id = v_attempt_id,
        producing_claim_token = v_claim_token,
        cleanup_token_hash = p_new_cleanup_token_hash
    WHERE object_id = v_candidate.object_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'backtest object cleanup reissue ownership vanished';
    END IF;
    RETURN v_candidate.object_id;
END;
$reissue$;

REVOKE ALL ON FUNCTION storage.reissue_backtest_object_cleanup(jsonb, text) FROM PUBLIC;

CREATE OR REPLACE FUNCTION storage.prepare_backtest_object_cleanup(p_candidates jsonb)
RETURNS SETOF storage.objects
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
SET lock_timeout = '5s'
AS $cleanup$
DECLARE
    v_attempt_id uuid;
    v_attempt_capability text;
    v_attempt_text text;
    v_candidate_count integer;
    v_candidate_ids uuid[];
    v_claim_token uuid;
    v_claim_text text;
    v_deleted_count integer;
    v_existing_count integer;
    v_foreign_keys jsonb;
    v_lock_acquired boolean := false;
    v_lock_attempt integer;
    v_reference_exists boolean;
    v_relation record;
    v_run_id uuid;
    v_run_text text;
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
                  'cleanup_token',
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
            content_hash text,
            cleanup_token text
        )
        WHERE candidate.object_id IS NULL
           OR nullif(candidate.storage_provider, '') IS NULL
           OR nullif(candidate.bucket_name, '') IS NULL
           OR nullif(candidate.object_key, '') IS NULL
           OR nullif(candidate.provider_version_id, '') IS NULL
           OR candidate.content_hash !~ '^[0-9a-f]{64}$'
           OR candidate.cleanup_token !~ '^[0-9a-f]{64}$'
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

    -- Target-first locking prevents a new ADD FK from becoming visible between
    -- catalog inspection and DELETE.  Every durable table is then locked in a
    -- DML-compatible mode using NOWAIT.  If DDL already owns any possible source
    -- and is waiting for the target, the PL/pgSQL exception subtransaction rolls
    -- back immediately, releasing the target before a bounded retry.
    FOR v_lock_attempt IN 1..12 LOOP
        v_lock_acquired := false;
        BEGIN
            LOCK TABLE storage.objects
                IN SHARE UPDATE EXCLUSIVE MODE NOWAIT;

            FOR v_relation IN
                SELECT relation.oid AS relation_oid,
                       namespace.nspname AS relation_schema,
                       relation.relname AS relation_name
                FROM pg_class AS relation
                JOIN pg_namespace AS namespace
                  ON namespace.oid = relation.relnamespace
                WHERE relation.relkind IN ('r', 'p')
                  AND relation.oid <> 'storage.objects'::regclass
                  AND namespace.nspname <> 'information_schema'
                  AND namespace.nspname !~ '^pg_(catalog|toast|temp_)'
                ORDER BY namespace.nspname, relation.relname, relation.oid
            LOOP
                BEGIN
                    EXECUTE format(
                        'LOCK TABLE %I.%I IN SHARE UPDATE EXCLUSIVE MODE NOWAIT',
                        v_relation.relation_schema,
                        v_relation.relation_name
                    );
                EXCEPTION
                    WHEN undefined_table THEN
                        RAISE lock_not_available USING MESSAGE =
                            'a possible storage.objects foreign-key source changed during cleanup locking';
                END;
            END LOOP;
            v_lock_acquired := true;
        EXCEPTION
            WHEN lock_not_available OR deadlock_detected THEN
                v_lock_acquired := false;
        END;

        EXIT WHEN v_lock_acquired;
        IF v_lock_attempt = 12 THEN
            RAISE lock_not_available USING MESSAGE =
                'backtest object cleanup exhausted 12 bounded DDL-lock retries before external deletion';
        END IF;
        PERFORM pg_sleep(least(0.01 * v_lock_attempt, 0.10));
    END LOOP;

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
    INTO v_foreign_keys
    FROM foreign_keys AS foreign_key;

    FOR v_source IN
        SELECT reference
        FROM jsonb_array_elements(v_foreign_keys) AS reference_rows(reference)
    LOOP
        IF NOT (v_source.reference->>'validated')::boolean THEN
            RAISE EXCEPTION
                'unvalidated foreign key %.% (constraint %) targets storage.objects; cleanup fails closed',
                v_source.reference->>'source_schema',
                v_source.reference->>'source_table',
                v_source.reference->>'constraint_name';
        END IF;

        IF jsonb_array_length(v_source.reference->'source_columns') <> 1
           OR v_source.reference->'target_columns' <> '["id"]'::jsonb
           OR v_source.reference->>'source_relkind' <> 'r'
           OR (v_source.reference->>'source_is_partition')::boolean
           OR (v_source.reference->>'source_has_inheritance')::boolean
           OR v_source.reference->>'target_relkind' <> 'r'
           OR (v_source.reference->>'target_is_partition')::boolean
           OR (v_source.reference->>'target_has_inheritance')::boolean
           OR (
                v_source.reference->>'delete_action' <> 'a'
                AND NOT (
                    v_source.reference->>'source_schema' = 'storage'
                    AND v_source.reference->>'source_table' = 'backtest_object_ownerships'
                    AND v_source.reference->'source_columns' = '["object_id"]'::jsonb
                    AND v_source.reference->>'delete_action' = 'c'
                )
           ) THEN
            RAISE EXCEPTION
                'unsupported storage.objects foreign-key shape at %.% (constraint %); cleanup fails closed',
                v_source.reference->>'source_schema',
                v_source.reference->>'source_table',
                v_source.reference->>'constraint_name';
        END IF;
    END LOOP;

    v_run_text := nullif(current_setting('idea2strategy.backtest_run_id', true), '');
    v_attempt_text := nullif(current_setting('idea2strategy.backtest_attempt_id', true), '');
    v_claim_text := nullif(current_setting('idea2strategy.backtest_claim_token', true), '');
    v_attempt_capability := nullif(
        current_setting('idea2strategy.backtest_attempt_cleanup_capability', true),
        ''
    );
    IF v_run_text IS NULL
       OR v_attempt_text IS NULL
       OR v_claim_text IS NULL
       OR v_attempt_capability IS NULL THEN
        RAISE EXCEPTION
            'backtest object cleanup requires current producer ownership claim context';
    END IF;
    BEGIN
        v_run_id := v_run_text::uuid;
        v_attempt_id := v_attempt_text::uuid;
        v_claim_token := v_claim_text::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION
                'backtest object cleanup producer ownership claim contains an invalid UUID';
    END;

    -- Attempt creation/reclaim locks the run row first.  Holding the same row
    -- through external deletion fences a successor attempt from appearing after
    -- the stale-predecessor check below.
    PERFORM run_row.id
    FROM backtest.runs AS run_row
    WHERE run_row.id = v_run_id
    FOR UPDATE;

    IF NOT FOUND OR NOT EXISTS (
        SELECT 1
        FROM backtest.run_attempts AS caller
        WHERE caller.id = v_attempt_id
          AND caller.run_id = v_run_id
          AND caller.claim_token = v_claim_token
          AND EXISTS (
                SELECT 1
                FROM storage.backtest_attempt_cleanup_capabilities AS capability
                WHERE capability.attempt_id = caller.id
                  AND capability.run_id = caller.run_id
                  AND capability.claim_token = caller.claim_token
                  AND capability.capability_hash = encode(
                        public.digest(v_attempt_capability, 'sha256'),
                        'hex'
                  )
          )
          AND (
                (
                    caller.status = 'RUNNING'
                    AND caller.claim_expires_at > clock_timestamp()
                )
                OR caller.status IN ('SUCCEEDED', 'FAILED', 'CANCELLED', 'SKIPPED')
          )
          AND NOT EXISTS (
                SELECT 1
                FROM backtest.run_attempts AS successor
                WHERE successor.run_id = caller.run_id
                  AND successor.attempt_number > caller.attempt_number
          )
    ) THEN
        RAISE EXCEPTION
            'backtest object cleanup claim is wrong, expired, stale, or superseded';
    END IF;

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
        WHERE object_row.legal_hold
           OR object_row.retention_until > clock_timestamp()
    ) THEN
        RAISE EXCEPTION
            'backtest object cleanup is blocked by legal hold or unexpired retention';
    END IF;

    IF (
        WITH RECURSIVE caller_lineage AS (
            SELECT attempt.id, attempt.previous_attempt_id
            FROM backtest.run_attempts AS attempt
            WHERE attempt.id = v_attempt_id
            UNION ALL
            SELECT predecessor.id, predecessor.previous_attempt_id
            FROM backtest.run_attempts AS predecessor
            JOIN caller_lineage AS lineage
              ON predecessor.id = lineage.previous_attempt_id
        )
        SELECT count(*)
        FROM storage.objects AS object_row
        JOIN jsonb_to_recordset(p_candidates) AS candidate(
            object_id uuid,
            storage_provider text,
            bucket_name text,
            object_key text,
            provider_version_id text,
            content_hash text,
            cleanup_token text
        ) ON candidate.object_id = object_row.id
        JOIN storage.backtest_object_ownerships AS ownership
          ON ownership.object_id = object_row.id
        JOIN backtest.run_attempts AS producer
          ON producer.id = ownership.producing_attempt_id
         AND producer.run_id = ownership.run_id
         AND producer.claim_token = ownership.producing_claim_token
        WHERE ownership.run_id = v_run_id
          AND ownership.cleanup_token_hash = encode(
                public.digest(candidate.cleanup_token, 'sha256'),
                'hex'
          )
          AND ownership.producing_attempt_id IN (
                SELECT lineage.id FROM caller_lineage AS lineage
          )
    ) IS DISTINCT FROM v_existing_count THEN
        RAISE EXCEPTION
            'backtest object cleanup candidate lacks exact producer ownership in the caller lineage';
    END IF;

    FOR v_source IN
        SELECT reference->>'source_schema' AS source_schema,
               reference->>'source_table' AS source_table,
               reference->>'constraint_name' AS constraint_name,
               reference->'source_columns'->>0 AS source_column
        FROM jsonb_array_elements(v_foreign_keys) AS reference_rows(reference)
        WHERE NOT (
            reference->>'source_schema' = 'storage'
            AND reference->>'source_table' = 'backtest_object_ownerships'
            AND reference->'source_columns' = '["object_id"]'::jsonb
        )
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
'Transaction-scoped cleanup for exact backtest objects owned by the caller attempt lineage. Target-first NOWAIT retries serialize every durable FK source; unvalidated constraints, legal holds, and live retention always fail before external deletion.';
