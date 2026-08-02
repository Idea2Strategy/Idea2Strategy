# User case contract v1 proposal

Status: isolated proposal for Idea2Strategy/Idea2Strategy#132 and blocked backend issue Idea2Strategy/Idea2Strategy-backend#147. It is not canonical or approved until a configured product authority approves the exact commit.

## 1. Purpose and non-goals

Users submit structured `INQUIRY`, `REPORT`, or `APPEAL` cases and read only their own current state and user-visible history. The case inbox is one-way workflow, not live chat, email support, or a file upload service. Operator assignment, investigation, and disposition belong to A20; sanction linkage belongs to A14.

## 2. States and transitions

User-visible states are `OPEN`, `NEEDS_INFORMATION`, `UNDER_REVIEW`, `RESOLVED`, and `REJECTED`. `RESOLVED` and `REJECTED` are terminal and set `closed_at`; a redundant `CLOSED` state is not used.

| Actor | Current state | Command/event | Result |
| --- | --- | --- | --- |
| account | none | `SUBMIT` / `SUBMITTED` | `OPEN` |
| operator (A20) | `OPEN` | `REVIEW_STARTED` | `UNDER_REVIEW` |
| operator (A20) | `OPEN` or `UNDER_REVIEW` | `INFORMATION_REQUESTED` | `NEEDS_INFORMATION` |
| account | `NEEDS_INFORMATION` | `ADD_EVIDENCE` / `EVIDENCE_ADDED` | `OPEN` |
| operator (A20) | non-terminal | `RESOLVED` | `RESOLVED` |
| operator (A20) | non-terminal | `REJECTED` | `REJECTED` |

Accounts cannot create operator events, edit subject/type after submission, append to terminal cases, or reopen a terminal case. A new issue requires a new case.

## 3. Current head and append-only history

`operations.cases` is the current projection. `case_version`, `current_event_sequence`, and `last_case_event_id` identify exactly one head. Every transition locks the case row, verifies the current state/version, increments version and sequence once, and appends exactly one `operations.case_events` row in the same transaction.

Sequence 1 is always `SUBMITTED`, has no previous event, and results in `OPEN`. Later events point to the immediately previous event. `(case_id, previous_event_id)` uniqueness prevents branching, and the current case head is non-null and must reference an event belonging to that case. The migration implements the case-head/event cycle as `DEFERRABLE INITIALLY DEFERRED`, so a pre-generated event ID can be installed as the case head and both sides are verified at commit. Events are never updated or deleted.

Only `USER_VISIBLE` events are returned to user APIs. `OPERATOR_ONLY` payloads remain excluded even when the user owns the case. Payloads contain structured text and stable reason codes, never credentials, private strategy source, raw file bodies, or unnecessary holdings.

## 4. Idempotent user commands

`SUBMIT` and `ADD_EVIDENCE` require an account-scoped idempotency key. The receipt key is `(account_id, command_type, idempotency_key)` and stores the canonical request hash plus the original successful HTTP status, code, body, case, and event.

The same key and hash returns the original response without another case, event, evidence link, or outbox message. The same key with another hash returns `409 IDEMPOTENCY_KEY_REUSED`. A failure rolled back before a receipt commits is not promised to replay identically.

Receipt, case head, event, evidence references, and application outbox-port write commit atomically. A17 transport failure cannot roll back or erase a committed case; production publishing waits for the approved A17 implementation.

## 5. Evidence ownership and privacy

Users may reference only an existing `AVAILABLE` `storage.objects` row; A19 does not upload files. Before mutation, the application calls the source-domain ownership port with `source_domain`, `source_resource_id`, storage object ID, and current account. It must prove current account ownership and the exact object relation.

The immutable evidence link records case/event/account, storage object, source resource, verified owner, policy version, and verification time. `owner_account_id` must equal the case account. Object absence, non-availability, source mismatch, and ownership failure all return the same non-enumerating result and create no case, event, receipt, or outbox record.

An evidence link does not grant new access to the underlying object. User detail responses expose only safe reference metadata allowed by the source domain, not bucket/key, private payload, or another user's identifiers.

## 6. API behavior

- submit: authenticated eligible account, structured type/subject/message, optional verified existing evidence references, idempotency key;
- list: cursor pagination scoped by authenticated account, stable `(created_at, id)` ordering;
- detail: account-scoped lookup returning current state and only user-visible events/evidence metadata;
- add evidence: only the owner and only from `NEEDS_INFORMATION`.

Unknown case IDs and case IDs owned by another account return the same not-found response. Queries always include account scope; authorization is not implemented as a post-query comparison.

`APPEAL` is accepted before A14 as an ordinary case type. It does not bypass authentication or create a sanction relation until A14 defines that additive boundary.

## 7. Failure, rollout, and verification

Unsupported type/state/event, illegal transition, stale version, missing ownership policy, ambiguous source result, and unavailable evidence fail closed. No handler invents a product state or silently drops an event.

Migration is additive. Existing review/example rows are not production seed. Deployment order is schema, compatible persistence, disabled API validation, then API enablement. Once append-only evidence exists, rollback is forward-fix only and must not delete case history or receipts.

Required tests cover concurrent duplicate submit, request-hash conflict, two writers on one head, illegal/terminal transitions, non-enumerating cross-account list/detail/evidence, unavailable object, owner mismatch, atomic case/event/receipt/outbox rollback, cursor stability, empty migration, and upgrade migration.

## 8. Approval gate

The types, states, terminal behavior, evidence ownership proof, and user/operator transition split are recommended defaults recorded on issue #132. They remain a proposal until a configured product authority approves the exact Git commit through the selected GitHub review provider.
