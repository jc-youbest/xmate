# iOS Components

Non-UI Swift modules under `ios/`. Includes storage, services, helpers,
adapters — anything that is not a view. Features reference these by ID.

ID scheme: C-XXX, monotonic, never reused.

When a component's spec grows beyond one row, move it to its own file at
`docs/components/C-XXX-name.md` and link from this catalog.

## Catalog

| ID | Name | Responsibility |
|---|---|---|
| C-001 | NoteStore | CRUD and persistence of Note entities and app settings |
| C-002 | PencilKitBridge | SwiftUI wrapper around PKCanvasView |
| C-003 | StrokeSerializer | Convert PKDrawing to/from on-disk format |
| C-005 | ExportEngine | Render notes as PDF / PNG / JPEG and assemble publish payloads |
| C-010 | SessionManager | Manage the auth session token locally |
| C-011 | ImageMediaStore | Manage images embedded in notes |
| C-012 | NoteLockService | Encrypt and unlock notes via biometrics or passcode |
| C-013 | ThumbnailRenderer | Render a note's first-page preview thumbnail |
| C-014 | UndoStack | Undo / redo stack scoped to a note |
| C-015 | LassoEngine | Lasso selection, transform, and clipboard ops |
| C-016 | PaperRenderer | Render paper-style backgrounds on the canvas |
| C-017 | FolderStore | CRUD and hierarchy of folders |
| C-018 | TagStore | CRUD of tags and tag-note relationships |
| C-019 | SearchIndex | Title, tag, and handwriting-text indexing and lookup |
| C-020 | HandwritingRecognizer | Vision-based stroke-to-text recognition |
| C-021 | PageManager | Multi-page operations: add, delete, reorder, duplicate |
| C-022 | SyncEngine | Orchestrate cross-device sync with the backend |
| C-023 | AuthClient | Drive OAuth flows on the client side |
| C-024 | PushNotificationHandler | Register for and route APNs notifications |
| C-025 | PlaybackRecorder | Capture per-stroke timing for replay |
| C-026 | PlaybackRenderer | Render recorded strokes as video or GIF |
| C-027 | PageGeometry | PaperSize struct + named PaperPresets and fit-to-viewport scale (F-053) |
| C-028 | SettingsStore | Global app preferences (Pagination Style, etc.) persisted via UserDefaults (F-056) |
| C-029 | ToolPickerHost | App-wide PKToolPicker singleton; registers/unregisters XmateCanvasView instances and binds the picker to whichever canvas DrawingSessionManager designates active via `setActiveCanvas`. Thin: it no longer chooses first responder or re-anchors on its own — all activation decisions come from C-030 (F-051 / F-053 / F-056) |
| C-030 | DrawingSessionManager | Single arbiter of canvas editing identity. Enforces "a Page has at most one active editing canvas; only the active canvas saves". Registry of live canvases (weak, keyed by identity) with pageID/role/visible/active/version; gates drawing-change saves (Coordinator → DrawingSessionManager → C-001 NoteStore); explicit handoff via `makeActive` (flush prev same-page sync → reload from store → mark active + bind ToolPicker → first responder) and `setDesiredActive(pageID:role:)` bootstrap across SwiftUI's async canvas creation; flushes all active canvases on `willResignActive`. Main-thread only (F-051 / F-053 / F-056) |
| C-031 | PageZoomModel | Whole-page zoom state and gesture math for the Content Screen: userZoom clamped 1.0×–3.0× (fit to 300%), pan offset clamped to caller-supplied half-overflow bounds, U-112 ZoomHUD visibility with 1 s linger after pinch end, and reset (page change silently; double-tap / U-113 ZoomResetButton with a HUD flash). Paper-agnostic — viewport bounds are passed per-call, so it serves letter, postcard, and future presets unchanged (F-053) |
