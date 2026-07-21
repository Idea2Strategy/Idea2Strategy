# Agent entry

## Required Idea2Strategy policy

Before any task, run `scripts/initialize-local-harness.ps1 -Verify`, then read `docs/collaboration-policy.md` in addition to the Stackcord entry below. It is the canonical Idea2Strategy-specific Git and collaboration policy. Do not modify it during ordinary work. If a change is needed, stop the affected work and record a separate policy-change request for the authorized policy document owner. Run `scripts/verify-collaboration-policy.ps1` after the local policy baseline exists.

<!-- stackcord:begin -->
Before changing the project, read `.harness/entry.md` and refresh actual context. Product meaning lives in `specs/`; obligations live in `contracts/`; coordination state lives in `.harness/`. Protected product meaning stays a proposal until `stackcord governance check --json` confirms an assigned product authority through the selected Git review provider; Git user.name and user.email never prove authority.

When `workspace.ui` is declared, recover its exact baseline and root pointer before frontend work. Optional UI tools create inputs; committed service specifications, contracts, and the UI baseline remain authoritative.
<!-- stackcord:end -->
