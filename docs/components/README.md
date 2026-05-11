# iOS Components

Non-UI Swift modules under `ios/`. Includes storage, services, helpers,
adapters — anything that is not a view. Features reference these by ID.

ID scheme: C-XXX, monotonic, never reused.

When a component's spec grows beyond one row, move it to its own file at
`docs/components/C-XXX-name.md` and link from this catalog.

## Catalog

| ID | Name | Responsibility |
|---|---|---|
| C-001 | NoteStore | CRUD and persistence of Note entities |
| C-002 | PencilKitBridge | SwiftUI wrapper around PKCanvasView |
| C-003 | StrokeSerializer | Convert PKDrawing to/from on-disk format |
| C-005 | ExportEngine | Render notes as PDF / PNG / JPEG |
| C-010 | SessionManager | Manage the auth session token locally |
