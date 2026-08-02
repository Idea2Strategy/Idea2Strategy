create table competition.room_final_access_grants (
    room_id uuid not null,
    account_id uuid not null,
    snapshot_id uuid not null,
    eligibility_basis varchar(40) not null,
    granted_at timestamptz not null,
    constraint competition_room_final_access_grants_pkey primary key (room_id, account_id),
    constraint competition_room_final_access_grants_snapshot_account_key unique (snapshot_id, account_id),
    constraint competition_final_access_basis_valid
        check (eligibility_basis in ('CREATOR', 'ACTIVE_PARTICIPANT')),
    constraint competition_room_final_access_grants_room_fkey
        foreign key (room_id) references competition.rooms (id) deferrable initially immediate,
    constraint competition_room_final_access_grants_account_fkey
        foreign key (account_id) references identity.accounts (id) deferrable initially immediate,
    constraint competition_room_final_access_grants_snapshot_fkey
        foreign key (snapshot_id) references competition.leaderboard_snapshots (id) deferrable initially immediate
);

comment on table competition.room_final_access_grants is
    'Immutable SECRET-room FINAL leaderboard access frozen at room finalization; query expiry does not delete evidence.';
