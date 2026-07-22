# Fresh-clone Collaboration Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make fresh GitHub and GitLab `develop` clones pass every documented collaboration startup check without copying user-specific local files.

**Architecture:** The existing local-harness initializer remains the single onboarding entry point. It creates an ignored, non-secret provider-authority reference only when missing, while the existing verifier continues to enforce its contents and Stackcord remains the provider-backed authorization boundary.

**Tech Stack:** PowerShell 5.1, Git, Stackcord 1.0.0, GitHub submodules, GitLab monolithic mirror

## Global Constraints

- Do not modify protected governance or verifier files without a fresh provider-backed approval.
- Never authenticate with Git name, Git email, or local metadata.
- Never overwrite an existing local owner record.
- Never track generated owner metadata, integrity metadata, credentials, caches, logs, or temporary artifacts.
- GitHub `develop` retains the exact `ui` submodule pointer; GitLab `develop` retains a monolithic `ui` tree.

---

### Task 1: Generate the non-secret authority reference

**Files:**
- Modify: `scripts/test-local-harness.ps1`
- Modify: `scripts/initialize-local-harness.ps1`

**Interfaces:**
- Consumes: a repository root containing `.git`, `.harness/manifest.yaml`, and the tracked local-harness skeleton
- Produces: ignored `.harness/local/project/policy/owner.yaml` containing `provider_authority: user:kcrmin` and `contact_email_is_authority: false`

- [ ] **Step 1: Write the failing first-run test**

Add assertions after the first initializer invocation:

```powershell
$ownerPath = Join-Path $sandbox '.harness/local/project/policy/owner.yaml'
Assert-True (Test-Path -LiteralPath $ownerPath -PathType Leaf) 'first bootstrap creates local authority reference'
$ownerText = Get-Content -Raw -Encoding utf8 $ownerPath
Assert-True $ownerText.Contains('provider_authority: user:kcrmin') 'authority reference names provider identity'
Assert-True $ownerText.Contains('contact_email_is_authority: false') 'authority reference rejects email authentication'
```

- [ ] **Step 2: Write the failing preservation test**

Before the second initializer run, replace the generated file with a sentinel local record. After the run, assert that its SHA-256 hash is unchanged.

- [ ] **Step 3: Run the focused test and verify RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
```

Expected: FAIL because a fresh initialization does not create `owner.yaml`.

- [ ] **Step 4: Implement minimal first-run creation**

Add an initializer function that writes this local-only content only when the file is absent:

```yaml
schema_version: 1
provider: github
repository: Idea2Strategy/Idea2Strategy
provider_authority: user:kcrmin
contact_email_is_authority: false
purpose: non-secret product-authority reference; provider verification is required
```

Call it after the local layout and policy integrity baseline are initialized.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run the same test and require all assertions to pass.

- [ ] **Step 6: Commit the tested behavior**

```powershell
git add scripts/test-local-harness.ps1 scripts/initialize-local-harness.ps1
git commit -m "fix: initialize clone authority reference"
```

### Task 2: Make onboarding instructions executable

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: Git, PowerShell, Stackcord 1.0.0, and access to the selected remote
- Produces: exact clone, initialize, verify, and status commands for contributors

- [ ] **Step 1: Add the startup sequence**

Document that the default branch is `develop`, GitHub clone uses `--recurse-submodules`, GitLab clone is monolithic, Stackcord 1.0.0 must be available, and the commands run in this order:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-local-harness.ps1 -Verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1
stackcord context audit --root . --json
stackcord status --json
```

Explain that governance status remains fail-closed until a fresh provider approval exists.

- [ ] **Step 2: Run documentation and policy regressions**

Run:

```powershell
git diff --check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
stackcord context audit --root . --json
```

- [ ] **Step 3: Commit onboarding documentation**

```powershell
git add README.md docs/superpowers/plans/2026-07-22-clone-readiness.md
git commit -m "docs: define clone onboarding checks"
```

### Task 3: Integrate and prove both distributed clone paths

**Files:**
- Mirror reviewed tracked changes into the GitLab monolithic candidate without changing its `ui` boundary
- Record Stackcord evidence locally

**Interfaces:**
- Consumes: clean candidate commits and both authenticated remotes
- Produces: matching reviewed behavior on each remote `develop` branch and fresh-clone verification evidence

- [ ] **Step 1: Verify candidates before publication**

Require policy verification, all local-harness assertions, context audit, `git diff --check`, ignored owner metadata, no tracked email/credential, and clean worktrees.

- [ ] **Step 2: Preserve repository boundaries**

Require GitHub `ui` at `283926c5cd91e89c15d0f661fc2120a053529930`. Require GitLab to have no `.gitmodules` and no nested `ui/.git`.

- [ ] **Step 3: Push candidate branches and fast-forward `develop`**

Push `fix/clone-readiness` to both remotes, verify the merged result, and push only `develop`; leave `main` and `feature/dbml` unchanged.

- [ ] **Step 4: Run real clean-clone acceptance**

For each remote, clone the default branch into an isolated temporary directory. Run initializer, policy verifier, context audit, status, clean-tree checks, and the appropriate UI boundary check. Require all mandatory checks to pass; governance `unknown` is acceptable only as the documented fail-closed authorization state.

- [ ] **Step 5: Finish coordination and audit completion**

Bind test, integration, and user-validation evidence to the exact commits, transition the Stackcord work through review and integrated to done, and verify remote heads, default branches, clean workspaces, unchanged `main`/DBML, and no remaining onboarding blocker.
