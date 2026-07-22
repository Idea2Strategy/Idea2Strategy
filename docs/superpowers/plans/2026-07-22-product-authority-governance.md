# Product Authority Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Idea2Strategy fail closed unless GitHub verifies `user:kcrmin` before canonical product, policy, business, contract, or governance mutation, while keeping email non-authoritative and other contributors limited to isolated proposals.

**Architecture:** Native Stackcord governance provides exact provider-account approval for integration and release. Repository entry instructions add the stricter pre-mutation stop for compliant agents, and the existing PowerShell verifier checks that neither configuration nor instructions can silently weaken the boundary. GitHub remains the canonical authority provider for both the GitHub root and GitLab monolithic mirror.

**Tech Stack:** Stackcord 1.0.0 governance YAML, Markdown agent instructions, PowerShell verification, GitHub/GitLab Git repositories.

## Global Constraints

- The sole authority is the provider-normalized GitHub subject `user:kcrmin`.
- The canonical review repository is `Idea2Strategy/Idea2Strategy`.
- `kyoungcheul.min@gmail.com` is contact metadata only and never authorization evidence.
- Missing, stale, unavailable, or non-matching provider evidence denies canonical mutation.
- Other actors may prepare isolated proposals but may not modify canonical protected sources in place or claim approval, integration, or release.
- Remote branch protection and CI remain explicitly unapplied; this work must not claim otherwise.
- Apply equivalent committed rules to the GitHub root and GitLab monolithic mirror.

---

### Task 1: Add a failing governance configuration verification

**Files:**
- Modify: `scripts/verify-collaboration-policy.ps1`
- Test: `scripts/verify-collaboration-policy.ps1`

**Interfaces:**
- Consumes: `.harness/governance.yaml`, `AGENTS.md`, `.agents/skills/use-project-harness/SKILL.md`, and `docs/collaboration-policy.md`.
- Produces: a nonzero exit when committed governance or canonical-write instructions differ from the approved authority design.

- [ ] **Step 1: Add exact governance assertions before changing governance configuration**

Load `.harness/governance.yaml` as text and assert these exact normalized values:

```powershell
$governancePath = Join-Path $repositoryRoot '.harness/governance.yaml'
$governanceText = Get-Content -Raw -Encoding utf8 $governancePath
foreach ($required in @(
  'enabled: true',
  'provider: github',
  'repository: Idea2Strategy/Idea2Strategy',
  'user:kcrmin',
  'protected_kinds: [product, policy, business, contract]'
)) {
  if (-not $governanceText.Contains($required)) {
    throw "Governance requirement is missing: $required"
  }
}
```

Also assert that the shared enforcement files contain `stackcord governance check --json`, `user:kcrmin`, `fresh provider`, `must not edit`, and an explicit rejection of Git name/email authority.

- [ ] **Step 2: Run the verifier and observe the intended failure**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1
```

Expected: FAIL because `.harness/governance.yaml` still contains `enabled: false` and no authority.

- [ ] **Step 3: Commit only after the red result is captured together with Task 2's green implementation**

Do not commit a permanently failing branch; retain the observed output as TDD evidence.

### Task 2: Enable native governance and the strict agent pre-mutation rule

**Files:**
- Modify: `.harness/governance.yaml`
- Modify: `AGENTS.md`
- Modify: `.agents/skills/use-project-harness/SKILL.md`
- Modify: `.agents/skills/use-project-harness/references/fallback.md`
- Modify: `docs/collaboration-policy.md`
- Modify: `.harness/local/project/policy/owner.yaml` (ignored local metadata only)

**Interfaces:**
- Consumes: the exact checks added in Task 1.
- Produces: native Stackcord governance plus a repository-local rule that stops canonical mutation before an authority check succeeds.

- [ ] **Step 1: Write the minimal governance configuration**

```yaml
schema_version: 1
enabled: true
provider: github
repository: Idea2Strategy/Idea2Strategy
product_authorities: [user:kcrmin]
protected_kinds: [product, policy, business, contract]
approval:
  minimum: 1
  authority_self_approval: true
```

- [ ] **Step 2: Add one consistent canonical-write contract to all agent entry points**

Require `stackcord governance check --json` before editing `.harness/governance.yaml`, `specs/**`, `contracts/**`, `docs/collaboration-policy.md`, or their enforcement files. State that only a fresh exact provider-backed approval identifying `user:kcrmin` permits canonical mutation; otherwise the agent must not edit those sources and may only prepare a clearly isolated proposal.

- [ ] **Step 3: Record the owner contact locally without treating it as authentication**

Add these ignored local fields:

```yaml
provider_authority: user:kcrmin
contact_email: kyoungcheul.min@gmail.com
contact_email_is_authority: false
```

- [ ] **Step 4: Run the verifier and confirm green**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1 -AuthorizedPolicyChange
```

Expected: PASS with governance assertions included in the JSON summary.

- [ ] **Step 5: Run context and harness regression checks**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
stackcord context audit --root . --json
stackcord governance check --root . --json
```

Expected: harness and context checks pass; governance is enabled and remains unapproved/unknown until fresh GitHub review evidence exists.

- [ ] **Step 6: Commit the GitHub candidate**

```powershell
git add .harness/governance.yaml AGENTS.md .agents/skills/use-project-harness/SKILL.md .agents/skills/use-project-harness/references/fallback.md docs/collaboration-policy.md scripts/verify-collaboration-policy.ps1
git commit -m "feat: enforce product authority governance"
```

Do not add `.harness/local/project/policy/owner.yaml`.

### Task 3: Mirror the governance contract into the GitLab monolithic repository

**Files:**
- Modify the same committed files in `C:/Users/SSAFY/Documents/Idea2Strategy/Idea2Strategy-gitlab`.
- Preserve: the monolithic `ui/` directory and absence of `.gitmodules`.

**Interfaces:**
- Consumes: the exact reviewed GitHub governance candidate.
- Produces: a semantically identical governance boundary in the GitLab mirror while GitHub remains the authority provider.

- [ ] **Step 1: Create the matching conventional GitLab branch**

Run:

```powershell
git switch -c chore/product-authority-governance
```

- [ ] **Step 2: Apply the exact committed governance and instruction content**

Use the same provider, repository, authority, protected kinds, and pre-mutation wording. Do not introduce GitLab account identity as an independent product authority.

- [ ] **Step 3: Run GitLab-local verification**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-harness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1 -AuthorizedPolicyChange
stackcord context audit --root . --json
stackcord governance check --root . --json
```

Expected: all repository checks pass and governance fails closed without fresh GitHub observation.

- [ ] **Step 4: Verify monolithic boundaries and commit**

```powershell
if (Test-Path .gitmodules) { throw 'GitLab must remain monolithic.' }
if (Test-Path ui/.git) { throw 'GitLab ui must not be a nested repository.' }
git add .harness/governance.yaml AGENTS.md .agents/skills/use-project-harness/SKILL.md .agents/skills/use-project-harness/references/fallback.md docs/collaboration-policy.md scripts/verify-collaboration-policy.ps1
git commit -m "feat: enforce product authority governance"
```

### Task 4: Verify, complete Stackcord work, and publish to develop

**Files:**
- No new product files.
- Local-only evidence: `.harness/local/evidence/**`.

**Interfaces:**
- Consumes: clean GitHub and GitLab candidate commits.
- Produces: verified Stackcord work completion and synchronized `develop` branches without changing `main` or the DBML review branch.

- [ ] **Step 1: Record current test, security, integration, and user evidence**

Use the approved commands in `.harness/commands.yaml` and bind the explicit user approval artifact to each clean candidate commit.

- [ ] **Step 2: Transition the Stackcord work through review, integrated, and done**

Run `stackcord work transition` and `stackcord work finish` with `--apply`, confirming the remote coordination revision after every transition.

- [ ] **Step 3: Push candidate branches and fast-forward each develop branch**

Push only after all checks pass. Keep GitHub `main` at its existing pre-v1.0 commit and keep `feature/dbml` isolated.

- [ ] **Step 4: Perform the final cross-repository audit**

Verify clean status, remote `develop` equality, Stackcord status, context audit, governance fail-closed state, GitHub UI submodule identity, GitLab monolithic boundary, ignored local metadata, and absence of credential-like values in shared files.
