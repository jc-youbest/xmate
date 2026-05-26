# F-054 Insert Media While Writing

While writing, the user adds photos or other media onto the page as freely
movable items — distinct from the photo frames placed when composing
stationery.

## Flow

When user inserts media while writing:
- The system photo picker opens; the chosen item is placed on the current
  page as a movable media item.

When user drags, pinches, or rotates a media item:
- Its position, scale, and rotation update. The item stays editable at any
  time — it is never locked.

When user writes over a media item with Apple Pencil:
- Strokes are drawn above the media item; the media stays on a lower layer.

When user removes a media item:
- The item and its stored asset are removed from the page.

When the page is zoomed (F-053 Page Geometry and Zoom):
- Media items scale together with the page as one unit. The page does
  not rotate with the device — letter content stays portrait, postcard
  content stays landscape — so media items have no separate
  device-rotation behaviour.

## Notes

Writing-mode media is distinct from the photo frames of F-050 Create
Single-page Personalized Stationery: F-050 photos are placed during the
compose phase and frozen by the Generate step, whereas writing-mode media
is added on a live page and stays editable. The add experience targets
parity with Apple Notes.
