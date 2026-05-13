# F-001 Handwriting Canvas

The user writes smoothly on a canvas with Apple Pencil. Strokes persist
across app launches.

## Flow

When user taps U-005 NewNoteButton on U-002 NoteListScreen:
- C-001 NoteStore creates a new Note.
- App navigates to U-010 NoteEditorScreen with U-023 Canvas focused.

When user draws on U-023 Canvas with Apple Pencil:
- C-002 PencilKitBridge captures the stroke (latency < 1 frame).
- C-003 StrokeSerializer serializes the stroke.
- C-001 NoteStore persists the serialized data.

When user rests their palm on U-023 Canvas while drawing:
- C-002 PencilKitBridge ignores the palm contact (palm rejection).

When user touches U-023 Canvas with a finger:
- C-002 PencilKitBridge ignores the touch (configurable via F-018 Settings).

When user taps U-012 BackButton on U-011 EditorTopBar:
- C-001 NoteStore flushes pending writes.
- App returns to U-002 NoteListScreen.

## Initial Implementation (v0)

Before the full flow above can be implemented, a minimal subset is built
standalone to validate the development pipeline.

v0 scope:
- The app launches directly into U-023 Canvas (U-002 NoteListScreen,
  U-010 NoteEditorScreen, U-011 EditorTopBar, U-015 PenToolbar, and
  U-024 PageNavigator are not yet present).
- C-002 PencilKitBridge hosts a full-screen PKCanvasView.
- A default pen with a default color and width is active.
- Strokes are not persisted — closing the app loses them. C-001 NoteStore
  and C-003 StrokeSerializer are deferred.

This subset validates the Xcode project setup, iPad 8 deployment, and
Apple Pencil 1 input. Persistence, navigation, and tool-switching parts
of the flow above will be added in subsequent iterations alongside
F-011 Note CRUD and F-002 Pen Tools.
