# F-034 Like

The user likes a post in the feed.

## Flow

When user taps U-070 LikeButton on a U-064 FeedItem:
- S-005 FeedService records the like for the post.
- U-070 LikeButton updates to a "liked" state and increments the count.

When user taps an already-liked U-070 LikeButton:
- S-005 FeedService removes the like.
- U-070 LikeButton reverts.
