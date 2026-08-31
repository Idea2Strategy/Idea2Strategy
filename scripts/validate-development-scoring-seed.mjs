import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const defaultScoringRoot = path.join(root, "config", "development", "scoring");
const expectedCodes = new Set([
  "SINGLE_TOTAL_RETURN_V1",
  "SINGLE_SHARPE_V1",
  "SINGLE_MAX_DRAWDOWN_V1",
  "COMPOSITE_BALANCED_V1",
]);
const forbiddenCommand = /(^|[^A-Za-z_])(alter|create|drop|grant|revoke|copy|do|call|truncate|delete|update|merge|begin|commit|rollback|set\s+role|reset\s+role)([^A-Za-z_]|$)/iu;

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

export function validateDevelopmentScoringSeed(scoringRoot = defaultScoringRoot) {
  const manifestPath = path.join(scoringRoot, "artifact-manifest.json");
  const sqlPath = path.join(scoringRoot, "scoring-template-seed.sql");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const sql = fs.readFileSync(sqlPath, "utf8");

  if (manifest.status !== "development") {
    throw new Error("scoring seed must be marked for the development environment");
  }
  if (!/^[0-9a-f]{64}$/u.test(manifest.sourceDecisionSha256)) {
    throw new Error("source decision checksum is malformed");
  }
  const sourceDecision = fs.readFileSync(path.join(root, manifest.sourceDecision), "utf8");
  if (sha256(sourceDecision) !== manifest.sourceDecisionSha256) {
    throw new Error("source decision checksum mismatch");
  }
  if (sha256(sql) !== manifest.artifacts["scoring-template-seed.sql"]) {
    throw new Error("scoring seed artifact checksum mismatch");
  }
  if (/^\s*\\/mu.test(sql) || forbiddenCommand.test(sql)) {
    throw new Error("scoring seed contains a forbidden command or psql metacommand");
  }

  const targets = [...sql.matchAll(/\binsert\s+into\s+((?:"?[a-z_]+"?\.)?"?[a-z_]+"?)/giu)]
    .map((match) => match[1].replaceAll('"', "").toLowerCase());
  if (targets.length < 5 || targets.some((target) => target !== "competition.scoring_template_versions")) {
    throw new Error("scoring seed target allowlist violation");
  }

  for (const code of expectedCodes) {
    const occurrences = [...sql.matchAll(new RegExp(`'${code}'`, "gu"))].length;
    if (occurrences < 2) throw new Error(`missing immutable collision guard for ${code}`);
  }
  const observedCodes = new Set([...sql.matchAll(/'(SINGLE_[A-Z_]+_V1|COMPOSITE_[A-Z_]+_V1)'/gu)]
    .map((match) => match[1]));
  if (observedCodes.size !== expectedCodes.size || [...observedCodes].some((code) => !expectedCodes.has(code))) {
    throw new Error("scoring seed template code set diverges from the manifest");
  }
  for (const fragment of [
    '"calculationRulesVersion":"official-room-scoring.v1"',
    '"adjustments":[]',
    '"coefficient":0.50',
    '"coefficient":0.30',
    '"coefficient":0.20',
    "actual.rules_document <> expected.rules_document",
    "actual.rules_hash <> expected.rules_hash",
    "actual.retired_at IS DISTINCT FROM expected.retired_at",
  ]) {
    if (!sql.includes(fragment)) throw new Error(`scoring seed is missing required boundary: ${fragment}`);
  }
  return { status: "passed", templates: expectedCodes.size, target: "competition.scoring_template_versions" };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(validateDevelopmentScoringSeed()));
}
