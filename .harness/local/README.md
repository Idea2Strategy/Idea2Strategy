# Local harness workspace

This directory exists in every clone, but Git tracks only this README and the
approved `.gitkeep` markers. All generated artifacts, temporary data, caches,
logs, Stackcord operation records, dbdiagram proposals, owner mappings, Jira
transfer records, and remote synchronization state stored here remain local.

Run `scripts/initialize-local-harness.ps1 -Verify` after cloning. Add
`-MigrateLegacy` only when migrating the former root `output/`, `tmp/`, or
`.idea2strategy-local/` directories. Never store credentials in this tree.
