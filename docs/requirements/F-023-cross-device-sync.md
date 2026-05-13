# F-023 Cross-device Note Sync

Notes created or modified on one device appear on the user's other devices via the custom backend.

## Flow

When user creates or modifies a note locally:
- C-001 NoteStore writes to local storage.
- C-022 SyncEngine enqueues the change for upload.

When app has network and a valid session:
- C-022 SyncEngine pushes pending changes to S-003 NoteSyncAPI.
- C-022 SyncEngine pulls remote changes since the last sync cursor.
- C-001 NoteStore merges the remote changes locally.
- U-055 SyncStatusIndicator on U-002 NoteListScreen reflects sync state (synced, syncing, offline).

When user opens U-002 NoteListScreen:
- C-022 SyncEngine triggers a pull to ensure freshness.
