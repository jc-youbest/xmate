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

## Key files

- None yet — this README alone keeps the folder tracked.

## Not responsible for

- Editing documents (Editor) or persistence internals (Storage — Library
  consumes NoteStore APIs).
- App navigation and validation, plus recipient/send/delivery behavior
  (future Social).

## Next step (current stage)

- Nothing. Do not build ahead of v3; designs land in the Backlog of `roadmap.md`
  first.

## Notes for AI changes

- Keep this module empty until v3 work explicitly starts. When it does,
  selection flows emit stable ids to App; Library never constructs Editor and
  Editor never learns about lists/inboxes.
