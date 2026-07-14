# Storage — Core Data persistence

## Responsibilities

- Core Data stack (store file in `Library/Application Support/`,
  app-private).
- Entities: Document (id, title, timestamps, ordered pages, document-level
  page preset id and logical page dimensions), Page (id, drawingData blob,
  version).
- Document lookup/creation (`loadOrCreateDocument(named:)`, plus a typed
  preset creation path for App-owned document selection), page
  add/delete/reset, and drawing load/save:
  - async debounced save path for while-writing saves;
  - sync flush path for handoffs and `willResignActive`;
  - versioned write guard — a write not strictly greater than the
    stored version is dropped (backstop against stale canvases).
- StrokeSerializer: PKDrawing ⇄ Data (thin today; later schema version /
  compression / encryption).

## Key files

- `NoteStore.swift`, `Document.swift`, `Page.swift`,
  `StrokeSerializer.swift`, `xmate.xcdatamodeld`

## Not responsible for

- Any UI concept: pagination styles, zoom, tool picker, screens. Storage
  must compile without importing SwiftUI/PencilKit UI types.
- Deciding which document the app opens (App layer).

## Next step (current stage)

- Later: stationery entities, sync hooks (custom backend, not CloudKit),
  and Library/new-document UI that calls the typed preset creation path.

## Notes for AI changes

- Drawing writes are addressed by page UUID, never by managed object —
  callers never hold a main-context object across threads. Keep it that
  way.
- Never weaken the version guard or the serial save queue; they pair
  with DrawingSessionManager's single-active-canvas gating.
- Schema changes need `shouldMigrateStoreAutomatically`-compatible
  (lightweight) migrations; test upgrade-in-place on device.
