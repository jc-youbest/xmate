# F-056 Pagination Style

The Content Screen offers two equal **Pagination Styles** — *Single
Page* and *Continuous* — as a global user preference applied
immediately. The two styles share all writing semantics (fixed logical
page, Pencil ink, page CRUD); they differ only in how multiple pages
are laid out and navigated.

Pagination Style is independent of Mode (Reading vs Writing — F-053
Notes) and of Paper (the document's dimensions, F-053). It composes
with both: a Letter (portrait paper) in Writing Mode + Continuous
gives vertical free scroll; a Postcard (landscape paper) in
Reading Mode + Continuous gives horizontal free scroll with two
pages partly visible.

## Direction by Paper Orientation

Pagination Style fixes the *navigation grammar* (discrete swipe vs
continuous scroll); the paper's orientation fixes the *direction*:

- **Portrait paper** (e.g. Letter) — direction is vertical. Swipe up /
  scroll down advances to the next page.
- **Landscape paper** (e.g. Postcard) — direction is horizontal. Swipe
  left / scroll right advances to the next page.

In code this is `paper.paginationAxis` — `.vertical` when
`paper.isPortrait`, `.horizontal` when `paper.isLandscape`. Adding a
new paper preset never touches the navigation code; the axis is
always derived from the paper's `width` and `height`.

## Flow

When user taps U-103 WritingOverflowMenu and selects U-111
PaginationStylePicker:
- C-028 SettingsStore writes the new `paginationStyle` value to
  UserDefaults.
- The current Content Screen re-renders immediately in the new style,
  preserving the current page.
- All future Content Screen sessions, on this and any other document,
  open in the new style until the user changes it again.

When U-101 WritingScreen is rendered with `paginationStyle == .singlePage`:
- The screen shows exactly one page at a time, centered and fit-scaled
  per F-053 (`PageGeometry.fitScale`). Page navigation uses finger
  swipes along `paper.paginationAxis` (F-051). This is the v1 stage-2
  behaviour (SinglePagesView).

When U-101 WritingScreen is rendered with `paginationStyle == .continuous`:
- Pages stack along `paper.paginationAxis` inside a free-scrolling
  ScrollView (ContinuousPagesView). Each page is scaled to the
  cross-axis viewport dimension (`PageGeometry.continuousFitScale`):
  width for portrait paper, height for landscape paper.
- The user scrolls with a finger pan or a fast swipe; PKCanvasView's
  `drawingPolicy = .pencilOnly` keeps Pencil reserved for writing.
- **No snap, no auto-alignment, ever.** Natural deceleration only. A
  state with two half-pages and the inter-page gap visible is a valid
  resting state, not a transient one. This applies in both Writing Mode
  and Reading Mode.
- "Current page" is defined geometrically: whichever page's centre is
  closest to the viewport centre along the scroll axis. Computed live
  via `.onScrollGeometryChange` (iOS 18+). U-093 PageIndicator and
  Delete Page both operate on this geometric current page.
- U-095 AddPageButton appends a blank page at the end and scrolls to
  it via a one-way UUID signal + `ScrollViewReader.scrollTo`.

When the user adds or deletes a page while in Continuous:
- The scroll container expands or contracts; the focus page stays
  under the user's view if possible.

## Visual Spec for Continuous

- **Inter-page gap**: 20 pt (in display coordinates), filled with
  the system secondary background colour
  (`Color(.systemGroupedBackground)`).
- **Page edge shadow**: each page gets a 4 pt drop shadow, opacity
  ~0.15, no offset; this reinforces the "independent sheet" feel and
  separates pages from the gap.
- **No page numbers** are painted in the gap or in the letterbox area.
  Page position is conveyed by U-093 PageIndicator in the top bar
  only.
- **Letterbox** (the area outside the fit-scaled page on the cross
  axis) keeps the same background colour as the page gap —
  visually the page sits on a continuous neutral field.

## Persistence

- The preference is global, not per-document.
- C-028 SettingsStore persists it in UserDefaults
  (`xmate.paginationStyle`), restored on app launch.
- Default for first-launch / unset value: `.singlePage`.

## Architecture Notes (from stage 3 implementation)

### No snap — permanent decision

The original spec described snap-on-rest in Writing Mode. This is
permanently removed. Attempting snap via `.scrollTargetBehavior` cuts
momentum and fails on zero-velocity releases; attempting it via
`.scrollPosition(id:)` creates a perpetual snap loop because the
binding is bidirectional — writing the "current page id" from a scroll
observer into a `.scrollPosition(id:)` binding causes the ScrollView
to immediately re-scroll to that position on every geometry change.
Free scroll is the correct and final design for both modes.

### Programmatic scroll — one-way only

Add Page in Continuous mode uses a one-way UUID signal: WritingScreen
sets `scrollTarget`; ContinuousPagesView calls
`scrollProxy.scrollTo(target)` and clears the signal. No binding
write-back. This is the only safe programmatic scroll path.

### PKToolPicker — C-029 ToolPickerHost, and why plain VStack

Multiple per-canvas PKToolPicker instances cannot coexist — they fight
for first responder and render duplicate picker UIs.

The solution is one app-wide picker in C-029 ToolPickerHost, registered
with all live canvases. The critical constraint: PKToolPicker associates
with specific UIResponder instances. When a canvas leaves the window
hierarchy, iOS resigns its first responder BEFORE SwiftUI's
`dismantleUIView` fires, and no reliable recovery path exists on real
hardware (re-priming `setVisible` after the fact does not work).

Therefore ContinuousPagesView uses a plain VStack, not LazyVStack. All
canvases are permanently in the hierarchy; no canvas is ever unexpectedly
removed during scrolling. The only removal scenario is explicit page
deletion, for which ToolPickerHost's `scheduleReanchor` promotes the
adjacent live canvas. For bounded stationery documents (letters,
postcards) the memory cost of keeping all canvases alive is acceptable.

XmateCanvasView (a PKCanvasView subclass) overrides `becomeFirstResponder`
and `resignFirstResponder` to notify ToolPickerHost — the only reliable
way to track which of several simultaneously visible canvases holds
Pencil focus.

## Notes

The two Pagination Styles are deliberately equal — neither is the
"correct" way to use xmate. Single Page enforces the "one independent
sheet" mental model and is the default precisely because that mental
model is the product's core identity. Continuous is for users who want
to skim or flow through a multi-page letter without breaking it into
discrete page turns.

Pagination Style intentionally does **not** vary by Mode or by Paper
— those are independent axes. Once a user has chosen Continuous,
they get Continuous on every paper (Letter, Postcard, any future
preset), in Reading Mode, and in Writing Mode. The setting is one
place, one choice, applied everywhere.

The vocabulary in this codebase reserves the noun "Mode" for Reading
vs Writing only; "Pagination Style" is the noun for Single Page vs
Continuous. This separation is enforced because users and code that
conflate the two axes consistently produce confusing UI.
