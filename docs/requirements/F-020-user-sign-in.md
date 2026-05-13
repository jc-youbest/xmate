# F-020 User Sign-in

The user signs in to xmate with Apple, Google, Facebook, or X.

## Flow

When app launches with no active session:
- App shows U-045 WelcomeScreen with U-046 SignInButton.

When user taps U-046 SignInButton:
- App shows U-047 ProviderPicker listing Apple, Google, Facebook, X.

When user taps a provider in U-047 ProviderPicker:
- C-023 AuthClient initiates the provider's OAuth flow.
- On success, S-001 AuthService verifies the OAuth token with the backend.
- S-002 UserProfileAPI returns or creates the user's profile.
- C-010 SessionManager stores the session token locally.
- App navigates to U-002 NoteListScreen.

When OAuth fails or the user cancels:
- App returns to U-045 WelcomeScreen with an inline error message.
