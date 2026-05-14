# F-050 Create Single-page Personalized Stationery

The user composes one sheet of personalized stationery, then locks it. A
stationery page has two phases: a compose phase (set background, lines, and
photos) and a write phase (handwriting on the locked sheet). Generation is
the one-way transition between them.

## Flow

When user starts a new stationery page:
- App opens U-085 StationeryComposerScreen in compose phase.
- The page starts with a default background color and no line style.

When user sets the background color in U-086 BackgroundColorPicker:
- U-085 StationeryComposerScreen updates the page background.

When user sets the line style in U-087 LineStylePicker (blank / ruled /
grid / dot):
- U-085 StationeryComposerScreen updates the line overlay drawn over the
  background.

When user picks a layout preset in U-088 LayoutPresetPicker (none /
photo-left / photo-right / photo-top / photo-bottom):
- U-085 StationeryComposerScreen pre-places a U-090 PhotoFrame in the
  corresponding region as a starting point. The frame can still be freely
  adjusted afterwards.

When user taps U-089 AddPhotoButton (up to 10 photos per page):
- App shows the system photo picker.
- The chosen image is placed in a new U-090 PhotoFrame on the page.

When user drags, rotates, or pinches a U-090 PhotoFrame:
- The frame's position, rotation, and scale update. Frames may sit anywhere
  on the page, overlapping or independent of layout-preset regions.

When user removes a U-090 PhotoFrame:
- The frame and its image are removed from the page.

When user taps U-091 GenerateButton:
- App shows U-092 GenerateConfirmDialog warning that generation is final and
  cannot be undone.

When user confirms in U-092 GenerateConfirmDialog:
- The background, line style, and all photo frames are flattened into a
  single locked stationery background.
- The page transitions to write phase: handwriting (F-001) is enabled, and
  the stationery composition can no longer be edited.
