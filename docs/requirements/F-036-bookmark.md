# F-036 Bookmark

The user saves a post for later viewing in their personal bookmark list.

## Flow

When user taps U-074 BookmarkButton on a U-064 FeedItem:
- S-005 FeedService records the bookmark for this user.
- U-074 BookmarkButton updates to a "bookmarked" state.

When user opens the "Bookmarks" entry from U-025 SettingsScreen or U-048 ProfileScreen:
- S-005 FeedService returns the user's bookmarked posts.
- The screen lists them similarly to U-063 FeedScreen.
