# F-005 Eraser

The user erases by pixel area or by whole stroke.

## Flow

When user taps U-019 EraserButton on U-015 PenToolbar:
- C-002 PencilKitBridge switches the active tool to the eraser.
- App shows U-026 EraserModeMenu offering "pixel" and "stroke" modes.

When user picks a mode in U-026 EraserModeMenu:
- C-002 PencilKitBridge configures the eraser to that mode.

When user drags Apple Pencil over a stroke on U-023 Canvas in eraser mode:
- C-002 PencilKitBridge removes the affected pixels (pixel mode) or the whole stroke (stroke mode).
- C-003 StrokeSerializer persists the updated drawing via C-001 NoteStore.

## Initial Implementation (v0)

v0 (shipped): pixel and stroke eraser modes are delivered by the system
PKToolPicker that F-001's v0 attaches to U-023 Canvas. The custom
U-019 EraserButton and U-026 EraserModeMenu described in the flow above
are still ahead.
