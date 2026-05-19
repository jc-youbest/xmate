# F-002 Pen Tools

The user picks a writing tool: pen, pencil, marker, or highlighter.

## Flow

When user taps U-016 PenToolPicker on U-015 PenToolbar:
- App shows the four tool options: pen, pencil, marker, highlighter.

When user selects a tool in U-016 PenToolPicker:
- C-002 PencilKitBridge switches the active tool to the selected type.
- U-016 PenToolPicker reflects the new selection.

When user draws on U-023 Canvas after selecting a tool:
- The stroke uses the selected tool's characteristics (pencil shows texture, marker is opaque flat, highlighter is translucent).

## Initial Implementation (v0)

v0 (shipped): pen, pencil, marker, and highlighter selection are delivered
by the system PKToolPicker that F-001's v0 attaches to U-023 Canvas. The
custom U-015 PenToolbar / U-016 PenToolPicker described in the flow above
is still ahead.
