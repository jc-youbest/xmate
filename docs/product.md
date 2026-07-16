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
explicit top-bar control:

- **Social Screen** — inbox / feed / pen-pal layer. v1 ships a
  structural stub; concrete layout lands v3+.
- **Content Screen** — one letter or postcard. Two **Modes** sharing one
  layout: **Reading Mode** (read-only, later increment) and **Writing
  Mode** (shipped). The word "Mode" is reserved for Reading vs Writing.

The future **Editor Workspace** may keep the Content Screen mounted while
showing auxiliary UI from other areas: a mailbox sidebar reduces the Editor's
viewport and reserves its own space (never slides over the writing surface),
while a floating Send Form may appear above Editor and temporarily suspend
writing interaction. These are in-app workspace accessories, not additional
top-level surfaces or independent iPadOS windows.

The Content Screen offers two equal **Pagination Styles** (global user
preference, applied immediately — never called a "mode"):

- **Single Page** — one full page at a time; finger swipes flip
  discretely. Direction derives from the document's resolved page-flow
  axis. Default.
- **Continuous** — pages stack and scroll continuously along the same
  axis.

Device/window orientation is separate from paper orientation. xmate is an
iPad full-screen app and deliberately opts out of external Split View / Stage
Manager resizing so Writing Mode can keep the interface orientation aligned
with the validated Document paper orientation. Ordinary components still
respond to how the user holds the iPad. Editor and every workspace accessory
must adapt inside the actual region App assigns; opening an internal sidebar,
for example, reduces Editor's viewport without changing its paper semantics.
Broader device-orientation flexibility is revisited in v5.

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

## UI principles

- Switch between the two top-level surfaces with an explicit top-bar control.
  A future mailbox sidebar may accompany Editor only by reserving layout space
  and shrinking its viewport, never by sliding over the writing surface.
- The page is one bounded sheet at fixed logical size: zoomable (1×–3×),
  never infinite, never free-panning beyond its edge, never reflowing.
- Pencil draws; fingers navigate (swipe, scroll, pan-while-zoomed,
  double-tap zoom reset). The finger never inks.
- A thin top bar carries navigation and document actions; the system
  PKToolPicker stays at the bottom. Destructive actions hide behind an
  overflow menu with confirmation alerts.
- A zoomed page is clipped to the canvas area — it never paints over the
  top bar. Transient feedback (the zoom-percentage HUD) is centered,
  translucent, touch-transparent, and auto-fades.

## Direction

Roadmap stages live in `roadmap.md` (v0 local writing → v1 complete
writing mode → v2 stationery editor → v3 main interface offline → v4
networked social → v5 device adaptation → v6 moderation). The future
feature pool is the Backlog section of `roadmap.md`.
