# F-015 Handwriting Search

The user finds a note by the content of its handwritten strokes.

## Flow

When user creates or modifies a note:
- C-020 HandwritingRecognizer runs Vision in the background to convert strokes to text.
- C-019 SearchIndex stores the recognized text against the note.

When user types in U-004 SearchField on U-003 NoteListToolbar:
- C-019 SearchIndex also searches recognized text from handwriting.
- U-008 NoteList includes notes matched only by handwriting content.
