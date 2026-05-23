# F-053 Page Rotation and Zoom

The page follows device rotation and can be zoomed, rescaling to fit the
available area without distorting its layout.

## Flow

When user rotates the iPad:
- The page re-fits to the new orientation. Handwriting and page content
  scale together uniformly, so the layout is preserved — a line filled in
  one orientation stays one line in the other.

When user zooms the page:
- The whole page scales as a single unit — handwriting and, in later
  stages, the stationery background scale together. The page stays one
  bounded sheet; this is not free panning of an infinite canvas.

When the writing-mode sidebar is shown or hidden:
- The page re-fits to the area the sidebar leaves free, using the same
  uniform scaling.

## Notes

The page is one fixed-size logical sheet; rotation, zoom, and the sidebar
only change how that fixed sheet is scaled onto the screen — the sheet's
own dimensions never change.
