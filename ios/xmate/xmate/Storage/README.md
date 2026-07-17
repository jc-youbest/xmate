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
- Future F-062 persistence adapter: raw envelope metadata records, migration,
  and atomic local primitives. Mailbox owns envelope lifecycle, mailbox query
  semantics, cache resolution, and the future remote repository boundary; see
  `docs/architecture.md` (Document envelope boundary and Mailbox component
  coordination).

## Key files

- `NoteStore.swift`, `Document.swift`, `Page.swift`,
  `StrokeSerializer.swift`, `xmate.xcdatamodeld`

## Not responsible for

- Any UI concept: pagination styles, zoom, tool picker, screens. Storage
  must compile without importing SwiftUI/PencilKit UI types.
- Deciding which document the app opens (App layer).
- App routes, mailbox presentation, recipient/send eligibility, mailbox/cache
  coordination, remote transport, or delivery transitions.

## Next step (current stage)

- Implement the Core Data v3 envelope-record adapter only after the F-062
  Mailbox domain and repository contracts are covered by focused tests.

## Notes for AI changes

- Drawing writes are addressed by page UUID, never by managed object —
  callers never hold a main-context object across threads. Keep it that
  way.
- Never weaken the version guard or the serial save queue; they pair
  with DrawingSessionManager's single-active-canvas gating.
- Schema changes need `shouldMigrateStoreAutomatically`-compatible
  (lightweight) migrations; test upgrade-in-place on device.
