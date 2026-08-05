# Development scoring template seed proposal

This directory is an isolated, unapproved proposal for Development runtime data.
It does not change `specs/`, `contracts/`, DBML, or Flyway migrations, and it must
not be applied until a configured product authority freshly approves the exact
artifact commit and checksums through the GitHub governance provider.

The proposal translates the four templates in
`proposals/official-room-scoring/official-room-scoring-decision.v1.md` into the
strict JSON shape consumed by backend `ScoringTemplateCatalogService`. The
backend provider implementation was observed at commit
`3902164b` (`feat: implement official room scoring (#140)`).

Application is intentionally delegated to the one-shot Development database
bootstrap. That bootstrap binds this SQL by SHA-256, permits only INSERT and
SELECT on `competition.scoring_template_versions`, verifies the four exact
immutable identities and content hashes, and records the observed catalog in
its receipt. It rejects DDL, DCL, mutation commands, psql metacommands, extra
tables, missing rows, duplicate identities, and checksum drift.

Approval is required for the exact proposed values before passing this file to
`invoke-development-database-bootstrap.ps1 -Execute`. Merge alone is not
approval, and this branch must not be described as deployable while the manifest
has `approved: false`.
