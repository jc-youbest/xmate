# F-031 Read-only Share Link

The user generates a public link to view a note in any web browser.

## Flow

When user taps U-068 CopyLinkButton from U-040 ExportFormatMenu:
- S-004 NoteShareAPI creates a public read-only URL for the note.
- App copies the URL to the system pasteboard.
- App shows a brief toast confirming the copy.

When anyone opens the URL in a browser:
- The backend serves a static web view of the note's pages; no app install required.
