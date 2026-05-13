# F-025 Pen Pal List

The user views who they follow and who follows them.

## Flow

When user opens U-059 PenPalListScreen:
- S-002 UserProfileAPI returns the list of pen pals (following and followers).
- The screen shows each pen pal as a U-060 PenPalListItem.

When user taps a U-060 PenPalListItem:
- App navigates to U-048 ProfileScreen of that user.
