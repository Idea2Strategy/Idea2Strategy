# Collaboration Harness and GitLab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standardize each clone's local harness workspace, protect local/generated data from Git, publish the reviewed shared baseline to GitHub, and prepare a separately authenticated monolithic GitLab workspace.

**Architecture:** Git tracks only the `.harness/local/` directory contract (`README.md` and exact `.gitkeep` markers); all operational content below it remains local. An idempotent PowerShell bootstrap migrates legacy root-local data and verifies the boundary. GitHub remains the submodule-based canonical workspace, while GitLab is a sibling monolithic checkout produced only from a reviewed GitHub commit.

**Tech Stack:** Git, Git submodules, PowerShell 5.1+, Stackcord CLI, Git Credential Manager, dbdiagram CLI (held; verification only)

## Global Constraints

- Do not change `db/schema.dbml` or accepted dbdiagram semantics.
- Do not print, store, migrate, or commit tokens, passwords, cookies, private keys, or recovery codes.
- Do not nest Git worktrees or the GitLab checkout inside the root repository.
- Do not overwrite a legacy file when its destination already exists.
- GitHub keeps `ui` as a submodule; GitLab receives real `ui` files in a separate monolithic workspace.
- Do not claim remote protection rules are active until verified on the corresponding server.

---

### Task 1: Executable local-harness boundary

**Files:**
- Create: `scripts/test-local-harness.ps1`
- Create: `scripts/initialize-local-harness.ps1`
- Create: `.harness/local/README.md`
- Create: `.harness/local/artifacts/.gitkeep`
- Create: `.harness/local/tmp/.gitkeep`
- Create: `.harness/local/cache/.gitkeep`
- Create: `.harness/local/logs/.gitkeep`
- Create: `.harness/local/project/policy/.gitkeep`
- Create: `.harness/local/project/jira/.gitkeep`
- Create: `.harness/local/project/remotes/.gitkeep`
- Create: `.harness/local/project/work/.gitkeep`
- Create: `.harness/local/dbdiagram/.gitkeep`
- Create: `.harness/local/operations/.gitkeep`

**Interfaces:**
- Consumes: repository root containing `.git/` and `.harness/manifest.yaml`
- Produces: `scripts/initialize-local-harness.ps1 [-RepositoryRoot <path>] [-MigrateLegacy] [-Verify]`, returning nonzero on conflict or boundary violation

- [x] **Step 1: Write an isolated failing test**

The test creates a temporary Git repository, copies the bootstrap script when present, creates legacy `output/`, `tmp/`, and `.idea2strategy-local/` fixtures, then asserts the documented skeleton, lossless migration, idempotence, and ignored non-marker contents.

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
```

Expected before implementation: nonzero exit because `scripts/initialize-local-harness.ps1` is missing.

- [x] **Step 2: Implement the bootstrap**

The script must use a fixed directory list, compare source/destination file hashes before removing legacy files, stop on mismatched destination collisions, create only missing directories/markers, and use `git check-ignore` plus `git ls-files` for verification.

- [x] **Step 3: Run red/green verification twice**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
```

Expected: both runs exit `0` with all assertions passed.

### Task 2: Comprehensive ignore policy and legacy migration

**Files:**
- Modify: `.gitignore`
- Modify: `scripts/verify-collaboration-policy.ps1`
- Move local content from: `output/`, `tmp/`, `.idea2strategy-local/`
- Move local content to: `.harness/local/artifacts/`, `.harness/local/tmp/`, `.harness/local/project/`

**Interfaces:**
- Consumes: Task 1 bootstrap and current local inventories
- Produces: one ignored local root with a tracked skeleton and no active legacy local roots

- [x] **Step 1: Replace `.gitignore` with labeled, narrow sections**

Include harness-local exceptions, secrets/environment files, OS/IDE metadata, logs/temp/cache, Node/pnpm/frontend, Python, JVM/Gradle/Maven, test/coverage, and tool-owned local directories. Keep `.env.example` explicitly shared and avoid source-hiding blanket extension rules.

- [x] **Step 2: Capture migration inventories and apply migration**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-local-harness.ps1 -MigrateLegacy -Verify
```

Expected: existing PDF, checkpoint, rendered pages, Jira record, policy metadata, remote state, and harness work records are present under their mapped destinations; no destination is overwritten.

- [x] **Step 3: Verify idempotence and Git boundary**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-local-harness.ps1 -Verify
git ls-files -- .harness/local
git check-ignore -v -- .harness/local/tmp/stackcord-checkpoint.yaml
```

Expected: only `README.md` and `.gitkeep` markers are eligible for tracking; operational files are ignored.

### Task 3: Recovery and policy path alignment

**Files:**
- Modify: `docs/collaboration-policy.md`
- Modify: `AGENTS.md`
- Modify: `.agents/skills/use-project-harness/SKILL.md`
- Modify: `.agents/skills/use-project-harness/references/fallback.md`
- Modify: `.harness/work/definitions/work.collaboration-policy-bootstrap.yaml` through supported Stackcord commands when its fingerprint must change

**Interfaces:**
- Consumes: Task 2 local path contract
- Produces: recovery instructions that discover the tracked skeleton and local records without exposing private values

- [x] **Step 1: Replace legacy local-path references**

All shared documentation must use `.harness/local/project/...`; `.idea2strategy-local/` remains only in migration history and verification of forbidden legacy data.

- [x] **Step 2: Update policy verification**

The verification script checks skeleton markers, ignored operational files, absence of tracked local content beyond the allowlist, policy integrity, and recovery links.

- [x] **Step 3: Run policy and Stackcord checks**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1 -BootstrapReview
stackcord context audit --root . --json
git diff --check
git submodule status --recursive
```

Expected: policy verification and context audit pass; `ui` pointer equals `283926c5cd91e89c15d0f661fc2120a053529930` and is clean.

### Task 4: Exact GitHub review candidate

**Files:**
- Review: every shared untracked or modified file in the root workspace
- Exclude: `.harness/local/` operational contents, `.dbdiagram/`, `.harness-drafts/`, dependencies, credentials, and generated artifacts

**Interfaces:**
- Consumes: Tasks 1–3 verified working tree
- Produces: an exact staged candidate with no secret or local-only file

- [ ] **Step 1: Inspect the complete candidate**

```powershell
git status --short --branch
git diff --check
git diff --cached --check
git submodule status --recursive
```

- [ ] **Step 2: Run all repository checks**

```powershell
pnpm run dbml:validate
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1 -BootstrapReview
stackcord context audit --root . --json
stackcord db diff --before db/schema.dbml --after .harness/local/dbdiagram/dbdiagram-verify-cloud/candidate.dbml --json
```

Expected: all commands exit `0`; DB semantic diff contains no changes.

- [ ] **Step 3: Commit and publish only after the candidate is exact**

Use ordinary project-oriented commit messages with no agent/tool markers. Push the reviewed GitHub branch without altering remote configuration or submodule history.

### Task 5: Separate GitLab monolithic workspace

**Files:**
- Create outside repository: sibling workspace `Idea2Strategy-gitlab`
- Record non-secret state locally: `.harness/local/project/remotes/sync-state.yaml`

**Interfaces:**
- Consumes: exact GitHub commit from Task 4 and GitLab HTTPS repository `https://lab.ssafy.com/s15-webmobile2-sub1/S15P11B205.git`
- Produces: independently authenticated GitLab checkout whose `ui/` is ordinary tracked content, not a gitlink

- [ ] **Step 1: Verify both remotes read-only**

```powershell
git ls-remote origin
$env:GCM_INTERACTIVE='never'
git -c credential.interactive=never ls-remote https://lab.ssafy.com/s15-webmobile2-sub1/S15P11B205.git
```

Expected: GitHub is reachable and GitLab authentication succeeds without printing credentials.

- [ ] **Step 2: Create the sibling workspace from the reviewed root commit**

Clone into an explicit sibling path, verify it is outside the GitHub root, and configure the GitLab URL only in that workspace. Remove the gitlink and `.gitmodules` there, copy the exact committed `ui` tree without its `.git` metadata, and verify ordinary tracked files replace mode `160000`.

- [ ] **Step 3: Verify monolithic boundaries**

```powershell
git -C ..\Idea2Strategy-gitlab ls-files --stage ui
git -C ..\Idea2Strategy-gitlab submodule status
git -C ..\Idea2Strategy-gitlab remote -v
```

Expected: `ui` entries are ordinary files, no submodule remains, and only the GitLab workspace has the GitLab push target.

- [ ] **Step 4: Commit and push the GitLab transformation**

Commit the GitLab-only structure conversion separately from product changes, push to the authenticated GitLab repository, re-read the exact remote branch, and record only commit IDs and topology state in the ignored local sync record.

### Task 6: Final collaboration readiness verification

**Files:**
- Verify only; do not change canonical product or DB files

**Interfaces:**
- Consumes: published GitHub baseline and GitLab monolithic commit
- Produces: evidence-backed readiness report with remaining unapplied server protections clearly identified

- [ ] **Step 1: Run fresh local verification**

```powershell
git status --short --branch
git submodule status --recursive
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1
stackcord context audit --root . --json
```

- [ ] **Step 2: Re-read remote identities**

Confirm the exact GitHub and GitLab commit IDs from their respective workspaces without displaying account identifiers or credentials.

- [ ] **Step 3: Report remaining governance boundaries**

State separately whether GitHub/GitLab protected branches, CODEOWNERS/approval rules, CI checks, Issue provider connectivity, and Jira migration have actually been configured. Unapplied controls remain unapplied.
