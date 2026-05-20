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

## Implementation Status

The app currently launches straight into a full-screen PKCanvasView hosted
by C-002 PencilKitBridge — no note list, no editor chrome, no navigation.
The system PKToolPicker is attached as a temporary tool UI (it covers
F-002..F-007). Strokes auto-save and reload across launches through
C-001 NoteStore; see F-011's Implementation Status.

Still ahead: the canvas is not yet hosted inside the multi-page document
structure of roadmap stage v0, and the navigation / editor flow described
above is not built. F-001's core behaviour — drawing strokes on a page —
does not change as that structure is added.
