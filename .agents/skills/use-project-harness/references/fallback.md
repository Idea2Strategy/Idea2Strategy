# Offline project recovery

1. Run `scripts/initialize-local-harness.ps1 -Verify`.
2. Read `AGENTS.md`, `docs/collaboration-policy.md`, the launch ledger, and only
   the specifications and contracts relevant to the request.
3. Inspect `git status --short --branch`, `git worktree list`, remotes, upstream
   divergence, and exact submodule pointers without mutating them.
4. Treat GitHub issue, pull-request, and review state as unverified until an
   authenticated connector or CLI can refresh it.
5. Keep shared work in a dedicated worktree and define path ownership,
   dependencies, merge order, first failing test, and acceptance evidence.
6. Protected canonical changes need an authority listed in
   `docs/product-authorities.yaml`. Before v1.0.0, record that authority's
   explicit instruction in the pull request. From v1.0.0, require a fresh
   approval on the exact commit.

Without authenticated GitHub access, do not claim that remote review, branch
protection, issue assignment, or release status was verified.
