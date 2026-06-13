# CLAUDE.md — Project Context for Claude

> Read this file at the start of every conversation about this project.
> It is an index, not a spec: each fact lives in exactly one document,
> linked below. Keep this file short; update it when structure changes.

## Project: xmate

A handwriting-first iPad app on a personalized-stationery model: a
document is an ordered sequence of fixed paper pages the user composes
(background, lines, photos), locks with a one-way Generate step, then
writes on by hand — plus a social layer for sharing with pen pals.
xmate is digital stationery, not a whiteboard or an Apple Notes clone.

Full product vision, core model, surfaces/modes, terminology, and UI
principles: **`docs/product.md`**.

## Where things live (single source of truth per topic)

- `docs/product.md` — product vision, core model, surfaces & modes,
  terminology, UI principles.
- `docs/architecture.md` — module layering, dependency rules, document
  injection flow, paper model, PencilKit canvas invariants, Xcode
  project conventions, tech stack, hardware constraints, **and all flow
  design notes** (how a flow was implemented + the alternatives tried
  and rejected — paging, zoom, etc.).
- `roadmap.md` — staged development path (v0..v6) and the Backlog
  (future-feature pool; the F-XXX registry).
- `docs/lifecycle.md` — how the iOS/SwiftUI/UIKit/PencilKit lifecycle and
  callbacks fire and in what order across the key scenarios (launch, page
  turn, mode switch, zoom, foreground), plus the running **problem log**
  of major lifecycle/timing issues and their status. The home for
  hard-won "which callback, in what order, in what app state" knowledge —
  record every major timing problem here.
- `ios/xmate/xmate/<Module>/README.md` — per-module self-description
  ONLY: responsibilities, key files, non-responsibilities, next step, AI
  notes. The primary doc for a module-focused session. Module READMEs do
  NOT hold flow/mechanism design — those go in `docs/architecture.md`.
- `README.md` — human-facing repo entry point.

Do not restate facts from these files here or in each other — link
instead. Duplication is what drifts out of sync.

**Rule — flow design has one home.** Every flow's final design (the
mechanism + the alternatives tried and rejected) is recorded in
`docs/architecture.md` (Flow design notes), whether the flow is internal
to one module or spans several. Telling those apart up front is hard and
module boundaries shift, so they share one home: recording a flow =
editing one file. Module READMEs only point to it.

## Module map (authoritative layering in `docs/architecture.md`)

Each module is a folder under `ios/xmate/xmate/` with its own README:

- **App/** — entry layer: `@main`, composition root, global settings.
  Resolves WHICH document opens and injects it; nothing imports App.
- **Editor/** — Content Screen: pagination, zoom, PencilKit writing
  stack. Edits only the injected document.
- **Storage/** — Core Data store, entities, drawing persistence. No UI.
- **Library/** — placeholder until v3 (personal document manager).
- **Shared/** — truly cross-module small types only (no junk drawer).
- Social — no code folder yet; created with its first file (v3+).

Dependency arrows point one way: App → Editor → Storage; everything may
use Shared; nothing imports App.

## Conventions

- All documents and code: English only. Conversations may be any language.
- Markdown filenames: kebab-case.
- `F-XXX` — Feature ID, the only catalog ID in use. Allocate new ones in
  the Backlog section of `roadmap.md`; numbering is monotonic, never
  reuse an ID. (The former U/C/S-XXX catalogs were retired in 2026-06:
  maintaining four parallel registries — plus code-header comments and
  commit prefixes — cost more upkeep than the greppability returned at a
  single-developer, pre-launch scale. Describe UI nodes, components, and
  server modules by name, not by ID.)
- Branch naming: `feature/F-0XX-short-name`, `fix/F-0XX-...`.
- Commit messages: `feat(F-0XX): summary`, `docs: summary`. When a commit
  embodies a design decision, state WHY, not only WHAT — the commit log
  is the ADR substitute (`git log --grep=...`).

## Working style

A session normally targets ONE module. The user typically says "Continue
xmate, module <name>. Read CLAUDE.md and
`ios/xmate/xmate/<Name>/README.md`." Begin by reading those; read other
modules' READMEs only when the work crosses a boundary.

End each session by writing decisions back into the relevant markdown
file — never leave conclusions only in chat. After a coding increment,
remind the user to test on the primary dev device (iPad 8th generation +
Apple Pencil 1st generation) before considering it done.
