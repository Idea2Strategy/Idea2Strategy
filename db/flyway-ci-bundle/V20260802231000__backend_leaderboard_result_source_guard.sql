CREATE OR REPLACE FUNCTION competition.enforce_leaderboard_result_source()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    snapshot_room_id uuid;
    room_type competition.competition_type;
    participation_room_id uuid;
    participation_bot_id uuid;
    performance_bot_id uuid;
    aggregate_participation_id uuid;
    aggregate_room_id uuid;
BEGIN
    SELECT snapshot.room_id, room.competition_type
      INTO snapshot_room_id, room_type
      FROM competition.leaderboard_snapshots snapshot
      JOIN competition.rooms room ON room.id = snapshot.room_id
     WHERE snapshot.id = NEW.snapshot_id;

    SELECT participation.room_id, participation.bot_id
      INTO participation_room_id, participation_bot_id
      FROM competition.participations participation
     WHERE participation.id = NEW.participation_id;

    IF snapshot_room_id IS NULL OR participation_room_id IS DISTINCT FROM snapshot_room_id THEN
        RAISE EXCEPTION 'leaderboard participation must belong to the snapshot room'
            USING ERRCODE = '23514';
    END IF;

    IF room_type = 'LIVE_PAPER' THEN
        IF NEW.performance_snapshot_id IS NULL OR NEW.backtest_aggregate_result_id IS NOT NULL THEN
            RAISE EXCEPTION 'LIVE_PAPER leaderboard requires a live performance snapshot'
                USING ERRCODE = '23514';
        END IF;
        SELECT snapshot.bot_id
          INTO performance_bot_id
          FROM performance.bot_snapshots snapshot
         WHERE snapshot.id = NEW.performance_snapshot_id;
        IF performance_bot_id IS DISTINCT FROM participation_bot_id THEN
            RAISE EXCEPTION 'live performance snapshot must belong to the participation bot'
                USING ERRCODE = '23514';
        END IF;
    ELSIF room_type = 'BACKTEST' THEN
        IF NEW.backtest_aggregate_result_id IS NULL OR NEW.performance_snapshot_id IS NOT NULL THEN
            RAISE EXCEPTION 'BACKTEST leaderboard requires a backtest aggregate result'
                USING ERRCODE = '23514';
        END IF;
        SELECT aggregate.participation_id, aggregate.evaluation_plan_room_id
          INTO aggregate_participation_id, aggregate_room_id
          FROM competition.backtest_aggregate_results aggregate
         WHERE aggregate.id = NEW.backtest_aggregate_result_id;
        IF aggregate_participation_id IS DISTINCT FROM NEW.participation_id
                OR aggregate_room_id IS DISTINCT FROM snapshot_room_id THEN
            RAISE EXCEPTION 'backtest aggregate must belong to the participation and snapshot room'
                USING ERRCODE = '23514';
        END IF;
    ELSE
        RAISE EXCEPTION 'unsupported competition type for leaderboard result source'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER competition_leaderboard_result_source_guard
AFTER INSERT OR UPDATE OF snapshot_id, participation_id, performance_snapshot_id, backtest_aggregate_result_id
ON competition.leaderboard_entries
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW
EXECUTE FUNCTION competition.enforce_leaderboard_result_source();
