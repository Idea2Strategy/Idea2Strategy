---
name: use-project-harness
description: Restore and verify Idea2Strategy project context using repository-owned scripts and Git state.
---

# Use Project Harness

Treat the user's natural-language request as the entry point. Run
`scripts/initialize-local-harness.ps1 -Verify`, read `AGENTS.md`,
`docs/collaboration-policy.md`, and the relevant specification or contract,
then inspect actual Git, worktree, submodule, issue, and pull-request state.

The launch plan is `docs/launch-readiness-plan.md`; its machine-readable ledger
is `docs/launch-readiness-tasks.json`. Use `scripts/launch-status.ps1 -Owner
<owner>` when selecting launch work. Do not infer live external status from a
cached local record.

For shared or risky work, use a dedicated worktree, declare path ownership and
merge order, and keep product meaning in `specs/` and obligations in
`contracts/`. Use tests as the completion evidence. The local operational area
under `.harness/local/` is ignored by Git and must never contain credentials.

Before changing protected product, policy, business, or contract sources,
read `docs/product-authorities.yaml`. Until v1.0.0, quote the explicit
instruction of one configured authority in the pull-request body. From v1.0.0,
require a fresh GitHub approval on the exact commit. Git display metadata never
proves authority.

If GitHub is unavailable, follow `references/fallback.md` and report external
review or issue state as unverified.
