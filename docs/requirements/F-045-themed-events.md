# F-045 Themed Events

xmate runs periodic prompts ("character of the day", "weekly haiku") that users can write to and publish.

## Flow

When a new event is active:
- S-005 FeedService returns the event metadata to the app.
- U-002 NoteListScreen shows U-081 EventBanner at the top.

When user taps U-081 EventBanner:
- App opens U-082 EventScreen with the prompt and a "join" call to action.

When user taps "join" on U-082 EventScreen:
- C-001 NoteStore creates a new note tagged with this event.
- App navigates to U-010 NoteEditorScreen.

When the user publishes the resulting note (F-026):
- The post is automatically associated with the event.
