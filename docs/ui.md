# UI

Global UI principles and the inventory of built UI. Future screens live
in `docs/backlog.md` until they are about to be built.

## Principles

- Two top-level surfaces (Social Screen, Content Screen), switched by an
  explicit top-bar control. No sliding sidebars over the writing surface.
- The Content Screen is locked to the paper's orientation; the in-content
  UI never rotates with the device.
- The page is one bounded sheet at fixed logical size: zoomable (1×–3×),
  never infinite, never free-panning beyond its edge, never reflowing.
- Pencil draws; fingers navigate (swipe, scroll, pan-while-zoomed,
  double-tap zoom reset). Finger never inks.
- Thin top bar for navigation and document actions; the system
  PKToolPicker stays at the bottom. Destructive actions hide behind an
  overflow menu with confirmation alerts.
- A zoomed page is clipped to the canvas area — it never paints over the
  top bar. Transient feedback (zoom percentage HUD) is centered,
  translucent, touch-transparent, and auto-fades.

## Built UI (current build)

IDs are kept as greppable anchors — every view file header carries its
U-XXX. Numbering is monotonic; never reuse an ID. Allocate new ones here.

- U-001 AppRoot (`App/RootView.swift`) — composition root; resolves the
  document and hosts the editor
- U-101 WritingScreen (`Editor/WritingScreen.swift`) — Writing-Mode
  variant of the Content Screen
  - U-102 WritingTopBar — page indicator (U-093), zoom reset button
    (U-113, live percentage while zoomed), add page (U-095), overflow
    menu (U-103) with pagination style picker (U-111) and delete actions
  - U-023 Canvas — PKCanvasView per page, sized to the logical paper
  - U-112 ZoomHUD — transient centered zoom percentage readout
- Planned next surfaces (IDs reserved): U-106 SocialScreen stub, U-002
  document list (Library, v3), U-085 StationeryComposerScreen (v2). The
  remaining historical U-XXX inventory was archived into
  `docs/backlog.md` entries; allocate fresh IDs as screens get designed.
