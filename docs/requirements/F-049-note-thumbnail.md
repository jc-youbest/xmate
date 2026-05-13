# F-049 Note Thumbnail

Each U-009 NoteListItem shows a small preview rendering of the note's first page.

## Flow

When user creates or modifies a note:
- C-013 ThumbnailRenderer regenerates the thumbnail of the first page (asynchronously, off the main thread).
- C-001 NoteStore stores the thumbnail alongside the note.

When user views U-008 NoteList:
- Each U-009 NoteListItem displays its cached thumbnail next to the title.

When a note is locked (F-048):
- U-009 NoteListItem shows a generic lock icon instead of the thumbnail.
