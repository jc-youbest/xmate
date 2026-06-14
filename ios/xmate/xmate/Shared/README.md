# Shared — cross-module small types

## Responsibilities

- Truly cross-module small types, enums, and extensions only. Currently:
  - `PaginationStyle` — persisted by SettingsStore (App), consumed by
    WritingScreen routing (Editor);
  - `Comparable.clamped(to:)` — used by zoom math and anywhere ranges
    need clamping.

## Key files

- `Types.swift` — everything above; split into more files only when a
  type grows.

## Not responsible for

- Anything module-specific. If only one module uses it, it lives in that
  module.

## Next step (current stage)

- None; grows only on demand.

## Notes for AI changes

- Do NOT let this become a junk drawer. Before adding here, prove two
  modules need the symbol; otherwise put it in the owning module.
- No dependencies on App/Editor/Storage/Library — Shared sits at the
  bottom of the graph (Foundation/SwiftUI only).
