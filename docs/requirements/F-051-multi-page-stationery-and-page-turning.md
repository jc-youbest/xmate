# F-051 Multi-page Stationery and Page Turning

A document is an ordered sequence of pages. Each page is a fixed sheet — a
locked stationery plus handwriting — that cannot be zoomed, scaled, or
panned. The user adds pages, turns between them, and removes pages.

## Flow

When user opens a document:
- App loads the document's ordered pages and shows the first one.
- U-093 PageIndicator shows the current position (e.g. "1 / 3").

When user operates U-094 PageTurnControl to go to the next or previous page:
- App shows the adjacent page. No zoom or pan — each page is a fixed sheet.
- U-093 PageIndicator updates.

When user taps U-095 AddPageButton:
- App shows U-097 AddPageSourceMenu offering two paths: compose a new
  stationery, or load one from the library.

When user picks "compose new" in U-097 AddPageSourceMenu:
- App opens F-050 Create Single-page Personalized Stationery.
- When F-050 produces a locked stationery, the flow continues below.

When user picks "load from library" in U-097 AddPageSourceMenu:
- App opens F-052 Stationery Library to pick a locked stationery.
- When the user picks one, the flow continues below.

When a locked stationery has been chosen by either path:
- It is deep-copied — with its image assets — into the document as a new
  page, appended after the current one. The copy means later changes to
  the library item never affect this page.
- The page enters write phase: handwriting (F-001) is enabled on it; its
  stationery is frozen.

When user taps U-096 RemovePageButton:
- App confirms, then removes the current page and shows an adjacent one.
- U-093 PageIndicator updates.
