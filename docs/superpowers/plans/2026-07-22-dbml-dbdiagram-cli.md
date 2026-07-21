# DBML and dbdiagram CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the canonical logical DBML for Idea2Strategy and add a reproducible, version-pinned dbdiagram CLI workflow without making the cloud diagram authoritative.

**Architecture:** Keep one canonical `db/schema.dbml` split by DBML schemas for identity, strategy, bot, trading, market data, backtest, competition, and operations. Store strategy graphs as RDB document values and model only their metadata and immutable versions relationally. Represent large market and backtest payloads through relational manifests pointing to immutable objects. Keep dbdiagram synchronization isolated through Stackcord so cloud edits remain proposals until reconciled into Git DBML.

**Tech Stack:** DBML, official `dbdiagram` CLI 0.2.0, its official `@dbml/core` parser 8.2.5, pnpm, Stackcord database coordination.

## Global Constraints

- `db/schema.dbml` is the only canonical logical database model.
- DBML schemas are logical boundaries and do not select a physical database topology.
- Exact DBMS, numeric precision, indexes, partitioning, retention, migration, and rollback implementation remain undecided.
- Live official orders, fills, and double-entry ledger records remain relational.
- High-volume backtest details and market bars remain immutable objects referenced by relational manifests.
- Strategy executable semantics and editor layout remain separate document values with separate hashes.
- dbdiagram cloud state is never applied directly to the canonical DBML.

---

### Task 1: Reproducible DBML Tooling

**Files:**
- Create: `package.json`
- Create: `pnpm-lock.yaml`

**Interfaces:**
- Consumes: bundled Node.js and pnpm runtime
- Produces: `pnpm dbml:validate` and `pnpm dbdiagram` commands

- [ ] **Step 1: Add exact development dependencies and scripts**

Create a private tooling-only package with `dbdiagram@0.2.0` and its official `@dbml/core@8.2.5` parser. Keep validation database-neutral and avoid installing unused database connector binaries.

- [ ] **Step 2: Install dependencies and lock versions**

Run: `pnpm install`

Expected: `pnpm-lock.yaml` is created and both CLIs resolve locally.

- [ ] **Step 3: Verify CLI availability**

Run: `pnpm exec dbdiagram --help`

Expected: help lists `init`, `push`, `pull`, authentication, and document commands.

### Task 2: Canonical Logical DBML

**Files:**
- Create: `db/schema.dbml`
- Create: `scripts/validate-dbml.mjs`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-22-logical-data-model-design.md`, `specs/`, and `contracts/`
- Produces: schema-qualified logical entities, references, uniqueness rules, and notes for all eight domains

- [ ] **Step 1: Write a structural assertion that fails before DBML exists**

Check that `db/schema.dbml` exists and contains every required schema, the strategy semantic/layout document fields, balanced-ledger structures, bot event sequence, and backtest detail object manifest.

- [ ] **Step 2: Confirm the assertion fails**

Run the PowerShell structural check before creating the file.

Expected: FAIL because `db/schema.dbml` does not exist.

- [ ] **Step 3: Create the canonical DBML**

Define the eight schema domains, current versus immutable records, cross-domain references, manifest boundaries, and notes for constraints that cannot be expressed portably in DBML.

- [ ] **Step 4: Validate DBML syntax**

Run: `pnpm dbml:validate`

Expected: exit code 0 and a JSON summary listing all eight schemas without parser errors.

- [ ] **Step 5: Run structural and semantic assertions**

Expected: every required schema and invariant marker passes; no references target missing tables.

### Task 3: Isolated dbdiagram Workflow

**Files:**
- Modify: `.gitignore`
- Create: `.env.example`
- Create or modify: Stackcord-managed isolated dbdiagram proposal metadata

**Interfaces:**
- Consumes: canonical `db/schema.dbml`, local `dbdiagram` CLI, optional user-provided `DBDIAGRAM_TOKEN` and diagram ID
- Produces: an isolated push proposal; no canonical mutation from cloud state

- [ ] **Step 1: Protect credentials and document the environment name**

Ignore `.env` and expose only the empty `DBDIAGRAM_TOKEN` name in `.env.example`.

- [ ] **Step 2: Prepare the isolated push proposal**

Run Stackcord database diagram preparation with canonical entry `db/schema.dbml`, action `push`, the observed CLI version, and token environment `DBDIAGRAM_TOKEN`.

Expected: an isolated copy and provenance are created without invoking the external service.

- [ ] **Step 3: Compare the isolated proposal with canonical DBML**

Run `stackcord db diff` between the canonical DBML and isolated proposal.

Expected: no semantic difference before any cloud edit.

- [ ] **Step 4: Verify local CLI without leaking credentials**

Run the local CLI help/version command. Only run authentication or push when credentials and a diagram ID are already supplied by the user environment; never persist the token.

### Task 4: Final Verification

**Files:**
- Verify: `db/schema.dbml`
- Verify: `package.json`
- Verify: `pnpm-lock.yaml`
- Verify: isolated dbdiagram proposal

**Interfaces:**
- Consumes: all preceding outputs
- Produces: reproducible verification evidence

- [ ] **Step 1: Run formatting and parser checks**

Run: `git diff --check` and `pnpm dbml:validate`

Expected: both exit successfully.

- [ ] **Step 2: Run Stackcord context and database checks**

Run context audit and DBML semantic diff against the isolated proposal.

Expected: no stale product context and no unreviewed canonical/cloud drift.

- [ ] **Step 3: Review scope**

Confirm no migration, production DB, authentication secret, cloud push, commit, or UI change was created.
