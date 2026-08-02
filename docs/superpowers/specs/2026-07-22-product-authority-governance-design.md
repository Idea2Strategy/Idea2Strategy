# Product-authority governance design

## Objective

Idea2Strategy must fail closed when an actor attempts to change canonical product meaning without product-owner authority. The product authorities are the GitHub accounts `user:kcrmin`, `user:pjy008008`, and `user:Juwon-Na`. The known owner email remains ignored local contact metadata, not authentication evidence.

## Current gap

The repository already tells agents to run `stackcord governance check`, but `.harness/governance.yaml` has governance disabled and declares no authority. Stackcord therefore reports governance as disabled. In addition, Stackcord 1.0.0 intentionally gates approval, integration, and release; it does not prevent arbitrary local filesystem edits. The project needs both native governance activation and a stricter repository-local pre-mutation rule.

## Authority and trust model

- Selected review provider: GitHub.
- Canonical review repository: `Idea2Strategy/Idea2Strategy`.
- Normalized product authorities: `user:kcrmin`, `user:pjy008008`, and `user:Juwon-Na`, with equal scope.
- Protected semantic kinds: `product`, `policy`, `business`, and `contract`. Every configured authority covers all of them; there is no per-kind or per-area restriction.
- Required approval count: one.
- Authority self-approval: allowed for any configured authority.
- A fresh provider observation for the exact head commit and protected fingerprint is required.
- Git `user.name`, Git `user.email`, commit author fields, issue assignment, comments, and cached observations never grant authority.
- The owner email may be retained in ignored local owner metadata as a contact and consistency hint, but a matching email never satisfies the gate.

The GitLab monolithic mirror uses the same GitHub governance authority and canonical review repository. A different GitLab username cannot independently approve protected product meaning.

## Canonical-write rule

Before editing protected canonical sources, a compliant agent must run `stackcord governance check --json` and inspect a fresh provider-backed result.

The following outcomes allow a canonical write:

1. governance is enabled;
2. the provider and repository match the committed policy;
3. the exact protected fingerprint and head commit are current;
4. the verified approving subject is a configured product authority (`user:kcrmin`, `user:pjy008008`, or `user:Juwon-Na`);
5. the result is approved.

If any condition is missing, stale, unknown, or rejected, the agent must not edit the canonical protected source. It may explain the block and prepare an isolated proposal that cannot be represented as approved, integrated, or releasable.

The protected canonical boundary includes:

- `.harness/governance.yaml` and the repository-local authority rules;
- `specs/**` product and policy meaning;
- `contracts/**` business, behavior, interface, and data obligations;
- `docs/collaboration-policy.md`;
- agent entry and verification files that enforce this boundary.

Implementation code is not authenticated merely by its path. However, code that changes protected behavior cannot be treated as canonical or integrated unless its referenced protected meaning has the required approval.

## Project changes

1. Enable native Stackcord governance with `user:kcrmin`, `user:pjy008008`, and `user:Juwon-Na` as the configured authorities.
2. Strengthen `AGENTS.md` and the repository-local harness skill so an unverified actor stops before canonical mutation instead of editing the protected source in place.
3. Record the owner email only in ignored local metadata and label it non-authoritative.
4. Extend the collaboration-policy verifier so it fails when governance is disabled, the provider/repository/authority differs, protected kinds are incomplete, or instructions accept Git display identity.
5. Apply equivalent committed governance configuration and rules to the GitHub submodule root and the separate GitLab monolithic repository.
6. Keep remote branch protection and CI status truthful; this change does not claim those external controls are active.

## Failure behavior

- Unknown provider identity: stop canonical mutation.
- Provider unavailable: stop canonical mutation; cached state is insufficient.
- Actor other than a configured product authority: allow only an isolated proposal.
- Matching local email without GitHub proof: unauthorized.
- Approval for an older commit or fingerprint: stale and unauthorized.
- Attempt to alter the governance policy while not currently authorized: stop and prepare a proposal.
- GitHub and GitLab governance configurations diverge: fail verification and do not publish the inconsistent candidate.

## Verification

- Start with a failing repository verification while governance remains disabled.
- Verify exact committed governance values and protected-kind coverage.
- Verify agent instructions require a fresh provider-backed check before canonical mutation and reject Git name/email as authority.
- Verify ignored local owner metadata is not tracked and contains no credential.
- Run Stackcord context, governance, harness, Git, submodule, and monolithic-boundary checks.
- Bind test, security, integration, and explicit user-validation evidence to the final clean commits before completing the work.

## Stackcord plugin boundary

No Stackcord defect is required to activate project governance. The stricter rule that blocks a canonical file write before mutation is not a Stackcord 1.0.0 guarantee. A separate plugin enhancement is specified in `docs/prompts/stackcord-pre-mutation-governance.md`; until that enhancement exists, compliant agents enforce the pre-mutation stop through the repository entry instructions and verifier, while Stackcord natively blocks unapproved integration and release.
