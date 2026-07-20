# Editor — Content Screen (document viewing & writing)

## Responsibilities

- Screen/: WritingScreen, the Writing-Mode variant of the Content Screen,
  plus WritingTopBar.
- Screen/: future typed toolbar render state/actions and Editor-owned local
  panel presentation. Cross-component output is emitted to App; the flow and
  toolbar contracts are in `docs/architecture.md`.
- Viewport/: both Pagination Styles: SinglePagesView (persistent offset carousel,
  flips animate offsets only — zero canvas recreation) and
  ContinuousPagesView / ContinuousNativePagesView.
- Viewport/: whole-page zoom 1×–3× (PageZoom: state/gesture math +
  ZoomHUD) and ZoomablePage (Single Page native UIScrollView zoom).
- PencilKit/: the PencilKit stack: PencilKitBridge (canvas + finger recognizers),
  ToolPickerHost (single PKToolPicker, convergent tool push),
  DrawingSessionManager (one authoritative canvas per Page, save gating).
  PencilKit is the handwriting layer, not the whole page surface.
- PageSurface/: PageSurface, the layer-ready page container: plain page
  background today, future content-object and overlay layers later, and the
  PencilKit drawing layer in between.
- Layout/: PageGeometry: PaperSize / PaperPreset catalogue / fit scale.
  EditorLayoutEngine is the future pure layout source; PageGeometry remains
  the compatibility bridge used by current runtime views.
- Layout/: Editor is document-directed: App requests the validated Document's
  interface orientation while this component is active. Editor owns its own
  layout inside the actual viewport and never makes window-orientation requests
  or affects another component.
- Workspace integration: App may assign Editor a reduced viewport for a mailbox
  sidebar. The first safe implementation flushes drawings and suspends Editor
  interaction while browsing; a future floating Send Form uses the same
  App-owned composition boundary. See `docs/architecture.md` (Editor Workspace
  accessories).
- Model/ and Configuration/: v2 editor vocabulary. PageSpec / PageSize /
  LayoutPolicy now provide the current A4 portrait default plus data-only A4
  landscape and postcard presets, bridged back through PageGeometry so runtime
  behavior stays unchanged.
- State/: inert EditorCommand / ViewportCommand / DrawingCommand values, plus
  EditorMutationPhase, for transaction-style viewport, zoom, mutation, and
  activation flows. The phase currently guards only Continuous current-page
  tracking during add/delete restore. EditorViewportState /
  EditorOperationPhase / EditorEvent model the future reset-before-structural
  operation state machine.
- Mutation/: PageMutationCoordinator planner for future add/delete
  transactions. WritingScreen uses it only to confirm add/delete target
  planning today; WritingScreen still owns runtime page mutation. The planner
  can now carry an unused, policy-derived future zoom reset command.
- Diagnostics/: editor feature flags and trace/diagnostic helpers.
- PageSurface/: reserved for future page-surface model work.

## Key files

- `Screen/WritingScreen.swift`, `Screen/WritingTopBar.swift`
- `Viewport/SinglePagesView.swift`, `Viewport/ContinuousPagesView.swift`,
  `Viewport/ContinuousNativePagesView.swift`, `Viewport/ZoomablePage.swift`,
  `Viewport/PageZoom.swift`
- `Layout/PageGeometry.swift`, `Layout/EditorLayoutContext.swift`,
  `Layout/EditorLayoutEngine.swift`
- `PageSurface/PageSurface.swift`
- `PencilKit/PencilKitBridge.swift`, `PencilKit/ToolPickerHost.swift`,
  `PencilKit/DrawingSessionManager.swift`
- `Model/PageSpec.swift`, `Configuration/EditorConfiguration.swift`
- `Configuration/InteractionPolicy.swift` — writing, read-only, and workspace-
  suspended capability contract supplied by App and enforced inside Editor
- `State/EditorOutputIntent.swift`, `State/EditorCommand.swift`,
  `State/EditorMutationPhase.swift`,
  `State/EditorOperationState.swift`
- `Mutation/PageMutationCoordinator.swift`

## Not responsible for

- Choosing the document: `WritingScreen(document:)` receives it from the
  App layer. No inbox/draft/new-document logic here, ever.
- Persistence details: load/save goes through NoteStore (Storage).
- Global preferences UI (App).
- App route/back behavior, Send Form, envelope/mailbox state, and direct calls
  to Library or Social.
- Selecting or applying the app/window orientation policy (App); Editor only
  adapts its content to its document semantics and actual viewport.

## Next step (current stage)

In priority order:

- F-062 Editor Workspace — verify the non-writing mailbox sidebar handoff,
  current-page continuity, and ToolPicker restoration on the primary iPad.
- F-059 zoom-pan physics — add inertia + edge rubber-band to the zoomed
  finger pan (today it stops dead on finger-up, no bounce).
- F-060 top-bar dead while zoomed — taps on WritingTopBar raise the
  PKCanvasView edit menu ("Select All / Insert Space") instead of hitting
  the buttons; restore hit-testing + suppress the canvas edit menu.
- F-054 writing-mode media attachments (Apple-Notes-like).

Later (behind v2): Reading Mode variant; per-document paper (drop the
`PaperPreset.letter` hard-code once Storage migrates).

## Notes for AI changes

- Respect the canvas invariants and the Flow design notes in
  `docs/architecture.md` (one authoritative canvas per Page; all
  canvases stay alive; convergent tool push; pencilOnly + finger-only
  recognizers attached to the canvas itself). They were earned through
  device debugging — do not regress casually.
- Never branch on a paper's NAME; derive behavior from
  `paper.width/height` only.
- Avoid bidirectional scroll bindings (`.scrollPosition(id:)` causes a
  snap loop); use the one-way `scrollTarget` UUID signal.
- Command types are preparation only until a coordinator interprets them;
  do not bypass DrawingSessionManager or viewport invariants by dispatching
  ad-hoc side effects from the command model.
- The App flow coordinator does not interpret EditorCommand or own
  viewport/page/PencilKit state. Before `.showSocial`, WritingScreen rejects a
  pending structural operation and synchronously flushes authoritative
  drawings; preserve that departure boundary for future component intents.
- `.showMailbox` is emitted by the visible top-bar mailbox control only from an
  idle, normal viewport. Opening synchronously applies workspace suspension:
  authoritative drawings flush, Pencil input and ToolPicker are disabled, and
  App keeps Editor mounted but blocks its hit testing until sidebar dismissal.
- App may select Editor interaction semantics but must not operate PencilKit.
  Writing allows Pencil plus finger navigation; future read-only viewing keeps
  page/zoom navigation without Pencil or ToolPicker; workspace suspension
  allows neither. DrawingSessionManager enforces the PencilKit side.
- An App/Workspace ancestor must never replace animation transactions for the
  Editor subtree. Doing so erases Single Page's explicit carousel animation;
  scope layout animation policy only to workspace-owned views.
- Keep WritingTopBar presentational: WritingScreen interprets typed local
  actions and converts only component-exit requests into App-facing output.
- Structural editor operations require a normal viewport. If Add Page, Delete
  Page, future reorder/duplicate/template/image operations are requested while
  zoomed, the future transaction must request zoom reset, wait for reset
  completion or no-op completion at 100%, then mutate and restore the viewport
  target. Do not reintroduce reset-token hacks during or after mutation.
- WritingScreen has a read-only `currentEditorViewportState` bridge for the
  existing zoom signals: Single Page, native Continuous stack, and legacy
  Continuous transform. Native Continuous per-page prototype is not a reliable
  operation-level owner yet. Add/delete do not consume this bridge yet.
- User reset is the first `EditorEvent` runtime bridge: WritingScreen maps
  top-bar reset and viewport-local double-tap reset to `resetZoomRequested`
  and then dispatches the existing owner-specific reset mechanism. This covers
  Single Page, legacy Continuous transform zoom, and native Continuous stack.
- Add Page is the first structural operation routed through
  `EditorOperationStateMachine`: normal viewports run the existing add-page
  logic immediately; zoomed viewports reset first, wait for reset completion,
  then run the existing add-page mutation/target/scroll restore on the next
  `MainActor` turn. Delete Page remains on the legacy direct path.
- Single Page keeps all page canvases mounted for flicker-free turns, but only
  the current page is registered as visible/hit-testable for PencilKit editing.
  After index/page-list changes, editing opens after a short activation window
  so the new page cannot receive Pencil input before ToolPicker handoff settles.
- EditorMutationPhase is partially live: WritingScreen keeps it active during
  Continuous add/delete restore and Continuous views use it only to ignore
  mutation-time current-page tracking callbacks. Do not use it to gate zoom
  reporting or DrawingSessionManager activation yet.
- PageMutationCoordinator is currently a pure planner, lightly bridged into
  WritingScreen for add/delete target selection only. Do not move storage
  mutation or side-effect ordering into it until the add/delete transaction is
  intentionally migrated.
- PageMutationPolicy / MutationZoomPolicy are preparation only. They can model
  "reset Continuous stack zoom before add/delete" as a future command, but
  WritingScreen does not dispatch that command yet. The failed add-page runtime
  reset bridge should stay reverted until the operation state machine owns the
  full reset-before-mutation transaction.
- Page-turn/zoom changes must be device-tested (iPad 8 + Pencil 1)
  before being considered done.
