# F-051 Multi-page Stationery and Page Turning

A document is an ordered sequence of stationery pages. The user adds pages,
turns between them, and removes pages. Each page is a fixed sheet — it
cannot be zoomed, scaled, or panned.

## Flow

When user opens a document:
- App loads the document's ordered pages and shows the first one.
- U-093 PageIndicator shows the current position (e.g. "1 / 3").

When user operates U-094 PageTurnControl to go to the next or previous page:
- App shows the adjacent page. No zoom or pan — each page is a fixed sheet.
- U-093 PageIndicator updates to the new position.

When user taps U-095 AddPageButton:
- App opens F-050 Create Single-page Personalized Stationery for the new
  page. On generation, the new page is appended after the current one.

When user taps U-096 RemovePageButton:
- App confirms, then removes the current page and shows an adjacent one.
- U-093 PageIndicator updates.
