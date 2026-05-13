# F-022 Account Settings

The user signs out or permanently deletes their account.

## Flow

When user opens U-052 AccountSection on U-025 SettingsScreen:
- The section shows U-053 SignOutButton and U-054 DeleteAccountButton.

When user taps U-053 SignOutButton:
- C-010 SessionManager clears the local session.
- App navigates to U-045 WelcomeScreen.

When user taps U-054 DeleteAccountButton:
- App confirms with a strong warning.
- S-002 UserProfileAPI permanently deletes the user's account and content.
- C-010 SessionManager clears the local session.
- App navigates to U-045 WelcomeScreen.
