# F-037 Push Notifications

The user receives push alerts for likes, comments, new follows, and other relevant events.

## Flow

When user signs in:
- C-024 PushNotificationHandler requests notification permission.
- On grant, C-024 PushNotificationHandler registers the device token with S-006 NotificationDispatcher.

When a relevant event occurs on the backend (like, comment, follow, mention):
- S-006 NotificationDispatcher sends an APNs payload to the user's devices.

When the user taps a delivered notification:
- App opens to the relevant screen (post, profile, comment thread).
