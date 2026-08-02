# COM-A21 case response deadline proposal

This isolated proposal closes the product gap between A20 operator case handling and A21 batch processing. It does not modify canonical contracts or DBML until product authority `user:kcrmin` reviews the exact proposal.

## Recommended decision

- `INFORMATION_REQUESTED` records an exact UTC `response_deadline_at` selected by a versioned case-deadline policy.
- The response window is half-open: evidence is accepted only while database time is strictly before the deadline.
- At or after the deadline, a case still in `NEEDS_INFORMATION` returns to `UNDER_REVIEW`; it is never automatically resolved, rejected, or sanctioned.
- The system appends one user-visible `INFORMATION_RESPONSE_DEADLINE_EXPIRED` event and stages the matching notification in the same transaction.
- Competing evidence and expiry commands lock the same current case row and decide from database time after the lock.
- Repeated or stale batch delivery is a successful no-op and cannot append another event.

## Rollout

1. Product-authority review of this proposal.
2. Canonical contract and DBML integration.
3. A20 migration/application port implementation.
4. A21 batch adapter wiring.
5. A22 PostgreSQL race and restart E2E.
