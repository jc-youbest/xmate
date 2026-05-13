# F-011 Note CRUD

The user creates, lists, renames, duplicates, and deletes notes.

## Flow

When user taps U-005 NewNoteButton on U-003 NoteListToolbar:
- C-001 NoteStore creates a new empty Note.
- App navigates to U-010 NoteEditorScreen.

When user views U-002 NoteListScreen:
- C-001 NoteStore returns the notes in the current folder.
- U-008 NoteList displays each note as a U-009 NoteListItem.

When user long-presses a U-009 NoteListItem:
- App shows U-032 NoteContextMenu with: rename, duplicate, delete, move.

When user picks "rename" in U-032 NoteContextMenu:
- App shows U-033 RenameNoteDialog pre-filled with the current title.
- On confirm, C-001 NoteStore updates the title.

When user picks "delete" in U-032 NoteContextMenu:
- App asks for confirmation.
- C-001 NoteStore removes the Note.
