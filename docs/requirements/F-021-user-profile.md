# F-021 User Profile

Each user has a public profile: handle, avatar, short bio.

## Flow

When user opens U-048 ProfileScreen from U-025 SettingsScreen:
- S-002 UserProfileAPI fetches the profile.
- U-048 ProfileScreen shows U-049 AvatarView, handle, and U-050 BioField.

When user taps U-051 EditProfileButton on U-048 ProfileScreen:
- U-049 AvatarView, handle, and U-050 BioField become editable.
- On save, S-002 UserProfileAPI persists the new values.
