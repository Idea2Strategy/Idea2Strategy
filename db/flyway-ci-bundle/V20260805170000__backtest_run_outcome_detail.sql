-- backtest: forward adoption of the approved run outcome projection.
--
-- The earlier V20260802143000 proposal was authored before newer central Flyway
-- history. It is preserved under fixtures/superseded-proposals for audit, but is
-- deliberately outside the active contribution directory. This globally ordered
-- forward version is the only bundle-eligible outcome migration.
--
-- Scope is intentionally limited to the three outcome fields already consumed by
-- the runtime. In particular this migration does not restore the retired legacy
-- input-pin fields dataset_manifest_id, dataset_hash, or
-- feature_materialization_version.

ALTER TABLE "backtest"."runs"
  ADD COLUMN "result_manifest_id" uuid,
  ADD COLUMN "retryable" boolean,
  ADD COLUMN "missing_requirements" jsonb;

-- backtest.v1 requires UNAVAILABLE.missingRequirements to be a non-empty array
-- of strings. NULL remains valid for every status where the field is not
-- applicable. retryable intentionally has no default: "not failed" and
-- "failed, not retryable" are different facts.
ALTER TABLE "backtest"."runs"
  ADD CONSTRAINT "runs_missing_requirements_is_a_non_empty_string_array"
  CHECK (
    "missing_requirements" IS NULL
    OR (
      jsonb_typeof("missing_requirements") = 'array'
      AND jsonb_array_length("missing_requirements") > 0
      AND NOT jsonb_path_exists("missing_requirements", '$[*] ? (@.type() != "string")')
    )
  );

COMMENT ON COLUMN "backtest"."runs"."result_manifest_id" IS 'COMPLETED resultManifestId linking the run to its immutable result manifest; NULL for other states.';
COMMENT ON COLUMN "backtest"."runs"."retryable" IS 'FAILED retryable decision; NULL when the run has not failed.';
COMMENT ON COLUMN "backtest"."runs"."missing_requirements" IS 'UNAVAILABLE missingRequirements as the non-empty ordered string array received from the worker; NULL for other states.';
