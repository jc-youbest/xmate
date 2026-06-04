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

The Content Screen has two Modes — **Reading Mode** and **Writing Mode**
— and they share the same page geometry described in this feature.
Letter logical size is 595×842 pt in both Modes; the fit-scale
calculation is identical; the page is portrait-locked in both Modes.
The Modes differ only in toolset and Pencil behaviour — Writing Mode
inks, Reading Mode does not — never in geometry. The same statement
holds for Postcard. This makes Reading Mode a pure subset of Writing
Mode at the rendering layer, which is why v1 ships Writing Mode and
Reading Mode reuses it later without geometry changes.

Pagination Style (F-056) is a separate axis on top of geometry. Both
Single Page and Continuous use the same logical page sizes and the
same fit-scale rule defined here; F-056 only adds the multi-page
layout container around them.

## Implementation Status

The geometry half of this feature ships in roadmap v1 stage 2. **Zoom
is not yet implemented** — it is the planned stage 3 work, on top of
the geometry layer below.

Stage 2 decisions:

- **C-027 PageGeometry**: new pure-data Swift enum in
  `ios/xmate/xmate/PageGeometry.swift`. Defines `ContentType`
  (`.letter` / `.postcard`), per-type logical sizes
  (`letterLogicalSize = 595×842` pt, A4 in PDF-standard points;
  `postcardLogicalSize = 864×576` pt, 4 × 6 inch ×2 for stroke
  precision), and `fitScale(in:for:)`.

- **WritingScreen (U-101)**: the canvas region is wrapped in a
  `GeometryReader`. The bridge is `.frame`-d at the letter logical
  dimensions and `.scaleEffect(fitScale)`-ed to fit the viewport,
  centered in a viewport-sized `ZStack`. Handwriting strokes are
  recorded in logical coordinates, so the same `Page.drawingData`
  reloads identically on any iPad.

- **PKCanvasView (C-002 PencilKitBridge)**: unchanged. The bridge
  doesn't care about its frame; SwiftUI sizes it externally and
  Apple Pencil input is auto-mapped to the bridge's own coordinate
  space via the layer transform.

- **Orientation lock**: declared in `project.pbxproj` build settings
  (`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad =
  "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown"`).
  This is a stage 2 simplification — it locks the entire app to
  portrait, which is correct for letter-only content. When postcard
  support arrives (with a Core Data `contentType` migration), the
  build-setting lock will be replaced by per-screen orientation
  control at the `UIHostingController` level.

- **Stage 2 hard-codes `.letter`**: `WritingScreen` reads
  `contentType: ContentType = .letter`. The follow-up postcard
  increment adds a `contentType` field to the `Document` Core Data
  entity, a migration, and the per-screen orientation switch.

- **Existing handwriting data**: strokes drawn in earlier stage-1
  builds were recorded at the raw viewport size (~810×1024 pt on
  iPad 8). After stage 2 they are interpreted as 595×842 logical
  coordinates, so old strokes appear shifted and partially clipped.
  Resolution: delete and reinstall the app on the dev device before
  testing stage 2; the new persistent store starts clean.

- **Zoom & double-tap (deferred)**: the flow above describes
  pinch-to-zoom and an optional double-tap. Neither is implemented in
  stage 2. Stage 3 will introduce a `userZoom` factor on top of
  `fitScale`, suspend swipe-driven page turning when zoomed in, and
  add bounded pan within the page.
