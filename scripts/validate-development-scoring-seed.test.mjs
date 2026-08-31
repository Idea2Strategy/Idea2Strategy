import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { validateDevelopmentScoringSeed } from "./validate-development-scoring-seed.mjs";

const root = path.resolve(import.meta.dirname, "..");
const source = path.join(root, "config", "development", "scoring");

function mutated(rewrite) {
  const target = fs.mkdtempSync(path.join(os.tmpdir(), "idea2strategy-scoring-seed-"));
  fs.cpSync(source, target, { recursive: true });
  rewrite(target);
  return target;
}

test("accepts the checksum-bound development scoring catalog", () => {
  assert.deepEqual(validateDevelopmentScoringSeed(), {
    status: "passed",
    templates: 4,
    target: "competition.scoring_template_versions",
  });
});

test("rejects a scoring catalog for another environment", () => {
  const target = mutated((directory) => {
    const file = path.join(directory, "artifact-manifest.json");
    const manifest = JSON.parse(fs.readFileSync(file, "utf8"));
    manifest.status = "production";
    fs.writeFileSync(file, JSON.stringify(manifest));
  });
  assert.throws(() => validateDevelopmentScoringSeed(target), /development environment/u);
});

test("rejects checksum drift", () => {
  const target = mutated((directory) => {
    fs.appendFileSync(path.join(directory, "scoring-template-seed.sql"), "\n-- drift\n");
  });
  assert.throws(() => validateDevelopmentScoringSeed(target), /artifact checksum mismatch/u);
});

test("rejects DDL and another table even if an attacker updates the manifest checksum", () => {
  for (const suffix of [
    "\nCREATE TABLE competition.unsafe(id int);\n",
    "\nINSERT INTO trading.fee_policy_versions SELECT * FROM trading.fee_policy_versions WHERE false;\n",
  ]) {
    const target = mutated((directory) => {
      const sqlFile = path.join(directory, "scoring-template-seed.sql");
      fs.appendFileSync(sqlFile, suffix);
      const manifestFile = path.join(directory, "artifact-manifest.json");
      const manifest = JSON.parse(fs.readFileSync(manifestFile, "utf8"));
      manifest.artifacts["scoring-template-seed.sql"] =
        crypto.createHash("sha256").update(fs.readFileSync(sqlFile, "utf8")).digest("hex");
      fs.writeFileSync(manifestFile, JSON.stringify(manifest));
    });
    assert.throws(() => validateDevelopmentScoringSeed(target), /forbidden command|allowlist violation/u);
  }
});
