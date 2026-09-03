-- Attempt rows are protected ownership evidence. Runtime workers may claim,
-- heartbeat, close, and recover them only through these fenced capabilities.

CREATE FUNCTION backtest.claim_run_attempt(
    p_run_id uuid,
    p_worker_id text,
    p_execution_key text,
    p_lease_milliseconds bigint
)
RETURNS SETOF backtest.run_attempts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $claim$
DECLARE
    v_attempt_id uuid;
    v_attempt_key text;
    v_claim_token uuid;
    v_inserted backtest.run_attempts%ROWTYPE;
    v_latest backtest.run_attempts%ROWTYPE;
    v_next_number integer := 1;
    v_now timestamp with time zone := clock_timestamp();
    v_run record;
BEGIN
    IF nullif(btrim(p_worker_id), '') IS NULL
       OR nullif(btrim(p_execution_key), '') IS NULL THEN
        RAISE EXCEPTION 'worker id and execution key must not be blank';
    END IF;
    IF p_lease_milliseconds <= 0 OR p_lease_milliseconds > 86400000 THEN
        RAISE EXCEPTION 'attempt lease must be between one millisecond and one day';
    END IF;

    SELECT run_row.status, run_row.cancellation_requested_at
    INTO v_run
    FROM backtest.runs AS run_row
    WHERE run_row.id = p_run_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'backtest run not found: %', p_run_id;
    END IF;
    IF v_run.status IN ('COMPLETED', 'FAILED', 'CANCELLED', 'UNAVAILABLE')
       OR v_run.cancellation_requested_at IS NOT NULL THEN
        RETURN;
    END IF;

    SELECT attempt.*
    INTO v_latest
    FROM backtest.run_attempts AS attempt
    WHERE attempt.run_id = p_run_id
    ORDER BY attempt.attempt_number DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        v_next_number := v_latest.attempt_number + 1;
        IF v_latest.status IN ('SUCCEEDED', 'CANCELLED', 'SKIPPED') THEN
            RETURN;
        END IF;
        IF v_latest.status = 'FAILED'
           AND v_latest.terminal_reason_code NOT IN ('LEASE_EXPIRED', 'RETRY_RELEASED') THEN
            RETURN;
        END IF;
        IF v_latest.status = 'RUNNING' THEN
            IF v_latest.claim_expires_at IS NOT NULL
               AND v_latest.claim_expires_at > v_now THEN
                RETURN;
            END IF;
            UPDATE backtest.run_attempts AS attempt
            SET status = 'FAILED',
                completed_at = v_now,
                failure_code = 'LEASE_EXPIRED',
                terminal_reason_code = 'LEASE_EXPIRED'
            WHERE attempt.id = v_latest.id
              AND attempt.claim_token = v_latest.claim_token
              AND attempt.status = 'RUNNING'
              AND attempt.claim_expires_at <= v_now;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'expired attempt was reclaimed concurrently';
            END IF;
        END IF;
    END IF;

    v_attempt_id := public.gen_random_uuid();
    v_claim_token := public.gen_random_uuid();
    v_attempt_key := p_execution_key || ':' || v_next_number;
    IF length(v_attempt_key) > 160 THEN
        RAISE EXCEPTION 'versioned worker execution key exceeds varchar(160)';
    END IF;

    INSERT INTO backtest.run_attempts(
        id,
        run_id,
        attempt_number,
        worker_execution_key,
        status,
        claim_token,
        worker_id,
        claimed_at,
        claim_expires_at,
        last_heartbeat_at,
        previous_attempt_id,
        started_at
    ) VALUES (
        v_attempt_id,
        p_run_id,
        v_next_number,
        v_attempt_key,
        'RUNNING',
        v_claim_token,
        p_worker_id,
        v_now,
        v_now + make_interval(secs => p_lease_milliseconds::double precision / 1000.0),
        v_now,
        CASE WHEN v_next_number = 1 THEN NULL ELSE v_latest.id END,
        v_now
    )
    ON CONFLICT DO NOTHING
    RETURNING * INTO v_inserted;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'attempt slot or execution key was claimed concurrently';
    END IF;

    UPDATE backtest.runs AS run_row
    SET status = 'RUNNING',
        started_at = coalesce(run_row.started_at, v_now)
    WHERE run_row.id = p_run_id
      AND run_row.status = 'QUEUED';

    RETURN NEXT v_inserted;
END;
$claim$;

REVOKE ALL ON FUNCTION backtest.claim_run_attempt(uuid, text, text, bigint) FROM PUBLIC;

CREATE FUNCTION backtest.heartbeat_run_attempt(
    p_attempt_id uuid,
    p_claim_token uuid,
    p_lease_milliseconds bigint
)
RETURNS SETOF backtest.run_attempts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $heartbeat$
DECLARE
    v_updated backtest.run_attempts%ROWTYPE;
    v_now timestamp with time zone := clock_timestamp();
BEGIN
    IF p_lease_milliseconds <= 0 OR p_lease_milliseconds > 86400000 THEN
        RAISE EXCEPTION 'attempt lease must be between one millisecond and one day';
    END IF;
    UPDATE backtest.run_attempts AS attempt
    SET last_heartbeat_at = v_now,
        claim_expires_at = v_now
            + make_interval(secs => p_lease_milliseconds::double precision / 1000.0)
    WHERE attempt.id = p_attempt_id
      AND attempt.claim_token = p_claim_token
      AND attempt.status = 'RUNNING'
      AND attempt.claim_expires_at > v_now
    RETURNING attempt.* INTO v_updated;
    IF FOUND THEN
        RETURN NEXT v_updated;
    END IF;
END;
$heartbeat$;

REVOKE ALL ON FUNCTION backtest.heartbeat_run_attempt(uuid, uuid, bigint) FROM PUBLIC;

CREATE FUNCTION backtest.close_run_attempt(
    p_attempt_id uuid,
    p_claim_token uuid,
    p_status text,
    p_terminal_reason_code text,
    p_failure_code text,
    p_requeue boolean
)
RETURNS SETOF backtest.run_attempts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $close$
DECLARE
    v_effective_failure text := p_failure_code;
    v_effective_reason text := p_terminal_reason_code;
    v_effective_status text := p_status;
    v_existing backtest.run_attempts%ROWTYPE;
    v_now timestamp with time zone := clock_timestamp();
    v_run record;
    v_run_id uuid;
    v_updated backtest.run_attempts%ROWTYPE;
BEGIN
    IF p_status NOT IN ('SUCCEEDED', 'FAILED', 'CANCELLED', 'SKIPPED')
       OR nullif(btrim(p_terminal_reason_code), '') IS NULL THEN
        RAISE EXCEPTION 'attempt close requires a terminal status and reason';
    END IF;
    IF p_requeue
       AND (p_status <> 'FAILED' OR p_terminal_reason_code <> 'RETRY_RELEASED') THEN
        RAISE EXCEPTION 'only RETRY_RELEASED may requeue a closed attempt';
    END IF;

    SELECT attempt.run_id
    INTO v_run_id
    FROM backtest.run_attempts AS attempt
    WHERE attempt.id = p_attempt_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT run_row.status, run_row.cancellation_requested_at
    INTO v_run
    FROM backtest.runs AS run_row
    WHERE run_row.id = v_run_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'backtest run not found: %', v_run_id;
    END IF;

    PERFORM attempt.id
    FROM backtest.run_attempts AS attempt
    WHERE attempt.id = p_attempt_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_run.cancellation_requested_at IS NOT NULL
       AND p_status = 'SUCCEEDED' THEN
        v_effective_status := 'CANCELLED';
        v_effective_reason := 'CANCELLED_BY_REQUEST';
        v_effective_failure := NULL;
    END IF;

    UPDATE backtest.run_attempts AS attempt
    SET status = v_effective_status::operations.work_status,
        completed_at = v_now,
        terminal_reason_code = v_effective_reason,
        failure_code = v_effective_failure
    WHERE attempt.id = p_attempt_id
      AND attempt.claim_token = p_claim_token
      AND attempt.status = 'RUNNING'
      AND attempt.claim_expires_at > v_now
    RETURNING attempt.* INTO v_updated;

    IF NOT FOUND THEN
        SELECT attempt.*
        INTO v_existing
        FROM backtest.run_attempts AS attempt
        WHERE attempt.id = p_attempt_id;
        IF FOUND
           AND v_existing.claim_token = p_claim_token
           AND v_existing.status::text = v_effective_status THEN
            RETURN NEXT v_existing;
        END IF;
        RETURN;
    END IF;

    IF v_effective_status = 'CANCELLED'
       AND p_status = 'SUCCEEDED' THEN
        UPDATE backtest.runs AS run_row
        SET status = 'CANCELLED',
            cancelled_at = v_now,
            completed_at = v_now
        WHERE run_row.id = v_run_id
          AND run_row.status = 'RUNNING';
    END IF;

    IF p_requeue THEN
        UPDATE backtest.runs AS run_row
        SET status = 'QUEUED'
        WHERE run_row.id = v_run_id
          AND run_row.status = 'RUNNING'
          AND run_row.cancellation_requested_at IS NULL;
    END IF;
    RETURN NEXT v_updated;
END;
$close$;

REVOKE ALL ON FUNCTION
    backtest.close_run_attempt(uuid, uuid, text, text, text, boolean)
    FROM PUBLIC;

CREATE FUNCTION backtest.recover_expired_run_attempt(
    p_attempt_id uuid,
    p_status text,
    p_reason text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $recover$
DECLARE
    v_now timestamp with time zone := clock_timestamp();
    v_row_count integer;
BEGIN
    IF p_status NOT IN ('FAILED', 'CANCELLED')
       OR nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'expired-attempt recovery requires FAILED or CANCELLED and a reason';
    END IF;
    UPDATE backtest.run_attempts AS attempt
    SET status = p_status::operations.work_status,
        completed_at = v_now,
        failure_code = CASE WHEN p_status = 'CANCELLED' THEN NULL ELSE p_reason END,
        terminal_reason_code = p_reason
    WHERE attempt.id = p_attempt_id
      AND attempt.status = 'RUNNING'
      AND (attempt.claim_expires_at IS NULL OR attempt.claim_expires_at <= v_now)
      AND (
            (p_status = 'CANCELLED' AND EXISTS (
                SELECT 1
                FROM backtest.runs AS run_row
                WHERE run_row.id = attempt.run_id
                  AND run_row.cancellation_requested_at IS NOT NULL
            ))
            OR
            (p_status = 'FAILED' AND EXISTS (
                SELECT 1
                FROM backtest.runs AS run_row
                WHERE run_row.id = attempt.run_id
                  AND run_row.cancellation_requested_at IS NULL
            ))
      )
      AND NOT EXISTS (
            SELECT 1
            FROM backtest.run_attempts AS newer
            WHERE newer.run_id = attempt.run_id
              AND newer.attempt_number > attempt.attempt_number
      );
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    RETURN v_row_count;
END;
$recover$;

REVOKE ALL ON FUNCTION backtest.recover_expired_run_attempt(uuid, text, text) FROM PUBLIC;

COMMENT ON FUNCTION backtest.claim_run_attempt(uuid, text, text, bigint) IS
'Fenced database-time claim capability; runtime roles cannot insert or update run_attempts directly.';
