# Product

xmate is a handwriting-first iPad app built on a personalized-stationery
model. Two products in one: a stationery authoring experience, plus a
social layer where users share documents with pen pals. The social layer
is the product's primary value; authoring is the foundation it is built
on.

## Core model

A **document** is an ordered sequence of **pages**, written on a
**paper** (fixed logical dimensions — see `architecture.md`). Each page
is a fixed sheet the user first composes — background color, line style,
photos in movable frames — then locks with a one-way **Generate** step,
after which it can be written on by hand. The user fills a page and
turns to the next, like real letter paper. A page can be zoomed but is
never an infinite or pannable canvas. xmate is digital stationery — not
a whiteboard, not an Apple Notes clone.

## Surfaces and modes

Two top-level full-screen surfaces, mutually exclusive, switched via an
explicit top-bar control (never a sliding sidebar over the writing
surface):

- **Social Screen** — inbox / feed / pen-pal layer. v1 ships a
  structural stub; concrete layout lands v3+.
- **Content Screen** — one letter or postcard. Two **Modes** sharing one
  layout: **Reading Mode** (read-only, later increment) and **Writing
  Mode** (shipped). The word "Mode" is reserved for Reading vs Writing.

The Content Screen offers two equal **Pagination Styles** (global user
preference, applied immediately — never called a "mode"):

- **Single Page** — one full page at a time; finger swipes flip
  discretely. Direction derives from paper orientation (portrait paper →
  vertical, landscape → horizontal). Default.
- **Continuous** — pages stack and scroll continuously along the same
  axis.

Device orientation never rotates the in-content UI: portrait paper locks
the Content Screen to portrait, landscape paper to landscape; the user
rotates the iPad to match. Revisited in v5.

## Terminology (essentials)

| Term | Meaning |
|---|---|
| Document / Note | Synonyms; ordered pages, the unit created/opened/shared |
| Paper / Paper Preset | Fixed logical sheet dimensions / named catalogue entry (Letter, Postcard) |
| Page | One bounded sheet of fixed logical size; compose phase then write phase |
| Stationery | A page's composed, generated-locked background |
| Generate | One-way action ending compose phase, enabling handwriting |
| Fit scale | Uniform scale projecting the logical page onto the current screen |
| Pen pal / Post / Playback | Social-layer concepts, v3+ |

## Direction

Roadmap stages live in `roadmap.md` (v0 local writing → v1 complete
writing mode → v2 stationery editor → v3 main interface offline → v4
networked social → v5 device adaptation → v6 moderation). The future
feature pool is `docs/backlog.md`.
