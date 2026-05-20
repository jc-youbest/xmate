# Roadmap

The development path as a sequence of stages. Each stage is a standalone,
testable iOS build. This plan is living — revised whenever direction changes.

Stage labels (v0, v1, ...) belong to the project, not to any single
feature. Per-feature progress is the status field in requirements/README.md.

## v0 — Local blank-page writing

App opens straight into the writing surface. The user can write with Apple
Pencil; strokes persist and reload across launches. A document is
multi-page — add pages, turn pages, delete a page, delete the whole
document. Every page background is blank: no template, no image, no theme.
The stored data is already the multi-page document structure; pages simply
carry no stationery content yet.

## v1 — Personalized stationery template editor

App opens into a stationery editing UI. The user composes a single-page
template:
- load multiple images, each freely rotatable, scalable, and placeable
  anywhere on the page (overlay elements);
- set a background — a solid color, a full-screen background photo, or a
  theme (postcard, ruled notebook, grid notebook). A background photo is
  NOT an overlay image: it can only be stretched / filled to the full page.
  A theme is treated as a special background image, possibly a vector.

A template can be saved locally while editing. Its data structure is
identical to a single Page of a v0 document, minus the handwriting. When
done, a template can be published; a published template can be loaded in
writing mode as the page background, with handwriting allowed on top.
Publishing = copying the template's Page-shaped data into a Page of a
writing-mode Document.

## v2 — Main interface, offline

App opens into a main interface. The user can: view handwritten letters
shared by others (faked with local test data for now — exact design TBD);
browse stationery templates others shared publicly; open the v0 writing
surface; while writing, swap a different template into any page at any
time (the template data overwrites that Page's photos / background / style
/ background color, never its handwriting strokes); jump to the v1 editor
at any time; apply one template to every page of a document at once.
Still standalone and offline — no network needed to test.

## v3 — Networked social

Pen pals, feed, publishing. First stage that requires the network.

## v4 — iPad device adaptation

Stationery and handwriting adapt across iPad screen sizes — iPad 8th
generation and newer real devices; testing expands to multiple sizes.
Cross-device then needs no dedicated work: one account on different-sized
iPads displays correctly.

## v5 — Networked content moderation

Server-side review of shared content.
