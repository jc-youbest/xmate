# CLAUDE.md — Project Context for Claude

> Read this file at the start of every conversation about this project.
> Keep it under two screens. Update it whenever a structural decision is made.

## Project: xmate

A handwriting-first iPad app built on a personalized-stationery model. A
document is an ordered sequence of pages. Each page is a fixed sheet the
user first composes — background color, line style, and photos in movable
frames — then locks with a one-way "generate" step, after which it can be
written on by hand. The user fills a page and turns to the next, like real
letter paper. Each page is one bounded sheet of fixed logical size and
fixed aspect ratio. It can be zoomed but is never an infinite or pannable
canvas. xmate is digital stationery — not a whiteboard, not an Apple Notes
clone.

A document is written on a **paper** — a sheet with fixed logical
dimensions in points. The paper's dimensions determine everything
mechanical about how the document is rendered and navigated:
orientation lock, pagination scroll direction, fit-to-screen scale.

xmate ships **Paper Presets** — named paper sizes the user picks from
when creating a new document:

- **Letter** — portrait, 1 : √2 (A4 portrait). The v1 default and
  the primary stationery.
- **Postcard** — landscape, 3 : 2 (4 × 6 inch). Same data model as
  Letter; only the paper dimensions differ.

Future presets (e.g. note, A5, greeting card) are added as new
entries in one preset catalogue — no other code branches on which
preset a document uses; all behaviour is derived from the paper's
dimensions. Code-level distinctions between letter and postcard are
deliberately absent: the only distinction is the values of
`paper.width` and `paper.height`.

Logical page sizes never change with device. Each iPad scales the
paper uniformly to fit; a line written on iPad mini occupies the same
relative space on iPad Pro 13". The app does not reflow content for
device size or orientation — handwriting layout is preserved verbatim
across all iPads.

Device orientation does not rotate the in-content UI. When the paper
is portrait, the Content Screen is locked to portrait; when the
paper is landscape, it is locked to landscape. If the user holds the
iPad the wrong way for the current paper, they are expected to
rotate the device — the app does not adapt to the user's grip.
Multi-orientation flexibility is deferred to v5.

The Content Screen offers two equal **Pagination Styles**, a global user
preference applied immediately:

- **Single Page** — one full page fills the screen at a time; finger
  swipes flip discretely between pages. Direction is derived from the
  paper's orientation (portrait paper → vertical; landscape paper →
  horizontal).
- **Continuous** — pages stack and scroll continuously in the same
  direction. In Writing Mode the scroll snaps to the nearest page when
  it stops, so the writing surface is always a single steady page; in
  Reading Mode the scroll is free, and two adjacent pages can be partly
  visible at once.

Pagination Style is one axis of the Content Screen; the other is **Mode**
— Reading Mode vs Writing Mode. The two share the same layout; only the
toolset and Pencil behaviour differ. (For consistency: the noun "Mode"
in this codebase refers to Reading vs Writing only; never use "mode" for
Pagination Style.)

The app has two top-level full-screen surfaces that the user explicitly
switches between:

- **Social Screen** — the inbox / feed / pen-pal layer. v1 ships a
  structural shell only; concrete layout lands in v3+.
- **Content Screen** — focuses on one letter or one postcard. Has
  Reading Mode and Writing Mode that share the same layout; only the
  toolset changes between them. The current `WritingScreen` is the
  Writing-Mode variant of this screen.

The two screens are mutually exclusive and switched via an explicit
top-bar control — never a sliding sidebar over the writing surface.

Two products in one: the stationery authoring experience above, plus a
social layer where users share their documents with pen pals. The social
layer is the product's primary value; authoring is the foundation it is
built on.

## Tech Stack

- Platform: iPadOS 18.0+. iOS 18 is the minimum deployment target.
- Language: Swift; SwiftUI for UI, UIKit where SwiftUI gaps exist.
- Drawing: PencilKit (Apple's official handwriting framework).
- Local storage: Core Data, stored in `Library/Application Support/` (app-private, not exposed to the Files app).
- Backend: a self-hosted custom backend, NOT CloudKit. Language, database,
  and hosting choices are deferred until needed.
- Authentication: multi-provider social login — Sign in with Apple (required
  by App Store), Google, Facebook, X. No app-level username/password.
- Cross-device sync: through the custom backend (no iCloud / CloudKit).
- IDE: Xcode (latest stable) on macOS.

## Hardware Constraints

- Primary dev device: iPad 8th generation (iPadOS 18.5) + Apple Pencil 1.
- Build machine: iMac.
- Must remain compatible with the latest iPad and the latest Apple Pencil.
  Pencil 2 / USB-C / Pro features (hover preview, double-tap, squeeze) are
  surfaced where the hardware supports them and silently ignored otherwise.
  Pencil-Pro-only features are nice-to-have, not required.

## Conventions

### Identifiers

- `F-XXX` — Feature (e.g. F-001 Handwriting Canvas)
- `U-XXX` — UI node in the containment tree (e.g. U-023 Canvas)
- `C-XXX` — iOS Component, non-UI Swift module under `ios/` (e.g. C-001 NoteStore)
- `S-XXX` — Server module under `backend/` (e.g. S-001 AuthService)

Numbering is monotonic; never reuse an ID. New IDs are added to their
respective catalog before being referenced from a feature.

### Files & Code

- All documents and code: English only. Conversations may be in any language.
- Markdown filenames: kebab-case.
- Branch naming: `feature/F-002-pen-tools`, `fix/F-002-...`.
- Commit messages: `feat(F-002): add pen tool picker`, `docs(C-001): introduce NoteStore`.
  When a commit changes UI / components / backend / features, the message
  should briefly state WHY, not only WHAT. The commit log is the substitute
  for an ADR; future spelunking uses `git log --grep=...`.
- Code-to-ID mapping: every Swift file that implements a UI node (U-XXX)
  or component (C-XXX) starts with a one-line header comment, e.g.
  `// U-023 Canvas` or `// C-002 PencilKitBridge`. This makes catalog IDs
  greppable from inside the code.

## Modules

The iOS app is split into modules, each a code folder under
`ios/xmate/xmate/` containing its own `README.md` (responsibilities, key
files, non-responsibilities, next step, AI notes):

- **App/** — entry layer: `@main`, composition root (U-001 RootView),
  global settings. No module imports from it. Document identity is
  resolved HERE (currently a hard-coded dev document name) and injected
  into the editor — the editor never chooses its own document.
- **Editor/** — Content Screen: pagination, zoom, PencilKit writing
  stack. Only edits the injected document.
- **Storage/** — Core Data store, entities, drawing persistence. Pure
  load/save; no UI knowledge.
- **Library/** — placeholder until v3 (personal document manager).
- **Shared/** — truly cross-module small types only (no junk drawer).
- Social — no code folder yet; created with its first file (v3+).

Dependency arrows point one way: App → Editor → Storage; everything may
use Shared; nothing imports App.

## Where Things Live

- `roadmap.md` — the development path: stages v0..v6 (global; never
  per-module).
- `docs/architecture.md` — module layering, document injection flow,
  paper model, PencilKit canvas invariants, Xcode project notes.
- `docs/product.md` — product vision, core model, surfaces/modes,
  terminology.
- `docs/ui.md` — UI principles + built UI inventory (global U-XXX
  registry).
- `docs/backlog.md` — future features, one line each (global F-XXX
  registry); details are designed when work starts, not before.
- `ios/xmate/xmate/<Module>/README.md` — per-module self-description;
  the primary doc for a module-focused session.
- `ios/` — Xcode project. `backend/` — backend code (created later).
- `assets/` — design and reference assets. `scripts/` — utility scripts.

## Working Style

A working session normally targets ONE module. The user will typically
say "Continue xmate, module <name>. Read CLAUDE.md and
`ios/xmate/xmate/<Name>/README.md`." Begin by reading those; read other
modules' READMEs only when the work crosses a boundary. When allocating
a new F/U/C ID or changing cross-module structure, consult `docs/ui.md`
(U-XXX) and `docs/backlog.md` (F-XXX) — IDs are global and monotonic,
so always check before allocating.

End each working session by writing decisions and updates back into the
relevant markdown files — do not leave conclusions only in chat. When
committing changes that involve a design decision, write the WHY into
the commit message.

After completing a coding increment, always remind the user to test on
the primary dev device (iPad 8th generation + Apple Pencil 1st generation)
before considering the increment done.
