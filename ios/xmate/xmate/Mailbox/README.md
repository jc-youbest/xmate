# Mailbox — letter and mailbox data coordination

## Responsibilities

- Own the `LetterEnvelope` domain/header value and stable envelope/document
  UUID association.
- Own the four fixed system mailbox locations: Inbox, Drafts, Outbox, and Sent.
- Define legal local envelope transitions without inventing remote delivery.
- Resolve Envelope metadata against the local Document cache by UUID and
  revision, returning typed hit/missing/stale/invalid results.
- Coordinate future mailbox-manifest and Document-payload sources behind a
  repository boundary. F-062 provides local behavior only.
- Return stable value snapshots and typed results to App and Library; never
  expose navigation side effects.

Flow mechanisms and rejected alternatives live only in
`docs/architecture.md` (Document envelope boundary and Mailbox component
coordination).

## Key files

- `Model/LetterEnvelope.swift` — envelope/header value and UUID association
- `Model/MailboxLocation.swift` — four fixed mailbox locations
- `Model/DeliveryState.swift` — minimal local transport vocabulary
- `Resolution/MailboxDocumentCacheResolution.swift` — pure cache resolution
- `Repository/LocalMailboxRepository.swift` — Storage record decoding, fixed
  mailbox queries, and local envelope/Document cache resolution
- `Transition/MailboxTransitionPolicy.swift` — legal local state changes

## Not responsible for

- SwiftUI sidebar/list presentation (Library).
- App navigation, workspace composition, orientation policy, or Editor
  injection (App).
- Document editing, viewport state, PencilKit, or ToolPicker behavior (Editor).
- Send Form UI and recipient/send eligibility (Social).
- Core Data schema/migration mechanics or drawing persistence (Storage).
- Authentication, networking, sync, retry workers, or remote delivery in
  F-062.

## Next step (current stage)

- Keep the completed local repository stable while App and Library add the
  mailbox workspace presentation; add no remote behavior in F-062.

## Notes for AI changes

- Keep Mailbox non-UI and mailbox-specific; do not turn it into a generic
  backend or navigation component.
- Editor must remain mailbox-blind. App is the only integration point that can
  resolve an envelope and inject a validated Document.
- Store one envelope record and query by `mailboxLocation`; never create one
  table or copy per visible list.
- A local Send action may queue an eligible Draft into Outbox but must not
  claim remote success or move it to Sent.
- Do not place envelope types in Shared merely because App, Library, and
  Storage exchange stable ids or persistence values.
