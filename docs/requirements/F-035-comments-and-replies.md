# F-035 Comments and Replies

The user posts comments and threaded replies on a post.

## Flow

When user opens a post:
- S-005 FeedService returns its comments.
- The post view shows U-071 CommentList with each comment as a U-073 CommentItem.

When user types in U-072 CommentInput and submits:
- S-005 FeedService creates the comment.
- A new U-073 CommentItem is appended to U-071 CommentList.

When user taps "reply" on a U-073 CommentItem:
- U-072 CommentInput attaches to that comment as a reply context.
- On submit, S-005 FeedService creates the reply nested under the parent.
