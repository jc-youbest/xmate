# F-042 Handwriting Playback Viewing

The viewer of a post can watch the writing process — strokes appear in the original order they were drawn.

## Flow

When user opens a post from U-063 FeedScreen or U-067 ExploreGrid:
- If playback data is available, the post view shows U-080 PlaybackPlayButton.

When user taps U-080 PlaybackPlayButton:
- U-079 PlaybackPlayer overlays the post view and replays strokes in original order via C-026 PlaybackRenderer.

When user taps U-079 PlaybackPlayer mid-play:
- Playback pauses and exposes scrubbing controls.
