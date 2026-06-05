# F-056 Pagination Style

The Content Screen offers two equal **Pagination Styles** — *Single
Page* and *Continuous* — as a global user preference applied
immediately. The two styles share all writing semantics (fixed logical
page, Pencil ink, page CRUD); they differ only in how multiple pages
are laid out and navigated.

Pagination Style is independent of Mode (Reading vs Writing — F-053
Notes) and of Paper (the document's dimensions, F-053). It composes
with both: a Letter (portrait paper) in Writing Mode + Continuous
gives vertical scroll with snap; a Postcard (landscape paper) in
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
  preserving the current page (the new layout scrolls to or snaps to
  that page).
- All future Content Screen sessions, on this and any other document,
  open in the new style until the user changes it again.

When U-101 WritingScreen is rendered with `paginationStyle == .singlePage`:
- The screen shows exactly one page at a time, centered and fit-scaled
  per F-053. Page navigation uses finger swipes along
  `paper.paginationAxis` (F-051). This is the v1 stage-2 behaviour.

When U-101 WritingScreen is rendered with `paginationStyle == .continuous`
in Writing Mode:
- Pages stack along `paper.paginationAxis` inside a scroll container.
  Each page is fit-scaled per F-053 to the cross-axis viewport
  dimension (width for portrait paper, height for landscape paper),
  leaving the main axis free for scrolling.
- The user scrolls with a finger pan or a fast swipe; PKCanvasView's
  `drawingPolicy = .pencilOnly` keeps Pencil reserved for writing.
- When the scroll comes to rest, the container **snaps** to the nearest
  page boundary, so the writing surface is always a single steady page.
  Snap animation: ease-out, ~0.25 s.
- The "current page" is defined as the snapped-to page. U-093
  PageIndicator updates after each snap.
- U-095 AddPageButton appends after the current snapped page (same as
  Single Page).

When U-101 WritingScreen is rendered with `paginationStyle == .continuous`
in Reading Mode (deferred — Reading Mode lands in a later increment):
- Pages stack along `paper.paginationAxis` in the same way, but the
  scroll **does not snap** — it decelerates freely. Two adjacent pages
  can be partly visible simultaneously, with the page gap clearly
  readable as a boundary.
- "Current page" has no meaningful definition; U-093 PageIndicator
  shows the page closest to the viewport center, updated live.

When the user adds or deletes a page while in Continuous:
- The scroll container expands or contracts accordingly; the focus
  page stays under the user's view if possible.

## Visual Spec for Continuous

- **Inter-page gap**: 20 pt (in fit-scaled coordinates), filled with
  the system secondary background colour
  (`Color(.systemGroupedBackground)`).
- **Page edge shadow**: each page gets a 4 pt drop shadow, opacity
  ~0.15, no offset; this reinforces the "independent sheet" feel and
  separates pages from the gap.
- **No page numbers** are painted in the gap or in the letterbox area.
  Page position is conveyed by U-093 PageIndicator in the top bar
  only.
- **Letterbox** (the area outside the fit-scaled page on the cross
  axis) keeps the same screen background colour as the page gap —
  visually the page sits on a continuous neutral field.

## Persistence

- The preference is global, not per-document.
- C-028 SettingsStore persists it in UserDefaults
  (`xmate.paginationStyle`), restored on app launch.
- Default for first-launch / unset value: `.singlePage`.

## Notes

The two Pagination Styles are deliberately equal — neither is the
"correct" way to use xmate. Single Page enforces the "one independent
sheet" mental model and is the default precisely because that mental
model is the product's core identity. Continuous is for users who want
to skim or flow through a multi-page letter without breaking it into
discrete page turns; the snap-on-write rule preserves a stable writing
surface inside that style.

Pagination Style intentionally does **not** vary by Mode or by Paper
— those are independent axes. Once a user has chosen Continuous,
they get Continuous on every paper (Letter, Postcard, any future
preset), in Reading Mode, and in Writing Mode. The setting is one
place, one choice, applied everywhere.

The vocabulary in this codebase reserves the noun "Mode" for Reading
vs Writing only; "Pagination Style" is the noun for Single Page vs
Continuous. This separation is enforced because users and code that
conflate the two axes consistently produce confusing UI.
