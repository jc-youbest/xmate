# Library — personal document manager (placeholder)

## Responsibilities (future, v3)

- Personal document/mailbox lists with thumbnails: drafts, inbox, outbox, and
  sent letters.
- Folders, tags, search, and selection UI. Selection emits a stable record id;
  App resolves/validates the Document and coordinates Editor presentation as
  defined in `docs/architecture.md` (App component coordination).
- System-responsive adaptive layout: Library owns its portrait/landscape UI for
  the viewport supplied by iPadOS. App applies that component policy; Library
  does not request a window orientation or affect another component.
- Future: provide mailbox sidebar content for App's Editor Workspace. In that
  presentation it inherits the outer Editor policy and emits selection intents;
  it does not resize or call Editor directly.

## Key files

- `MailboxSidebarOutputIntent.swift` — typed sidebar close request consumed by
  App; Library never changes workspace state directly

## Not responsible for

- Editing documents (Editor), mailbox/cache rules (Mailbox), or persistence
  internals (Storage). Library consumes presentation-ready Mailbox outputs.
- App navigation and validation, plus recipient/send/delivery behavior
  (future Social).

## Next step (current stage)

- Implement the F-062 mailbox sidebar shell using App's completed accessory
  presentation state. Consume Mailbox values and emit stable envelope ids only.

## Notes for AI changes

- When sidebar implementation begins, consume Mailbox summaries and emit stable
  envelope ids to App. Library never constructs Editor, fetches Document
  payloads, or teaches Editor about lists/inboxes.
