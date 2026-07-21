# Strategy Release Schema Naming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename strategy and reusable-component execution snapshots from `version` to `release` without changing their immutable-release behavior.

**Architecture:** Keep drafts mutable and releases immutable. Rename only strategy release entities, join tables, and foreign keys; retain genuine format, catalog, dataset, and scoring-template version terminology.

**Tech Stack:** DBML, Node.js, `@dbml/core`, PowerShell/Git verification.

## Global Constraints

- Work only on `feature/dbml` in its isolated worktree.
- `db/schema.dbml` remains the canonical database model.
- Do not change table relationships or product behavior in this naming-only change.
- Keep `schema_version`, `language_version`, `catalog_version`, `scoring_template_versions`, and other genuine version fields unchanged.

---

### Task 1: Add a naming regression check

**Files:**
- Create: `scripts/validate-dbml-release-names.mjs`
- Modify: `package.json`

**Interfaces:**
- Consumes: `db/schema.dbml`
- Produces: `pnpm dbml:validate-release-names`

- [x] Add a validator that requires the four release table names and rejects the former strategy/component version table and foreign-key names.
- [x] Run `pnpm dbml:validate-release-names` before the rename and confirm that it fails on the existing schema.

### Task 2: Rename immutable strategy release entities

**Files:**
- Modify: `db/schema.dbml`
- Modify: `docs/superpowers/specs/2026-07-22-logical-data-model-design.md`

**Interfaces:**
- Consumes: the approved immutable-release product policy.
- Produces: `strategy_releases`, `component_releases`, `release_components`, `release_instruments`, `strategy_release_id`, and `component_release_id`.

- [x] Rename the four tables and all matching references and indexes.
- [x] Rename every strategy/component release foreign key consistently across bot, trading, and backtest schemas.
- [x] Update the logical data model design examples and descriptions.

### Task 3: Verify and publish the branch

**Files:**
- Verify: `db/schema.dbml`
- Verify: all tracked text files

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: a pushed `feature/dbml` branch.

- [x] Run `pnpm dbml:validate` and expect 68 parsed tables.
- [x] Run `pnpm dbml:validate-release-names` and expect success.
- [x] Search for prohibited former strategy/component version identifiers and expect no matches.
- [x] Run `git diff --check` and inspect the exact diff.
- [ ] Commit only the DBML naming plan, validator, schema, package script, and logical-data-model design.
- [ ] Push `feature/dbml` to `origin` without merging it into `main`.
