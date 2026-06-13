# Backlog

The future-feature pool. One line per feature — detailed flow specs are
written only when a feature is about to be built, and live as working
notes in the owning module's README or the commit history.

Historical F-XXX IDs are kept for traceability (they appear in old
commits). Numbering is monotonic; never reuse an ID; allocate new ones
here. Gaps are normal (withdrawn IDs).

## Done (v0–v1)

- F-051 Multi-page document and page turning
- F-053 Page geometry and zoom (300% cap, HUD, dual reset)
- F-056 Pagination style (Single Page / Continuous, global preference)

## v1 remainder

- F-054 Insert media while writing — Apple-Notes-like attachments that
  move/scale/delete anytime and zoom with the page
- F-055 Social Screen v1 stub — structural shell + explicit switching
  with the Content Screen
- Reading Mode — read-only Content Screen variant sharing the layout

## v2 — Stationery (editor + library modules)

- F-050 Create single-page personalized stationery — compose background
  color / line style / photo frames, then one-way Generate
- F-052 Stationery library — browse, pick, rename, delete locked
  stationery; publish/apply templates per roadmap v2/v3

## v3 — Library module (personal document manager)

- F-011 Document CRUD (list, create, rename, duplicate, delete)
- F-012 Folder organization · F-013 Tags · F-014 Title/tag search ·
  F-015 Handwriting search
- F-048 Lock note (biometric) · F-049 Document thumbnails
- Inbox / drafts / sent letters views feeding documents into the editor

## v3+/v4 — Account & social

- F-018 Settings UI · F-020 Social sign-in (Apple/Google/Facebook/X) ·
  F-021 User profile · F-022 Account settings · F-023 Cross-device sync
  (custom backend, not CloudKit)
- F-024 Add pen pal · F-025 Pen pal list · F-026 Publish document as
  post · F-027 Feed · F-028 Profile page · F-029 Discover
- F-030 Share sheet · F-031 Read-only share link · F-032 Watermark /
  signature · F-033 Playback export
- F-034 Like · F-035 Comments · F-036 Bookmark · F-037 Push
  notifications
- F-038 Privacy controls · F-039 Block · F-040 Report · F-041 Moderation
  pipeline (v6 server side)
- Reserved backend modules (S-XXX, designed when their features start):
  S-001 AuthService (verify OAuth tokens from Apple/Google/Facebook/X) ·
  S-002 UserProfileAPI · S-003 NoteSyncAPI · S-004 NoteShareAPI ·
  S-005 FeedService · S-006 NotificationDispatcher (APNs) ·
  S-007 ModerationService

## Stretch

- F-042 Playback viewing · F-043 Collaborative documents · F-045 Themed
  events · F-046 Drift bottle

## Retired / superseded

- F-001–F-007 pen tool features — covered by the system PKToolPicker
- F-008 canvas zoom/pan (cancelled) · F-009 multi-page note (→ F-051) ·
  F-010 paper styles (→ F-050) · F-016/F-017 export to PDF/image
  (re-spec when sharing is designed) · F-047 insert image (→ F-050)
