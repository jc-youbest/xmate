# Roadmap

The development path as a sequence of stages. Each stage is a standalone,
testable iOS build. This plan is living — revised whenever direction changes.

Stage labels (v0, v1, ...) belong to the project, not to any single
feature. Per-feature progress is tracked by the status groupings in the
Backlog section below (Done / v1 remainder / v2 … / Retired).

## v0 — Local blank-page writing

App opens straight into the writing surface. The user writes with Apple
Pencil; strokes persist and reload across launches. Storage already models a
multi-page document, but v0 ships a single-page writing surface only — page
turning, adding and deleting pages, and deleting the document are deferred to
v1. Every page background is blank: no template, no image, no theme.

## v1 — Complete writing mode

The full handwriting experience built on the v0 surface.

A document becomes truly multi-page. The user turns pages with a vertical
paging swipe of the finger, adds and deletes pages, and deletes the whole
document. Only the Apple Pencil draws — the finger is reserved for
navigation. A thin top bar carries the page indicator, an add-page button,
a back-to-social button, and an overflow menu for destructive actions; the
system tool picker stays at the bottom.

v1 splits the app into two top-level full-screen surfaces:

- **Content Screen** — focuses on one letter or one postcard. v1 ships
  the writing variant; the read-only browse variant shares its layout and
  arrives later.
- **Social Screen** — placeholder shell for inbox / feed / pen-pal
  surfaces. v1 ships a structural stub with explicit navigation to and
  from the Content Screen; its concrete contents are designed in v3+.

A document is written on a **paper** — a sheet with fixed logical
dimensions. xmate ships two **Paper Presets** in v1: **Letter** (portrait
A4, 1 : √2) and **Postcard** (landscape, 3 : 2, 4 × 6 inch). Same data
model, only the dimensions differ. Future presets (e.g. notes, A5,
greeting card) are added as new entries in one catalogue — no code
branches on a preset's name; orientation, scroll direction and aspect
all derive from the paper's `width` and `height`.

Pages have fixed logical dimensions; every iPad uniformly scales the page
to fit. Handwriting position is preserved verbatim — a line on iPad mini
and the same line on iPad Pro 13" occupy the same relative space. Content
never reflows for screen size.

Device orientation does not rotate the in-content UI. A document written
on portrait paper locks the Content Screen to portrait; landscape paper
locks it to landscape. The user is expected to orient the device to the
paper — the app does not adapt to grip. Multi-orientation flexibility
across the app is deferred to v5.

The Content Screen offers two equal **Pagination Styles** as a global
user preference applied immediately (F-056):

- **Single Page** — discrete swipe between full-screen pages,
  direction derived from the paper's orientation (vertical for
  portrait paper, horizontal for landscape paper). Default for new
  users; this is what stage 2 ships.
- **Continuous** — pages stack and scroll continuously. Writing Mode
  snaps to the nearest page after scrolling stops; Reading Mode (a
  later increment) scrolls freely with two pages partly visible at
  once. Stage 3 ships Continuous for letter content.

The Content Screen supports whole-page zoom (1× to 3×). Zoom scales
handwriting and, in later stages, the stationery background as one unit.
The page remains one bounded sheet — never an infinite canvas, never
free-panning beyond the page edge.

The user can add media attachments while writing. The add-image experience
matches Apple Notes. These writing-mode attachments — distinct from the
photos placed in stationery mode (v2) — can be moved, scaled, and deleted
at any time. They scale together with the page under zoom.

**v1 status (as built, 2026-06).** Shipped: multi-page + paging, add /
delete page, delete document, the top bar, both Pagination Styles (F-056),
zoom (F-053), stroke persistence. NOT yet shipped despite the description
above — the Postcard preset (paper is hard-coded to Letter pending a
per-document paper migration), the Social Screen stub (F-055), Reading
Mode, and media attachments (F-054). Current priority re-orders the
remainder: finish the zoom defects (F-059, F-060) and media (F-054), then
move to v2 stationery; the Social stub, Reading Mode and per-document paper
are deferred behind v2. Remaining items are tracked in the Backlog.

## v2 — Personalized stationery template editor

App opens into a stationery editing UI. The user composes a single-page
template:

- load multiple images, each freely rotatable, scalable, and placeable
  anywhere on the page (overlay elements);
- set a background — a solid color, a full-screen background photo, or a
  theme (postcard, ruled notebook, grid notebook). A background photo is
  NOT an overlay image: it can only be stretched / filled to the full page.
  A theme is treated as a special background image, possibly a vector.

A template can be saved locally while editing. Its data structure is
identical to a single Page of a writing-mode document, minus the
handwriting. When done, a template can be published; a published template
can be loaded in writing mode as the page background, with handwriting
allowed on top. Publishing = copying the template's Page-shaped data into a
Page of a writing-mode Document.

## v3 — Main interface, offline

App opens into a main interface. The user can: view handwritten letters
shared by others (faked with local test data for now — exact design TBD);
browse stationery templates others shared publicly; open the v1 writing
mode; while writing, swap a different template into any page at any time
(the template data overwrites that Page's photos / background / style /
background color, never its handwriting strokes); jump to the v2 editor at
any time; apply one template to every page of a document at once. Still
standalone and offline — no network needed to test.

## v4 — Networked social

Pen pals, feed, publishing. First stage that requires the network.

## v5 — iPad device adaptation

Stationery and handwriting adapt across iPad screen sizes — iPad 8th
generation and newer real devices; testing expands to multiple sizes.
Cross-device then needs no dedicated work: one account on different-sized
iPads displays correctly.

This is also the stage that revisits device-orientation flexibility. v1
locks each document to its paper's orientation (portrait paper →
portrait UI; landscape paper → landscape UI); v5 evaluates whether to
relax that lock — for example, by allowing the Social Screen to
support both orientations on iPads with attached keyboards, or by
introducing a "wide letter" paper preset for landscape-only iPad
setups. Any relaxation must preserve the v1 guarantee that handwriting
layout never reflows.

## v6 — Networked content moderation

Server-side review of shared content.

---

# Backlog

The future-feature pool. One line per feature — detailed flow specs are
written only when a feature is about to be built, and live as working
notes in the owning module's README or the commit history.

F-XXX is the only catalog ID still in use; it appears in commits for
traceability. Numbering is monotonic; never reuse an ID; allocate new
ones here. Gaps are normal (withdrawn IDs).

## Done (v0–v1)

- F-051 Multi-page document and page turning
- F-053 Page geometry and zoom (300% cap, HUD, dual reset)
- F-056 Pagination style (Single Page / Continuous, global preference)

## v1 remainder

Next Editor increment (current priority), in order:

- F-059 Continuous native zoom/pan — replace the laggy per-frame SwiftUI
  stack transform with a feature-flagged sibling path. Per-page native zoom
  proved smooth but failed two-half-page viewport semantics; retain it only for
  A/B comparison. Prototype outer native stack zoom next, then add bounded
  visible-page-session constraints, reset, edit-menu arbitration,
  mutations/navigation, and device acceptance. Single Page remains untouched.
  Polishes F-053.
- F-060 Top-bar buttons dead while zoomed — when zoomed, taps on
  WritingTopBar do nothing (Add Page, overflow menu) and instead raise the
  PKCanvasView edit callout ("Select All / Insert Space"): the zoomed canvas
  / its edit interaction is capturing touches over the top-bar region.
  Restore top-bar hit-testing and suppress the canvas edit menu. Fixes
  F-053.
- F-054 Insert media while writing — Apple-Notes-like attachments that
  move/scale/delete anytime and zoom with the page.

Deferred behind v2 (were v1; re-prioritised — authoring foundation first):

- F-055 Social Screen v1 stub — structural shell + explicit switching
  with the Content Screen.
- Reading Mode — read-only Content Screen variant sharing the layout.
- Per-document paper — drop the `PaperPreset.letter` hard-code (Core Data
  migration) so the Postcard preset actually ships; folds into the v2
  Storage restructure.

## v2 — Stationery (editor + library modules)

- F-050 Create single-page personalized stationery — compose background
  color / line style / photo frames, then one-way Generate
- F-052 Stationery library — browse, pick, rename, delete locked
  stationery; publish/apply templates per roadmap v2/v3

## v3 — Library module (personal document manager)

- F-011 Document CRUD (list, create, rename, duplicate, delete)
- F-012 Folder organization · F-013 Tags · F-014 Title/tag search ·
  F-015 Handwriting search
- F-048 Lock note (biometric) · F-049 Document thumbnails
- Inbox / drafts / sent letters views feeding documents into the editor

## v3+/v4 — Account & social

- F-018 Settings UI · F-020 Social sign-in (Apple/Google/Facebook/X) ·
  F-021 User profile · F-022 Account settings · F-023 Cross-device sync
  (custom backend, not CloudKit)
- F-024 Add pen pal · F-025 Pen pal list · F-026 Publish document as
  post · F-027 Feed · F-028 Profile page · F-029 Discover
- F-030 Share sheet · F-031 Read-only share link · F-032 Watermark /
  signature · F-033 Playback export
- F-034 Like · F-035 Comments · F-036 Bookmark · F-037 Push
  notifications
- F-038 Privacy controls · F-039 Block · F-040 Report · F-041 Moderation
  pipeline (v6 server side)
- Reserved backend modules (designed when their features start):
  AuthService (verify OAuth tokens from Apple/Google/Facebook/X) ·
  UserProfileAPI · NoteSyncAPI · NoteShareAPI · FeedService ·
  NotificationDispatcher (APNs) · ModerationService

## Robustness / tech debt

- F-057 Startup data preparation — load document, pages and decode page
  drawings in an explicit load phase (off the main thread where possible)
  with `loading` / `ready` / `failed` states, instead of reading inside
  `onAppear` and decoding strokes synchronously in `makeUIView` during the
  view flow. Avoids main-thread jank as documents grow. Evidence: a
  Single↔Continuous mode switch rebuilds every canvas and synchronously
  decodes every page, producing a measured ~0.31 s main-thread hang on a
  7-page document (debugger attached, so inflated — re-measure in a release
  build with Instruments). Same synchronous-decode cost also hits launch.
- F-058 Stroke-decode failure handling — a page whose drawing data fails
  to decode must surface an error / be marked corrupt and routed to a
  recovery flow, never silently render as a blank page (today
  `StrokeSerializer.decode` returning nil is swallowed, which is silent
  data loss). Pairs with F-057's `failed` state.

## Stretch

- F-042 Playback viewing · F-043 Collaborative documents · F-045 Themed
  events · F-046 Drift bottle

## Retired / superseded

- F-001–F-007 pen tool features — covered by the system PKToolPicker
- F-008 canvas zoom/pan (cancelled) · F-009 multi-page note (→ F-051) ·
  F-010 paper styles (→ F-050) · F-016/F-017 export to PDF/image
  (re-spec when sharing is designed) · F-047 insert image (→ F-050)
