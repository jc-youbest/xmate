# F-047 Insert Image into Note

The user inserts an image into the current page; the image becomes a movable layer beneath handwriting.

## Flow

When user taps U-041 InsertImageButton on U-015 PenToolbar:
- App shows the system photo picker.

When user picks an image:
- C-011 ImageMediaStore stores the image asset for this note.
- A U-042 ImageOverlay appears on U-023 Canvas with default size and position.

When user drags U-042 ImageOverlay on U-023 Canvas:
- C-011 ImageMediaStore updates the image's position.

When user pinches or rotates U-042 ImageOverlay:
- C-011 ImageMediaStore updates the image's size and rotation.

When user draws on U-023 Canvas while a U-042 ImageOverlay is present:
- C-002 PencilKitBridge draws strokes above the image (image stays on the lower layer).

When user long-presses U-042 ImageOverlay:
- App offers "delete" to remove the image.
