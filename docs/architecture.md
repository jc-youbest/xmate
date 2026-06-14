# Architecture

Global architecture of the xmate iOS app. Module-level detail lives in
each module's README next to its code (`ios/xmate/xmate/<Module>/README.md`).

## Layering

    App  →  Editor  →  Storage
     │                    ↑
     └────→ Library ──────┘        Shared: small cross-module types

- **App** (`App/`) — entry layer: `@main`, RootView (composition root),
  global settings. Depends on modules; no module ever imports from it.
- **Editor** (`Editor/`) — Content Screen: pagination, zoom, the
  PencilKit writing stack. Edits exactly the document it is given.
- **Storage** (`Storage/`) — Core Data store, Document/Page entities,
  drawing load/save. Knows nothing about UI (no pagination styles, no
  zoom, no tool picker).
- **Library** (`Library/`) — placeholder; document list / drafts /
  inbox / sent letters land in v3.
- **Shared** (`Shared/`) — truly cross-module small types only
  (currently `PaginationStyle`, `Comparable.clamped`). Not a junk drawer.

## Xcode project

| Setting | Value |
|---|---|
| Project name | `xmate` |
| Bundle Identifier | `com.cwc.xmate` |
| Deployment target | iPadOS 18.0 |
| Device family | iPad only |
| Interface | SwiftUI |
| Language | Swift |

Xcode wraps the project in a product-named folder, so the on-disk layout
double-nests (`ios/xmate/xmate/`):

- `ios/xmate/xmate.xcodeproj/` — the Xcode project; open this.
- `ios/xmate/xmate/` — application source, one folder per module, each
  carrying its own `README.md`.
- `ios/xmate/xmateTests/` — unit tests; `xmateUITests/` — UI tests.

The source folder is a filesystem-synchronized group (`objectVersion 77`):
files added to a module folder on disk join the target automatically — no
pbxproj edits. Module `README.md` files are excluded from the app target
via a membership-exception set in the pbxproj so they are never bundled.

## Document input model

The editor never decides which document it shows.

    xmateApp / RootView (App)
        ↓  resolves WHICH document        v1: hard-coded dev name
    WritingScreen(document:) (Editor)
        ↓  edits exactly that document
    NoteStore (Storage)
        ↓  load / save only

- v1: `RootView` resolves a hard-coded dev document name through
  `NoteStore.loadOrCreateDocument(named:)` and injects the `Document`.
- Future sources — inbox (social), drafts/list (Library), new creation —
  all resolve a `Document` outside the editor and inject it the same way.

## Paper model

A document is written on a paper with fixed logical dimensions in points
(Letter 595×842 portrait; Postcard 864×576 landscape). Everything
mechanical — orientation lock, pagination axis, swipe directions, scroll
axis, fit scale — derives from `paper.width` / `paper.height`. **No code
branches on a paper's name.** New presets are catalogue entries only.
Logical page size never changes with device; every iPad scales the page
uniformly to fit, and handwriting never reflows.

Current stage limitation: `paper` is hard-coded to `PaperPreset.letter`
in WritingScreen until the per-document paper Core Data migration.

## PencilKit canvas principles

These invariants were earned through device debugging; do not regress
them casually.

1. **One authoritative canvas per Page** (DrawingSessionManager): a Page
   is never edited by two canvases at once; only the active canvas
   saves. Activation order: flush previous → reload from store → mark
   active + bind tool picker → become first responder.
2. **Versioned writes** (NoteStore): every drawing write carries a
   monotonic version; a write not strictly greater than the stored
   version is dropped. Backstop against stale canvases clobbering newer
   handwriting.
3. **All page canvases stay alive** in both pagination styles — never
   create/destroy a PKCanvasView on page turn. Required for flicker-free
   flips (Single Page offset carousel) and stable PKToolPicker anchoring
   (Continuous uses a plain VStack, never Lazy).
4. **Tool state is convergent, not delivery-dependent** (ToolPickerHost):
   PencilKit's implicit observer/first-responder tool delivery misses
   changes during responder churn; the host pushes every selected tool
   into all registered canvases and re-stamps on register/activate.
5. **Pencil draws, fingers navigate**: drawingPolicy `.pencilOnly`;
   swipe/pan/double-tap recognizers accept `.direct` touches only and
   are attached directly to the PKCanvasView (covering views break
   Pencil coexistence).
6. Never rely on undocumented implicit framework behavior (cf. the
   rejected `.scrollPosition(id:)` bidirectional binding; the one-way
   `scrollTarget` UUID signal is used instead).

## Flow design notes

How each implemented flow ended up as it is — the settled decision and
the alternatives tried and rejected, plus the constraint that forced the
choice. All flows, whether internal to one module or spanning several,
are recorded here in one place: telling them apart up front is hard and
module boundaries move, so a single home avoids shuffling notes between
files. Record decisions, not plans.

### Single Page paging

Persistent-offset carousel (SinglePagesView). A page turn animates
`currentPageIndex`; every page's offset shifts by one stride, so no
canvas is created or destroyed (principle 3) — the flip is flicker-free
and the departing page needs no emergency flush (it stays alive;
DrawingSessionManager hands the active-editor role over explicitly).
Swipe axis derives from paper orientation (portrait → vertical,
landscape → horizontal). *Rejected:* rebuilding the page view per turn
(flicker).

### Continuous paging

Pages stack in a plain `VStack`, never `LazyVStack`: the PKToolPicker
needs window-attached canvases (principle 3), and lazy loading would
detach off-screen pages and break tool anchoring. Writing Mode snaps to
the nearest page when scrolling stops (the writing surface is always one
steady page); Reading Mode (later) scrolls freely with two adjacent
pages partly visible. Programmatic moves use a one-way `scrollTarget`
UUID signal. *Rejected:* `LazyVStack` (tool picker breaks);
`.scrollPosition(id:)` two-way binding (snap loop — principle 6).

### Zoom

Whole-page zoom 1×–3× (PageZoomModel owns state and gesture math),
capped at 300%. Handwriting and (later) the stationery background scale
as one unit; the page stays one bounded sheet — never infinite, never
free-panning past its edge. The zoomed page is clipped to the canvas
area so it never paints over the top bar. Reset to 100% by finger
double-tap or the top-bar zoom-reset button (live percentage while
zoomed); a transient centered ZoomHUD reports the percentage and
auto-fades. *Rejected:* free-panning / infinite canvas — xmate is
bounded stationery, not a whiteboard.

### Activation bootstrap

The pagination views (SinglePagesView / ContinuousPagesView) declare the
desired-active page to DrawingSessionManager in a **one-shot `onAppear`**.
Therefore the editor must not instantiate them before the page list is
loaded: `WritingScreen` gates the canvas area on `!pages.isEmpty`, so the
pagination view is created once, with pages present, and its `onAppear`
runs `setDesiredActive` — which is what makes a canvas get promoted
(`makeActive` → first responder → ToolPicker) on the first page at launch.
*Rejected (caused the bug):* rendering the pagination view before pages
load — its `onAppear` then fired with an empty page list, `setDesiredActive`
was never called, no canvas was promoted, and the PKToolPicker never bound
until a page turn re-declared the desired page. Full story and the
`EditorTrace` toggle for re-tracing this path: `docs/lifecycle.md`.

## Tech stack

- iPadOS 18.0+ minimum; Swift, SwiftUI (UIKit where SwiftUI gaps exist);
  PencilKit for handwriting.
- Local storage: Core Data in `Library/Application Support/`
  (app-private, not exposed to the Files app).
- Backend (later): self-hosted custom backend — NOT CloudKit. Sync and
  social go through it. Auth: multi-provider social login (Apple,
  Google, Facebook, X); no app-level passwords.
- Primary dev device: iPad 8th gen (iPadOS 18.5) + Apple Pencil 1; must
  stay compatible with the latest iPad/Pencil. Pencil 2/Pro features are
  optional enhancements, silently ignored on older hardware.
