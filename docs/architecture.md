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
  DEBUG builds can opt into a separate named dev document for one preset
  via `DevDocumentPagePresetProbe`; this exercises the same persisted
  document PageSpec path without adding user-facing preset UI or mutating
  the default A4 portrait dev document.
- Future sources — inbox (social), drafts/list (Library), new creation —
  all resolve a `Document` outside the editor and inject it the same way.

## Paper model

A document is written on a paper with fixed logical dimensions in points
(A4 595×842 portrait by default; other presets include A4 landscape and
postcard portrait/landscape). Page shape, aspect ratio, fit scale, and
default flow-axis choices derive from page-spec data, not a paper name.
**No code branches on a paper's name.** New presets are catalogue entries
only. Logical page size never changes with device; every iPad scales the
page uniformly to fit, and handwriting never reflows.

Current stage: the document page spec is stored on `Document` as a preset
id plus logical page width/height. `PagePresetCatalog` carries A4
portrait, A4 landscape, postcard portrait, and postcard landscape as data
entries; new documents persist A4 portrait by default. The data flows
through `PageSpec` / `PageSize` / `LayoutPolicy` and is adapted by
`PageGeometry` back into the existing `PaperSize` runtime path.

Layout resolution is explicit and small: `EditorConfiguration` resolves
the active `LayoutPolicy` from the selected `PageSpec` and current
presentation style. That makes the effective flow axis come from
`PageSpec.flowAxis` while preserving the existing runtime bridge. The
current default resolves to A4 portrait, vertical flow, and whichever
Single Page / Continuous presentation the existing settings choose.
`EditorLayoutContext` is the value passed through WritingScreen and the
editor view hierarchy for that resolved layout. It carries the page spec,
page size/orientation, flow axis, presentation style, resolved policy, and
the current bridged `PaperSize`; it is not observable state and does not
select presets.

Current persisted model: Core Data model version `xmate 2.xcdatamodel`
adds `Document.pagePresetID`, `Document.logicalPageWidth`, and
`Document.logicalPageHeight`. `Page` still stores only `id`,
`drawingData`, `version`, and its inverse `document` relationship. Flow
axis is not persisted; it is reconstructed from the resolved page spec and
layout policy. Legacy v1 documents may have nil or zero page-spec fields,
so `Document.resolvedPageSpec` computes a safe A4 portrait fallback without
rewriting drawing blobs or treating migration normalization as a document
edit. New documents persist the A4 portrait preset id and dimensions once
at creation. `NoteStore` also exposes a typed preset creation path for the
App layer; the preset is applied only when creating a new named document,
while existing documents keep their persisted page spec.

Future ownership decision: page specification belongs to the `Document`,
not each `Page` and not `SettingsStore`. xmate documents are ordered
stationery sheets of one paper kind; a mid-document paper change would
make page-turning, generation, sharing, and print/export semantics
ambiguous. `SettingsStore` may own the global presentation preference
(`singlePage` / `continuous`) but not document paper semantics.
`LayoutPolicy` combines the document's page spec with presentation style
and runtime environment, and `EditorLayoutContext` is the value SwiftUI
views consume.

Core Data migration stores document-level page-spec fields only:
`pagePresetID: String?`, `logicalPageWidth: Double`, and
`logicalPageHeight: Double`. `PageSpec.flowAxis` remains runtime layout
policy, not a persisted field in this increment; it is reconstructed from
the resolved preset or from dimensions when building the runtime
`PageSpec`. Existing stores lightweight-migrate with nil or zero added
fields, then compute an A4 portrait fallback at read time. Do not rewrite
`Page.drawingData` during migration or fallback resolution.

PKDrawing persistence: each page's `drawingData` is
`PKDrawing.dataRepresentation()` captured from a canvas whose bounds are
the current logical page size. PKDrawing stores absolute drawing geometry
in that logical coordinate space. Reopening the same document with a
different runtime `PageSpec` does not reflow or normalize strokes: the
stored coordinates remain absolute. A larger page can make strokes occupy
a smaller relative area; a smaller or differently shaped page can crop
content outside the new bounds. This is why existing documents must
migrate to A4 portrait semantics before user-selectable presets land.

Document-semantic data and runtime presentation data are separate:
document paper width/height/preset identify the stationery being edited;
presentation style selects Single Page or Continuous; page flow describes
how pages are arranged in the editor; viewport size/orientation is the
actual SwiftUI/window geometry available at runtime; preferred interface
orientation is an optional app/window request, not page identity.

`EditorLayoutEngine` is the future pure layout source. It can take an
`EditorLayoutContext` plus viewport size and page count, then returns page
frames, content size, fit scale, gap, flow axis, and presentation style.
Current runtime views still use their existing layout code through the
`PageGeometry` compatibility bridge; the engine is being introduced before
it becomes authoritative.

## Orientation and adaptive layout contract

The app target currently generates its Info.plist from build settings.
For iPad (`TARGETED_DEVICE_FAMILY = 2`), both Debug and Release declare
`UISupportedInterfaceOrientations_iPad` as portrait and portrait-upside-
down only. The iPhone orientation keys are irrelevant because the target
is iPad-only. There is no AppDelegate/SceneDelegate orientation override,
no `UIWindowScene.requestGeometryUpdate` call, no `UIDevice` orientation
forcing, and no runtime consumer of `PaperSize.orientationLock`.

Consequently, changing `PageSpec` today changes logical page dimensions,
resolved flow axis, and rendering/fit geometry only. It does not rotate
the app window or the editor chrome. A landscape page displayed in the
current iPad target is a landscape sheet fitted inside a portrait editor
viewport, which is why it appears like a landscape photo in a portrait
frame and leaves vertical unused space.

Page orientation and window orientation are different contracts. Page
orientation is stable document content semantics. Window orientation is
the current container supplied by iPadOS: full-screen, Split View, Stage
Manager, resizable windows, and future external displays can all provide
viewports whose aspect ratio does not match the document's paper. The
editor must therefore always adapt layout to the actual viewport size.
When full-screen and supported by the target, the app may also request a
preferred interface orientation matching the document's page orientation,
but that request is only a preference and cannot replace responsive
layout.

Recommended runtime contract:
`PageSpec` describes document paper semantics; `LayoutPolicy` combines the
page spec, presentation style, preferred flow, and environment rules;
`EditorLayoutContext` carries the resolved value for SwiftUI; the actual
viewport size is always authoritative for fit scale and chrome placement;
WritingTopBar chooses a compact/regular/landscape-aware layout from the
viewport and context, not from a preset name. Future full-screen iPad
support can use both strategies: request landscape when a landscape
document opens and the app is full-screen, while still adapting correctly
when iPadOS gives the app a portrait, split, Stage Manager, or external
display window.

`EditorCommand` / `ViewportCommand` / `DrawingCommand` are inert command
values that describe future editor transactions such as scroll-to-page,
zoom reset, page selection, viewport-anchor preservation, and drawing
activation. They are not dispatched by the runtime yet. Their purpose is
to prepare PageMutationCoordinator and the zoomed add/delete fix so page
array mutation, viewport reconciliation, zoom reset, displayed-page
selection, and DrawingSessionManager activation can become one explicit,
ordered transaction instead of scattered view state changes.

`EditorViewportState` / `EditorOperationPhase` / `EditorEvent` are inert
state-machine vocabulary for the same migration. They record the editor rule
that structural operations require a normal viewport. If an operation is
requested while zoomed, the future transaction waits for a zoom-reset event
before applying the operation and restoring the viewport target. The current
runtime interprets these values for user-initiated zoom reset actions and for
Add Page. WritingScreen turns the top-bar reset button and viewport-local
finger double-tap reset requests into `EditorEvent.resetZoomRequested`; a
normal viewport completes as an idempotent no-op, and a zoomed viewport
dispatches the existing reset mechanism for the observed owner. Add Page is the
first structural operation routed through the same state machine: if the
viewport is normal it runs the legacy add-page body immediately; if zoomed, it
parks a pending Add Page, requests reset with `.beforeAddPage`, waits for reset
completion, then runs the unchanged add-page mutation/target/scroll restore
logic. Reset completion is consumed on the next `MainActor` turn so UIKit /
SwiftUI zoom callbacks never synchronously mutate the page array or editor
state from inside a view update. Delete Page does not consume the operation
state machine yet.
WritingScreen also has a read-only observation bridge into
`EditorViewportState`: Single Page maps from the existing `ZoomablePage` zoom
report mirrored in `PageZoomModel`, native Continuous `.stack` maps from the
outer stack zoom report, and legacy Continuous transform zoom maps from
`PageZoomModel` only when that legacy path is active. The native Continuous
`.perPage` prototype is not mapped as a structural-operation owner yet because
it does not expose a single reliable editor-level zoom owner signal.

`EditorMutationPhase` is the first narrow phase guard for those future
transactions. Its phases are idle, planning page mutation, applying page
mutation, restoring viewport, and activating drawing. WritingScreen uses it
as a non-authoritative trace around the add/delete-page legacy flows:
apply/reload pages, confirm target planning, then restore current index and
scroll target. In Continuous, the phase remains active until the existing
one-way scroll target is consumed, and Continuous page tracking ignores
mutation-time geometry/current-page reports so they cannot overwrite the
mutation target. The phase does not suppress zoom tracking or incidental
drawing activation yet.

`PageMutationCoordinator` is currently a pure planner. It models
target-page selection for add/delete page transactions and returns future
viewport, zoom, and drawing-activation commands those transactions will
use. WritingScreen now consults it only to confirm add/delete target
selection after the legacy page mutation and page reload have happened,
with fallbacks to the legacy append-to-end and delete-neighbor indexes if
the planner ever disagrees. `PageMutationPolicy` / `MutationZoomPolicy`
can describe an unused future zoom command, but WritingScreen must not
dispatch it directly from page mutation yet. Device testing showed that
mutation-time reset tokens leave per-page and Continuous native scroll-view
state inconsistent. The planner exists so the later zoomed add/delete fix can
move page mutation, viewport restoration, zoom reset, and activation as one
operation-state-machine transaction.

## Page surface layering

`PageSurface` is the editor's shared page rendering container. Its layer
order is: page background, future content objects, PencilKit drawing, then
future overlays / selection UI. Current behavior renders only the same
plain white page background plus the existing PencilKit drawing layer.
PencilKit is therefore an ink layer on the page, not the whole page model.

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
Swipe axis, stride extent, and page offsets derive from
`EditorLayoutContext.flowAxis`: vertical flow uses up/down swipes and
Y offsets; horizontal flow uses left/right swipes and X offsets. The
current default A4 portrait context resolves to vertical flow, so legacy
Single Page behavior stays unchanged. *Rejected:* rebuilding the page
view per turn (flicker); branching on preset names such as A4 landscape
or postcard.

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

### Structural operations and viewport state

The editor has two user-facing viewport states for transaction purposes:
**normal** (100%, stable content size/offset) and **zoomed** (owned by Single
Page, Continuous native stack, or the legacy Continuous transform path).
Zoomed state still allows zoom, pan, handwriting, explicit reset zoom, and
supported Continuous browsing/scrolling. It does not allow structural
document/page operations to execute immediately.

Structural operations include add page, delete page, future duplicate/reorder,
page size or orientation changes, page background/template/theme changes, and
first implementation foreground object/image insertion. These operations
require a normal viewport because they mutate the page array, page geometry,
scroll content size, or page surface layers underneath scroll/zoom owners.
Running them during or before a settled zoom reset corrupts navigation state.

Rule: when a structural operation is requested while zoomed, enqueue the
operation, request zoom reset first, wait for zoom-reset completion, then apply
the operation, recalculate affected layout/content-size state, restore its
viewport target, and return to idle. If the viewport is already at 100%, reset
is an idempotent no-op completion and the operation can proceed immediately.
This is an editor-level transaction rule, not an Add Page special case. Any
future operation whose behavior depends on page geometry, scroll bounds, active
canvas ownership, or page-surface composition must reuse this state-machine
path.

Reset zoom is therefore an editor command/event, not only a UI gesture. The
same command vocabulary must cover finger double-tap reset, toolbar reset,
add/delete preconditions, future template/object insertion preconditions,
tests, and recovery. Future implementations should route these through the
operation state machine instead of firing reset tokens during or after a page
mutation.

Current runtime bridge: WritingScreen can derive `currentEditorViewportState`
from existing zoom signals. The top-bar reset button and viewport-local
double-tap reset requests now route through `EditorEvent.resetZoomRequested`
before dispatching the existing reset token or PageZoom reset. This bridge
covers Single Page, legacy Continuous transform zoom, and native Continuous
`.stack`; the native `.perPage` prototype remains a comparison path without a
single editor-level zoom owner.

Add Page is the first structural operation routed through this rule in both
Single Page and native Continuous stack. In both modes, a zoomed Add Page is
planned as: observe zoomed viewport, park the pending operation, reset the
owning zoom viewport to normal, wait for reset completion on a safe main-actor
turn, run the existing page-creation mutation, refresh page/layout state, and
restore the target to the newly added page. Continuous additionally updates
the native stack content-height constraint so `UIScrollView.contentSize`
matches the new page count before the final scroll target is expected to be
reachable. Single Page additionally keeps only the current page hit-testable
and delays Pencil input for one short activation window after the new page is
selected so PencilKit/ToolPicker handoff settles before writing resumes.
Delete Page still uses its legacy direct handler, but it is a structural
operation and must move onto this same reset-before-operation path before its
zoomed behavior is considered complete.

*Rejected:* resetting Continuous native stack zoom from Add Page while also
mutating pages and restoring `scrollTarget`. Device testing made the page look
visually reset, but left internal `UIScrollView` content size/offset state
inconsistent and made the new page unreachable until mode switching. Single
Page also showed that per-page `ZoomablePage` state can remain zoomed on the
old page after Add Page. Reset-before-operation must be completed or treated as
already complete before any structural mutation begins.

### Single Page zoomed edit-menu arbitration

Single Page has two intentional finger-input states. At minimum zoom
(100%), PencilKit selection remains available, including its **Select All /
Insert Space** edit menu. Above minimum zoom, the page is navigation-first:
finger input belongs to native `UIScrollView` pan/pinch and the app's
double-tap reset, not to PencilKit selection.

PencilKit hosts this menu in its private `PKTiledView`, with tap triggers on
`PKSelectionGestureView`; it is not an `XmateCanvasView` responder-menu path.
`ZoomablePage` therefore arbitrates at those selection tap recognizers. Each
is made to require the app's finger double-tap reset recognizer to fail, so a
reset wins, and the selection taps are disabled while zoomed above minimum
then restored on return to minimum. The coordination is refreshed after
PencilKit relayout because its private selection subtree may be recreated.
Apple Pencil drawing recognizers are never touched.

This changes only Single Page edit-menu arbitration. Its native
`UIScrollView` zoom/pan is unchanged, and `ContinuousPagesView`, `PageZoom`,
and `PencilKitBridge` are outside the fix. The rejected approaches and device
evidence are recorded in `docs/lifecycle.md`.

### Continuous native zoom/pan migration

Continuous currently zooms by applying SwiftUI `scaleEffect` / `offset` to
the complete page stack, driven by `PageZoomModel`. Because every finger-pan
frame publishes `panOffset`, SwiftUI re-evaluates the enclosing screen and
transforms the live multi-page hierarchy, including its persistent
`PKCanvasView`s. This is a structural performance problem; tuning the pan math
does not remove the high-frequency SwiftUI path.

The candidate design uses the outer native `UIScrollView` as zoom owner for
the persistent Continuous stack, so every page fragment and gap visible in the
viewport scales together without per-frame SwiftUI state. A later increment
will bound each zoom session to the page group visible when the pinch begins;
whole-document free zoom is not the product model. Keep this as a sibling path
behind a feature flag until device acceptance.

The native stack controller owns an explicit height constraint for the hosted
SwiftUI page stack: top/bottom padding, page count, page height, and inter-page
gaps determine `UIScrollView.contentSize`. Do not rely only on
`UIHostingController` intrinsic-size invalidation after page mutation; device
testing showed Add Page could update the SwiftUI page array and top-bar count
while the scroll view still clamped programmatic scroll to the old content
height. Native stack zoom-display reports are also deferred to the next main
queue turn before they update `WritingScreen` state; `UIScrollViewDelegate`
zoom callbacks can occur during representable update/layout, and synchronously
publishing SwiftUI state from that path produces undefined-behavior warnings.
Single Page uses the same rule for its per-page zoom scroll views. A shared
reset token reaches every hosted page, but only the page that actually performs
a zoom reset reports completion; fit-state pages do not claim completion for a
structural-operation precondition they did not satisfy.
Single Page still keeps every page canvas mounted to avoid page-turn flicker,
but DrawingSessionManager visibility is narrower than SwiftUI lifetime: only
the current page index is registered as visible for ToolPicker/active-canvas
handoff. Off-screen pages remain warm but cannot become the ToolPicker anchor.
Pencil hit testing is a separate readiness gate: after a Single Page
index/page-list change, hit testing is held closed for one short activation
window, then the current page is re-declared desired active. This keeps
ToolPicker ownership continuous during page turns while still preventing a
very fast first stroke after zoomed Add Page from landing before the new
page's handoff has stabilized.
Returning to a warm page still re-promotes its canvas if it is not the
current ToolPicker anchor, even when that page already has the same
authoritative canvas in `activeByPage`; otherwise backward paging falls
through to first-responder recovery and creates a visible picker gap.

*Rejected as the final Continuous design:* persistent inner zoom scroll views
per page. Device testing proved that path smooth, but when the viewport showed
two half-pages it enlarged only one half and left the other inert. It remains
available only as an A/B comparison prototype. Single Page is the stable
reference and is not part of this migration; do not modify it or generalize
`ZoomablePage` yet. Diagnosis is in `docs/lifecycle.md`; rollout order is in
`roadmap.md` (F-059).

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
