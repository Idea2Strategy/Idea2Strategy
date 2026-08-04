import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";
import test from "node:test";

const contractUrl = new URL("../contracts/data/corporate-action-approval.v1.md", import.meta.url);
const contract = await readFile(contractUrl, "utf8");
const registry = await readFile(new URL("../contracts/registry.yaml", import.meta.url), "utf8");
const index = await readFile(new URL("../contracts/data/index.md", import.meta.url), "utf8");

test("pins the approved corporate-action contract and exact fingerprint", () => {
  assert.match(contract, /id: contract\.operations\.corporate-action-approval\.v1/);
  assert.match(contract, /Status: approved canonical contract/);
  assert.match(contract, /root PR #204/);
  const fingerprint = `sha256:${createHash("sha256").update(contract).digest("hex")}`;
  assert.ok(registry.includes("id: contract.operations.corporate-action-approval.v1"));
  assert.ok(registry.includes(`fingerprint: ${fingerprint}`), "stale registry fingerprint");
  assert.match(index, /corporate-action-approval\.v1\.md/);
});

test("uses the stored content hash as the decision version", () => {
  assert.match(contract, /`decidedContentHash`/);
  assert.match(contract, /exactly equal.*`terms_hash`/s);
  assert.doesNotMatch(contract, /numeric targetVersion/i);
});

test("keeps every approved fail-closed transition", () => {
  for (const phrase of [
    "provider is unwired",
    "ACTIVE operator",
    "unknown schema version",
    "do not trigger regeneration again",
    "explicit withdrawal event",
    "SUPERSEDED",
    "explicitly names the prior candidate",
  ]) assert.ok(contract.includes(phrase), `missing obligation: ${phrase}`);
});

test("defines a delivery envelope without adding DDL", () => {
  for (const field of [
    "candidateId", "decision", "decidedContentHash", "evidenceBindings",
    "actorId", "auditId", "permissionId", "requestSchemaVersion",
    "decidedAt", "supersedesCandidateId", "deliveryId", "aggregateSequence",
  ]) assert.ok(contract.includes(`\`${field}\``), `missing wire field: ${field}`);
  assert.match(contract, /authors no DDL/i);
});
