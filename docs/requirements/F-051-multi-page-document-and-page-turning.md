# F-051 Multi-page Document and Page Turning

The document is an ordered sequence of pages; the user turns between them,
adds pages, and removes pages.

## Flow

When user opens U-101 WritingScreen:
- C-001 NoteStore loads the document's ordered pages and shows the first.
- U-023 Canvas renders that page.
- U-093 PageIndicator on U-102 WritingTopBar shows the position, e.g. "1 / 3".

When user swipes up on U-101 WritingScreen and a next page exists:
- C-001 NoteStore flushes the current page's pending strokes.
- U-023 Canvas turns to the next page; U-093 PageIndicator updates.
  (The swipe is a finger gesture; only Apple Pencil draws, so it never
  conflicts with handwriting.)

When user swipes down on U-101 WritingScreen and a previous page exists:
- C-001 NoteStore flushes the current page's pending strokes.
- U-023 Canvas turns to the previous page; U-093 PageIndicator updates.

When user taps U-095 AddPageButton on U-102 WritingTopBar:
- C-001 NoteStore appends a new blank page after the current page.
- U-023 Canvas turns to the new page; U-093 PageIndicator updates.

When user opens U-103 WritingOverflowMenu on U-102 WritingTopBar:
- The menu offers "delete page" and "delete document". "delete page" is
  disabled when the document has only one page.

When user picks "delete page" in U-103 WritingOverflowMenu:
- App asks for confirmation.
- On confirm, C-001 NoteStore removes the current page and shows an
  adjacent page; U-093 PageIndicator updates.

When user picks "delete document" in U-103 WritingOverflowMenu:
- The flow continues in F-011 Note CRUD.
