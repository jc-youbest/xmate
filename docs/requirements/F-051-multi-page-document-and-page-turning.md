# F-051 Multi-page Document and Page Turning

The document is an ordered sequence of pages; the user turns between them,
adds pages, and removes pages. U-101 WritingScreen is the writing variant
of the Content Screen and one of v1's two top-level screens (alongside
U-106 SocialScreen — see F-055).

## Flow

When user opens U-101 WritingScreen:
- C-001 NoteStore loads the document's ordered pages and shows the first.
- U-023 Canvas renders that page.
- U-093 PageIndicator on U-102 WritingTopBar shows the position, e.g. "1 / 3".

When user swipes up on U-101 WritingScreen and a next page exists:
- C-001 NoteStore flushes the current page's pending strokes.
- U-023 Canvas turns to the next page; U-093 PageIndicator updates.
  (The swipe is a finger gesture; only Apple Pencil draws, so it never
  conflicts with handwriting.)

When user swipes down on U-101 WritingScreen and a previous page exists:
- C-001 NoteStore flushes the current page's pending strokes.
- U-023 Canvas turns to the previous page; U-093 PageIndicator updates.

When user taps U-095 AddPageButton on U-102 WritingTopBar:
- C-001 NoteStore appends a new blank page after the current page.
- U-023 Canvas turns to the new page; U-093 PageIndicator updates.

When user taps U-107 BackToSocialButton on U-102 WritingTopBar:
- C-001 NoteStore flushes the current page's pending strokes.
- The app transitions to U-106 SocialScreen (F-055). The current document
  remains intact; opening it again returns to the same page.

When user opens U-103 WritingOverflowMenu on U-102 WritingTopBar:
- The menu offers "delete page" and "delete document". "delete page" is
  disabled when the document has only one page.

When user picks "delete page" in U-103 WritingOverflowMenu:
- App asks for confirmation.
- On confirm, C-001 NoteStore removes the current page and shows an
  adjacent page; U-093 PageIndicator updates.

When user picks "delete document" in U-103 WritingOverflowMenu:
- The flow continues in F-011 Note CRUD.

## Notes

In v1, U-095 AddPageButton appends a blank page. Adding a page from a
saved stationery — the "compose new / load from library" path — returns
with the stationery model in roadmap v2.

## Implementation Status

The multi-page core (page turning, add page, delete page, delete
document) was implemented in the v1 first increment. The
U-107 BackToSocialButton flow is **not yet implemented** — it lands
with F-055 Social Screen v1 Stub when the second top-level screen is
introduced.

Key decisions from the implemented core:

- **WritingScreen (U-101)**: new `WritingScreen.swift`; `ContentView` is
  now a thin shell that hosts it. The screen manages `[Page]` and
  `currentPageIndex` as `@State`.

- **Page identity**: `PencilKitBridge` is keyed with `.id(page.id)` (the
  page's UUID). A page turn creates a fresh `PKCanvasView` loaded from
  Core Data. `dismantleUIView` flushes pending strokes before teardown so
  no drawing is lost on a fast swipe.

- **Swipe gestures**: two `UISwipeGestureRecognizer`s (.up, .down) are
  added to the `PKCanvasView` with `allowedTouchTypes = [.direct]`
  (finger only). `drawingPolicy = .pencilOnly` means finger touches never
  draw, so the two systems never conflict.

- **Slide transition**: `WritingScreen` applies an `.asymmetric(.move)`
  transition driven by a `turningForward` flag, giving a vertical page-
  slide animation (0.18 s ease-in-out).

- **Delete document (v1 stub)**: resets the document to a single blank
  page instead of navigating to a note list. Will be replaced by F-011
  navigation in v3.

- **NoteStore additions**: `pages(of:)`, `appendPage(to:)`,
  `deletePage(_:from:)`, `resetDocument(_:)`.
