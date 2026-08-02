-- E28 stores ineligible official results without inventing a rank or score.
-- Existing eligible rows remain unchanged; the finalization service owns the
-- eligibility/rank/score consistency rule for newly appended entries.
alter table competition.leaderboard_entries
    alter column rank drop not null,
    alter column score drop not null;
