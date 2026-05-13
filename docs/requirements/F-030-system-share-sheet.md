# F-030 System Share Sheet Integration

The user shares an exported note via the iOS system share sheet.

## Flow

When user taps U-014 ShareButton on U-011 EditorTopBar and picks an export format:
- C-005 ExportEngine produces the file (see F-016 and F-017).
- App presents the iOS share sheet (UIActivityViewController) with the file as payload.

When user picks a destination in the system share sheet:
- The system handles delivery (mail, messages, third-party apps). xmate does nothing further.
