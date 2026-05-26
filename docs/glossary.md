# Glossary

Shared vocabulary for this project. Update whenever a new term recurs.

| Term | Meaning |
|---|---|
| Document | An ordered sequence of pages — the unit a user creates, opens, and shares. F-050 / F-051 and later features use "document". A document is one of two content types: Letter or Postcard. |
| Note | The term earlier features (e.g. F-011) use for the same thing as a document. Treat as a synonym of Document. |
| Letter | Content type whose pages are portrait, aspect 1 : √2 (A4 portrait). The default writing-mode content type. |
| Postcard | Content type whose pages are landscape, aspect 3 : 2 (4 × 6 inch postcard). Same underlying data model as Letter; only the page dimensions differ. |
| Content type | One of {Letter, Postcard}. Fixed at document creation; determines page aspect ratio and Content Screen orientation lock for the document's lifetime. |
| Page | One bounded sheet of fixed logical size within a document. It can be zoomed, but is never an infinite or pannable canvas, and never rotates with the device. Has a compose phase and a write phase. |
| Logical page size | A page's fixed dimensions in logical points. Never changes — not on rotation, not on zoom, not on cross-device opens. |
| Fit scale | The uniform scale `min(viewport.w / logical.w, viewport.h / logical.h)` applied to project the logical page onto the current iPad screen. Differs across iPad models; the logical page itself does not. |
| Content Screen | The top-level full-screen surface focused on one document. Has a read-only browse mode and an edit mode that share the same layout; only the toolset changes. U-101 WritingScreen is its writing variant. |
| Social Screen | The other top-level full-screen surface — inbox, feed, pen-pal layer, etc. v1 ships a structural stub only. U-106 SocialScreen. |
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
