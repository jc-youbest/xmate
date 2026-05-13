# F-009 Multi-page Note

A note can have multiple pages; the user can add, switch, delete, and reorder them.

## Flow

When user opens U-010 NoteEditorScreen:
- C-021 PageManager loads the note's pages.
- U-024 PageNavigator displays each page as a U-028 PageThumbnail.

When user taps U-029 AddPageButton on U-024 PageNavigator:
- C-021 PageManager appends a new blank page.
- U-024 PageNavigator inserts a new U-028 PageThumbnail.
- U-023 Canvas switches to the new page.

When user taps a U-028 PageThumbnail:
- U-023 Canvas switches to that page.

When user long-presses a U-028 PageThumbnail:
- App shows U-030 PageContextMenu with: delete, duplicate, reorder.

When user picks an action in U-030 PageContextMenu:
- C-021 PageManager performs the action.
- C-001 NoteStore persists the updated page list.
