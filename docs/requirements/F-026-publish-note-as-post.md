# F-026 Publish Note as Post

The user publishes a note (or a single page) to the public feed.

## Flow

When user taps U-014 ShareButton on U-011 EditorTopBar:
- App shows U-040 ExportFormatMenu, which includes U-061 PublishButton.

When user taps U-061 PublishButton:
- App shows U-062 PublishConfirmDialog with a preview and an optional caption.

When user confirms in U-062 PublishConfirmDialog:
- C-005 ExportEngine renders the post payload.
- S-004 NoteShareAPI uploads the note as a public post.
- The post appears in U-063 FeedScreen for the user's followers.
