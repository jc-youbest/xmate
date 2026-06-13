# Editor — Content Screen (document viewing & writing)

## Responsibilities

- WritingScreen: the Writing-Mode variant of the Content Screen.
- Both Pagination Styles: SinglePagesView (persistent offset carousel,
  flips animate offsets only — zero canvas recreation) and
  ContinuousPagesView (free-scroll plain VStack — never Lazy, the
  PKToolPicker needs window-attached canvases).
- Whole-page zoom 1×–3× (PageZoom: state/gesture math + ZoomHUD).
- The PencilKit stack: PencilKitBridge (canvas + finger recognizers),
  ToolPickerHost (single PKToolPicker, convergent tool push),
  DrawingSessionManager (one authoritative canvas per Page, save gating).
- PageGeometry: PaperSize / PaperPreset catalogue / fit scale.

## Key files

- `WritingScreen.swift`, `WritingTopBar.swift`
- `SinglePagesView.swift`, `ContinuousPagesView.swift`
- `PageZoom.swift`, `PageGeometry.swift`
- `PencilKitBridge.swift`, `ToolPickerHost.swift`,
  `DrawingSessionManager.swift`

## Not responsible for

- Choosing the document: `WritingScreen(document:)` receives it from the
  App layer. No inbox/draft/new-document logic here, ever.
- Persistence details: load/save goes through NoteStore (Storage).
- Global preferences UI (App).

## Next step (current stage)

- Reading Mode variant; writing-mode media attachments; per-document
  paper (drop the `PaperPreset.letter` hard-code once Storage migrates).

## Notes for AI changes

- Respect the canvas invariants in `docs/architecture.md` (one active
  canvas per Page; all canvases stay alive; convergent tool push;
  pencilOnly + finger-only recognizers attached to the canvas itself).
  They were earned through device debugging — do not regress casually.
- Never branch on a paper's NAME; derive behavior from
  `paper.width/height` only.
- Avoid bidirectional scroll bindings (`.scrollPosition(id:)` causes a
  snap loop); use the one-way `scrollTarget` UUID signal.
- Page-turn/zoom changes must be device-tested (iPad 8 + Pencil 1)
  before being considered done.
