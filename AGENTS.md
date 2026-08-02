# Agent entry

## Required Idea2Strategy policy

Before any task, run `scripts/initialize-local-harness.ps1 -Verify`, then read `docs/collaboration-policy.md` in addition to the Stackcord entry below. It is the canonical Idea2Strategy-specific Git and collaboration policy. Do not modify it during ordinary work. If a change is needed, stop the affected work and record a separate policy-change request for the authorized policy document owner. Run `scripts/verify-collaboration-policy.ps1` after the local policy baseline exists.

## Product authority canonical-write gate

Before editing `.harness/governance.yaml`, `specs/**`, `contracts/**`, `docs/collaboration-policy.md`, or the files that enforce this gate, run `stackcord governance check --json`. A canonical write is allowed only when a fresh provider observation for the exact repository, head commit, and protected fingerprint reports an approved authority that is one of the configured product authorities: `user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`, or `user:Pearone99`. If the result is missing, stale, unknown, unavailable, or names any other subject, you must not edit the canonical protected source; create only a clearly isolated proposal and do not describe it as approved, integrated, or releasable. Git user.name and user.email never prove authority.

<!-- stackcord:begin -->
Before changing the project, read `.harness/entry.md` and refresh actual context. Product meaning lives in `specs/`; obligations live in `contracts/`; coordination state lives in `.harness/`. Protected product meaning stays a proposal until `stackcord governance check --json` confirms an assigned product authority through the selected Git review provider; Git user.name and user.email never prove authority.

When `workspace.ui` is declared, recover its exact baseline and root pointer before frontend work. Optional UI tools create inputs; committed service specifications, contracts, and the UI baseline remain authoritative.
<!-- stackcord:end -->
