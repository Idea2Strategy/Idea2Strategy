-- Runtime backtest workers may publish only through the staged-object lifecycle.
-- Keep the already-hardened
-- cleanup implementations from V20260902000001, but put a direct-successor gate
-- in front of them.  Applied migrations remain untouched.

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

    -- Non-backtest producers supply no attempt context and remain outside this
    -- ledger.  A backtest registration always supplies all four attempt fields.
    -- The cleanup token alone is optional: provider-reconciled bytes that have no
    -- authoritative row are registered for reading, but deliberately stay unowned.
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
       OR v_attempt_capability IS NULL THEN
        RAISE EXCEPTION
            'backtest object registration requires run, attempt, claim, and attempt capability together';
    END IF;
    IF v_cleanup_token_hash IS NOT NULL
       AND v_cleanup_token_hash !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'backtest object producer cleanup token hash is invalid';
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
            RAISE EXCEPTION 'backtest object producer ownership contains an invalid UUID';
    END;

    IF v_key_run_id IS NULL OR v_key_run_id IS DISTINCT FROM v_run_id THEN
        RAISE EXCEPTION 'backtest object producer run does not match its canonical object key';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM backtest.run_attempts AS attempt
        JOIN storage.backtest_attempt_cleanup_capabilities AS capability
          ON capability.attempt_id = attempt.id
         AND capability.run_id = attempt.run_id
         AND capability.claim_token = attempt.claim_token
        WHERE attempt.id = v_attempt_id
          AND attempt.run_id = v_run_id
          AND attempt.claim_token = v_claim_token
          AND attempt.status = 'RUNNING'
          AND attempt.claim_expires_at > clock_timestamp()
          AND capability.capability_hash = encode(
                public.digest(v_attempt_capability, 'sha256'),
                'hex'
          )
    ) THEN
        RAISE EXCEPTION 'backtest object registration requires the current live attempt claim';
    END IF;

    IF v_cleanup_token_hash IS NULL THEN
        RETURN NEW;
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

ALTER FUNCTION storage.reissue_backtest_object_cleanup(jsonb, text)
    RENAME TO reissue_backtest_object_cleanup_recursive_legacy;
ALTER FUNCTION storage.prepare_backtest_object_cleanup(jsonb)
    RENAME TO prepare_backtest_object_cleanup_recursive_legacy;

REVOKE ALL ON FUNCTION
    storage.reissue_backtest_object_cleanup_recursive_legacy(jsonb, text)
    FROM PUBLIC;
REVOKE ALL ON FUNCTION
    storage.prepare_backtest_object_cleanup_recursive_legacy(jsonb)
    FROM PUBLIC;

DO $revoke_legacy_cleanup$
DECLARE
    v_role text;
BEGIN
    FOREACH v_role IN ARRAY ARRAY[
        'idea2strategy_backend',
        'idea2strategy_batch',
        'idea2strategy_trading',
        'idea2strategy_backtest',
        'idea2strategy_pipeline'
    ] LOOP
        IF to_regrole(v_role) IS NOT NULL THEN
            EXECUTE format(
                'REVOKE ALL ON FUNCTION storage.reissue_backtest_object_cleanup_recursive_legacy(jsonb, text) FROM %I',
                v_role
            );
            EXECUTE format(
                'REVOKE ALL ON FUNCTION storage.prepare_backtest_object_cleanup_recursive_legacy(jsonb) FROM %I',
                v_role
            );
        END IF;
    END LOOP;
END;
$revoke_legacy_cleanup$;

CREATE FUNCTION storage.reissue_backtest_object_cleanup(
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
    v_attempt_id uuid;
    v_attempt_text text;
    v_candidate_id uuid;
    v_owner_attempt_id uuid;
    v_previous_attempt_id uuid;
    v_run_id uuid;
    v_run_text text;
BEGIN
    -- Preserve the legacy function's closed input contract before inspecting the
    -- protected ownership ledger.
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

    v_attempt_text := nullif(current_setting('idea2strategy.backtest_attempt_id', true), '');
    v_run_text := nullif(current_setting('idea2strategy.backtest_run_id', true), '');
    IF v_attempt_text IS NULL OR v_run_text IS NULL THEN
        RAISE EXCEPTION 'backtest object cleanup reissue requires current attempt capability context';
    END IF;
    BEGIN
        v_attempt_id := v_attempt_text::uuid;
        v_run_id := v_run_text::uuid;
        v_candidate_id := (p_candidate->>'object_id')::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'backtest object cleanup reissue attempt context is invalid';
    END;

    SELECT attempt.previous_attempt_id
    INTO v_previous_attempt_id
    FROM backtest.run_attempts AS attempt
    WHERE attempt.id = v_attempt_id
      AND attempt.run_id = v_run_id;

    SELECT ownership.producing_attempt_id
    INTO v_owner_attempt_id
    FROM storage.backtest_object_ownerships AS ownership
    WHERE ownership.object_id = v_candidate_id
      AND ownership.run_id = v_run_id;

    -- An exact unowned object, an unrelated object, and an older ancestor are all
    -- reusable immutable bytes, but none may be adopted for compensation.
    IF v_owner_attempt_id IS NULL
       OR v_owner_attempt_id NOT IN (v_attempt_id, v_previous_attempt_id) THEN
        RETURN NULL;
    END IF;

    RETURN storage.reissue_backtest_object_cleanup_recursive_legacy(
        p_candidate,
        p_new_cleanup_token_hash
    );
END;
$reissue$;

REVOKE ALL ON FUNCTION storage.reissue_backtest_object_cleanup(jsonb, text) FROM PUBLIC;

CREATE FUNCTION storage.prepare_backtest_object_cleanup(p_candidates jsonb)
RETURNS SETOF storage.objects
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
SET lock_timeout = '5s'
AS $cleanup$
DECLARE
    v_attempt_id uuid;
    v_attempt_text text;
    v_previous_attempt_id uuid;
    v_run_id uuid;
    v_run_text text;
BEGIN
    IF jsonb_typeof(p_candidates) IS DISTINCT FROM 'array' THEN
        RETURN QUERY
        SELECT *
        FROM storage.prepare_backtest_object_cleanup_recursive_legacy(p_candidates);
        RETURN;
    END IF;

    v_attempt_text := nullif(current_setting('idea2strategy.backtest_attempt_id', true), '');
    v_run_text := nullif(current_setting('idea2strategy.backtest_run_id', true), '');
    IF v_attempt_text IS NULL OR v_run_text IS NULL THEN
        RAISE EXCEPTION 'backtest object cleanup requires current producer ownership claim context';
    END IF;
    BEGIN
        v_attempt_id := v_attempt_text::uuid;
        v_run_id := v_run_text::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'backtest object cleanup producer ownership claim contains an invalid UUID';
    END;

    SELECT attempt.previous_attempt_id
    INTO v_previous_attempt_id
    FROM backtest.run_attempts AS attempt
    WHERE attempt.id = v_attempt_id
      AND attempt.run_id = v_run_id;

    IF EXISTS (
        SELECT 1
        FROM jsonb_to_recordset(p_candidates) AS candidate(object_id uuid)
        JOIN storage.backtest_object_ownerships AS ownership
          ON ownership.object_id = candidate.object_id
        WHERE ownership.run_id = v_run_id
          AND ownership.producing_attempt_id NOT IN (
                v_attempt_id,
                v_previous_attempt_id
          )
    ) THEN
        RAISE EXCEPTION
            'backtest object cleanup candidate lacks exact producer ownership by the attempt or its immediate successor';
    END IF;

    RETURN QUERY
    SELECT *
    FROM storage.prepare_backtest_object_cleanup_recursive_legacy(p_candidates);
END;
$cleanup$;

REVOKE ALL ON FUNCTION storage.prepare_backtest_object_cleanup(jsonb) FROM PUBLIC;

CREATE FUNCTION storage.register_backtest_object(p_object jsonb)
RETURNS SETOF storage.objects
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $register$
DECLARE
    v_object record;
    v_registered storage.objects%ROWTYPE;
BEGIN
    IF jsonb_typeof(p_object) IS DISTINCT FROM 'object'
       OR (
            SELECT array_agg(key ORDER BY key)
            FROM jsonb_object_keys(p_object) AS keys(key)
          ) IS DISTINCT FROM ARRAY[
              'bucket_name', 'byte_size', 'compression_codec', 'content_hash',
              'created_at', 'deleted_at', 'encryption_key_ref', 'file_format', 'id',
              'legal_hold', 'media_type', 'object_key', 'period_end', 'period_start',
              'provider_version_id', 'quarantined_at', 'retention_policy_version',
              'retention_until', 'row_count', 'schema_version', 'status',
              'storage_provider', 'superseded_at', 'verified_at'
          ]::text[] THEN
        RAISE EXCEPTION 'backtest storage registration document shape is invalid';
    END IF;

    SELECT *
    INTO v_object
    FROM jsonb_to_record(p_object) AS object_document(
        id uuid,
        status text,
        storage_provider text,
        bucket_name text,
        object_key text,
        provider_version_id text,
        content_hash text,
        byte_size bigint,
        file_format text,
        compression_codec text,
        media_type text,
        schema_version text,
        row_count bigint,
        period_start timestamp with time zone,
        period_end timestamp with time zone,
        encryption_key_ref text,
        retention_policy_version text,
        retention_until timestamp with time zone,
        legal_hold boolean,
        created_at timestamp with time zone,
        verified_at timestamp with time zone,
        quarantined_at timestamp with time zone,
        superseded_at timestamp with time zone,
        deleted_at timestamp with time zone
    );
    IF v_object.id IS NULL
       OR v_object.status IS DISTINCT FROM 'STAGED'
       OR nullif(v_object.storage_provider, '') IS NULL
       OR nullif(v_object.bucket_name, '') IS NULL
       OR nullif(v_object.object_key, '') IS NULL
       OR nullif(v_object.provider_version_id, '') IS NULL
       OR v_object.content_hash !~ '^[0-9a-f]{64}$'
       OR v_object.byte_size < 0
       OR nullif(v_object.file_format, '') IS NULL
       OR nullif(v_object.compression_codec, '') IS NULL
       OR nullif(v_object.media_type, '') IS NULL
       OR nullif(v_object.schema_version, '') IS NULL
       OR (v_object.row_count IS NOT NULL AND v_object.row_count < 0)
       OR (v_object.period_start IS NOT NULL AND v_object.period_end < v_object.period_start)
       OR nullif(v_object.retention_policy_version, '') IS NULL
       OR v_object.legal_hold IS NULL
       OR v_object.created_at IS NULL
       OR v_object.verified_at IS NOT NULL
       OR v_object.quarantined_at IS NOT NULL
       OR v_object.superseded_at IS NOT NULL
       OR v_object.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'backtest storage registration requires one exact STAGED object';
    END IF;
    IF nullif(current_setting('idea2strategy.backtest_run_id', true), '') IS NULL
       OR nullif(current_setting('idea2strategy.backtest_attempt_id', true), '') IS NULL
       OR nullif(current_setting('idea2strategy.backtest_claim_token', true), '') IS NULL
       OR nullif(current_setting('idea2strategy.backtest_attempt_cleanup_capability', true), '') IS NULL THEN
        RAISE EXCEPTION 'backtest storage registration requires current attempt context';
    END IF;

    INSERT INTO storage.objects(
        id, status, storage_provider, bucket_name, object_key,
        provider_version_id, content_hash, byte_size, file_format,
        compression_codec, media_type, schema_version, row_count,
        period_start, period_end, encryption_key_ref, retention_policy_version,
        retention_until, legal_hold, created_at, verified_at, quarantined_at,
        superseded_at, deleted_at
    ) VALUES (
        v_object.id, 'STAGED', v_object.storage_provider, v_object.bucket_name,
        v_object.object_key, v_object.provider_version_id, v_object.content_hash,
        v_object.byte_size, v_object.file_format, v_object.compression_codec,
        v_object.media_type, v_object.schema_version, v_object.row_count,
        v_object.period_start, v_object.period_end, v_object.encryption_key_ref,
        v_object.retention_policy_version, v_object.retention_until,
        v_object.legal_hold, v_object.created_at, NULL, NULL, NULL, NULL
    )
    ON CONFLICT DO NOTHING
    RETURNING * INTO v_registered;
    IF FOUND THEN
        RETURN NEXT v_registered;
    END IF;
END;
$register$;

REVOKE ALL ON FUNCTION storage.register_backtest_object(jsonb) FROM PUBLIC;

CREATE FUNCTION storage.transition_backtest_object(
    p_object_id uuid,
    p_target text,
    p_at timestamp with time zone
)
RETURNS SETOF storage.objects
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $transition$
DECLARE
    v_attempt_capability text;
    v_attempt_id uuid;
    v_attempt_text text;
    v_claim_token uuid;
    v_claim_text text;
    v_key_run_id uuid;
    v_run_id uuid;
    v_run_text text;
    v_updated storage.objects%ROWTYPE;
BEGIN
    IF p_target NOT IN ('AVAILABLE', 'QUARANTINED') OR p_at IS NULL THEN
        RAISE EXCEPTION 'backtest object transition target is invalid';
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
        RAISE EXCEPTION 'backtest object transition requires current attempt context';
    END IF;
    BEGIN
        v_run_id := v_run_text::uuid;
        v_attempt_id := v_attempt_text::uuid;
        v_claim_token := v_claim_text::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'backtest object transition attempt context is invalid';
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM backtest.run_attempts AS attempt
        JOIN storage.backtest_attempt_cleanup_capabilities AS capability
          ON capability.attempt_id = attempt.id
         AND capability.run_id = attempt.run_id
         AND capability.claim_token = attempt.claim_token
        WHERE attempt.id = v_attempt_id
          AND attempt.run_id = v_run_id
          AND attempt.claim_token = v_claim_token
          AND attempt.status = 'RUNNING'
          AND attempt.claim_expires_at > clock_timestamp()
          AND capability.capability_hash = encode(
                public.digest(v_attempt_capability, 'sha256'),
                'hex'
          )
    ) THEN
        RAISE EXCEPTION 'backtest object transition requires the current live attempt claim';
    END IF;

    SELECT object_row.*
    INTO v_updated
    FROM storage.objects AS object_row
    WHERE object_row.id = p_object_id;
    IF FOUND AND v_updated.status = p_target::storage.object_status THEN
        RETURN NEXT v_updated;
        RETURN;
    END IF;

    SELECT substring(
        object_row.object_key FROM
        '^backtest-results/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/'
    )::uuid
    INTO v_key_run_id
    FROM storage.objects AS object_row
    WHERE object_row.id = p_object_id;
    IF v_key_run_id IS NULL OR v_key_run_id IS DISTINCT FROM v_run_id THEN
        RAISE EXCEPTION 'backtest object transition run does not match its canonical object key';
    END IF;

    IF p_target = 'AVAILABLE' THEN
        UPDATE storage.objects AS object_row
        SET status = 'AVAILABLE', verified_at = p_at
        WHERE object_row.id = p_object_id
          AND object_row.status = 'STAGED'
        RETURNING object_row.* INTO v_updated;
    ELSE
        UPDATE storage.objects AS object_row
        SET status = 'QUARANTINED', quarantined_at = p_at
        WHERE object_row.id = p_object_id
          AND object_row.status IN ('STAGED', 'AVAILABLE')
        RETURNING object_row.* INTO v_updated;
    END IF;
    IF FOUND THEN
        RETURN NEXT v_updated;
    END IF;
END;
$transition$;

REVOKE ALL ON FUNCTION
    storage.transition_backtest_object(uuid, text, timestamp with time zone)
    FROM PUBLIC;

COMMENT ON FUNCTION storage.register_backtest_object(jsonb) IS
'Registers only a STAGED canonical backtest object for a live attempt; reconciled provider bytes may remain deliberately unowned.';
COMMENT ON FUNCTION storage.prepare_backtest_object_cleanup(jsonb) IS
'Direct-producer or immediate-successor gate around the DDL-safe exact-version cleanup implementation.';
