# Local harness workspace

This directory exists in every clone, but Git tracks only this README and the
approved `.gitkeep` markers. All generated artifacts, temporary data, caches,
logs, operation records, dbdiagram proposals, owner mappings, Jira
transfer records, and remote synchronization state stored here remain local.

Run `scripts/initialize-local-harness.ps1 -Verify` after cloning. Add
`-MigrateLegacy` only when migrating the former root `output/`, `tmp/`, or
`.idea2strategy-local/` directories. Files below `tmp/`, `cache/`, and `logs/`
are disposable and should not be used as completion evidence. Keep durable,
non-secret receipts in `artifacts/` and project metadata in `project/`. Never
store credentials in this tree.
