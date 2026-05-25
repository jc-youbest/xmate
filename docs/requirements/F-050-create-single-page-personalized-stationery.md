# F-050 Create Single-page Personalized Stationery

The user composes one sheet of personalized stationery and locks it. The
output is a locked Stationery saved to the Stationery Library (F-052),
reusable across documents. Composing involves no handwriting — that happens
later, on a page made from this stationery (F-051).

## Flow

When user starts composing a new stationery:
- App opens U-085 StationeryComposerScreen with an unlocked stationery:
  a default background color, no line style, no photos.
- The unlocked stationery is persisted as it is edited, so the user can
  leave and resume an unfinished composition.

When user sets the background color in U-086 BackgroundColorPicker:
- U-085 StationeryComposerScreen updates the stationery background.

When user sets the line style in U-087 LineStylePicker (blank / ruled /
grid / dot):
- U-085 StationeryComposerScreen updates the line overlay.

When user picks a layout preset in U-088 LayoutPresetPicker (none /
photo-left / photo-right / photo-top / photo-bottom):
- U-085 StationeryComposerScreen pre-places a U-090 PhotoFrame in the
  corresponding region as a starting point. The frame can still be freely
  adjusted afterwards.

When user taps U-089 AddPhotoButton (up to 10 photos per stationery):
- App shows the system photo picker.
- The chosen image is placed in a new U-090 PhotoFrame.

When user drags, rotates, or pinches a U-090 PhotoFrame:
- The frame's position, rotation, and scale update. Frames may sit
  anywhere, overlapping or independent of layout-preset regions.

When user removes a U-090 PhotoFrame:
- The frame and its image are removed.

When user taps U-091 GenerateButton:
- App shows U-092 GenerateConfirmDialog warning that locking is final.

When user confirms in U-092 GenerateConfirmDialog:
- The stationery is locked: background, line style, and photo frames
  become immutable.
- The locked stationery is saved to the Stationery Library (F-052),
  available to be placed into a document as a page (F-051).
