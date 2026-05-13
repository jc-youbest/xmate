# F-032 Watermark and Signature

Exported and published content can carry a subtle "xmate" watermark or the user's handle as a signature. User-controlled.

## Flow

When user opens watermark settings under U-025 SettingsScreen:
- The section shows toggles for "show watermark" and "show handle as signature".

When user toggles a watermark option:
- C-001 NoteStore (settings) persists the choice.

When C-005 ExportEngine renders content for export or publishing:
- It overlays the watermark and/or signature according to the current settings.
