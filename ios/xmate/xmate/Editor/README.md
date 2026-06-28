# Editor — Content Screen (document viewing & writing)

## Responsibilities

- Screen/: WritingScreen, the Writing-Mode variant of the Content Screen,
  plus WritingTopBar.
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
- Model/ and Configuration/: v2 editor vocabulary. PageSpec / PageSize /
  LayoutPolicy now provide the current A4 portrait data, bridged back through
  PageGeometry so runtime behavior stays unchanged.
- State/: inert EditorCommand / ViewportCommand / DrawingCommand values for
  future transaction-style viewport, zoom, mutation, and activation flows.
- Mutation/: PageMutationCoordinator planner for future add/delete
  transactions. WritingScreen uses it only for add-page target planning today;
  WritingScreen still owns runtime page mutation.
- Diagnostics/: editor feature flags and trace/diagnostic helpers.
- PageSurface/: reserved for future page-surface model work.

## Key files

- `Screen/WritingScreen.swift`, `Screen/WritingTopBar.swift`
- `Viewport/SinglePagesView.swift`, `Viewport/ContinuousPagesView.swift`,
  `Viewport/ContinuousNativePagesView.swift`, `Viewport/ZoomablePage.swift`,
  `Viewport/PageZoom.swift`
- `Layout/PageGeometry.swift`, `Layout/EditorLayoutEngine.swift`
- `PageSurface/PageSurface.swift`
- `PencilKit/PencilKitBridge.swift`, `PencilKit/ToolPickerHost.swift`,
  `PencilKit/DrawingSessionManager.swift`
- `Model/PageSpec.swift`, `Configuration/EditorConfiguration.swift`
- `State/EditorCommand.swift`
- `Mutation/PageMutationCoordinator.swift`

## Not responsible for

- Choosing the document: `WritingScreen(document:)` receives it from the
  App layer. No inbox/draft/new-document logic here, ever.
- Persistence details: load/save goes through NoteStore (Storage).
- Global preferences UI (App).

## Next step (current stage)

In priority order:

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
- PageMutationCoordinator is currently a pure planner, lightly bridged into
  WritingScreen for add-page target selection only. Do not move delete or
  side-effect ordering into it until the add/delete transaction is intentionally
  migrated.
- Page-turn/zoom changes must be device-tested (iPad 8 + Pencil 1)
  before being considered done.
