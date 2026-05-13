# F-024 Add Pen Pal / Follow

The user follows another user to see their public posts in the feed.

## Flow

When user opens U-056 PenPalSearchScreen:
- The screen shows U-057 PenPalSearchField.

When user types in U-057 PenPalSearchField:
- S-002 UserProfileAPI searches users by handle or display name.
- The screen lists matching users.

When user taps U-058 AddPenPalButton next to a user:
- S-002 UserProfileAPI creates a follow relationship.
- U-058 AddPenPalButton changes to a "following" state.
