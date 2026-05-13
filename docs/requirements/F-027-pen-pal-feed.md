# F-027 Pen Pal Feed

The user sees recent posts from people they follow.

## Flow

When user opens U-063 FeedScreen:
- S-005 FeedService returns recent posts from followed users.
- U-063 FeedScreen displays each post as a U-064 FeedItem.

When user pulls to refresh U-063 FeedScreen:
- S-005 FeedService returns fresher posts since the last fetch.

When user taps a U-064 FeedItem:
- App opens a full-screen view of the post's pages.
