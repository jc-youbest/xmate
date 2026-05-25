# F-007 Undo / Redo

The user reverses or replays recent edits.

## Flow

When user taps U-021 UndoButton on U-015 PenToolbar:
- C-014 UndoStack pops the last action.
- C-001 NoteStore reflects the reverted state.
- U-023 Canvas re-renders.

When user taps U-022 RedoButton on U-015 PenToolbar:
- C-014 UndoStack reapplies the last undone action.
- C-001 NoteStore reflects the new state.
- U-023 Canvas re-renders.

When user makes any new edit after undoing:
- C-014 UndoStack discards the forward redo history.

## Implementation Status

Undo and redo controls are delivered by the system PKToolPicker that F-001
attaches to the canvas. The custom U-021 UndoButton and U-022 RedoButton
described in the flow above are still ahead.
