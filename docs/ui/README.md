# UI Tree

The containment hierarchy of UI elements in the iOS app. This document
defines *what contains what* — not *where things are placed* or *what they
look like*. Layout, position, color, and visual style are decided per
feature and in a separate style guide later.

Features reference UI nodes by ID. Whenever a feature needs a UI element
that does not exist here, add it here first.

ID scheme: U-XXX, monotonic, never reused. A short inline description is
optional; omit when the name is self-explanatory.

## Tree

- U-001 AppRoot
  - U-002 NoteListScreen — browses all notes
    - U-003 NoteListToolbar
      - U-004 SearchField
      - U-005 NewNoteButton
    - U-006 FolderSidebar
      - U-007 FolderItem
    - U-008 NoteList
      - U-009 NoteListItem
  - U-010 NoteEditorScreen
    - U-011 EditorTopBar
      - U-012 BackButton
      - U-013 NoteTitleField
      - U-014 ShareButton
    - U-015 PenToolbar
      - U-016 PenToolPicker — selects pen / pencil / marker / highlighter
      - U-017 ColorPicker
      - U-018 ThicknessSlider
      - U-019 EraserButton
      - U-020 LassoButton
      - U-021 UndoButton
      - U-022 RedoButton
    - U-023 Canvas — active drawing surface
    - U-024 PageNavigator
  - U-025 SettingsScreen
