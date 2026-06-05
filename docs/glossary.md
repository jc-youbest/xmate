# Glossary

Shared vocabulary for this project. Update whenever a new term recurs.

| Term | Meaning |
|---|---|
| Document | An ordered sequence of pages — the unit a user creates, opens, and shares. F-050 / F-051 and later features use "document". A document is created with a chosen paper (typically from a Paper Preset). |
| Note | The term earlier features (e.g. F-011) use for the same thing as a document. Treat as a synonym of Document. |
| Paper | A writable sheet's fixed logical dimensions in points (`PaperSize` in code). Determines aspect ratio, Content Screen orientation lock, and Continuous Pagination Style scroll axis — all derived from `width` and `height`, never from a separate name or type. A document carries its paper for its lifetime. |
| Paper Preset | A named entry in xmate's paper catalogue (`PaperPreset.letter`, `PaperPreset.postcard`, …). Presets are pure data — adding a new paper kind is one entry in the catalogue, with no code branches keyed on its name. |
| Letter | Paper Preset: portrait, 1 : √2 (A4 portrait, 595 × 842 pt). The v1 default. |
| Postcard | Paper Preset: landscape, 3 : 2 (4 × 6 inch, 864 × 576 pt). Same data model as Letter; only the paper dimensions differ. |
| Page | One bounded sheet of fixed logical size within a document. It can be zoomed, but is never an infinite or pannable canvas, and never rotates with the device. Has a compose phase and a write phase. |
| Logical page size | A page's fixed dimensions in logical points. Never changes — not on rotation, not on zoom, not on cross-device opens. |
| Fit scale | The uniform scale `min(viewport.w / logical.w, viewport.h / logical.h)` applied to project the logical page onto the current iPad screen. Differs across iPad models; the logical page itself does not. |
| Content Screen | The top-level full-screen surface focused on one document. Has two Modes (Reading Mode, Writing Mode) sharing the same layout; only the toolset changes. U-101 WritingScreen is its Writing-Mode variant. |
| Social Screen | The other top-level full-screen surface — inbox, feed, pen-pal layer, etc. v1 ships a structural stub only. U-106 SocialScreen. |
| Mode | The Content Screen's edit-state axis. One of {Reading Mode, Writing Mode}. Layout is identical in both; only the toolset and Pencil behaviour differ. **This word is reserved for Reading vs Writing only — never used for Pagination Style.** |
| Reading Mode | The read-only variant of the Content Screen. Pencil does not ink; navigation and zoom still work. v1 defers Reading Mode to a later increment. |
| Writing Mode | The editable variant of the Content Screen. Pencil writes onto the active page. v1's WritingScreen ships this Mode. |
| Pagination Style | The Content Screen's page-navigation axis, a global user preference applied immediately. One of {Single Page, Continuous}. Independent of Mode and Paper. Defined in F-056. |
| Single Page | Pagination Style in which one full page fills the screen at a time; finger swipes flip discretely between pages. Direction is derived from the paper's orientation — vertical for portrait paper, horizontal for landscape paper. The v1 default. |
| Continuous | Pagination Style in which pages stack and scroll continuously. In Writing Mode the scroll snaps to the nearest page when it stops; in Reading Mode the scroll is free and two adjacent pages can be partly visible at once. |
| Stationery | A page's composed background — background color, line style, and photo frames — flattened and locked by the Generate step. |
| Compose phase | The editable phase of a page, in which the user builds its stationery. |
| Write phase | The phase after generation, in which the user writes by hand on the locked stationery. |
| Generate | The one-way action that flattens and locks a page's stationery, ending the compose phase and beginning the write phase. |
| Photo frame | A movable, rotatable, scalable container holding one photo during the compose phase. |
| Stroke | A continuous mark made between one pen-down and the next pen-up. |
| Post | A document (or page) published to the social feed. |
| Pen pal | A user another user follows or is mutual with, depending on the relationship model chosen. |
| Playback | A reconstruction of the order and timing of strokes, replayable as animation. |
| Pencil | Apple Pencil hardware, any generation, unless otherwise specified. |
| ADR | Architecture Decision Record. xmate keeps no ADR files; decision rationale lives in commit messages instead. |
