CREATE FUNCTION trading.delete_private_bot_runtime(candidate_ids uuid[], delete_events boolean)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF delete_events THEN
        DELETE FROM bot.bot_events WHERE bot_id = ANY(candidate_ids);
    ELSE
        DELETE FROM bot.runtime_state_changes WHERE bot_id = ANY(candidate_ids);
        DELETE FROM bot.evaluation_runs WHERE bot_id = ANY(candidate_ids);
        DELETE FROM bot.runtime_state_values WHERE bot_id = ANY(candidate_ids);
    END IF;
END;
$$;

COMMENT ON FUNCTION trading.delete_private_bot_runtime(uuid[], boolean) IS
    'Trading-owned half of FK-safe private Bot deletion; the backend owner coordinates it in the same database transaction.';
