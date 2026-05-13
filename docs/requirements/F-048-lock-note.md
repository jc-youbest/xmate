# F-048 Lock Note

The user locks a note behind Face ID, Touch ID, or device passcode.

## Flow

When user taps U-043 LockNoteButton on U-011 EditorTopBar:
- App requests biometric or passcode confirmation via the system.
- On success, C-012 NoteLockService marks the note as locked and encrypts its content at rest.

When user taps a locked U-009 NoteListItem on U-008 NoteList:
- App shows U-044 UnlockDialog and triggers biometric or passcode auth.
- On success, C-012 NoteLockService decrypts the note and the editor opens.
- On failure or cancel, the note stays locked.

When user taps U-043 LockNoteButton on an already-locked note:
- After biometric confirmation, C-012 NoteLockService removes the lock and decrypts content.
