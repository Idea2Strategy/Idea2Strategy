-- The published strategy-bot.v1 compiled plan a bot's evaluation runtime loads it from.
--
-- Root #190: every input existed at release time and nothing assembled them into the contract, so
-- no real bot could ever start. The evaluation runtime reads exactly one document per bot, keyed by
-- bot id, and verifies the snapshot hash it pins against the hash the RUN or STOP command carries.
--
-- A separate table rather than a column on bot.launch_snapshots, for two reasons. The document is
-- derived from that snapshot, so storing it inside the row whose hash it pins would make the hash a
-- function of its own input. And a bot released before this table existed simply has no row, which
-- the runtime reports as a missing snapshot — the loud, correct answer — where a nullable column on
-- an existing row would read as a plan that exists and is empty.
--
-- Immutable by construction: a release writes it once inside the transaction that writes the
-- snapshot, and nothing updates it afterwards, because a released strategy's meaning must not move
-- underneath a running bot.

CREATE TABLE bot.launch_contract_plans (
    bot_id uuid PRIMARY KEY,
    contract_version varchar(40) NOT NULL,
    plan_schema_version varchar(40) NOT NULL,
    plan_checksum varchar(128) NOT NULL,
    plan_document jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT (now()),
    CONSTRAINT launch_contract_plan_bot_fk
        FOREIGN KEY (bot_id) REFERENCES bot.launch_snapshots (bot_id),
    CONSTRAINT launch_contract_plan_checksum_is_prefixed_digest
        CHECK (plan_checksum ~ '^sha256:[0-9a-f]{64}$'),
    CONSTRAINT launch_contract_plan_document_is_object
        CHECK (jsonb_typeof(plan_document) = 'object')
);

COMMENT ON TABLE bot.launch_contract_plans IS
    'The strategy-bot.v1 compiled plan published for one bot at release time, read by the evaluation runtime.';
COMMENT ON COLUMN bot.launch_contract_plans.plan_checksum IS
    'The contract''s own planChecksum, sha256-prefixed, recomputed by every consumer from the fields it decoded.';
