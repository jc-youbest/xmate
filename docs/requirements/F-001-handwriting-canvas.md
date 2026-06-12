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

The canvas is hosted inside U-101 WritingScreen (roadmap stage v1).
C-002 PencilKitBridge wraps PKCanvasView with `drawingPolicy = .pencilOnly`
— finger touches never draw; they are handled by UISwipeGestureRecognizers
for page turning (F-051). The system PKToolPicker remains the tool UI,
covering F-002..F-007. Strokes persist and reload across launches via
C-001 NoteStore (Core Data). Drawing is flushed in `dismantleUIView`
before the PKCanvasView is torn down on a page turn.
