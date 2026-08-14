# Local V1 Rebaseline and Backup Restore Design

## Context

The Development AWS environment has been taken down. The next supported starting point is a clean local environment populated from the backup under `D:\Idea2Strategy-backups\baseline-2026-08-13`.

The current backup cannot be started safely with the current migration bundle. It contains `identity.device_authorization_status` and `identity.device_authorization_requests`, but its `flyway_schema_history` stops before `V20260810120000__backend_device_authorization_requests.sql`. Flyway therefore attempts to recreate the existing enum and aborts.

The repository also carries one historical V1 plus timestamped migrations from backend, trading, backtest, and data-pipeline repositories. Those migrations describe the path from an obsolete starting point rather than the new pre-launch starting point.

## Goals

- Replace the active historical migration chain with one new V1 representing the exact current schema.
- Preserve all canonical seed/reference data created by the current migration bundle.
- Keep runtime database grants generated from `DatabaseAccessPolicy` as a repeatable migration.
- Provide a destructive, explicit, reproducible command that restores the D-drive PostgreSQL and S3 backup into local Docker volumes.
- Let another administrator pull the branches, run the documented commands, and reach the same working UI and service state.
- Preserve the historical migrations in Git history without retaining them as active Flyway inputs.

## Non-goals

- Preserve upgrade compatibility with the retired AWS database or any pre-rebaseline local volume.
- Modify product specifications, contracts, or governance policy.
- Restore AWS infrastructure or credentials.
- Import noncurrent S3 object versions or delete markers into MinIO. The local runtime uses the current-version object set.

## Baseline generation

The baseline generator uses the existing committed canonical bundle as its source of truth:

1. Apply the complete current bundle to an empty temporary PostgreSQL 16 database.
2. Export the final application schemas without owners, environment-specific credentials, Flyway history, or generated runtime grants.
3. Export data from that clean database. Because the source began empty, this contains only canonical seed/reference rows created by migrations.
4. Assemble the schema and seed exports into a deterministic UTF-8/LF `V1__initial_schema.sql`.
5. Apply the generated V1 to a second empty database and compare normalized schema and seed-data fingerprints with the source database.

The generated repeatable `R__database_runtime_grants.sql` remains separate so future table changes continue to receive permissions derived from code.

## Repository changes

### Backend

- Replace `V1__initial_schema.sql` with the generated current baseline.
- Remove timestamped backend migration SQL files from the active migration directory.
- Update `MigrationPolicy.BASELINE_SHA256`, migration documentation, and tests.
- Replace tests coupled to historical migration filenames with final-schema or baseline behavior assertions where needed.

### Trading, backtest, and data pipeline

- Remove timestamped SQL files from each active migration contribution directory.
- Keep contribution metadata and directories so future post-V1 migrations retain repository ownership boundaries.
- Update contribution documentation and tests that require historical filenames.

### Root superproject

- Update submodule pointers only after each submodule branch is committed and pushed.
- Refresh the committed Flyway CI bundle and its source-revision metadata.
- Align `db/schema.dbml` and development documentation with the new V1.
- Add the local backup restore command and its tests.

## Local restore command

The root command accepts a backup directory and requires `-Force`. It performs only these destructive operations:

- stop the `idea2strategy-local` compose project;
- remove the explicitly named PostgreSQL, MinIO, LocalStack, and bootstrap-state volumes owned by this project;
- leave D-drive files, source checkouts, unrelated Docker resources, and frontend dependency caches untouched.

It then:

1. validates `backup-manifest.json`, `database.dump`, the current-version S3 directory, and recorded checksums/counts;
2. starts clean infrastructure using `.env.docker` local credentials, never credentials from the AWS backup environment file;
3. applies the new V1 and repeatable grants;
4. truncates application tables while retaining the new V1 Flyway history row;
5. restores database data only, excluding `public.flyway_schema_history`;
6. restores current S3 objects into the configured local MinIO market-data bucket;
7. starts all application services;
8. verifies manifest row counts, MinIO object count, migration count, container health, and HTTP endpoints.

Any failed validation stops before deleting volumes. Any failed restore leaves the D backup unchanged and reports the exact failed phase.

## Testing

- Baseline policy tests prove that only V1 is active before contributed post-V1 migrations.
- A clean-database equivalence test compares the old bundle source and generated V1 before the historical files are removed.
- Flyway bundle tests prove one successful V1 plus the generated repeatable grant migration, 181 application tables, and zero failed migrations.
- Restore-script tests use a small synthetic dump/object fixture to prove validation, deletion boundaries, Flyway-history exclusion, and failure behavior.
- A final real-backup rehearsal resets local project volumes, restores the D backup, checks the manifest counts and 10,732 current S3 objects, and verifies the UI/API endpoints.

## Delivery order

1. Commit and push affected child repositories on feature branches.
2. Update the root feature branch to those exact child commits.
3. Refresh and verify the pinned root Flyway bundle.
4. Commit and push the root feature branch.
5. Recreate the local environment from the D backup using only the pushed revisions.

The child branches and root branch target their respective `develop` branches. No direct commit or push is made to `develop` or `main`.
