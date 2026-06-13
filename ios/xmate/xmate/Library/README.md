# Library — personal document manager (placeholder)

## Responsibilities (future, v3)

- Document list with thumbnails; drafts, inbox, sent letters.
- Folders, tags, search; opening an item resolves a Document and injects
  it into the editor (composition-root pattern).

## Key files

- None yet — this README alone keeps the folder tracked.

## Not responsible for

- Editing documents (Editor) or persistence internals (Storage — Library
  consumes NoteStore APIs).

## Next step (current stage)

- Nothing. Do not build ahead of v3; designs land in `docs/backlog.md`
  first.

## Notes for AI changes

- Keep this module empty until v3 work explicitly starts. When it does,
  document selection flows here must hand a resolved Document to the
  editor — never teach the editor about lists/inboxes.
