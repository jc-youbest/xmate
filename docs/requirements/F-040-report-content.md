# F-040 Report Content

The user reports a post or profile that violates community rules.

## Flow

When user taps U-077 ReportButton on a U-064 FeedItem or U-048 ProfileScreen:
- App shows U-078 ReportDialog with reason categories.

When user submits a reason in U-078 ReportDialog:
- S-007 ModerationService records the report.
- App shows a "thanks, we'll review it" confirmation.
