# Development legacy market catalog bootstrap

This runbook materializes the existing Development market catalog into the
canonical runtime database without rewriting the legacy database or any S3
object. The provider implementation is pinned by the root gitlink to
`ac3cecf5fcd1918d6902fbbaa38ce347af56c23b`, and the operator must supply the
immutable ARM64 `pipeline-worker` ECR digest produced from that release candidate.

The orchestrator launches one temporary `t4g.small` host with no inbound rules,
uses SSM Run Command, fetches both database credentials from Secrets Manager only
on that host, and terminates the instance in `finally`. Database URLs are placed
only in an owner-readable Docker env-file; they are not command arguments,
Terraform outputs, evidence, or normal logs. A transient inline role policy is
removed after the command window.

## 1. Produce and review the dry run

Run from an exact, clean root checkout. Substitute the reviewed Development AWS
account guard and exact ECR digest. `-Execute` authorizes the temporary AWS compute
and versioned evidence write; it does not authorize catalog writes in `DryRun`.

```powershell
./scripts/invoke-development-market-catalog-bootstrap.ps1 `
  -AwsProfile idea2strategy-terraform `
  -ExpectedAwsAccountId '<development-account-id>' `
  -PipelineImageDigest 'sha256:<64-lowercase-hex>' `
  -Phase DryRun -Execute
```

The result must report `status: passed`, 768 verified version-pinned objects, 96
manifests, a source digest, and the key, `VersionId`, and SHA-256 of a receipt in
the existing versioned market-data bucket. Review the receipt's per-table source,
target, and missing counts. Keep these three values for the apply gate:

- `source_digest`
- `receipt_version_id`
- `receipt_sha256`

The dry run performs database reads and S3 HEAD requests only. It does not upload,
delete, or rewrite market objects and does not change either database.

## 2. Apply the reviewed snapshot

Use the same root commit and image digest. The orchestrator retrieves the exact
versioned dry-run receipt and rejects any mismatch in root, provider commit,
image, bucket, digest, 768-object gate, or 96-manifest gate.

```powershell
./scripts/invoke-development-market-catalog-bootstrap.ps1 `
  -AwsProfile idea2strategy-terraform `
  -ExpectedAwsAccountId '<development-account-id>' `
  -PipelineImageDigest 'sha256:<same-64-lowercase-hex>' `
  -Phase Apply -ReviewedDryRunSourceDigest '<reviewed-source-digest>' `
  -ReviewedDryRunReceiptVersionId '<reviewed-version-id>' `
  -ReviewedDryRunReceiptSha256 '<reviewed-receipt-sha256>' `
  -Execute
```

The provider first repeats the read-only preflight, performs the append-only
migration in one transaction, and immediately executes it again. Success requires
the replay to return `ALREADY_APPLIED` with zero inserted rows. The final apply
receipt is also uploaded as a versioned object and identifies the exact root,
provider commit, image digest, source digest, counts, apply result, and replay.

## Failure and recovery

- A divergent or extra canonical row fails closed; no overwrite is attempted.
- A missing or changed S3 version, size, encryption marker, or content hash fails
  before database writes.
- A failed transaction rolls back. Re-run DryRun and review new evidence before
  retrying Apply.
- If cleanup reports a failure, terminate only the instance tagged
  `Purpose=idea2strategy-development-market-catalog-bootstrap` and remove only the
  named transient inline policy from the Terraform-managed bootstrap role. Never
  delete the RDS database, catalog rows, or historical S3 objects as rollback.
