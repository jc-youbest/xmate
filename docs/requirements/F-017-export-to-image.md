# F-017 Export to Image

The user exports a note's pages as image files (PNG or JPEG).

## Flow

When user taps U-014 ShareButton on U-011 EditorTopBar:
- App shows U-040 ExportFormatMenu.

When user picks "PNG" or "JPEG" in U-040 ExportFormatMenu:
- C-005 ExportEngine renders each page to an image in the chosen format.
- App hands the resulting images to the system share sheet (see F-030).
