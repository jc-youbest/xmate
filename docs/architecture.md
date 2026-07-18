# Architecture

Global architecture of the xmate iOS app. Module-level detail lives in
each module's README next to its code (`ios/xmate/xmate/<Module>/README.md`).

## Layering

    App → Editor ─────────→ Storage
    App → Library → Mailbox → Storage
    App → Social
    App → Mailbox

    Shared: small cross-module types

- **App** (`App/`) — entry layer: `@main`, RootView (composition root),
  global settings, and cross-component flow coordination. Depends on
  modules; no module ever imports from it.
- **Editor** (`Editor/`) — Content Screen: pagination, zoom, the
  PencilKit writing stack. Edits exactly the document it is given.
- **Mailbox** (`Mailbox/`, introduced by F-062) — letter/mailbox data
  component: owns envelope lifecycle, the four system mailbox locations,
  local cache resolution, and the future local/remote repository boundary. It
  has no UI and never opens Editor.
- **Storage** (`Storage/`) — Core Data implementation for raw envelope metadata
  and Document/Page content persistence, migrations, and atomic local
  operations. Knows nothing about UI, navigation, or remote transport.
- **Library** (`Library/`) — placeholder; personal collection and mailbox
  list/sidebar UI lands in v3. Consumes Mailbox outputs and emits selection
  intents; it does not open Editor.
- **Social** (`Social/`) — the current structural Social Screen shell; future
  send form, pen-pal, and delivery behavior. It emits typed intents and does
  not embed or call Editor.
- **Shared** (`Shared/`) — truly cross-module small types only
  (currently `PaginationStyle`, `Comparable.clamped`). Not a junk drawer.

Dependency arrows remain one-way: Editor uses Storage for authoritative page
and drawing persistence; Mailbox uses Storage for local records; Library uses
Mailbox for mailbox presentation data; App composes all components and invokes
Mailbox resolution for cross-component flows. Editor never imports Mailbox or
Library. Envelope/domain types stay with Mailbox and its persistence boundary,
not Shared merely because several components exchange stable ids.

## Xcode project

| Setting | Value |
|---|---|
| Project name | `xmate` |
| Bundle Identifier | `com.cwc.xmate` |
| Deployment target | iPadOS 18.0 |
| Device family | iPad only |
| Window presentation | Full-screen only (`UIRequiresFullScreen`) |
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

- v1: `RootView` supplies the hard-coded development-document request/resolver;
  `AppFlowCoordinator` invokes it through
  `NoteStore.loadOrCreateDocument(named:)` and coordinates the resulting open.
  DEBUG builds can opt into a separate named dev document for one preset
  via `DevDocumentPagePresetProbe`; this exercises the same persisted
  document PageSpec path without adding user-facing preset UI or mutating
  the default A4 portrait dev document.
- Future sources — inbox (social), drafts/list (Library), new creation —
  all resolve a `Document` outside the editor and inject it the same way.
  The App flow coordinator owns that resolution/open pipeline; a source
  component reports a stable record id and never constructs Editor directly.

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

Current persisted model: Core Data model version `xmate 3.xcdatamodel`
inherits the v2 `Document.pagePresetID`, `Document.logicalPageWidth`, and
`Document.logicalPageHeight` fields and adds the mailbox persistence described
under Document envelope boundary. `Page` still stores only `id`,
`drawingData`, `version`, and its inverse `document` relationship. Flow
axis is not persisted; it is reconstructed from the resolved page spec and
layout policy. Legacy v1 documents may have nil or zero page-spec fields,
so `Document.resolvedPageSpec` computes a safe A4 portrait fallback without
rewriting drawing blobs or treating migration normalization as a document
edit. New documents persist the A4 portrait preset id and dimensions once
at creation. `NoteStore` also exposes a typed preset creation path for the
App layer; the preset is applied only when creating a new named document,
while existing documents keep their persisted page spec.

Opening a document is stricter than resolving a fallback. Storage may still
compute safe fallback values for old or partial records, but the App layer must
validate the raw persisted document preset before the editor is created. The
current open policy accepts only `a4-portrait`, `a4-landscape`, and
`postcard-landscape`; catalogue entries that are not in that allow-list remain
data-only until their editor behavior is intentionally enabled. A valid open
also requires the stored logical width/height to match the selected preset.
Once validation passes, `Document.pagePresetID` is the preset source for
editor layout and for the App-layer window orientation policy. DEBUG creation
probes may choose which persisted dev document to create, but they are not a
runtime layout source after the document has loaded.

Future ownership decision: page specification belongs to the `Document`,
not each `Page` and not `SettingsStore`. xmate documents are ordered
stationery sheets of one paper kind; a mid-document paper change would
make page-turning, generation, sharing, and print/export semantics
ambiguous. `SettingsStore` may own the global presentation preference
(`singlePage` / `continuous`) but not document paper semantics.
`LayoutPolicy` combines the document's page spec with presentation style
and runtime environment, and `EditorLayoutContext` is the value SwiftUI
views consume.

The v1→v2 page-spec migration stores these document-level fields only:
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

## Component orientation and adaptive layout contract

Every UI component owns the adaptive layout of its own content, but App owns
the active window-orientation policy. The App flow coordinator knows which
policy belongs to the active component, applies it when that component becomes
active, and replaces it when navigation activates another component. A
component never changes the policy of a sibling or makes an independent window
orientation request.

There are two component policy categories:

- **System-responsive** — the component accepts the portrait or landscape
  arrangement supplied by iPadOS, normally following how the user holds the
  iPad. Library, Social, a standalone Send Form, and other ordinary top-level
  UI use this policy. Each component decides how its own controls and content
  adapt in each actual viewport.
- **Document-directed** — Editor is the deliberate exception. After App has
  validated the Document, the coordinator derives the supported/preferred
  interface orientation from its persisted page preset. A full-screen Editor
  presentation applies that policy and physical iPad rotation must not move it
  away from the document orientation. An Editor Workspace with a visible
  mailbox sidebar instead keeps its last committed window policy even when the
  selected Document changes; the commit timing is defined below.

These policies govern the window request, not component layout algorithms.
Every component still lays itself out within the actual region it receives.
xmate now requires full-screen iPad presentation and opts out of external Split
View / Stage Manager resizing so Editor's document-directed policy can be
enforced. Internal workspace composition still changes child viewports: a
mailbox sidebar can reduce Editor's width even though the App window remains
full-screen. The Document remains the semantic source for page layout, while
workspace presentation state determines when its orientation becomes the App
window policy.

The app target currently generates its Info.plist from build settings.
For iPad (`TARGETED_DEVICE_FAMILY = 2`), both Debug and Release declare
portrait and landscape interface orientations. The iPhone orientation keys
are irrelevant because the target is iPad-only. There is no `UIDevice`
orientation forcing. Both configurations set `UIRequiresFullScreen = true`;
this is an intentional product tradeoff: xmate gives up external iPad
multitasking windows in exchange for a stable paper-aligned Writing Mode.

`AppFlowCoordinator` now assigns every resolved route a
`ComponentWindowLayoutPolicy`. `.systemResponsive` supports all declared iPad
interface orientations; `.documentDirected` carries an
`EditorWindowOrientationPolicy` derived from the validated Document preset.
The coordinator applies the active policy to `AppWindowLayoutPolicyStore`,
which is the source used by
`UIApplicationDelegate.application(_:supportedInterfaceOrientationsFor:)`.
`WindowOrientationPolicyBridge` then calls `UIWindowScene.requestGeometryUpdate`
for the current scene as a best-effort request. The runtime exercises both
categories: Editor is document-directed, while the standalone Social Screen is
system-responsive. Returning to Editor reapplies its stored route policy.

This keeps the editor's document model clean: `PageSpec` remains paper
semantics, while App owns the supported/preferred window orientation. The
geometry request and supported-orientation callback work together in the
full-screen scene; views still adapt to their actual assigned viewport because
internal workspace accessories can resize them.

Before injecting a document into `WritingScreen`, `AppFlowCoordinator` runs
`DocumentOpenValidator`. Open-time document failures are App-layer errors
with stable codes, not editor states. `XMATE-DOC-0001` means invalid
document orientation; `XMATE-DOC-0002` means invalid document preset;
`XMATE-DOC-0003` means the stored logical page size does not match the
document preset. The current validator treats square page orientation as
invalid. On validation failure, the coordinator publishes failed state;
RootView presents the error and does not load the editor or install the
window-orientation bridge.

Page orientation and window orientation are different contracts. Page
orientation is stable document content semantics. Window orientation is
the current container supplied by iPadOS: full-screen, Split View, Stage
Manager, resizable windows, and future external displays can all provide
viewports whose aspect ratio does not match the document's paper. The
editor must therefore always adapt layout to the actual viewport size.
When Editor is active, App requests a supported/preferred interface orientation
matching the document's page orientation and maintains that route policy so
physical device rotation does not choose the opposite Editor orientation in
full-screen use. That window policy cannot replace responsive layout when
iPadOS supplies a constrained viewport.

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

The orientation bridge is intentionally centralized at the App layer.
Document page orientation may influence the preferred window orientation,
but WritingTopBar, page presentation views, zoom views, and PencilKit
canvases must not make independent interface-orientation requests. They
all consume the same `EditorLayoutContext` and the same SwiftUI viewport
supplied by the window. This prevents conflicting states such as a
landscape canvas inside portrait chrome, or a horizontal page flow inside
an independently portrait top bar. Page-specific components may adapt
their layout from abstract values such as `PageFlowAxis`, presentation
style, page size, and viewport dimensions, but the app/window orientation
policy has one owner: `AppFlowCoordinator` through the active route's component
policy and the App-layer window policy bridge.

Landscape support was able to reuse the existing portrait editor behavior
because the core responsibilities are separated. `PageSpec` and
`PageSize` describe paper identity; `LayoutPolicy` resolves presentation
style and flow axis; `EditorLayoutContext` passes that resolved value
through the view hierarchy; `PageGeometry` bridges the new model into the
older runtime layout path; and `EditorOperationStateMachine` sequences
operations such as reset-before-add-page independently of page shape or
flow direction. As a result, landscape Single Page and Continuous flows
reuse the same PencilKit canvas ownership, zoom/pan behavior, double-tap
reset, ToolPicker handling, and add-page transaction ordering that were
stabilized for A4 portrait. New page presets should therefore enter the
system as data and policy inputs, not as preset-name branches in layout
consumers.

There are three separate orientation concepts:

- Page orientation: stable document semantics derived from the page spec,
  such as A4 portrait or A4 landscape.
- Window/app orientation: the current interface orientation of the iPadOS
  window that contains the editor.
- Device orientation: how the user is physically holding the iPad.

The active component policy requests the allowed window orientations, and
iPadOS remains the final window authority. Requiring full screen removes the
known multitasking mode that rejected Editor's request during device testing.
A system-responsive component follows the resulting system orientation. Editor
keeps the Document page orientation as its paper and preferred-flow source
while using its assigned viewport to size and place WritingTopBar, pages, zoom
surfaces, and canvas content.

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

### App component coordination

App owns a small state-driven flow coordinator for transitions between full UI
components. `AppFlowCoordinator` exposes typed Editor and Social routes plus
resolving/ready/failed flow state. `RootView` renders that state and supplies
the current source-specific named development-document resolver; it does not
perform validation, policy derivation, or destination selection itself.

The current typed document-open source is the stable development-document
name. The resolved Core Data Document is held beside the route in
`ResolvedAppDestination`, never inside the route value. Future Library/Social
sources add stable document or envelope ids to the same request vocabulary.
Those components will expose typed output intents, and App will map the intents
to routes. No component imports App or constructs/calls a sibling component.

Each route also declares its component window-layout policy. App knows whether
the active component is system-responsive or document-directed and applies the
matching supported/preferred interface orientations for only that route.
Ordinary components follow iPadOS/device orientation and own their internal
portrait/landscape adaptation. Editor uses the validated Document preset as its
route policy and is not redirected by physical device rotation in full-screen
use. In both categories, the component remains responsible for laying out its
own UI in the actual viewport; it cannot affect a sibling's layout. The full
contract and iPadOS fallback are defined in Component orientation and adaptive
layout contract above.

Window policy belongs to the outermost active workspace, not every visible
child. A mailbox sidebar or floating Send Form presented inside Editor
Workspace inherits the workspace's document-directed policy. The same Send
Form presented later as a standalone route is system-responsive. Presentation
context, rather than feature name alone, determines whether a UI changes the
active window policy.

Routes carry stable record ids and source context, not Core Data managed
objects. Opening a document always follows one App-owned pipeline: resolve the
record through Storage, validate the raw persisted document with
`DocumentOpenValidator`, derive/apply the editor window-orientation policy, and
only then present `WritingScreen`. Failure stops before Editor construction and
uses the existing App-layer open error. Back/return behavior is the inverse
route transition owned by App, not an Editor or Library side effect.

Mailbox selection now enters that boundary through
`AppFlowCoordinator.selectMailboxEnvelope`. It is accepted only while an Editor
destination is current and receives source-specific resolver closures from the
composition root rather than constructing Storage or Mailbox dependencies
inside the coordinator. App requires a repository cache hit, re-fetches the
Document by the verified UUID, rechecks its revision, and runs the same open
validator before publishing a mailbox-envelope Editor route. Missing envelopes,
repository failures, missing/stale/invalid cache results, a changed cache entry,
or document validation failures return typed rejections and leave the current
Editor destination unchanged. Selection within the mailbox workspace preserves
the current route's window policy and does not issue a geometry update; closing
the future sidebar is the separate commit point for the selected Document's
orientation policy.

Leaving Editor for Social uses an Editor-owned handoff before App changes
route. WritingScreen rejects the request while a page mutation or structural
operation is pending, synchronously flushes every authoritative drawing
canvas, then emits `.showSocial`. App stores the resolved Editor destination
as the inverse transition, applies Social's system-responsive policy, and
presents the Social shell. Social emits `.returnToEditor`; App restores the
same resolved Document and reapplies its document-directed policy. Normal
SwiftUI teardown still unregisters the old canvases, and returning constructs
fresh views from the already-flushed canonical drawings. App does not interpret
`EditorCommand`, viewport commands, zoom ownership, page mutation phases, or
PencilKit state; those remain Editor-internal transaction mechanisms despite
the coordinator terminology.

Initial source resolution runs once. Invalid documents reach the existing
failed UI/alert without resolving or applying an Editor policy; valid documents
apply their document-directed policy before publication. The Editor/Social
pair deliberately uses an explicit inverse transition rather than introducing
a general navigation stack for two surfaces. Social is only a structural shell;
it neither queries mailbox data nor creates envelope records. Deep links,
multi-window restoration, arbitrary route history, and a general navigation
framework remain out of scope. *Rejected:* ad hoc component-to-component calls;
managed objects stored in route values; an App coordinator that owns Editor
interaction state; building a generic stack before a third route needs it.

### Document envelope boundary

Letter metadata and letter content are separate persisted records joined by a
stable UUID. `LetterEnvelope` is the lightweight header/index record used to
rebuild and display a mailbox without loading handwriting. `Document` is the
content payload: ordered pages, paper semantics, stationery, and handwriting.
Neither record embeds the other and the local Core Data model must not use a
required object relationship between them. The durable association is
`LetterEnvelope.documentID == Document.id`.

Both ids are client-generated permanent UUIDs, created before any future
network request and reused unchanged by the backend. They are never recycled.
This lets an offline draft acquire its final identity at creation and avoids a
second server-specific id namespace. Do not add `remoteID` unless a concrete
backend constraint later proves that a second identifier is necessary.

The envelope header contains the fields required to render, organize, and
resolve a letter without its Document payload:

```text
LetterEnvelope
├── id
├── documentID
├── title
├── senderID?                // optional for incomplete drafts
├── recipientID?             // optional for incomplete drafts
├── mailboxLocation
├── deliveryState
├── documentRevision
├── createdAt
├── updatedAt
├── sentAt?
└── receivedAt?
```

Optional values are still first-class schema fields; an incomplete draft has
the full envelope shape with nil participant/delivery timestamps rather than a
different record format. `documentRevision` is the server-authoritative
content version used later to distinguish a valid local cache hit from a stale
Document with the same UUID. A monotonic revision or equivalent opaque version
is preferred over comparing device timestamps. The current local-only
increment may initialize a local revision without implementing server conflict
or synchronization behavior.

There are exactly four initial **system mailbox locations**: `inbox`, `draft`,
`outbox`, and `sent`. They are fixed typed values, not user-created Folder
records and not four separate stores or entities. Storage keeps one envelope
record per `id`; Library forms each list by querying `mailboxLocation`. Moving
a letter from Drafts to Outbox updates that same envelope atomically and never
copies it into a list-specific record. Trash, Archive, Spam, custom folders,
rules, labels, and folder hierarchies are not part of this model. If custom
organization is later justified, it gets a separate Folder/membership design
without changing the meaning of `mailboxLocation`.

Mailbox location and delivery state remain orthogonal. Location answers where
the current user's header is listed; delivery state answers what has happened
to outgoing transport. F-062 uses only `notSubmitted`, `queued`, and `unknown`:
the last value represents restored or deterministic history whose transport
outcome the local build did not observe. The local Send action may change an
eligible draft to `outbox` plus `queued`, but it must not move it to `sent` or
claim remote success. Do not pre-build sending, retry, delivered, or failure
state machines for F-062. Deterministic Inbox/Sent development records are seed
history, not evidence produced by the local Send action.

A locally created draft is one atomic Storage operation: create its envelope,
its Document, and the Document's first Page together. The objects are stored
separately but the operation must not publish an envelope whose initial local
Document failed to save. Drafts may keep sender or recipient nil. Queueing a
draft first flushes authoritative drawing state and freezes the existing
Document revision; it does not create a snapshot or a second Document. A later
explicit Duplicate feature may create a new envelope/document pair with new
UUIDs.

Local persistence is two logical caches:

```text
Envelope metadata cache                 Document content cache
───────────────────────                 ──────────────────────
envelope id                             document id
document id ──────────────────────────> pages / drawings
mailbox location                        cached revision
header metadata                         cache metadata
document revision
```

The caches have independent availability and retention. A restored envelope
may exist while its Document is absent locally; this is a cache miss, not an
invalid envelope. Selecting an envelope follows one App-owned resolution
pipeline: load envelope by id, look up Document by `documentID`, require the
cached revision to match, and only then validate and inject the Document into
Editor. In the future, a missing or stale Document causes a backend fetch by
`documentID`, followed by local persistence and the same validation pipeline.
Fetch, persistence, or validation failure must leave the currently valid
Editor Document unchanged. F-062 implements the local repository boundary and
cache lookup only—no authentication, server request, sync, or network fallback.

Deleting a local envelope removes the current user's local header. Its
Document is cache data, not relationship-owned content: Storage may explicitly
evict the corresponding local Document when no local envelope references it,
but Core Data cascade ownership must not encode a future global deletion. On a
backend, one user deleting a Sent entry must not delete the recipient's Inbox
entry or the shared payload. Server retention and final payload garbage
collection are separate future policies.

After authentication and sync exist, reinstall/new-device recovery is
metadata-first. The client fetches a mailbox manifest, recreates the four
lists from envelope headers, and leaves Document payloads uncached until the
user opens them. A manifest alone cannot recover handwriting that was never
uploaded: cross-device Draft recovery therefore requires future Draft content
sync, and the current local-only build makes no uninstall-recovery guarantee.

The future backend should not store one global `mailboxLocation` directly on a
shared envelope. Location belongs to a user-envelope membership because the
same delivered letter can be `sent` for its sender and `inbox` for its
recipient:

```text
Envelope        envelope UUID, document UUID, header, delivery metadata
MailboxEntry    user UUID, envelope UUID, mailbox location
DocumentPayload document UUID, revision, document content
```

The server mailbox-manifest response is the join of `MailboxEntry` and
Envelope header data; it omits `DocumentPayload`. Full snapshots can rebuild a
fresh device, while revisions/tombstones for efficient incremental sync are a
future backend concern. The local single-user cache may keep
`mailboxLocation` directly on `LetterEnvelope` because it is a projection of
only the active user's mailbox.

Storage owns the Core Data schema, migrations, raw envelope/document records,
and atomic persistence primitives. Mailbox owns the semantic operations built
on those primitives: UUID association, atomic draft creation, mailbox queries,
cache validity/eviction policy, local transitions, and the future remote
repository boundary. Library owns list/sidebar presentation and emits stable
envelope ids. Social owns recipient/send eligibility and the Send Form. App
owns envelope selection, Document resolution/validation, Editor injection,
and transition ordering. Editor edits only the resolved Document. Envelope
domain vocabulary belongs to Mailbox rather than Shared; Storage-facing record
representations must not create a dependency cycle back into Mailbox.

Legacy Documents are preserved in place. The schema migration creates one
Draft envelope header for every existing Document id, copies the existing
title into the envelope header, initializes local revision metadata, and does
not rewrite Page order, drawing blobs, or drawing versions. After migration,
public creation APIs must create an envelope/document pair rather than a new
orphan Document.

The current local implementation is Core Data model version
`xmate 3.xcdatamodel`. It adds independent `LetterEnvelopeRecord` records and
`Document.contentRevision`; there is deliberately no Core Data relationship
between them. Storage uses automatic inferred lightweight migration from v2,
then runs an idempotent post-load backfill that creates a Draft / `notSubmitted`
envelope only for a Document UUID not already represented. New local drafts
save the envelope, Document, and first Page in one view-context transaction.
Every accepted structural or drawing-content write increments
`Document.contentRevision` and copies that value and the same `updatedAt` into
the matching envelope in the same context save. Rejected stale drawing writes
do not advance either revision. The migration path is covered with an actual
v2 SQLite fixture so page order, drawing bytes, drawing versions, paper fields,
and timestamps are checked after opening through the v3 store.

During the current pre-release development phase, installed Document data is
disposable. The implemented v2→v3 migration remains useful regression coverage,
but future schema increments are not required to preserve an older development
installation: deleting and reinstalling the app is an accepted test reset.
Do not let speculative backward compatibility block the active model design;
explicit production migration guarantees begin only when the project declares
that user data must be retained.

*Rejected:* sender/recipient/mailbox fields on Document; a required Core Data
Envelope→Document relationship that cannot represent an uncached payload; one
overloaded status combining mailbox and transport; four physical mailbox
tables; list-specific envelope copies; dynamic Folder entities for the four
system locations; eagerly downloading every Document during mailbox restore;
deleting a shared backend payload as a side effect of one user's mailbox
deletion; separate client and server UUIDs without a demonstrated need; and an
email-complete model with archive/trash/spam/rules/threading before xmate needs
those features.

### Mailbox component coordination

Mailbox is a non-UI data component between presentation/coordinator modules
and Storage. It exists so envelope organization, local cache behavior, and
future server interaction do not leak into Editor, Library views, App routes,
or raw Core Data APIs. Its public surface returns stable value snapshots and
typed results rather than exposing navigation side effects or requiring a
caller to hold managed objects across asynchronous work.

Mailbox owns:

- `LetterEnvelope` domain/header values and stable envelope/document ids;
- the fixed Inbox/Drafts/Outbox/Sent query vocabulary;
- envelope lifecycle and legal local transitions;
- local envelope-manifest and Document-cache coordination;
- cache hit, miss, stale-revision, eviction, and resolution policy;
- the future remote manifest and Document-payload source boundary.

Mailbox does not own SwiftUI, Editor canvas state, App navigation, window
orientation, Send Form presentation, PencilKit drawing handoffs, or Core Data
migration mechanics. Storage remains the local persistence implementation.
No remote implementation is created in F-062; the boundary is introduced only
where current local behavior requires it.

Library owns the mailbox sidebar UI. It asks Mailbox for presentation-ready
envelope summaries, displays the four system locations, and emits typed intents
such as `selectMailbox`, `selectEnvelope(envelopeID:)`, and `closeSidebar`.
Library does not fetch a Document, construct Editor, or change the workspace.
The UI may label the four locations as folders, but no Folder domain entity is
implied.

Editor remains mailbox-blind. A WritingTopBar control may produce Editor output
such as `showMailbox` or `showSendForm`; Editor never queries Envelope records,
imports Library, calls Mailbox, or downloads content. It continues to edit only
the validated Document App injects and to own its drawing/viewport lifecycle.

App is the sole cross-component coordinator. The first visible sidebar keeps
Editor mounted but suspends its hit testing for the entire browsing session.
Opening is accepted only while Editor has no mutation or structural operation
in progress and its viewport is at the normal 100% state; Editor then
synchronously flushes every authoritative drawing before emitting
`showMailbox`. The sidebar-selection flow is therefore:

```text
Library emits selectEnvelope(envelopeID)
→ App asks Mailbox to resolve the envelope's Document
→ Mailbox checks documentID and cached revision through Storage
→ local hit authorizes the Storage adapter to return the cached Document
→ future miss/stale result may hydrate through a remote source, then persist
→ App validates the resolved Document
→ App replaces the Editor selection only after successful validation
```

The future remote step is inert in the local build. A local miss is a typed
resolution failure, not a fabricated blank Document. Any flush, resolution,
persistence, or validation failure leaves the current valid Editor Document in
place. While the mailbox sidebar is visible, a successful selection updates
Editor content without committing a new App window orientation, as defined in
Editor Workspace accessories below.

The current `LocalMailboxRepository` is a main-actor facade over Storage's
view-context APIs. It queries the single envelope store by typed
`MailboxLocation`, decodes raw records into immutable `LetterEnvelope` values,
and rejects missing, negative, or unknown persisted values at that boundary.
Resolving an envelope id joins only by UUID and compares the envelope revision
with a `CachedDocumentDescriptor`; it returns typed hit, missing, or stale
metadata and never exposes a managed object. App may request the actual
Document from Storage only after a hit, then performs its existing open
validation before injection. An unknown envelope id returns no result, while a
missing Document remains a valid metadata-only cache miss. This local facade
does not seed data, mutate delivery state, fetch remotely, or fabricate
content.

Social owns Send Form UI and eligibility rules, then emits a typed save/queue
intent. App invokes the matching Mailbox operation after completing the Editor
drawing handoff. Social does not mutate Storage or call Mailbox directly, and
Mailbox does not present Social UI. This preserves App as the integration
point rather than turning the data component into a sibling-component
coordinator.

*Rejected:* putting envelope/folder/cache/network behavior in Editor; letting
the Library sidebar open or mutate Editor directly; putting SwiftUI sidebar UI
inside Mailbox; making Storage coordinate server requests; direct
Social→Mailbox delivery mutations; and a generic backend component whose scope
extends beyond letter/mailbox data.

### Writing top-bar coordination

`WritingTopBar` remains a small Editor-owned presentation view. Its evolution
path is strongly typed render state plus strongly typed actions, interpreted by
`WritingScreen`; it does not become an editor or app coordinator. Editor-local
actions such as zoom reset, page mutation, pagination preference, and future
template/theme/style panels stay inside Editor. Actions that leave the Content
Screen are converted by Editor into typed output intents for App.

Editor owns one optional panel/popup selection rather than a Boolean per
popover. Small document-editing panels remain local; Send Form and other full
components are App routes. Any template/theme/style choice that changes page
geometry or page-surface composition must enter the existing structural
operation state machine and honor reset-before-operation.

Toolbar layout adapts from the actual available viewport width, including
Split View and Stage Manager, rather than device orientation, size class alone,
or paper preset name. Essential navigation/status/actions remain visible;
secondary actions move into overflow as width contracts. The existing custom
top-bar/canvas boundary and hit-testing behavior remain intact. A generic
`AnyView`/array-driven toolbar framework and placeholder future panels are
deferred until real controls demonstrate the need. *Rejected:* direct sibling
navigation from the top bar; top-bar ownership of panel or editor transaction
state; layout branches based on preset names or physical device orientation.

### Full-screen document-directed orientation

Device testing of the first AppFlowCoordinator increment opened a validated A4
landscape Document with a landscape Editor layout, then rotated the physical
iPad to portrait. Because the target supported multitasking and did not require
full screen, `requestGeometryUpdate` failed with "The current windowing mode
does not allow for programmatic changes to interface orientation." iPadOS
rotated the App UI to portrait while the paper correctly remained landscape,
leaving an unacceptably small writing surface.

xmate therefore requires full-screen iPad presentation in both Debug and
Release. This is an App-wide capability, intentionally trading external Split
View / Stage Manager support for a stable document-directed Editor. Ordinary
components remain system-responsive within the full-screen App and may rotate
with the user; Editor restricts the active supported orientations to the
validated Document orientation. `requestGeometryUpdate` remains the immediate
rotation request, while the application-delegate mask maintains the route
policy after physical device rotation.

Internal multi-pane UI is unaffected: it is composed inside the one full-screen
App window. *Rejected:* accepting a portrait Editor window for landscape paper
and merely fitting a small page; relying on a best-effort geometry request while
remaining in a multitasking window mode. An orientation gate remains a possible
future recovery path if a later platform/window configuration can still refuse
the full-screen request, but it is not part of this increment.

### Editor Workspace accessories

App now composes `EditorWorkspace` as stable sibling positions: a leading
Library `MailboxSidebarView`, a divider, and the current `WritingScreen`.
Opening or closing changes assigned width without replacing the workspace or
animating the structural resize. The sidebar shows Inbox, Drafts, Outbox, and
Sent and emits stable Envelope ids; it never overlays the writing surface. A
future floating Send Form may appear above Editor, giving the user continuity
with the current Document while temporarily suspending writing interaction.
Neither accessory is an independent `UIWindowScene` or a replacement top-level
surface.

App owns workspace composition and accessory presentation state. Library or
Social supplies the sidebar/form UI and emits typed intents. Editor receives
only its assigned viewport and typed lifecycle requests; no sibling module
calls another. The outer Editor Workspace keeps the Document-directed window
policy most recently committed for full-screen Editor. A standalone Library,
Social, or Send Form route instead uses a system-responsive policy.

`AppFlowCoordinator.editorWorkspaceAccessory` represents the optional mailbox
sidebar. The visible top-bar control emits Editor's typed `showMailbox` output,
which can open it only from an Editor destination; Library's typed
`closeSidebar` output can close it only while that accessory is active. Opening
does not change route or window policy. Envelope selection is rejected unless
this sidebar state is active. Closing recomputes the selected Document's
document-directed policy, applies it before publishing the full-screen Editor
destination, and then clears the accessory. Social transition requests are
ignored while the mailbox is open so the coordinator never stores an ambiguous
Editor return policy.

While the mailbox sidebar is visible, selecting Documents from Inbox, Drafts,
Outbox, or Sent must not repeatedly rotate the App. App resolves and validates
each selection before injecting it into Editor, but selection updates only the
workspace's current Document and Editor page layout. It does not replace
`AppWindowLayoutPolicyStore` or issue a scene geometry request. The selected
Document may therefore have a portrait page inside a landscape App UI, or the
reverse; this temporary mismatch is intentional. Editor fits the fixed page
into its reduced assigned viewport and never treats window orientation as a
substitute for the Document's own PageSpec.

The latest selected Document orientation becomes eligible for the window only
when Editor is requested as the full-screen workspace. This includes initial
full-screen opening, replacing the Document while already in a full-screen
Editor flow, and dismissing the mailbox sidebar back to full-screen Editor.
The request may originate from an external App-coordinated flow or from an
Editor control, but Editor only emits a typed full-screen intent; App remains
the sole owner that validates the latest selected Document, transitions the
workspace presentation state, derives the document-directed policy, and
applies it. The policy is derived at commit time from the latest validated
selection, not cached from the Document that originally opened the workspace.
This creates an explicit distinction between **selected Document orientation**
and **committed window orientation** and prevents orientation thrashing during
mailbox browsing.

For this first implementation, mailbox browsing is explicitly non-writing.
Before contraction, WritingScreen requires idle mutation/operation state and a
normal viewport, then flushes authoritative drawings. Editor remains mounted
but its hit testing stays disabled until dismissal, so no drawing or viewport
state can change behind the sidebar. A successful selection replaces the
validated destination and deliberately gives the newly selected Core Data
Document a fresh WritingScreen identity; failed resolution leaves the current
Editor untouched. The leading width is capped at 320 points and yields before
the Editor would fall below 500 points (268/500 on the supported 768-point iPad
width). Expansion reenables Editor interaction after App commits the latest
selected Document's orientation policy. Supporting active writing while the
sidebar is open would require the richer ordered viewport/canvas/ToolPicker
resize transaction described by the rejected alternatives below; it is not an
implicit extension of this safe browsing mode.

A floating Send Form keeps Editor mounted but blocks underlying canvas hit
testing, performs any required drawing flush/suspension before presentation,
and restores the authoritative canvas/ToolPicker handoff when dismissed. Its
exact suspension events remain deferred. *Rejected:* treating sidebar contents
as direct Editor children;
allowing Pencil input through a floating panel; shrinking the Editor below a
useful writing size merely to preserve a side-by-side layout; applying every
sidebar selection's Document orientation immediately and rotating the entire
workspace while the user browses.

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

Continuous page flow is axis-aware through `EditorLayoutContext.flowAxis`.
Vertical flow stacks pages top-to-bottom and tracks the viewport center along
Y; horizontal flow stacks pages left-to-right and tracks along X. The runtime
does not branch on preset names such as A4 landscape or postcard landscape.
Both the legacy SwiftUI Continuous path and the native Continuous stack path
derive their scroll axis from the resolved layout context, so A4 portrait keeps
the same vertical behavior while landscape presets can move through the same
layout policy path as Single Page.

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

The native stack controller owns an explicit primary-axis content-length
constraint for the hosted SwiftUI page stack. In vertical flow, the host width
matches the viewport and the explicit length is height; in horizontal flow,
the host height matches the viewport and the explicit length is width. Padding,
page count, scaled page primary extent, and inter-page gaps determine
`UIScrollView.contentSize`. Do not rely only on `UIHostingController`
intrinsic-size invalidation after page mutation; device testing showed Add Page
could update the SwiftUI page array and top-bar count while the scroll view
still clamped programmatic scroll to the old content length. Native stack
zoom-display reports are also deferred to the next main queue turn before they
update `WritingScreen` state; `UIScrollViewDelegate` zoom callbacks can occur
during representable update/layout, and synchronously publishing SwiftUI state
from that path produces undefined-behavior warnings.
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
