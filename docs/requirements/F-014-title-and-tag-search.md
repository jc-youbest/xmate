# F-014 Title and Tag Search

The user finds a note by its title or tags.

## Flow

When user types in U-004 SearchField on U-003 NoteListToolbar:
- C-019 SearchIndex queries by title prefix and tag match.
- U-008 NoteList filters to matching notes in real time.

When user clears U-004 SearchField:
- U-008 NoteList returns to the full unfiltered list of the current folder.
