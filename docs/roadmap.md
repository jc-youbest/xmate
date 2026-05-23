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
and an overflow menu for destructive actions; the system tool picker stays
at the bottom.

The page follows device rotation and supports whole-page zoom. Handwriting —
and, in later stages, any stationery background — scales together, so a
filled line stays one line across orientations and zoom levels. The page is
still one bounded sheet, never an infinite canvas.

The user can add media attachments while writing. The add-image experience
matches Apple Notes. These writing-mode attachments — distinct from the
photos placed in stationery mode (v2) — can be moved, scaled, and deleted at
any time, and rotate together with the page.

A left sidebar appears, reserved for later features (letter history,
received letters, sent letters, and so on). For now it is a structural
placeholder; the requirement is that the writing-page zoom and layout
integrate cleanly with it — the page rescales to the area the sidebar leaves
free.

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

## v6 — Networked content moderation

Server-side review of shared content.
