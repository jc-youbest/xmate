# F-006 Lasso Selection

The user selects a group of strokes to move, scale, copy, or delete.

## Flow

When user taps U-020 LassoButton on U-015 PenToolbar:
- C-002 PencilKitBridge switches the active tool to the lasso.

When user draws a closed loop on U-023 Canvas in lasso mode:
- C-015 LassoEngine identifies the enclosed strokes.
- App shows U-027 LassoActionMenu near the selection with: move, scale, copy, delete.

When user picks an action in U-027 LassoActionMenu:
- C-015 LassoEngine performs the action.
- C-003 StrokeSerializer and C-001 NoteStore persist the result.

## Initial Implementation (v0)

v0 (shipped): lasso selection plus the standard transform / copy / delete
actions are delivered by the system PKToolPicker that F-001's v0 attaches
to U-023 Canvas. The custom U-020 LassoButton and U-027 LassoActionMenu
described in the flow above are still ahead.
