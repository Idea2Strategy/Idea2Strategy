# Stackcord plugin change prompt: pre-mutation governance gate

Use this prompt in a separate Stackcord plugin development task.

---

Extend Stackcord with an optional fail-closed pre-mutation governance gate for canonical product meaning. Preserve the existing rule that ordinary contributors may prepare isolated proposals, but prevent compliant Stackcord-driven workflows from writing protected canonical sources in place unless a fresh selected-provider observation proves an allowed product authority for the exact repository, head commit, and protected fingerprint.

Requirements:

- Inspect the actual Stackcord repository, current governance design, schemas, CLI behavior, tests, and Skills before changing anything.
- Keep Git-provider normalized account identity as the only default authority proof. Never authenticate with Git `user.name`, Git `user.email`, commit author fields, issue assignment, comments, or cached review state.
- Add a backward-compatible governance option whose default preserves current behavior. The strict option must express that canonical writes require verified authority before mutation.
- Define a deterministic mapping from protected semantic kinds (`product`, `policy`, `business`, `contract`, and governance itself) to canonical paths or stable documents without treating all implementation code as protected merely because it is code.
- Add a read-only CLI preflight that receives the intended paths and semantic references, reads a fresh normalized observation from the selected provider, and returns one of these user-visible results:
  - canonical write allowed for a verified authority;
  - canonical write denied, isolated proposal allowed;
  - verification unavailable, canonical write denied;
  - request does not touch protected canonical meaning.
- Fail closed for missing, stale, mismatched, unauthorized, malformed, or unavailable provider evidence.
- Bind authorization to the exact repository, provider, head commit, protected fingerprint, and normalized subject.
- Prevent an unauthorized change to the governance configuration from granting authority in the same change.
- Provide a safe proposal workflow that writes outside canonical protected paths and cannot be reported as approved, integrated, or releasable.
- Update the repository-local Skill, Markdown fallback, command help, schemas, examples, and documentation. State clearly that Stackcord cannot stop a person with arbitrary filesystem access and does not replace branch protection, CODEOWNERS, required reviews, or CI.
- Add deterministic tests for authorized and unauthorized accounts, spoofed matching email, stale commit, stale fingerprint, provider outage, cached observation rejection, governance self-escalation, protected and unprotected paths, proposal isolation, integration/release compatibility, clone recovery, and backward compatibility when strict mode is disabled.
- Use TDD. Demonstrate the failing tests before implementation and run the complete relevant test suite afterward.
- Do not add a live-provider dependency to ordinary unit tests. Use normalized fixtures for provider observations.
- Do not implement email-based authorization. If owner email is stored as contact metadata, mark it non-authoritative and exclude it from access decisions.

Acceptance example:

- Policy authority is `user:kcrmin` on GitHub.
- A fresh exact observation for `user:kcrmin` allows a canonical protected write.
- Any other subject, an unknown actor, or a local Git identity using `kyoungcheul.min@gmail.com` without provider proof is denied canonical mutation and may only create an isolated proposal.
- Existing projects without strict pre-mutation mode retain Stackcord's current proposal/approval/integration behavior.

Deliver a reviewed design, implementation plan, tests, implementation, migration notes, and exact verification evidence. Do not publish or release the plugin unless separately authorized.

---
