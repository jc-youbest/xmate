# F-004 Stroke Thickness

The user adjusts how thick strokes are drawn.

## Flow

When user moves U-018 ThicknessSlider on U-015 PenToolbar:
- C-002 PencilKitBridge updates the active tool's width.

When user draws on U-023 Canvas after adjusting:
- The stroke is rendered at the new width.

## Implementation Status

Per-tool stroke thickness is delivered by the system PKToolPicker that
F-001 attaches to the canvas. The custom U-018 ThicknessSlider described in
the flow above is still ahead.
