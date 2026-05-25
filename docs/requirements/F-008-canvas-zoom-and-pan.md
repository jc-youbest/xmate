# F-008 Canvas Zoom and Pan

**Status: Cancelled.** This feature described free pinch-zoom and two-finger
panning of the canvas. The product keeps a bounded-page model with no free
panning. Whole-page zoom — scaling the page without panning — did later
re-emerge and is specified by F-053 Page Rotation and Zoom (roadmap v1); the
free pan/zoom of F-008 itself remains cancelled. Kept for history.

The user zooms in/out and pans around the canvas for fine work or overview.

## Flow

When user pinches U-023 Canvas with two fingers:
- C-002 PencilKitBridge scales the canvas to the pinch factor (range 0.25x to 4x).

When user drags U-023 Canvas with two fingers:
- C-002 PencilKitBridge translates the canvas viewport.

When user double-taps U-023 Canvas with two fingers:
- C-002 PencilKitBridge resets zoom to 1x and centers the page.
