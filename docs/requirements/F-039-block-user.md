# F-039 Block User

The user prevents another user from interacting with them or seeing their content.

## Flow

When user taps U-076 BlockUserButton on another user's U-048 ProfileScreen:
- App confirms the action.
- S-002 UserProfileAPI records the block.
- The blocked user can no longer view this user's posts, comment, or follow them.

When user opens the blocked-users list under U-075 PrivacySection:
- S-002 UserProfileAPI returns the list of blocked users.
- User can unblock any of them.
