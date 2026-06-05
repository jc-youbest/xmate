# Roadmap

The development path as a sequence of stages. Each stage is a standalone,
testable iOS build. This plan is living — revised whenever direction changes.

Stage labels (v0, v1, ...) belong to the project, not to any single
feature. Per-feature progress is the status field in requirements/README.md.

## v0 — Local blank-page writing

App opens straight into the writing surface. The user writes with Apple
Pencil; strokes persist and reload across launches. Storage already models a
multi-page document, but v0 ships a single-page writing surface only — page
turning, adding and deleting pages, and deleting the document are deferred to
v1. Every page background is blank: no template, no image, no theme.

## v1 — Complete writing mode

The full handwriting experience built on the v0 surface.

A document becomes truly multi-page. The user turns pages with a vertical
paging swipe of the finger, adds and deletes pages, and deletes the whole
document. Only the Apple Pencil draws — the finger is reserved for
navigation. A thin top bar carries the page indicator, an add-page button,
a back-to-social button, and an overflow menu for destructive actions; the
system tool picker stays at the bottom.

v1 splits the app into two top-level full-screen surfaces:

- **Content Screen** — focuses on one letter or one postcard. v1 ships
  the writing variant; the read-only browse variant shares its layout and
  arrives later.
- **Social Screen** — placeholder shell for inbox / feed / pen-pal
  surfaces. v1 ships a structural stub with explicit navigation to and
  from the Content Screen; its concrete contents are designed in v3+.

A document is written on a **paper** — a sheet with fixed logical
dimensions. xmate ships two **Paper Presets** in v1: **Letter** (portrait
A4, 1 : √2) and **Postcard** (landscape, 3 : 2, 4 × 6 inch). Same data
model, only the dimensions differ. Future presets (e.g. notes, A5,
greeting card) are added as new entries in one catalogue — no code
branches on a preset's name; orientation, scroll direction and aspect
all derive from the paper's `width` and `height`.

Pages have fixed logical dimensions; every iPad uniformly scales the page
to fit. Handwriting position is preserved verbatim — a line on iPad mini
and the same line on iPad Pro 13" occupy the same relative space. Content
never reflows for screen size.

Device orientation does not rotate the in-content UI. A document written
on portrait paper locks the Content Screen to portrait; landscape paper
locks it to landscape. The user is expected to orient the device to the
paper — the app does not adapt to grip. Multi-orientation flexibility
across the app is deferred to v5.

The Content Screen offers two equal **Pagination Styles** as a global
user preference applied immediately (F-056):

- **Single Page** — discrete swipe between full-screen pages,
  direction derived from the paper's orientation (vertical for
  portrait paper, horizontal for landscape paper). Default for new
  users; this is what stage 2 ships.
- **Continuous** — pages stack and scroll continuously. Writing Mode
  snaps to the nearest page after scrolling stops; Reading Mode (a
  later increment) scrolls freely with two pages partly visible at
  once. Stage 3 ships Continuous for letter content.

The Content Screen supports whole-page zoom (1× to 3×). Zoom scales
handwriting and, in later stages, the stationery background as one unit.
The page remains one bounded sheet — never an infinite canvas, never
free-panning beyond the page edge.

The user can add media attachments while writing. The add-image experience
matches Apple Notes. These writing-mode attachments — distinct from the
photos placed in stationery mode (v2) — can be moved, scaled, and deleted
at any time. They scale together with the page under zoom.

## v2 — Personalized stationery template editor

App opens into a stationery editing UI. The user composes a single-page
template:

- load multiple images, each freely rotatable, scalable, and placeable
  anywhere on the page (overlay elements);
- set a background — a solid color, a full-screen background photo, or a
  theme (postcard, ruled notebook, grid notebook). A background photo is
  NOT an overlay image: it can only be stretched / filled to the full page.
  A theme is treated as a special background image, possibly a vector.

A template can be saved locally while editing. Its data structure is
identical to a single Page of a writing-mode document, minus the
handwriting. When done, a template can be published; a published template
can be loaded in writing mode as the page background, with handwriting
allowed on top. Publishing = copying the template's Page-shaped data into a
Page of a writing-mode Document.

## v3 — Main interface, offline

App opens into a main interface. The user can: view handwritten letters
shared by others (faked with local test data for now — exact design TBD);
browse stationery templates others shared publicly; open the v1 writing
mode; while writing, swap a different template into any page at any time
(the template data overwrites that Page's photos / background / style /
background color, never its handwriting strokes); jump to the v2 editor at
any time; apply one template to every page of a document at once. Still
standalone and offline — no network needed to test.

## v4 — Networked social

Pen pals, feed, publishing. First stage that requires the network.

## v5 — iPad device adaptation

Stationery and handwriting adapt across iPad screen sizes — iPad 8th
generation and newer real devices; testing expands to multiple sizes.
Cross-device then needs no dedicated work: one account on different-sized
iPads displays correctly.

This is also the stage that revisits device-orientation flexibility. v1
locks each document to its paper's orientation (portrait paper →
portrait UI; landscape paper → landscape UI); v5 evaluates whether to
relax that lock — for example, by allowing the Social Screen to
support both orientations on iPads with attached keyboards, or by
introducing a "wide letter" paper preset for landscape-only iPad
setups. Any relaxation must preserve the v1 guarantee that handwriting
layout never reflows.

## v6 — Networked content moderation

Server-side review of shared content.
