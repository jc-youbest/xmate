# F-016 Export to PDF

The user exports a note as a PDF file.

## Flow

When user taps U-014 ShareButton on U-011 EditorTopBar:
- App shows U-040 ExportFormatMenu listing PDF, PNG, JPEG, and other share options.

When user picks "PDF" in U-040 ExportFormatMenu:
- C-005 ExportEngine renders each page of the note as a PDF page.
- App hands the resulting PDF to the system share sheet (see F-030).
