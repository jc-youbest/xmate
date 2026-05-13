# F-041 Moderation Pipeline

Reports are reviewed and acted on. Backend-only feature; no end-user UI beyond the report submission (F-040) and the eventual notification of an outcome.

## Flow

When S-007 ModerationService receives a new report:
- It enqueues the report for human review.
- Reports above a severity threshold trigger automatic temporary action (e.g., hide post pending review).

When a moderator decides on a report:
- S-007 ModerationService applies the decision (remove content, warn user, suspend account, or dismiss).
- Affected users receive a notification via S-006 NotificationDispatcher.
