# ios/

The Xcode project for the iOS app.

## Project Conventions

| Setting | Value |
|---|---|
| Project name | `xmate` |
| Bundle Identifier | `com.cwc.xmate` |
| Deployment target | iPadOS 18.0 |
| Device family | iPad only |
| Interface | SwiftUI |
| Language | Swift |

## Layout

Xcode wraps the project in a folder named after the product, so the
layout is (the double-`xmate` nesting is Xcode's default):

- `xmate/` — Xcode project wrapper (auto-created by Xcode)
  - `xmate.xcodeproj/` — the Xcode project; open this.
  - `xmate/` — application source, one folder per module, each carrying
    its own `README.md`. Module map and dependency rules live in
    [`docs/architecture.md`](../docs/architecture.md) — not duplicated here.
  - `xmateTests/` — unit tests. `xmateUITests/` — UI tests.

The source folder is a filesystem-synchronized group (`objectVersion
77`): files added to a module folder on disk join the target
automatically — no pbxproj edits. Module `README.md` files are excluded
from the app target via a membership-exception set in the pbxproj so
they are never bundled.

Each Swift file implementing a UI node (U-XXX) or component (C-XXX)
starts with a one-line header comment carrying its catalog ID; see
[`CLAUDE.md`](../CLAUDE.md) → Conventions → Code-to-ID mapping.
