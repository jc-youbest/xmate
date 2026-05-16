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

v0 (shipped): the app launches directly into a full-screen PKCanvasView
hosted by C-002 PencilKitBridge — no U-002 NoteListScreen, no U-010
NoteEditorScreen, no navigation. The system PKToolPicker is attached as a
temporary tool UI, covering F-002..F-007 in their v0 form. Strokes are
auto-saved and restored across launches; see F-011's Initial
Implementation. This subset validated the Xcode project setup, iPad 8
deployment, and Apple Pencil 1 input.

Superseded by the stationery model: under F-050 / F-051 the canvas is the
write phase of a locked page inside a document, not a standalone screen,
and the v0 single-file persistence is replaced by F-011's v1 Core Data
store. F-001's own behaviour — drawing strokes on a page — carries
forward unchanged.
