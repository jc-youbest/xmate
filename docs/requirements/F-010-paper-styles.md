# F-010 Paper Styles

The user picks the paper background for a note page.

## Flow

When user opens U-031 PaperStylePicker from U-024 PageNavigator or from U-025 SettingsScreen (default for new pages):
- The picker shows: blank, ruled, grid, dot.

When user picks a style in U-031 PaperStylePicker:
- C-016 PaperRenderer renders the chosen background on U-023 Canvas.
- C-001 NoteStore persists the choice for the current page, or as the default if entered from settings.
