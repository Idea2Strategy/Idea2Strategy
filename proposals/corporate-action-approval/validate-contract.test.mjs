import { readFile } from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const contract = await readFile(new URL("./contract.md", import.meta.url), "utf8");
const readme = await readFile(new URL("./README.md", import.meta.url), "utf8");

test("stays an unapproved isolated proposal", () => {
  assert.match(contract, /Status: isolated canonical proposal/);
  assert.match(contract, /user:kcrmin` reviews the exact commit/);
  assert.match(readme, /Nothing here is canonical or approved/);
  assert.match(readme, /must not be copied into `contracts\/`/);
});

test("requires every field that proves an approval result", () => {
  for (const field of [
    "candidate identity",
    "decided version",
    "evidence binding",
    "actor",
    "audit binding",
    "permission and schema version",
  ]) assert.ok(contract.includes(field), `missing required approval field: ${field}`);

  // Absence of any one field must refuse, not degrade.
  assert.match(contract, /If any one is absent, D \*\*refuses and applies nothing\*\*/);
  // Raw transport identity is never permission evidence.
  assert.match(contract, /Raw operator, ALB, and servlet identity headers are not permission evidence/);
});

test("pins all five fail-closed rules", () => {
  for (const heading of [
    "### 3.1 Unapproved — deny by default",
    "### 3.2 Forgery — an unproven result is not an approval",
    "### 3.3 Duplicate — idempotent, not re-applied",
    "### 3.4 Cancellation — a withdrawal is a new fact",
    "### 3.5 Superseded — exactly one approval holds authority",
  ]) assert.ok(contract.includes(heading), `missing fail-closed rule: ${heading}`);
});

test("an unwired provider refuses rather than reporting a quiet slot", () => {
  assert.match(contract, /"zero approvals" and "no provider" are indistinguishable/);
  assert.match(contract, /Test-only local decision injection must not exist on the production path/);
});

test("an unknown schema version is never read leniently", () => {
  assert.match(contract, /A future `requestSchemaVersion` is \*\*not\*\* interpreted leniently/);
  assert.match(contract, /forged result becomes indistinguishable from a valid one/);
});

test("separates duplicate convergence from re-decision refusal", () => {
  assert.match(contract, /converge on already-applied and do not trigger regeneration again/);
  assert.match(contract, /ConflictingDecisionError/);
  assert.match(contract, /A duplicate is not a \*\*re-decision\*\*/);
});

test("withdrawal regenerates forward without breaking published reproducibility", () => {
  assert.match(contract, /not a deletion and not a state rollback/);
  assert.match(contract, /must stay reproducible/);
});

test("supersede requires naming the prior candidate, else it is a conflict", () => {
  assert.match(contract, /only the newest contributes to `approved_actions\(\)`/);
  assert.match(contract, /explicitly names the prior candidate identity/);
  assert.match(contract, /is \*\*not\*\* a supersede but a \*\*conflict\*\*/);
  // The reason the rule exists, not just the rule.
  assert.match(contract, /silently wrong by a factor of two/);
});

test("assigns the CORPORATE_ACTION provider to A, with the reason", () => {
  assert.match(contract, /owned by A \(backend\)\*\*/);
  assert.match(contract, /D is the consumer of approval results, not the provider/);
  assert.match(contract, /authenticity adjudication would move to D and §3.2 could not hold/);
});

test("keeps refusal reason codes distinguishable", () => {
  assert.match(contract, /must be \*\*distinct\*\* reasons/);
  for (const response of [
    "security investigation",
    "deployment-ordering problem",
    "re-approval request",
  ]) assert.ok(contract.includes(response), `missing operational response: ${response}`);
});

test("authors no DDL and says so", () => {
  assert.match(contract, /authors \*\*no DDL\*\*/);
  assert.match(readme, /no\*\* `schema.draft.dbml`/);
});

test("records what merged code already satisfies", () => {
  assert.match(contract, /already satisfies §3.1 and half of §3.3/);
  assert.match(contract, /§3.2, §3.4, §3.5 and §4 are implemented when/);
});
