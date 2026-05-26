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

A document is one of two content types, and the type fixes the page's
orientation for the lifetime of the document:

- **Letter** — portrait pages, fixed aspect 1 : √2 (A4 portrait). The
  primary stationery; the writing-mode default.
- **Postcard** — landscape pages, fixed aspect 3 : 2 (4 × 6 inch postcard).
  Same underlying data model as a letter, only the page dimensions differ.

Logical page sizes never change with device. Each iPad scales the logical
page uniformly to fit; a line written on iPad mini occupies the same
relative space on iPad Pro 13". The app does not reflow content for device
size or orientation — handwriting layout is preserved verbatim across all
iPads.

Device orientation does not rotate the in-content UI. While the user is on
a letter, the screen is locked to portrait; while on a postcard, it is
locked to landscape. If the user holds the iPad the wrong way for the
current content, they are expected to rotate the device — the app does not
adapt to the user's grip. Multi-orientation flexibility is deferred to v5.

The app has two top-level full-screen surfaces that the user explicitly
switches between:

- **Social Screen** — the inbox / feed / pen-pal layer. v1 ships a
  structural shell only; concrete layout lands in v3+.
- **Content Screen** — focuses on one letter or one postcard. Has a
  read-only browse mode and an edit mode that share the same layout; only
  the toolset changes between them. The current `WritingScreen` is the
  writing variant of this screen.

The two screens are mutually exclusive and switched via an explicit
top-bar control — never a sliding sidebar over the writing surface.

Two products in one: the stationery authoring experience above, plus a
social layer where users share their documents with pen pals. The social
layer is the product's primary value; authoring is the foundation it is
built on.

## Tech Stack

- Platform: iPadOS, latest two major versions supported.
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
- Markdown filenames: kebab-case (`F-002-pen-tools.md`).
- Branch naming: `feature/F-002-pen-tools`, `fix/F-002-...`.
- Commit messages: `feat(F-002): add pen tool picker`, `docs(C-001): introduce NoteStore`.
  When a commit changes UI / components / backend / features, the message
  should briefly state WHY, not only WHAT. The commit log is the substitute
  for an ADR; future spelunking uses `git log --grep=...`.
- Code-to-ID mapping: every Swift file that implements a UI node (U-XXX)
  or component (C-XXX) starts with a one-line header comment, e.g.
  `// U-023 Canvas` or `// C-002 PencilKitBridge`. This makes catalog IDs
  greppable from inside the code.

### Feature File Format

Feature files are flow-centric. Each feature is described as a sequence of
`When <trigger>: <system actions>` blocks. Every UI / component / backend
reference uses the exact `ID Name` form, matching its catalog. Performance
or compatibility constraints go inline next to the relevant step, e.g.
`(latency < 1 frame)`. No Acceptance Criteria, Non-goals, Open Questions,
Dependencies, or Status sections.

See `docs/requirements/_template.md` and `docs/requirements/F-001-handwriting-canvas.md`.

## Where Things Live

- `docs/roadmap.md` — the development path: stages v0..v6.
- `docs/requirements/` — feature index and per-feature flow specs (F-XXX).
- `docs/ui/README.md` — UI containment tree (U-XXX).
- `docs/components/README.md` — iOS component catalog (C-XXX).
- `docs/backend/README.md` — backend module catalog (S-XXX).
- `docs/glossary.md` — shared terminology.
- `ios/` — Xcode project.
- `backend/` — backend code (created later).
- `assets/` — design and reference assets.
- `scripts/` — utility scripts.

## Working Style

When starting a new conversation, the user will typically say
"Continue xmate. Read CLAUDE.md and <relevant doc>." Begin by reading
those files. Always also read `docs/requirements/README.md` — it is the
feature inventory and status register; reading it keeps the feature
catalog current without being explicitly asked.

End each working session by writing decisions and updates back into the
relevant markdown files — do not leave conclusions only in chat. When
committing changes that involve a design decision, write the WHY into
the commit message.

After completing a coding increment, always remind the user to test on
the primary dev device (iPad 8th generation + Apple Pencil 1st generation)
before considering the increment done.
