# F-012 Folder Organization

The user organizes notes into nested folders.

## Flow

When user views U-006 FolderSidebar:
- C-017 FolderStore returns the folder hierarchy.
- U-006 FolderSidebar displays each folder as a U-007 FolderItem (nested).

When user taps a U-007 FolderItem:
- U-008 NoteList filters to notes in that folder.

When user taps U-034 NewFolderButton on U-006 FolderSidebar:
- App prompts for a folder name.
- C-017 FolderStore creates the folder under the currently selected parent.

When user long-presses a U-007 FolderItem:
- App shows U-035 FolderContextMenu with: rename, delete, move.

When user picks "move" in U-032 NoteContextMenu on a note:
- App shows U-036 MoveNoteToFolderDialog listing available folders.
- On selection, C-001 NoteStore updates the note's folder reference.
