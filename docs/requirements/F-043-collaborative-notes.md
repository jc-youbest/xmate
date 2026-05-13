# F-043 Collaborative Notes

Two or more pen pals can edit the same note in real time. Highly experimental; subject to large design changes.

## Flow

When user invites a pen pal to a note:
- S-003 NoteSyncAPI marks the note as shared and notifies the invitee.

When two users open the shared note simultaneously:
- C-022 SyncEngine establishes a real-time channel via the backend.
- Each user's strokes appear on the other's U-023 Canvas with brief delay.
- Cursor presence (where each collaborator is writing) is shown on U-023 Canvas.

## Notes

Real-time consistency strategy (CRDT vs OT vs locked-page model) is unresolved.
