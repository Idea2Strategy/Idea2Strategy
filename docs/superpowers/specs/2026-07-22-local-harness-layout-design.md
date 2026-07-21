# Local harness layout and ignore design

Date: 2026-07-22
Status: approved structure, pending implementation review

## Purpose

Every clone must contain the same discoverable local-workspace skeleton while generated artifacts, temporary files, credentials, operational receipts, and user-specific metadata remain outside Git history. Stackcord-owned local data and Idea2Strategy-specific local data share `.harness/local/` instead of creating unrelated root directories.

## Shared and local boundary

The repository tracks only `.harness/local/README.md` and exact `.gitkeep` markers that establish the approved directory skeleton. Every other file below `.harness/local/` is ignored.

```text
.harness/local/
├─ README.md
├─ artifacts/
├─ tmp/
├─ cache/
├─ logs/
├─ project/
│  ├─ policy/
│  ├─ jira/
│  ├─ remotes/
│  └─ work/
├─ dbdiagram/
└─ operations/
```

- `artifacts/`: generated reports, rendered documents, exports, and other disposable outputs.
- `tmp/`: short-lived conversion, extraction, and intermediate files.
- `cache/`: reproducible downloaded or computed caches.
- `logs/`: local diagnostic logs that contain no credentials by design.
- `project/policy/`: local policy-owner mapping and non-secret integrity metadata.
- `project/jira/`: persistent local Jira-transfer records.
- `project/remotes/`: non-secret GitHub/GitLab topology and synchronization state.
- `project/work/`: local per-harness work references and state.
- `dbdiagram/`: Stackcord-isolated dbdiagram proposals and local tool settings.
- `operations/`: Stackcord operation receipts and journals.

Actual Git worktrees and the future GitLab monolithic checkout must not be nested inside the root repository. `.harness/local/project/remotes/` records only non-secret pointers and synchronization state for those external workspaces.

## Migration

Implementation moves existing content without deleting or overwriting files:

- `output/` to `.harness/local/artifacts/`
- `tmp/` to `.harness/local/tmp/`
- `.idea2strategy-local/policy/` to `.harness/local/project/policy/`
- `.idea2strategy-local/jira/` to `.harness/local/project/jira/`
- `.idea2strategy-local/remotes/` to `.harness/local/project/remotes/`
- `.idea2strategy-local/harness/` to `.harness/local/project/work/`

Existing Stackcord data under `.harness/local/dbdiagram/` and `.harness/local/operations/` stays in place. Root `.dbdiagram/` remains an ignored tool-owned compatibility directory until the installed dbdiagram CLI is verified to support a relocated settings path.

If a source and destination contain the same relative path, migration stops and reports the conflict. It never silently replaces either file. The now-empty legacy root directories are removed only after source and destination inventories match.

## Ignore policy

`.gitignore` uses labeled sections for:

- the tracked `.harness/local/` skeleton and ignored local contents;
- environment files and credential material;
- logs, dumps, caches, temporary files, and generated artifacts;
- Node.js, pnpm, frontend builds, tests, and browser-test output;
- Python environments, bytecode, tests, coverage, typing, and lint caches;
- Java, Gradle, Maven, JVM build output, and IDE metadata;
- Windows and macOS filesystem metadata;
- IntelliJ-family and VS Code user-specific state;
- tool-owned local directories such as `.dbdiagram/` and `.harness-drafts/`.

Narrow exceptions preserve intentional shared examples such as `.env.example`. The policy avoids blanket extension patterns that could hide legitimate source files. Generated deliverables intended for release must be copied to an explicitly tracked release path rather than committed from `.harness/local/artifacts/`.

## Bootstrap and recovery

Because Git does not preserve empty directories, exact `.gitkeep` markers create the skeleton on clone. A bootstrap/verification script recreates missing directories, verifies ignore behavior, rejects unexpected tracked files below `.harness/local/`, and reports legacy root-local directories. The repository harness skill and collaboration policy point to the new local paths.

The script is idempotent: rerunning it creates missing directories but does not modify existing local records. It never reads, prints, migrates, or stores tokens, passwords, session cookies, private keys, or recovery codes.

## GitLab credentials

The self-managed GitLab repository uses a separate HTTPS remote in a separate monolithic workspace. Git Credential Manager receives credentials only through its interactive Windows prompt triggered against the exact HTTPS repository URL. Tokens are never passed as command arguments, environment variables, files, documentation, or logs. A token pasted into conversation is treated as compromised and is not used.

The current GCM installation has no GitLab-specific login command, so connection requires the exact self-managed GitLab HTTPS repository URL before an interactive credential request can be opened.

## Verification

Implementation is complete only when all of the following hold:

1. A fresh clone contains the documented `.harness/local/` skeleton.
2. Non-marker files anywhere below `.harness/local/` are ignored and untracked.
3. Existing local records and generated artifacts have matching pre/post migration inventories.
4. Root `output/`, `tmp/`, and `.idea2strategy-local/` no longer contain active data.
5. The bootstrap script passes twice without changing existing records.
6. Policy integrity, Stackcord context audit, Git diff checks, and submodule checks pass.
7. `db/schema.dbml` retains its current hash and semantic content.
8. No credential value appears in shared files, Git history, command arguments, or verification output.
