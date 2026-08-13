# Portable Local Development, Data Baseline, and AWS Return Design

Date: 2026-08-12
Status: approved direction from the project owner conversation

## Goal

Make the complete Idea2Strategy stack usable by collaborators on local machines, preserve the irreplaceable market-data catalog and Parquet objects outside Git, and keep a deterministic path to a completely separate AWS account.

## Decisions

### Local runtime

- Docker Compose remains the orchestration layer.
- PostgreSQL replaces RDS, MinIO replaces S3, LocalStack replaces SQS, and Redis remains an ephemeral cache.
- The first bootstrap may build and start the complete stack.
- Later edits rebuild only the selected application service. Shared PostgreSQL, MinIO, Redis, and LocalStack containers stay running.
- Compose service names are the stable unit of selection; one command must support `backend-api`, `backend-batch`, `backend-worker`, `admin-mcp`, `market-gateway`, `trading-worker`, `backtest-api`, `backtest-worker`, and `frontend`.

### Durable data baseline

- Parquet objects and database dumps are not stored in Git or Git LFS.
- The primary baseline lives in a user-selected local SSD directory outside the repository and must have a second independent physical copy.
- Git stores only scripts, documentation, a schema-versioned baseline manifest example, and checksums generated inside the baseline directory.
- The export unit consists of:
  - a PostgreSQL custom-format dump for the required market-data and storage catalog schemas;
  - every referenced S3 object at its exact bucket key;
  - a machine-readable inventory containing logical object UUID, source key, source provider version, byte size, and SHA-256;
  - export metadata and verification results.
- Fake customer data is not part of the required baseline.

### Object identity

- `storage.objects.id` and S3 object keys are logical identities and must be preserved.
- Copying an object to MinIO or a new S3 bucket does not regenerate those values.
- AWS S3 VersionId and MinIO version IDs are provider-specific physical metadata. Import records a target mapping and updates only provider-location metadata when necessary.
- Import is rejected when bytes do not match the baseline SHA-256, when an expected object is missing, or when duplicate logical IDs disagree.

### Collaboration

- Source, Compose definitions, scripts, and the small manifest schema are shared through Git.
- Each collaborator receives the large baseline through an approved physical or object-storage transfer, verifies it, and imports it locally.
- Secrets, AWS credentials, dumps, Parquet files, generated inventories, and local target mappings remain Git-ignored.
- A collaborator can develop with synthetic fixtures when the full baseline is unavailable, but cannot claim market-data parity until baseline verification passes.

### CI scheduling

- Pull requests run root policy checks and lint/unit/build only for changed service pointers or relevant root files.
- Database, API contract, Compose, Flyway bundle, or submodule pointer changes enable integration checks.
- Full E2E and security checks run on `main`, nightly schedule, and manual dispatch, not ordinary pull requests.
- Terraform remains in the repository and runs for infrastructure changes, `main`, and manual dispatch.
- A small always-running summary job keeps branch protection stable even when expensive jobs are skipped.

### New AWS account

1. Create the new root account and configure administrative access separately from application IAM.
2. Bootstrap Terraform state and apply the retained Terraform modules with new account-specific variables.
3. Run Flyway against the new RDS instance.
4. Upload baseline objects to the new market-data bucket using their exact keys.
5. Restore the market-data/storage catalog, remapping only bucket/provider/version fields required by the target.
6. Verify counts, UUID/key relationships, byte size, SHA-256, and application reads before enabling writers.
7. Keep the local baseline and its second copy until the new AWS backup and restore drill pass.

## Safety boundaries

- Export is read-only against the source AWS account.
- Import requires an explicit target and refuses an AWS endpoint unless the operator opts in.
- No script prints credentials or embeds them in manifests.
- Destructive reset remains separate from normal start/restart commands.
- Terraform state, AWS credentials, database dumps, and object bytes never enter Git.

## Verification

- Static tests prove Compose service targeting and CI path routing.
- Fixture tests export, verify, tamper-detect, and import a small database/object baseline.
- Docker smoke tests prove infrastructure persistence and targeted service rebuild behavior.
- A real source export is complete only after the source AWS credentials and required CLI tools are available and the generated baseline verifies from the second copy.
