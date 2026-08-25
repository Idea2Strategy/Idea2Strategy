alter table competition.room_invitations
    add column claimed_by_account_id uuid,
    add column claimed_at timestamptz,
    add column admitted_participation_id uuid;

alter table competition.room_invitations
    add constraint room_invitations_claim_pair_ck
        check ((claimed_by_account_id is null) = (claimed_at is null)),
    add constraint room_invitations_admission_requires_claim_ck
        check (admitted_participation_id is null or claimed_by_account_id is not null),
    add constraint room_invitations_claimed_by_account_id_fkey
        foreign key (claimed_by_account_id) references identity.accounts(id) deferrable,
    add constraint room_invitations_admitted_participation_id_fkey
        foreign key (admitted_participation_id) references competition.participations(id) deferrable;

create unique index room_invitations_admitted_participation_id_uq
    on competition.room_invitations(admitted_participation_id)
    where admitted_participation_id is not null;

create index room_invitations_account_admission_idx
    on competition.room_invitations(room_id, claimed_by_account_id, admitted_participation_id, expires_at)
    where claimed_by_account_id is not null;

comment on column competition.room_invitations.claimed_by_account_id is
    'Account that authenticated while consuming the one-time secret. A room UUID alone never grants admission.';
comment on column competition.room_invitations.admitted_participation_id is
    'Participation that atomically spent this account-bound admission grant.';
