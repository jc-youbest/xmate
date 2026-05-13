# F-013 Tags

The user assigns one or more tags to a note for cross-cutting organization.

## Flow

When user opens U-010 NoteEditorScreen:
- U-037 TagsField in U-011 EditorTopBar shows the note's current tags as U-039 TagBadge instances.

When user taps U-037 TagsField:
- App shows U-038 TagPicker listing existing tags plus a "create new" option.

When user picks a tag in U-038 TagPicker:
- C-018 TagStore links the tag to the note.
- U-037 TagsField adds a U-039 TagBadge.

When user taps a U-039 TagBadge:
- C-018 TagStore removes the tag from the note.
- The badge disappears.
