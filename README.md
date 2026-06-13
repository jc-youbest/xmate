# xmate

A handwriting-first iPad app built on a personalized-stationery model. Each
page is a fixed sheet the user composes — background, lines, and framed
photos — then locks and writes on by hand. A social layer lets users share
their multi-page stationery documents with pen pals.

Built with Swift, SwiftUI, and PencilKit on iPadOS. Backed by a custom
self-hosted backend (not CloudKit). Targets the latest Apple Pencil while
remaining compatible with Apple Pencil 1st generation.

## Repository Layout

- `CLAUDE.md` — context for AI-assisted development sessions.
- `roadmap.md` — development path, stages v0..v6.
- `docs/` — exactly four files: `architecture.md`, `product.md`,
  `ui.md`, `backlog.md`.
- `ios/` — Xcode project; each module folder under
  `ios/xmate/xmate/` carries its own `README.md`.
- `backend/` — custom backend code (created later).
- `assets/` — design assets and reference materials.
- `scripts/` — utility scripts.

## Documentation Entry Points

- [`CLAUDE.md`](CLAUDE.md) — start here for any development session.
- [`roadmap.md`](roadmap.md) — where the project is and what's next.
- [`docs/architecture.md`](docs/architecture.md) — module layering and invariants.
- [`docs/product.md`](docs/product.md) — product vision and terminology.
- [`docs/ui.md`](docs/ui.md) — UI principles and built UI inventory.
- [`docs/backlog.md`](docs/backlog.md) — future features, one line each.

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
