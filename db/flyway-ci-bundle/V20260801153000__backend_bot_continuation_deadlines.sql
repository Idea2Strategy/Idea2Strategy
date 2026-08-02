CREATE TABLE "bot"."continuation_deadlines" (
  "bot_id" uuid PRIMARY KEY,
  "due_at" timestamptz NOT NULL,
  "last_renewed_at" timestamptz,
  "renewal_sequence" bigint NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL,
  "updated_at" timestamptz NOT NULL,
  CONSTRAINT "bot_continuation_due_after_renewal" CHECK (last_renewed_at IS NULL OR due_at > last_renewed_at),
  CONSTRAINT "bot_continuation_sequence_nonnegative" CHECK (renewal_sequence >= 0)
);

CREATE INDEX ON "bot"."continuation_deadlines" ("due_at");

ALTER TABLE "bot"."continuation_deadlines"
  ADD FOREIGN KEY ("bot_id") REFERENCES "bot"."bots" ("id") DEFERRABLE INITIALLY IMMEDIATE;

COMMENT ON TABLE "bot"."continuation_deadlines" IS
  '무소속 실행 봇의 명시적 계속 실행 확인 기한. 조회와 로그인은 이 행을 변경하지 않는다.';
