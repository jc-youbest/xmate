# F-046 Drift Bottle

The user can send a handwritten note to a random anonymous recipient and may receive bottles in return.

## Flow

When user taps U-083 DriftBottleButton from U-040 ExportFormatMenu after finishing a note:
- App confirms the recipient will be a stranger.
- S-004 NoteShareAPI sends the note into the drift bottle pool.

When user opens U-084 DriftBottleScreen:
- S-005 FeedService returns any bottles addressed to this user.
- The screen displays them one at a time.

When user replies to a bottle:
- The reply goes back to the original sender as another bottle (sender remains anonymous to the receiver).

## Notes

Anonymity rules and abuse prevention (rate limits, reportability) need careful design.
