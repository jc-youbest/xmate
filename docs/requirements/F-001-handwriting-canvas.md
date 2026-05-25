# F-001 Handwriting Canvas

The user writes smoothly on a canvas with Apple Pencil. Strokes persist
across app launches.

## Flow

When user draws on U-023 Canvas with Apple Pencil:
- C-002 PencilKitBridge captures the stroke (latency < 1 frame).
- C-003 StrokeSerializer serializes the stroke.
- C-001 NoteStore persists the serialized data.

When user rests their palm on U-023 Canvas while drawing:
- C-002 PencilKitBridge ignores the palm contact (palm rejection).

When user touches U-023 Canvas with a finger:
- C-002 PencilKitBridge does not draw — only Apple Pencil draws. Finger
  input is reserved for navigation.

## Implementation Status

The app currently launches straight into a full-screen PKCanvasView hosted
by C-002 PencilKitBridge — no note list, no editor chrome, no navigation.
The system PKToolPicker is attached as a temporary tool UI (it covers
F-002..F-007). Strokes auto-save and reload across launches through
C-001 NoteStore; see F-011's Implementation Status.

Still ahead: the canvas is not yet hosted inside the multi-page writing
mode of roadmap stage v1 — U-101 WritingScreen and page turning (F-051)
are not built. F-001's core behaviour — drawing strokes on a page — does
not change as that structure is added. Pencil-only input is firm: from v1
the finger is reserved for navigation and never draws, so there is no
finger-drawing setting.
