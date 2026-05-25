# xmate

A handwriting-first iPad app built on a personalized-stationery model. Each
page is a fixed sheet the user composes — background, lines, and framed
photos — then locks and writes on by hand. A social layer lets users share
their multi-page stationery documents with pen pals.

Built with Swift, SwiftUI, and PencilKit on iPadOS. Backed by a custom
self-hosted backend (not CloudKit). Targets the latest Apple Pencil while
remaining compatible with Apple Pencil 1st generation.

## Repository Layout

- `docs/` — feature specs, UI tree, component and backend catalogs, glossary.
- `ios/` — Xcode project (created later).
- `backend/` — custom backend code (created later).
- `assets/` — design assets and reference materials.
- `scripts/` — utility scripts.

## Documentation Entry Points

- [`CLAUDE.md`](CLAUDE.md) — context for AI-assisted development sessions.
- [`docs/requirements/`](docs/requirements/) — feature index and per-feature flow specs.
- [`docs/ui/`](docs/ui/) — UI containment tree.
- [`docs/components/`](docs/components/) — iOS component catalog.
- [`docs/backend/`](docs/backend/) — backend module catalog.
- [`docs/glossary.md`](docs/glossary.md) — shared vocabulary.

## Test Hardware

Primary development and test setup:

- iPadOS 18.5 (may be upgraded)
- iPad (8th generation)
- Apple Pencil (1st generation)

The app must also remain compatible with the latest iPad and the latest
Apple Pencil. Full hardware constraints, including how newer-Pencil
features should be surfaced, are documented in [`CLAUDE.md`](CLAUDE.md).

## Development Setup

To be filled in once the Xcode project is created.

## License

TBD.
