# F-052 Stationery Library

The library holds locked stationery the user has composed (F-050). Saved
stationery can be reused as the basis for new pages (F-051) instead of
composing from scratch each time.

## Flow

When user opens U-098 StationeryLibraryScreen:
- App lists every locked stationery as a U-099 StationeryLibraryItem,
  each showing a preview.

When user picks a U-099 StationeryLibraryItem via F-051's "load from
library" path:
- The selected locked stationery is returned to F-051, which copies it
  into the document as a new page.

When user long-presses a U-099 StationeryLibraryItem:
- App shows U-100 StationeryLibraryItemMenu with: rename, delete.

When user picks "delete" in U-100 StationeryLibraryItemMenu:
- App confirms, then removes the stationery from the library. Documents
  that already used it are unaffected — each page holds its own copy.

## Notes

Sharing locked stationery with other users is a planned future extension
(it is part of why locked stationery is persisted independently), but is
out of scope for this feature as written.
