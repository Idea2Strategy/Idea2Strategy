# Development initial operator RBAC bootstrap proposal

Status: **isolated proposal only; not approved, integrated, executable, or
releasable**.

`stackcord governance check --json` returned `unknown` at root
`21437cb2e940679b800645a6adae33943fd0dee3`. This directory intentionally does
not change specifications, contracts, DBML, governance, collaboration policy,
or the canonical Flyway bundle.

## Exact evidence

- Root: `21437cb2e940679b800645a6adae33943fd0dee3`.
- Backend: `bef4de6969d3ad83d147bf55c479fecd4116b76d`.
- UI: `ac0469a14d2a4d929368e42dbb768802073f0c8c`.
- UI issue #110 requires the deployed operator trust path and permission,
  forbidden, stale-MFA, revoke, retire, and disable acceptance. Its merged UI
  includes catalog/assignment visibility, direct sanction apply/lift, and all
  nine operator-case commands.
- `evidence.json` pins the exact source blobs inspected for this proposal.

## Permission inventory

`catalog.json` contains 19 permissions:

- RBAC catalog and assignment read;
- RBAC role grant and revoke;
- direct account sanction apply and lift;
- operator-case queue/detail read;
- all nine backend `OperatorCaseCommand.Action` values: `ASSIGN`, `REASSIGN`,
  `UNASSIGN`, `START_REVIEW`, `REQUEST_INFORMATION`, `RESOLVE`, `REJECT`,
  `APPLY_SANCTION`, and `RELEASE_SANCTION`;
- the existing canonical `COMPETITION_ROOM_READ` and
  `COMPETITION_ROOM_MANAGE` rows.

UUID selection is conservative:

- account-sanction IDs retain the exact backend production defaults;
- case IDs retain the exact fallback sequence in `OperatorCaseConfiguration`
  (`a200...018` through `a200...028`);
- competition IDs, descriptions, and sensitivity retain the exact approved
  migration rows (`e300...001` and `e300...002`);
- only the four RBAC permissions and two proposed development roles lacked a
  production/default identity, so only those six received new UUIDv4 values.
  Test-only `a220...` and `a22e...` fixtures were not promoted to production
  identities.

The proposed development catalog has two roles. `DEVELOPMENT_ROOT_OPERATOR`
holds all permissions. `DEVELOPMENT_OPERATIONS_OPERATOR` holds all operational
permissions except RBAC grant/revoke. The root role marks exactly that lower
role's permission set delegable, allowing a strict higher-rank grant/revoke
journey without allowing the lower role to administer RBAC.

## Runtime guard inputs

`runtime-guard-inputs.json` maps every permission to the exact Spring property
or code guard used by Backend and maps the two UI build variables used for
permission-based visibility. It is a reviewed input artifact, not Terraform or
runtime configuration. Canonical adoption must wire these values through the
approved secret/config path and retain MFA-required reads.

## Bootstrap template and intentionally unfilled identity

`bootstrap-manifest.template.json` matches the strict Backend
`OperatorBootstrapManifest` shape and embeds the exact reviewed catalog. It is
deliberately not executable. The following values remain visibly unfilled:

- database session `current_user` expected for the one-shot command;
- operator issuer/subject HMAC key version and 64-hex digest;
- initial operator account and role-assignment IDs;
- deployment actor, correlation, and audit-event IDs.

Do not put issuer, subject, Cognito token, HMAC key, digest, database password,
or completed manifest in Git, Terraform state, CI logs, issue comments, or PR
artifacts. On the approved one-shot SSM host, derive the digest with Backend's
exact `VersionedOperatorSubjectHmac`: HMAC-SHA-256 over four-byte big-endian
issuer length + issuer UTF-8 bytes + four-byte big-endian subject length +
subject UTF-8 bytes. Use the same current key/version injected into Backend.

After filling the template only inside that controlled host:

1. Verify the catalog hash equals the `catalog.json` entry in
   `CHECKSUMS.sha256` and the manifest `catalogContentHash`.
2. Compute the completed manifest SHA-256 without printing its bytes.
3. Set `I2S_BOOTSTRAP_JDBC_URL`, `I2S_BOOTSTRAP_DB_USER`, and
   `I2S_BOOTSTRAP_DB_PASSWORD` only in the ephemeral process environment.
4. Run `operator bootstrap --manifest <private-path> --expected-sha256 <hash>`
   once through SSM. The database must be in the expected empty bootstrap state.
5. Archive only the credential-free receipt. Securely remove the private
   completed manifest after verification.

## Authority-gated adoption

Before adopting any permission code, role, hierarchy, delegability, catalog
version, or bootstrap meaning, refresh provider evidence for the exact adoption
head and run `stackcord governance check --json`. Continue only with a verified
configured product authority. Adoption then requires Backend/UI/root wiring,
an exact catalog/manifest review, one-shot bootstrap receipt, and deployed UI
#110 acceptance. Merging this proposal alone authorizes none of those actions.
