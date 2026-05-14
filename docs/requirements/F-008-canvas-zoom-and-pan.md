# F-008 Canvas Zoom and Pan

**Status: Cancelled.** The product uses a fixed-page stationery model — each
page is a fixed sheet that cannot be zoomed or panned. Kept for history in
case a "zoom in for fine detail" need re-emerges; would need re-discussion
before any implementation.

The user zooms in/out and pans around the canvas for fine work or overview.

## Flow

When user pinches U-023 Canvas with two fingers:
- C-002 PencilKitBridge scales the canvas to the pinch factor (range 0.25x to 4x).

When user drags U-023 Canvas with two fingers:
- C-002 PencilKitBridge translates the canvas viewport.

When user double-taps U-023 Canvas with two fingers:
- C-002 PencilKitBridge resets zoom to 1x and centers the page.
