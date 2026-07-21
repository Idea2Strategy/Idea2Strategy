# Strategy Template Copy Model Implementation Plan

**Goal:** Keep strategy releases self-contained, persist only successful server validation evidence, and treat templates as copy sources rather than linked runtime components.

## Decisions

- Frontend validation is transient and is not stored.
- The server validates every release request and inserts `strategy_releases` only after success.
- A release stores `semantic_hash`, `validator_version`, and `validated_at` as its successful validation evidence.
- A template is copied into a draft with new node identities; drafts and releases retain no template relationship.
- Blocks, nodes, edges, parameters, groups, formulas, and layout remain inside the strategy JSON documents.

## Changes

- [x] Make the strategy-model validator fail on persisted validation runs, component entities, and template links.
- [x] Remove `validation_runs` and `strategy_releases.validation_run_id`.
- [x] Add successful server-validation evidence directly to `strategy_releases`.
- [x] Replace component draft/release/link entities with independent `strategy_templates`.
- [x] Keep `release_instruments` as the normalized released-instrument relationship.
- [x] Validate DBML syntax, strategy-model rules, semantic diff, and stale-name absence.
- [ ] Commit and push `feature/dbml`.
- [ ] Push the verified canonical DBML to the existing dbdiagram.io diagram and pull it back for a zero-diff check.
