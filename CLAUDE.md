# CLAUDE.md — Project Context for Claude

> Read this file at the start of every conversation about this project.
> Keep it under two screens. Update it whenever a structural decision is made.

## Project: xmate

A handwriting-first iPad app for taking notes and sharing handwritten work
with pen pals. Two products in one: a polished notes app comparable to Apple
Notes, plus a social layer where users exchange handwritten pages — including
sending handwritten letters with embedded images to friends.

The social/sharing layer is the product's primary value. The notes app is
the foundation on top of which sharing is built.

## Tech Stack

- Platform: iPadOS, latest two major versions supported.
- Language: Swift; SwiftUI for UI, UIKit where SwiftUI gaps exist.
- Drawing: PencilKit (Apple's official handwriting framework).
- Local storage: TBD (Core Data or SwiftData).
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

### Feature File Format

Feature files are flow-centric. Each feature is described as a sequence of
`When <trigger>: <system actions>` blocks. Every UI / component / backend
reference uses the exact `ID Name` form, matching its catalog. Performance
or compatibility constraints go inline next to the relevant step, e.g.
`(latency < 1 frame)`. No Acceptance Criteria, Non-goals, Open Questions,
Dependencies, or Status sections.

See `docs/requirements/_template.md` and `docs/requirements/F-001-handwriting-canvas.md`.

## Where Things Live

- `docs/requirements/` — feature index and per-feature flow specs (F-XXX).
- `docs/ui/README.md` — UI containment tree (U-XXX).
- `docs/components/README.md` — iOS component catalog (C-XXX).
- `docs/backend/README.md` — backend module catalog (S-XXX).
- `docs/glossary.md` — shared terminology.
- `ios/` — Xcode project (created later).
- `backend/` — backend code (created later).
- `assets/` — design and reference assets.
- `scripts/` — utility scripts.

## Working Style

When starting a new conversation, the user will typically say
"Continue xmate. Read CLAUDE.md and <relevant doc>." Begin by reading
those files. End each working session by writing decisions and updates back
into the relevant markdown files — do not leave conclusions only in chat.
When committing changes that involve a design decision, write the WHY into
the commit message.
