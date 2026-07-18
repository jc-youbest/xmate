# Library — personal document manager (placeholder)

## Responsibilities

- Personal document/mailbox lists with thumbnails: drafts, inbox, outbox, and
  sent letters.
- Folders, tags, search, and selection UI. Selection emits a stable record id;
  App resolves/validates the Document and coordinates Editor presentation as
  defined in `docs/architecture.md` (App component coordination).
- System-responsive adaptive layout: Library owns its portrait/landscape UI for
  the viewport supplied by iPadOS. App applies that component policy; Library
  does not request a window orientation or affect another component.
- Provide mailbox sidebar content for App's Editor Workspace. In that
  presentation it inherits the outer Editor policy and emits selection intents;
  it does not resize or call Editor directly.

## Key files

- `MailboxSidebarView.swift` — four-location mailbox navigation and local
  Envelope-summary list
- `MailboxSidebarOutputIntent.swift` — typed close and stable Envelope-selection
  requests consumed by App; Library never changes workspace state directly

## Not responsible for

- Editing documents (Editor), mailbox/cache rules (Mailbox), or persistence
  internals (Storage). Library consumes presentation-ready Mailbox outputs.
- App navigation and validation, plus recipient/send/delivery behavior
  (future Social).

## Next step (current stage)

- Add user-facing typed selection/load failure presentation after primary-iPad
  verification of the sidebar shell.

## Notes for AI changes

- When sidebar implementation begins, consume Mailbox summaries and emit stable
  envelope ids to App. Library never constructs Editor, fetches Document
  payloads, or teaches Editor about lists/inboxes.
