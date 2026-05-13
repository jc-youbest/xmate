# F-038 Privacy Controls

The user controls who can see their posts and profile.

## Flow

When user opens U-075 PrivacySection on U-025 SettingsScreen:
- The section shows: default post visibility (private / pen pals / public), profile visibility (pen pals / public), and a search-discoverability toggle.

When user changes any privacy setting:
- S-002 UserProfileAPI persists the choice.
- Future posts and profile responses honor the new setting.
