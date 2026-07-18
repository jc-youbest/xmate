# Storage — Core Data persistence

## Responsibilities

- Core Data stack (store file in `Library/Application Support/`,
  app-private).
- Core Data v3 entities: Document (id, title, timestamps, ordered pages,
  document-level page preset id, logical page dimensions, content revision),
  Page (id, drawingData blob, version), and independent
  LetterEnvelopeRecord metadata joined to Document by UUID rather than a Core
  Data relationship.
- Document lookup/creation (`loadOrCreateDocument(named:)`, plus a typed
  preset creation path for App-owned document selection), page
  add/delete/reset, and drawing load/save:
  - async debounced save path for while-writing saves;
  - sync flush path for handoffs and `willResignActive`;
  - versioned write guard — a write not strictly greater than the
    stored version is dropped (backstop against stale canvases).
- StrokeSerializer: PKDrawing ⇄ Data (thin today; later schema version /
  compression / encryption).
- F-062 persistence adapter: raw envelope metadata records, automatic
  lightweight v2→v3 migration followed by idempotent legacy Draft backfill,
  and atomic local creation/revision primitives. Mailbox owns envelope
  lifecycle, mailbox query semantics, cache resolution, and the future remote
  repository boundary; see `docs/architecture.md` (Document envelope boundary
  and Mailbox component coordination).

## Key files

- `NoteStore.swift`, `Document.swift`, `Page.swift`,
  `LetterEnvelopeRecord.swift`, `StrokeSerializer.swift`,
  `xmate.xcdatamodeld`

## Not responsible for

- Any UI concept: pagination styles, zoom, tool picker, screens. Storage
  must compile without importing SwiftUI/PencilKit UI types.
- Deciding which document the app opens (App layer).
- App routes, mailbox presentation, recipient/send eligibility, mailbox/cache
  coordination, remote transport, or delivery transitions.

## Next step (current stage)

- Keep the completed v3 primitives behind Mailbox's local repository while App
  integrates envelope selection; do not move cache semantics into Storage.

## Notes for AI changes

- Drawing writes are addressed by page UUID, never by managed object —
  callers never hold a main-context object across threads. Keep it that
  way.
- Never weaken the version guard or the serial save queue; they pair
  with DrawingSessionManager's single-active-canvas gating.
- Schema changes need `shouldMigrateStoreAutomatically`-compatible
  (lightweight) migrations; test upgrade-in-place on device.
