# F-053 Page Geometry and Zoom

The page is a fixed-size logical sheet that scales uniformly to fit any
iPad, preserving handwriting layout verbatim across devices. A document's
content type (letter or postcard) fixes the page aspect ratio and the
in-content UI orientation for the document's lifetime. The user can zoom
the whole page as a single unit but can never break the page boundary.

## Logical Page Sizes

Every page has fixed logical dimensions in points, set by the document's
content type:

- **Letter** — portrait, aspect 1 : √2 (A4 portrait). Logical size in
  points is the implementation's choice; the ratio is what matters.
- **Postcard** — landscape, aspect 3 : 2 (4 × 6 inch postcard). Same.

A page's logical size never changes — not on device rotation, not on
zoom, not on cross-device opens.

## Flow

When user opens a letter on U-101 WritingScreen:
- The screen is locked to portrait orientation
  (`UIInterfaceOrientationMask.portrait`).
- U-023 Canvas is sized to the letter's logical dimensions and scaled
  uniformly by `fitScale = min(viewport.w / logical.w, viewport.h /
  logical.h)` to fit the available area; any unfilled area shows the
  screen background.
- Handwriting strokes are stored in logical page coordinates; the same
  data on another iPad re-fits to that device's screen without reflow.

When user opens a postcard on U-101 WritingScreen:
- The screen is locked to landscape orientation
  (`UIInterfaceOrientationMask.landscape`).
- The same fit-to-screen logic applies, using the postcard's landscape
  logical dimensions.

When user holds the iPad in the orientation that does not match the
current content type:
- The app does not rotate the UI to match the device. The user is
  expected to rotate the device to match the content (iOS shows the
  locked UI sideways on the screen, prompting the user physically).

When user pinches the page with two fingers (1× ≤ zoom ≤ 3×):
- The whole page — handwriting, and any later stationery background —
  scales together as one unit; the logical page itself is unchanged.
- When `zoomScale == fitScale`, the page exactly fits the viewport;
  finger swipes up/down still drive page turning (F-051).
- When `zoomScale > fitScale`, the page is larger than the viewport;
  finger pan inside the canvas drives translation, bounded by the page
  edges (no overscroll). Swipe-driven page turning is suspended in this
  zoomed state — the user pinches back to fit before turning.

When user double-taps with a finger inside the page (optional, not v1-required):
- The page toggles between `fitScale` and an intermediate fixed zoom
  (e.g. 2× of fitScale) centered on the tap point.

When the iPad screen size differs across the user's devices:
- The logical page is unchanged; only `fitScale` differs. A line of
  handwriting drawn on iPad mini occupies the same fraction of the page
  on iPad Pro 13" — it never wraps and never re-positions.

## Notes

This feature deliberately does not include device-rotation-driven UI
flips. v1 locks orientation per content type so that handwriting can
never be reflowed or re-shaped by a grip change. Device-rotation
flexibility — for example, allowing the Social Screen to live in either
orientation — is revisited in v5 iPad device adaptation, and any such
relaxation must preserve the v1 no-reflow guarantee.

There is also no sidebar reflow flow: v1 has no overlay sidebar on the
Content Screen. Browsing happens on the Social Screen (F-055), and
transitions between Content and Social are explicit screen-level moves,
not co-existing panels.
