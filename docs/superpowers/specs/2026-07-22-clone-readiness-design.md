# Fresh-clone collaboration readiness design

## Goal

A contributor who clones the default `develop` branch must be able to run the documented local-harness initialization and mandatory collaboration verification without copying machine-specific files from another checkout.

## Chosen approach

`scripts/initialize-local-harness.ps1` will create a non-secret local product-authority reference when `.harness/local/project/policy/owner.yaml` is absent. The file identifies the configured provider authority, `user:kcrmin`, rather than claiming that the contributor is that authority. It explicitly states that contact email is not authority and contains no email or credential.

Existing local owner metadata is never overwritten. This preserves the product owner's optional local contact record while giving every fresh clone the minimum non-authoritative reference required by the existing policy verifier.

## Boundaries

- Do not modify the protected governance policy or its verifier while provider approval is unavailable.
- Do not track generated owner metadata in Git.
- Do not use Git name, Git email, or a locally generated file as authentication.
- Provider-backed Stackcord governance remains the only authority check for protected canonical writes.
- GitHub continues to use the exact `ui` submodule pointer; GitLab continues to contain an ordinary monolithic `ui` tree.

## Initialization flow

1. Clone the repository's default `develop` branch.
2. On GitHub, initialize the `ui` submodule as part of clone or with the documented update command.
3. Run `scripts/initialize-local-harness.ps1 -Verify`.
4. The initializer creates the local directory skeleton, policy-integrity baseline, and non-secret authority reference when absent.
5. Run `scripts/verify-collaboration-policy.ps1`.
6. Run Stackcord context/status checks; protected changes remain fail-closed until a fresh provider approval is available.

## Error handling

- Initialization fails when the repository root or harness manifest is missing.
- Existing owner metadata is preserved byte-for-byte.
- The verifier continues to reject a missing or malformed authority reference.
- Generated operational files stay ignored, so initialization leaves the tracked working tree clean.

## Testing

- Extend the local-harness test to prove a first run creates the authority reference with the required non-authoritative fields.
- Prove a second run does not overwrite a contributor's existing local owner metadata.
- Keep migration, idempotence, ignore-boundary, and tracked-file assertions passing.
- After integration, perform real clean clones from GitHub and GitLab and run initialization, policy verification, context audit, Git cleanliness, and repository-layout checks.

## Completion criteria

Both remote default branches point to the integrated commits, and clean clones from both remotes complete every documented onboarding check without manual local-file repair.
