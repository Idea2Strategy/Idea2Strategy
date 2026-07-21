# Git Flow Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `develop` the verified collaboration and default branch on both remotes while reserving `main` for the complete `v1.0.0` release.

**Architecture:** Publish one policy correction from the GitHub submodule workspace, apply it to the GitLab monolithic workspace, then change host defaults through credential-manager-backed API calls. Delete only redundant or mistaken refs after exact SHA and default-branch checks pass.

**Tech Stack:** Git, PowerShell 5.1+, Git Credential Manager, GitHub REST API, self-managed GitLab REST API, Stackcord CLI

## Global Constraints

- GitHub `main` must remain at `8d890b9bf553286171c0421a6c997dc2314005b7`.
- GitLab `main` must not be deleted until GitLab reports `develop` as default.
- Credentials remain in Git Credential Manager and process memory only; never print or persist them.
- Do not change DBML semantics, the GitHub `ui` gitlink, or the GitLab `ui` tree.
- Ordinary future pull/merge requests target `develop`; only release and post-release hotfix work targets `main`.

---

### Task 1: Canonical Git Flow policy

**Files:**
- Create: `docs/superpowers/specs/2026-07-22-git-flow-design.md`
- Create: `docs/superpowers/plans/2026-07-22-git-flow-correction.md`
- Modify: `docs/collaboration-policy.md`

- [x] Record the approved branch roles, PR targets, release tag rule, and repository-specific correction.
- [x] Refresh the authorized local policy integrity hash and run policy, Stackcord, DBML, and submodule verification.
- [x] Commit with `docs: define develop-first git flow` and push the current GitHub review branch.

### Task 2: GitHub develop branch

**Files:**
- Modify only Git refs and ignored local sync metadata.

- [ ] Rename the clean linked-worktree branch from `feature/collaboration-harness` to `develop`.
- [ ] Push `develop`, verify its exact remote SHA, then delete the redundant remote feature branch.
- [ ] Change the GitHub default branch to `develop` through a credential-manager-backed API call and verify it without exposing account data.

### Task 3: GitLab develop branch

**Files:**
- Modify only Git refs and ignored local sync metadata in `Idea2Strategy-gitlab`.

- [ ] Fetch the exact GitHub policy commit and cherry-pick it into the clean monolithic workspace.
- [ ] Rename the local GitLab branch from `main` to `develop`, push it, and verify its exact remote SHA.
- [ ] Change the GitLab default branch to `develop`, verify the symref, then delete the mistaken remote `main`.

### Task 4: Final verification

**Files:**
- Verify only.

- [ ] Confirm both hosting projects report `develop` as default and both local workspaces track `develop`.
- [ ] Confirm GitHub `main` remains unchanged and GitLab `main` no longer exists.
- [ ] Confirm GitHub has exactly one `ui` gitlink, GitLab has none, and the GitLab `ui` tree equals the source UI tree.
- [ ] Run local-harness, collaboration-policy, Stackcord context, DBML hash, build, remote-SHA, and clean-worktree checks.
