# F-003 Color Picker

The user picks the active stroke color from a preset palette or a custom color.

## Flow

When user taps U-017 ColorPicker on U-015 PenToolbar:
- App shows the color palette plus a "custom" entry.

When user taps a preset color in U-017 ColorPicker:
- C-002 PencilKitBridge updates the active tool's color.
- U-017 ColorPicker reflects the selection.

When user picks "custom" in U-017 ColorPicker:
- App shows the system color wheel.
- On selection, C-002 PencilKitBridge updates the active tool's color.

## Implementation Status

A preset palette and a system color wheel for custom colors are delivered
by the system PKToolPicker that F-001 attaches to the canvas. The custom
U-017 ColorPicker described in the flow above is still ahead.
