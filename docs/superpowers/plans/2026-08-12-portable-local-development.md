# Portable Local Development Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preserve the production-relevant market-data baseline locally, let collaborators run and update the modular Docker stack efficiently, and make CI plus Terraform ready for a later deployment into a different AWS account.

**Architecture:** Root PowerShell tools orchestrate a versioned baseline directory and Docker Compose service units. CI begins with a deterministic changed-path classifier whose outputs gate service, integration, infrastructure, E2E, and security jobs. Provider-specific object version identifiers are recorded as mappings while logical UUIDs, keys, and hashes remain stable.

**Tech Stack:** PowerShell 5.1+, Docker Compose, PostgreSQL 16 tools, MinIO client/S3-compatible API, AWS CLI v2, GitHub Actions, Terraform 1.15.

---

### Task 1: Lock data and orchestration contracts with failing tests

**Files:**
- Create: `scripts/test-market-data-baseline.ps1`
- Create: `scripts/test-ci-change-routing.ps1`
- Modify: `scripts/test-docker-development.ps1`

1. Add fixture tests requiring a versioned baseline manifest, deterministic SHA-256 inventory, missing/tampered-object rejection, and logical UUID/key preservation.
2. Add routing tests for docs-only, individual submodule pointers, DB/contract/Compose, Terraform, main, nightly, and manual cases.
3. Add Docker script tests requiring a service selector and targeted `docker compose up -d --build <service>` invocation.
4. Run all three tests and confirm they fail for the missing implementation.

### Task 2: Implement portable market-data baseline tools

**Files:**
- Create: `scripts/market-data-baseline.ps1`
- Create: `scripts/export-market-data-baseline.ps1`
- Create: `scripts/import-market-data-baseline.ps1`
- Create: `scripts/verify-market-data-baseline.ps1`
- Create: `docs/infrastructure/market-data-baseline-runbook.md`
- Modify: `.gitignore`

1. Implement shared path, manifest schema, hashing, inventory, and safe process helpers.
2. Implement source export using `pg_dump` and AWS S3 read operations, preserving logical IDs and keys.
3. Implement local MinIO/PostgreSQL import with explicit target parameters and a target-version mapping receipt.
4. Implement offline verification that needs no AWS access.
5. Add ignore rules for all generated baseline payloads and receipts.
6. Run fixture tests and PowerShell parser checks.

### Task 3: Implement targeted Docker development

**Files:**
- Modify: `scripts/dev.ps1`
- Modify: `scripts/dev-menu.ps1`
- Modify: `infra/docker/README.md`
- Modify: `docs/development-start-guide.md`

1. Add a validated `-Service` selector mapped to Compose services.
2. Make targeted restart prepare Flyway only when required and rebuild/recreate only the selected service and dependencies that are not already running.
3. Preserve existing full `up`, infrastructure-only mode, volumes, and destructive reset separation.
4. Run static Docker checks, Compose config validation, and a targeted command smoke test.

### Task 4: Implement deterministic CI path routing

**Files:**
- Create: `scripts/resolve-ci-change-scope.ps1`
- Modify: `.github/workflows/ci.yml`
- Modify: `scripts/test-ci-scheduling.ps1`
- Modify: `scripts/test-github-action-runtime-pins.ps1` if new pinned actions are introduced

1. Implement classifier outputs for each service, root/schema, integration, infrastructure, E2E, and security scopes.
2. Add an always-running classify job and gate jobs from its outputs.
3. Run changed-service lint/unit/build only for changed gitlinks or service-affecting root files.
4. Gate Flyway/contract/Compose integration to relevant paths.
5. Schedule full E2E/security for main, nightly, and manual dispatch.
6. Gate Terraform to infrastructure paths, main, and manual dispatch.
7. Add a final summary job with stable status and test every routing scenario.

### Task 5: Document the agent and collaborator workflow

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `docs/development-start-guide.md`
- Modify: `docs/infrastructure/market-data-baseline-runbook.md`

1. Link the baseline runbook and state the no-Git-data rule.
2. Document first full startup, later targeted rebuild, baseline verification, and new-account restore order.
3. State that a real export is not complete without CLI/authentication evidence and a verified second copy.

### Task 6: Verify locally and attempt the real baseline export

**Files:**
- Generated outside Git: operator-selected baseline directory
- Generated outside Git: second-copy directory or external SSD

1. Run collaboration, Docker, CI routing, CI scheduling, baseline fixture, and Terraform readiness tests.
2. Run `docker compose config` and start the infrastructure stack.
3. Import fixture baseline into local PostgreSQL/MinIO and validate object reads plus catalog relations.
4. Detect AWS CLI, PostgreSQL client tools, source credentials, and destination disk capacity without exposing secrets.
5. If available, export the real market-data baseline read-only, copy it to the second device, and verify both copies.
6. If unavailable, report the exact external prerequisite while leaving all code and local fixture verification complete.

### Task 7: Final review

1. Run `git diff --check` and inspect the complete diff for secrets or generated data.
2. Re-run all new and affected tests from a clean process.
3. Record what is locally ready, what data was actually copied, and the exact remaining AWS-account actions.
