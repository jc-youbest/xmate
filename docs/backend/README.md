# Backend Modules

Server-side modules in the custom backend project under `backend/`.
Independent from the iOS app — likely a different language and deployment.
The list below is a planning placeholder; modules will be filled in as
features that need them are designed.

ID scheme: S-XXX, monotonic, never reused.

When a module's spec grows beyond one row, move it to its own file at
`docs/backend/S-XXX-name.md` and link from this catalog.

## Catalog

| ID | Name | Responsibility |
|---|---|---|
| S-001 | AuthService | Verify OAuth tokens from Apple / Google / Facebook / X |
| S-002 | UserProfileAPI | Profile CRUD endpoints |
| S-003 | NoteSyncAPI | Cross-device note sync |
| S-004 | NoteShareAPI | Share a handwritten letter to another user |
| S-005 | FeedService | Pen pal feed generation |
| S-006 | NotificationDispatcher | APNs push integration |
| S-007 | ModerationService | Report intake and review workflow |
