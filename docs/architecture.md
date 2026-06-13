# Architecture

Global architecture of the xmate iOS app. Module-level detail lives in
each module's README next to its code (`ios/xmate/xmate/<Module>/README.md`).

## Layering

    App  →  Editor  →  Storage
     │                    ↑
     └────→ Library ──────┘        Shared: small cross-module types

- **App** (`App/`) — entry layer: `@main`, RootView (composition root),
  global settings. Depends on modules; no module ever imports from it.
- **Editor** (`Editor/`) — Content Screen: pagination, zoom, the
  PencilKit writing stack. Edits exactly the document it is given.
- **Storage** (`Storage/`) — Core Data store, Document/Page entities,
  drawing load/save. Knows nothing about UI (no pagination styles, no
  zoom, no tool picker).
- **Library** (`Library/`) — placeholder; document list / drafts /
  inbox / sent letters land in v3.
- **Shared** (`Shared/`) — truly cross-module small types only
  (currently `PaginationStyle`, `Comparable.clamped`). Not a junk drawer.

## Xcode project

| Setting | Value |
|---|---|
| Project name | `xmate` |
| Bundle Identifier | `com.cwc.xmate` |
| Deployment target | iPadOS 18.0 |
| Device family | iPad only |
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

- v1: `RootView` resolves a hard-coded dev document name through
  `NoteStore.loadOrCreateDocument(named:)` and injects the `Document`.
- Future sources — inbox (social), drafts/list (Library), new creation —
  all resolve a `Document` outside the editor and inject it the same way.

## Paper model

A document is written on a paper with fixed logical dimensions in points
(Letter 595×842 portrait; Postcard 864×576 landscape). Everything
mechanical — orientation lock, pagination axis, swipe directions, scroll
axis, fit scale — derives from `paper.width` / `paper.height`. **No code
branches on a paper's name.** New presets are catalogue entries only.
Logical page size never changes with device; every iPad scales the page
uniformly to fit, and handwriting never reflows.

Current stage limitation: `paper` is hard-coded to `PaperPreset.letter`
in WritingScreen until the per-document paper Core Data migration.

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
