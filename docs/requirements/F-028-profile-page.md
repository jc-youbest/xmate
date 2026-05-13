# F-028 Profile Page

The user views any user's public profile and their public posts.

## Flow

When user navigates to U-048 ProfileScreen of another user:
- S-002 UserProfileAPI fetches that user's profile.
- S-005 FeedService fetches that user's public posts.
- U-048 ProfileScreen shows U-049 AvatarView, handle, bio, and U-065 ProfilePostsList.

When user taps a post in U-065 ProfilePostsList:
- App opens that post for viewing.
