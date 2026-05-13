# F-033 Handwriting Playback Export

The user exports the writing process of a page as a video or animated GIF — strokes appear in the order they were drawn.

## Flow

When user taps U-069 ExportPlaybackButton from U-040 ExportFormatMenu on a page:
- C-025 PlaybackRecorder reads per-stroke timing data stored with the page.
- C-026 PlaybackRenderer renders the strokes appearing in order to a video or GIF.
- App presents the result via the system share sheet (see F-030).
