# Local V1 Rebaseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the pre-launch migration history with one current V1, retain Flyway for all subsequent development, and provide a verified restore path from the 2026-08-13 D-drive backup.

**Architecture:** Build the new V1 from a clean PostgreSQL instance migrated with the last historical bundle, then prove the new V1 produces the same schema and seed data. Child repositories stop contributing pre-baseline migrations; the root pins those commits, publishes a one-baseline bundle, and owns a guarded local restore command that recreates only project data volumes.

**Tech Stack:** PowerShell 5.1, Docker Desktop/Compose, PostgreSQL 16 (`pg_dump`, `pg_restore`, `psql`), Flyway 11, Java 21/Gradle, Git submodules, MinIO Client.

## Global Constraints

- The new V1 is the immutable starting point; future development resumes timestamped Flyway migrations.
- Preserve `D:\Idea2Strategy-backups` and unrelated Docker resources.
- Destructive local volume reset requires `-Force` and exact project-owned volume names.
- Never import AWS/backup passwords into `.env.docker`; local services use local credentials.
- Restore current S3 object versions only; noncurrent versions and delete markers remain backup evidence.
- Do not mix the pre-existing uncommitted `db/schema.dbml` or INT04 evidence into unrelated commits.
- Push child feature branches before the root feature branch that pins them.

---

### Task 1: Capture the historical bundle and generate the new baseline

**Files:**
- Create: `scripts/new-v1-baseline.ps1`
- Create: `scripts/test-new-v1-baseline.ps1`
- Modify: `backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql`

**Interfaces:**
- Consumes: the exact generated bundle at `.harness/local/tmp/flyway-bundle` and Docker PostgreSQL 16.
- Produces: `scripts/new-v1-baseline.ps1 -SourceBundle <path> -Output <path>` and a deterministic V1 SQL file.

- [ ] **Step 1: Write the failing baseline-generator contract test**

The test must require `-SourceBundle`, `-Output`, and `-VerifyOnly`; assert rejection of a bundle without `V1__initial_schema.sql`; and assert the script contains explicit exclusion of `public.flyway_schema_history`, `--no-owner`, and `--no-privileges`.

- [ ] **Step 2: Run the contract test and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-new-v1-baseline.ps1`

Expected: FAIL because `scripts/new-v1-baseline.ps1` does not exist.

- [ ] **Step 3: Implement deterministic baseline generation**

The script must create two uniquely named temporary PostgreSQL containers, apply the historical bundle to the first, export schema and canonical seed data while excluding Flyway history, normalize UTF-8/LF output, apply the result to the second, and compare:

```sql
SELECT table_schema, table_name, column_name, ordinal_position, data_type, udt_schema, udt_name,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema IN ('identity','strategy','market_data','storage','backtest','bot','trading','competition','performance','operations')
ORDER BY 1,2,4;
```

It must also compare per-table row counts from the two clean databases and always remove its temporary containers and volume in `finally` blocks.

- [ ] **Step 4: Run the generator against the last historical bundle**

Run:

```powershell
.\scripts\prepare-flyway-bundle.ps1
.\scripts\new-v1-baseline.ps1 `
  -SourceBundle .harness/local/tmp/flyway-bundle `
  -Output backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql
```

Expected: PASS with matching schema and seed-data fingerprints.

- [ ] **Step 5: Commit the generator and generated baseline in the backend branch only after Task 2 updates the policy**

No commit occurs in this step because the backend checksum and tests must change atomically in Task 2.

### Task 2: Make backend treat the generated V1 as the new immutable baseline

**Files:**
- Modify: `backend/db-migration/src/main/java/com/idea2strategy/backend/migration/MigrationPolicy.java`
- Modify: `backend/db-migration/src/main/resources/db/migration/README.md`
- Delete: `backend/db-migration/src/main/resources/db/migration/V2026*.sql`
- Modify/Delete: `backend/db-migration/src/test/java/com/idea2strategy/backend/migration/*Migration*Test.java`
- Test: `backend/db-migration/src/test/java/com/idea2strategy/backend/migration/MigrationPolicyTest.java`

**Interfaces:**
- Consumes: generated V1 from Task 1.
- Produces: a backend migration directory containing exactly the new V1 before future migrations and a checksum-pinned policy.

- [ ] **Step 1: Add failing policy assertions**

Require `MigrationPolicy.verifyDirectory` to accept a directory containing only the generated V1, reject a changed V1 checksum, and still accept a valid future `V20260814000000__backend_example.sql` after V1.

- [ ] **Step 2: Run focused tests and verify failure**

Run: `backend\gradlew.bat --no-daemon :db-migration:test --tests com.idea2strategy.backend.migration.MigrationPolicyTest`

Expected: FAIL on the old V1 checksum or historical-file assumptions.

- [ ] **Step 3: Update the checksum and remove active historical migrations**

Set `BASELINE_SHA256` to the normalized SHA-256 of the generated V1. Delete timestamped SQL from the active central directory. Rewrite migration-specific contract tests as final-schema tests where the behavior remains important; delete tests whose sole contract is the presence/text of a retired migration file.

- [ ] **Step 4: Run the backend migration and persistence suites**

Run:

```powershell
backend\gradlew.bat --no-daemon :db-migration:test
backend\gradlew.bat --no-daemon :modules:backend-persistence:test
```

Expected: PASS.

- [ ] **Step 5: Commit and push the backend branch**

```powershell
git -C backend switch -c feature/local-v1-rebaseline
git -C backend add db-migration
git -C backend commit -m "chore: establish the pre-launch V1 baseline"
git -C backend push -u origin feature/local-v1-rebaseline
```

### Task 3: Reset child migration contribution histories

**Files:**
- Delete: `trading-engine/db/migration-contributions/migrations/V2026*.sql`
- Delete: `backtest-engine/db/migration-contributions/migrations/V2026*.sql`
- Delete: `data-pipeline/db/migration-contributions/migrations/V2026*.sql`
- Modify: contribution README/test files that enumerate those migrations.

**Interfaces:**
- Consumes: new V1 includes the final effects of all deleted contribution migrations.
- Produces: empty active contribution directories that continue accepting future timestamped migrations.

- [ ] **Step 1: Add or update contribution tests to require an empty pre-launch directory while retaining valid metadata**

Each repository test must assert its `contribution.properties` remains valid and that a newly added correctly owned timestamped migration would be accepted by the central assembler contract.

- [ ] **Step 2: Run each focused test and observe historical-file assumptions fail**

Run the repository-native test commands documented in each contribution README or package configuration.

- [ ] **Step 3: Remove timestamped contribution SQL and update documentation**

Keep `contribution.properties`, `migrations/README.md` or `.gitkeep`, and fixtures used by non-production tests. State that new files after the rebaseline use the existing timestamp-owner naming rule.

- [ ] **Step 4: Run each child repository's full relevant suite**

Run Java/Gradle tests for trading, pytest for backtest, and unittest/pytest as configured for data-pipeline. Expected: PASS.

- [ ] **Step 5: Commit and push each child branch**

Use `feature/local-v1-rebaseline` in each repository and descriptive `chore: reset migrations after V1 rebaseline` commits.

### Task 4: Refresh the root canonical bundle and validation

**Files:**
- Modify: root gitlinks for `backend`, `trading-engine`, `backtest-engine`, `data-pipeline`
- Modify: `db/flyway-ci-bundle/**`
- Modify: `scripts/test-flyway-ci-bundle.ps1`
- Modify: `scripts/test-flyway-migration.ps1`
- Modify: `scripts/test-flyway-upgrade-rehearsal.ps1`
- Modify: `docs/development-start-guide.md`

**Interfaces:**
- Consumes: pushed child commits from Tasks 2 and 3.
- Produces: root pinned bundle containing `V1__initial_schema.sql`, generated repeatable grants, manifest metadata, and no pre-baseline timestamped migration.

- [ ] **Step 1: Update failing root tests for the new bundle contract**

Assert exactly one successful versioned migration (`V1`) plus one successful repeatable migration on first run, zero new migrations on second run, 181 application tables, and no `V2026*.sql` in the committed bundle.

- [ ] **Step 2: Run root Flyway tests and verify they fail against the historical committed bundle**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-flyway-ci-bundle.ps1`

- [ ] **Step 3: Refresh the bundle from exact child revisions**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/refresh-flyway-ci-bundle.ps1`

- [ ] **Step 4: Replace upgrade rehearsal with baseline equivalence verification**

The rehearsal must compare the archived pre-rebaseline bundle from the parent commit with the new V1 on empty PostgreSQL instances, rather than trying to upgrade an already migrated database across an intentionally broken history boundary.

- [ ] **Step 5: Run root Flyway and Docker configuration tests**

Run `test-flyway-migration.ps1`, `test-flyway-ci-bundle.ps1`, the revised rehearsal, and `test-docker-development.ps1`. Expected: PASS.

### Task 5: Add guarded D-backup restore automation

**Files:**
- Create: `scripts/restore-local-backup.ps1`
- Create: `scripts/test-restore-local-backup.ps1`
- Modify: `scripts/dev.ps1`
- Modify: `docs/development-start-guide.md`

**Interfaces:**
- Produces: `restore-local-backup.ps1 -BackupPath <directory> -Force [-NoBrowser]`.
- Consumes: `backup-manifest.json`, `database.dump`, `s3-current/`, `.env.docker`, Docker Compose, and the new Flyway bundle.

- [ ] **Step 1: Write failing static and synthetic-fixture tests**

Tests must prove validation occurs before any `docker volume rm`, exact volume allowlisting, required `-Force`, checksum verification, exclusion of `public.flyway_schema_history`, current-version-only S3 import, and cleanup on failure.

- [ ] **Step 2: Run tests and verify failure because the script is missing**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-restore-local-backup.ps1`

- [ ] **Step 3: Implement backup validation and exact destructive boundary**

Resolve `BackupPath` to an absolute path, require it to be outside the repository, validate manifest SHA-256 and counts, and remove only:

```text
idea2strategy-postgres-data
idea2strategy-minio-data
idea2strategy-localstack-data
idea2strategy-local_bootstrap-state
```

Do not remove frontend dependency volumes, source files, or D-drive contents.

- [ ] **Step 4: Implement database and object restore**

Start infrastructure, apply V1, truncate application tables with foreign-key-safe generated SQL, restore `database.dump` data only while excluding Flyway history, copy `s3-current` keys preserving relative paths, and then start all application services.

- [ ] **Step 5: Verify restored counts and endpoints**

Compare the manifest counts for `storage.objects`, `market_data.dataset_manifests`, `market_data.dataset_objects`, `market_data.dataset_lineage`, `market_data.quality_incidents`, and `market_data.pipeline_runs`; require 10,732 MinIO objects; and probe the UI plus service health endpoints.

- [ ] **Step 6: Run synthetic restore tests**

Expected: PASS without touching real project volumes.

### Task 6: Commit, push, and perform a clean real-backup rehearsal

**Files:**
- Modify: root feature branch files from Tasks 1, 4, and 5.
- Preserve uncommitted: `db/schema.dbml` and `docs/evidence/INT04-release-31323280012-readonly-check.md` unless separately attributed and intentionally included.

**Interfaces:**
- Produces: pushed `feature/local-v1-rebaseline` root branch and a running local environment.

- [ ] **Step 1: Run the required policy/harness verification**

Run `initialize-local-harness.ps1 -Verify` and `verify-collaboration-policy.ps1`. Expected: PASS.

- [ ] **Step 2: Run all relevant root and child tests from clean pinned revisions**

Record exact commands and outputs. Any failure blocks the push claim.

- [ ] **Step 3: Commit root integration without unrelated local changes**

Stage explicit paths only, verify `git diff --cached`, and commit `chore: establish the pre-launch V1 baseline`.

- [ ] **Step 4: Push the root feature branch**

Run: `git push -u origin feature/local-v1-rebaseline`.

- [ ] **Step 5: Reset and restore the real local project data**

Run:

```powershell
.\scripts\restore-local-backup.ps1 `
  -BackupPath 'D:\Idea2Strategy-backups\baseline-2026-08-13' `
  -Force -NoBrowser
```

- [ ] **Step 6: Verify clean reproducibility and report URLs**

Require the root and child branches to match pushed commits, Docker services to be healthy, manifest counts to match, MinIO to contain 10,732 objects, and the UI to return HTTP 200. Report `http://localhost:15173` plus API and MinIO console URLs.
