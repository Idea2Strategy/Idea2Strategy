# Market-data baseline runbook

This runbook preserves the valuable stock-data catalog, backfill manifests, lineage, and Parquet objects while development moves off AWS. Customer records are not part of the required baseline.

## What is stored where

Git contains the export/import/verification scripts and this runbook. It must not contain database dumps, Parquet objects, generated manifests, import receipts, AWS credentials, or `.env.docker`.

Choose a directory on an SSD outside the repository, for example `D:\Idea2Strategy-data\baseline-2026-08-12`. Copy the completed directory to a second independent disk. A baseline is not complete until both copies pass verification.

The logical UUID in `storage.objects.id`, every S3 object key, and every SHA-256 stay unchanged. S3 or MinIO provider version IDs are physical locations and are recorded again during import.

## 1. Prepare the local stack

```powershell
.\scripts\dev.ps1 up -Scope all -WithBackend -NoBrowser
```

After the first full build, rebuild only a changed service:

```powershell
.\scripts\dev.ps1 restart -Service backend-api -NoBrowser
.\scripts\dev.ps1 restart -Service backtest-worker -NoBrowser
```

## 2. Export from the old AWS account

Prerequisites: authenticated AWS CLI v2, `psql`, `pg_dump`, enough free SSD space, an RDS connection URL, and read permission for the source bucket and object versions. The command performs only database reads and S3 `GetObject` operations. If RDS is private, run the exporter from an approved network path such as an SSM port-forwarded session or the existing database-access host; do not make RDS public for the backup.

```powershell
.\scripts\export-market-data-baseline.ps1 `
  -BaselinePath 'D:\Idea2Strategy-data\baseline-2026-08-12' `
  -DatabaseUrl $env:I2S_SOURCE_DATABASE_URL `
  -Bucket 'SOURCE_MARKET_DATA_BUCKET' `
  -Region 'ap-northeast-2' `
  -AwsProfile 'old-account-readonly'
```

The exporter creates `market-catalog.dump`, `storage-objects.csv`, `objects/`, and `baseline-manifest.json`. It downloads every catalogued object in the selected market-data bucket by its exact key and source VersionId, then verifies byte size and SHA-256. Keeping the storage catalog separate prevents unrelated result-bucket metadata from being restored without its bytes.

## 3. Verify and make the second copy

```powershell
.\scripts\verify-market-data-baseline.ps1 -BaselinePath 'D:\Idea2Strategy-data\baseline-2026-08-12'
Copy-Item -Recurse 'D:\Idea2Strategy-data\baseline-2026-08-12' 'E:\Idea2Strategy-backup\baseline-2026-08-12'
.\scripts\verify-market-data-baseline.ps1 -BaselinePath 'E:\Idea2Strategy-backup\baseline-2026-08-12'
```

Do not delete the source AWS data after one successful copy. Retain it until the second local copy and the later new-account restore drill both pass.

## 4. Import into local PostgreSQL and MinIO

Start local infrastructure first. Read the generated credentials from the Git-ignored `.env.docker`; do not paste them into Git or chat.

```powershell
$env:AWS_ACCESS_KEY_ID = '<MINIO_ROOT_USER from .env.docker>'
$env:AWS_SECRET_ACCESS_KEY = '<MINIO_ROOT_PASSWORD from .env.docker>'
.\scripts\import-market-data-baseline.ps1 `
  -BaselinePath 'D:\Idea2Strategy-data\baseline-2026-08-12' `
  -DatabaseUrl $env:I2S_LOCAL_DATABASE_URL `
  -TargetBucket 'idea2strategy-local-market-data' `
  -Region 'ap-northeast-2' `
  -S3EndpointUrl 'http://127.0.0.1:19000'
```

The import receipt records the new provider version ID for each unchanged logical UUID and key. An import without `-S3EndpointUrl` is rejected unless `-AllowAwsTarget` is explicitly supplied.

## 5. Move to a completely different AWS root account

1. Create and secure the new root account; create day-to-day administrative access separately.
2. Apply `infra/terraform/bootstrap`, then the environment modules with new account-specific variables and remote state.
3. Run the central Flyway bundle against the new RDS instance.
4. Run the importer with the new database URL and bucket. Omit `-S3EndpointUrl`, add the new AWS profile, and explicitly pass `-AllowAwsTarget`.
5. Verify object counts, logical UUIDs, keys, byte sizes, SHA-256 values, catalog relations, and application reads.
6. Enable writers only after verification; keep both SSD copies until an AWS backup/restore drill succeeds.

Terraform remains reusable because credentials, account IDs, bucket names, DNS values, and state are external inputs. Do not copy old Terraform state into the new account.

## Current-machine prerequisite check

```powershell
Get-Command aws, psql, pg_dump, pg_restore
aws sts get-caller-identity
```

Review the identity before export or import. Never print environment variables containing credentials.
