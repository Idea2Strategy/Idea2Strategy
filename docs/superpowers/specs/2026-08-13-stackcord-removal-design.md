# Stackcord Removal Design

## Decision

Idea2Strategy no longer depends on Stackcord. The repository keeps its existing
Git, pull-request, product-authority, local workspace, and launch-readiness
rules, but those rules must be executable without a Stackcord CLI, plugin,
marketplace, hook, manifest, or work ledger.

This change is explicitly authorized by product authority `user:kcrmin` in the
2026-08-12/13 conversation: "Stackcord는 지워줘. 이제 더 이상 사용하지 않을꺼야" and
"모든 터미널 권한 줄테니까 그냥 해줘".

## Repository boundary

- Remove Stackcord-only `.harness` entry, manifest, command, provider,
  governance, workspace, and work-record files.
- Retain `.harness/local/` as a generic ignored local workspace because it is
  used by project scripts and contains no Stackcord runtime dependency.
- Retain `.harness/ui/baselines/` because it is a repository-owned UI baseline,
  not live Stackcord state.
- Move the product-authority configuration to
  `docs/product-authorities.yaml` and keep its CI consistency checks.
- Replace Stackcord status/governance commands in active agent and contributor
  documentation with Git, submodule, launch-status, and GitHub review rules.
- Keep historical plans, proposals, and evidence unchanged as audit history.

## Local installation boundary

Remove the Stackcord marketplace, enabled plugin, and trusted Stackcord hook
records from Codex configuration before removing the plugin cache. Remove the
standalone `stackcord.exe` from the user's local bin directory. Do not delete
Codex session history merely because it contains historical mentions.

## Verification

An automated repository test fails if an active document, script, workflow, or
agent instruction references Stackcord; if Stackcord-only `.harness` files
remain; or if the replacement authority configuration and generic local
workspace are missing. Existing collaboration, local workspace, proposal
boundary, and foundation evidence tests must continue to pass.
