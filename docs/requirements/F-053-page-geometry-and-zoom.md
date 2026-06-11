# F-053 Page Geometry and Zoom

The page is a fixed-size logical sheet that scales uniformly to fit any
iPad, preserving handwriting layout verbatim across devices. A document's
**paper** (typically chosen from a Paper Preset such as Letter or
Postcard) fixes the page aspect ratio and the in-content UI orientation
for the document's lifetime. The user can zoom the whole page as a
single unit but can never break the page boundary.

## Logical Page Sizes

A document's page has the fixed logical dimensions of its **paper**, in
points. The v1 catalogue ships two presets:

- **Letter** — portrait, 595 × 842 pt (A4 in PDF-standard points,
  aspect 1 : √2 to within 0.1%).
- **Postcard** — landscape, 864 × 576 pt (4 × 6 inch ×2 for stroke
  precision, aspect 3 : 2 exactly).

Adding a new paper (e.g. an A5 note, a square greeting card) means
one new entry in `PaperPreset.catalog`; no code branches anywhere
need to learn its name. Orientation lock and pagination scroll axis
are derived from `paper.width` and `paper.height` — never from a name.

A paper's logical size never changes — not on device rotation, not on
zoom, not on cross-device opens.

## Flow

When user opens a document whose paper is portrait (e.g. Letter):
- The screen is locked to portrait orientation
  (`paper.orientationLock == .portrait`).
- U-023 Canvas is sized to the paper's logical dimensions and scaled
  uniformly by `fitScale = min(viewport.w / paper.w, viewport.h /
  paper.h)` to fit the available area; any unfilled area shows the
  screen background.
- Handwriting strokes are stored in logical page coordinates; the same
  data on another iPad re-fits to that device's screen without reflow.

When user opens a document whose paper is landscape (e.g. Postcard):
- The screen is locked to landscape orientation
  (`paper.orientationLock == .landscape`).
- The same fit-to-screen logic applies, using the landscape paper's
  dimensions.

When user holds the iPad in the orientation that does not match the
current paper:
- The app does not rotate the UI to match the device. The user is
  expected to rotate the device to match the paper (iOS shows the
  locked UI sideways on the screen, prompting the user physically).

When user pinches the page with two fingers:
- The whole page — handwriting, and any later stationery background —
  scales together as one unit; the logical page itself is unchanged.
- Minimum zoom is `fitScale` (the page fits the viewport exactly). The
  user cannot zoom out below fit — there is no "smaller than screen" state.
- Maximum zoom is 3× fitScale (300%) — the roadmap's 1×–3× range.
  (An earlier revision left this unbounded; capped in stage 4.)
- U-112 ZoomHUD — a centered, translucent percentage readout
  (100%–300%) — appears while pinching and fades out 1 s after the
  fingers lift. It never intercepts touches. This matches the
  convention of mainstream handwriting apps.
- U-102 WritingTopBar stays visible at all zoom levels: the canvas
  area is clipped, so the scaled page can never paint over the bar.
- **At fit (zoomScale == fitScale) — "unzoomed state":**
  - Single Page: finger swipes drive page turning (F-051).
  - Continuous: finger pan drives free scroll between pages (F-056).
- **Above fit (zoomScale > fitScale) — "zoomed state":**
  - Both modes: finger gestures become pan only, bounded by the page
    edges (no overscroll past the page boundary).
  - Single Page: swipe-driven page turning is suspended.
  - Continuous: free scroll between pages is suspended; only pan within
    the current page is possible.
  - U-113 ZoomResetButton appears in U-102 WritingTopBar showing the
    live percentage (e.g. "153%"); tapping it restores 100%.
  - The user returns to the unzoomed state by pinching back to
    fitScale, double-tapping the page with a finger, or tapping
    U-113 ZoomResetButton. An explicit reset flashes U-112 ZoomHUD
    ("100%") once as feedback.

When user double-taps with a finger inside the page while zoomed:
- The page animates back to 100% (fit). At fit, a finger double-tap
  is a no-op. (The earlier idea of toggling up to an intermediate
  zoom on double-tap at fit remains optional and unimplemented.)

When the iPad screen size differs across the user's devices:
- The paper's logical size is unchanged; only `fitScale` differs. A
  line of handwriting drawn on iPad mini occupies the same fraction
  of the paper on iPad Pro 13" — it never wraps and never re-positions.

## Notes

This feature deliberately does not include device-rotation-driven UI
flips. v1 locks orientation per paper so that handwriting can never be
reflowed or re-shaped by a grip change. Device-rotation flexibility —
for example, allowing the Social Screen to live in either orientation
— is revisited in v5 iPad device adaptation, and any such relaxation
must preserve the v1 no-reflow guarantee.

There is also no sidebar reflow flow: v1 has no overlay sidebar on the
Content Screen. Browsing happens on the Social Screen (F-055), and
transitions between Content and Social are explicit screen-level moves,
not co-existing panels.

The Content Screen has two Modes — **Reading Mode** and **Writing Mode**
— and they share the same page geometry described in this feature. A
Letter paper is 595×842 pt in both Modes; the fit-scale calculation is
identical; the page is portrait-locked in both Modes. The Modes differ
only in toolset and Pencil behaviour — Writing Mode inks, Reading Mode
does not — never in geometry. The same statement holds for Postcard
and any future paper. This makes Reading Mode a pure subset of Writing
Mode at the rendering layer, which is why v1 ships Writing Mode and
Reading Mode reuses it later without geometry changes.

Pagination Style (F-056) is a separate axis on top of geometry. Both
Single Page and Continuous use the same paper logical sizes and the
same fit-scale rule defined here; F-056 only adds the multi-page
layout container around them.

## Implementation Status

The geometry half of this feature ships in roadmap v1 stage 2. **Zoom
ships in stage 3**, layered on top of the geometry layer below.

Stage 2 decisions (with the stage 2.5 refactor folded in):

- **C-027 PageGeometry** lives in `ios/xmate/xmate/PageGeometry.swift`
  and exposes:
    - `struct PaperSize { width, height }` plus derived
      `isPortrait`, `isLandscape`, `aspectRatio`,
      `orientationLock`, `paginationAxis`.
    - `enum PaperPreset` with `.letter = 595×842 pt` and
      `.postcard = 864×576 pt`, plus a `catalog` array used by the
      future paper picker.
    - `PageGeometry.fitScale(in:for:)` taking a `PaperSize`.
  There is no `ContentType` enum: letter and postcard are values of
  the same struct, and all behaviour (orientation, scroll axis) is
  derived from the dimensions. Adding a new paper kind is one entry
  in `PaperPreset.catalog` with no other code changes.

- **WritingScreen (U-101)**: the canvas region is wrapped in a
  `GeometryReader`. The bridge is `.frame`-d at the paper's logical
  dimensions and `.scaleEffect(fitScale)`-ed to fit the viewport,
  centered in a viewport-sized `ZStack`. Stage 2 hard-codes
  `paper = PaperPreset.letter`; once `Document` carries its paper
  through a Core Data migration, the screen reads it from the
  document instead.

- **PKCanvasView (C-002 PencilKitBridge)**: unchanged. The bridge
  doesn't care about its frame; SwiftUI sizes it externally and
  Apple Pencil input is auto-mapped to the bridge's own coordinate
  space via the layer transform.

- **Orientation lock**: declared in `project.pbxproj` build settings
  (`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad =
  "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown"`).
  This is a stage 2 simplification — it locks the entire app to
  portrait, which is correct while every document uses Letter. When a
  non-portrait paper ships (with the Core Data migration that records
  per-document paper dimensions), the build-setting lock is replaced
  by per-screen orientation control derived from
  `paper.orientationLock` at the `UIHostingController` level.

- **Existing handwriting data**: strokes drawn in earlier stage-1
  builds were recorded at the raw viewport size (~810×1024 pt on
  iPad 8). After stage 2 they are interpreted as 595×842 logical
  coordinates, so old strokes appear shifted and partially clipped.
  Resolution: delete and reinstall the app on the dev device before
  testing stage 2; the new persistent store starts clean.

- **Zoom (stage 3, reworked in stage 4)**: state and gesture math
  live in **C-031 PageZoomModel** (`PageZoom.swift`), consumed by
  WritingScreen for both Pagination Styles.
  - `userZoom` clamped to 1.0×–3.0× (fit to 300%). Reset (without
    HUD flash) on every page change so each page opens at fit.
  - `MagnificationGesture` attached as `.simultaneousGesture` on
    the canvas area (two-finger; never conflicts with Pencil).
  - **Finger panning**: a `UIPanGestureRecognizer` with
    `allowedTouchTypes = [.direct]` attached directly to
    PKCanvasView inside C-002 PencilKitBridge — the only reliable
    way to accept finger panning while writing with Pencil.
    Pan offset bounded by the half-overflow per axis so the page
    edge never passes the viewport edge.
  - **U-112 ZoomHUD**: centered translucent percentage capsule;
    shown on pinch change, hidden 1 s after pinch end
    (`PageZoomModel.hudLinger`); touch-transparent.
  - **Reset to 100%**: finger double-tap on the page (finger-only
    `UITapGestureRecognizer` in PencilKitBridge, both styles) or
    U-113 ZoomResetButton in the top bar. Both animate the reset
    and flash the HUD once.
  - **Top bar never covered**: WritingScreen applies `.clipped()`
    to the canvas area, so the scaled page cannot paint over
    U-102 WritingTopBar.
  - **Single Page zoomed state**: swipe callbacks passed as `nil`
    → pagination suspended; the recognisers stay attached (no-op
    dispatch), so toggling zoom never recreates a canvas.
  - **Continuous zoomed state**: the ScrollView is frozen
    (`scrollDisabled`) and the whole stack is scaled/offset; the
    SAME current-page canvas keeps editing and owns the finger
    pan. No overlay canvas — the one-canvas-per-Page invariant
    (C-030) holds.
