# ios/

The Xcode project for the iOS app.

## Project Conventions

| Setting | Value |
|---|---|
| Project name | `xmate` |
| Bundle Identifier | `com.cwc.xmate` |
| Deployment target | iPadOS 17.0 |
| Device family | iPad only |
| Interface | SwiftUI |
| Language | Swift |

## Layout

The Xcode project is created in this directory using the conventions
above. Xcode wraps the project in a folder named after the product, so
the resulting layout is:

- `xmate/` — Xcode project wrapper (auto-created by Xcode)
  - `xmate.xcodeproj/` — Xcode project file
  - `xmate/` — application source folder
    - `xmateApp.swift` — app entry point
    - Other `.swift` files, named to match catalog IDs where applicable
  - `xmateTests/` — unit tests
  - `xmateUITests/` — UI tests

The double-`xmate` nesting is Xcode's default. Open the project by
double-clicking `ios/xmate/xmate.xcodeproj`.

Each Swift file implementing a UI node (U-XXX) or component (C-XXX)
starts with a one-line header comment carrying its catalog ID; see
[`CLAUDE.md`](../CLAUDE.md) → Conventions → Code-to-ID mapping.
