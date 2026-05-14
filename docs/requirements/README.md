# Features

The complete feature inventory for xmate. One file per feature.

Features are listed in approximate build order — foundations first, then
the social layer on top — but nothing forces this order; the developer may
pick any unblocked feature next.

New features get a new `F-XXX` and a file copied from
[`_template.md`](_template.md).

ID scheme: F-XXX, monotonic, never reused. Withdrawn IDs are not reissued —
gaps in the sequence are normal.

Status legend: `_not yet written_` < `(Draft)` < `(In Design)` < `(Implemented)` < `(Shipped)`. Terminal states (off the progression): `(Deprecated)`, `(Cancelled)`.

## Foundation — Local Handwriting & Notes

- F-001 Handwriting canvas — [`F-001-handwriting-canvas.md`](F-001-handwriting-canvas.md) (In Design)
- F-002 Pen tools — [`F-002-pen-tools.md`](F-002-pen-tools.md) (Draft)
- F-003 Color picker — [`F-003-color-picker.md`](F-003-color-picker.md) (Draft)
- F-004 Stroke thickness — [`F-004-stroke-thickness.md`](F-004-stroke-thickness.md) (Draft)
- F-005 Eraser — [`F-005-eraser.md`](F-005-eraser.md) (Draft)
- F-006 Lasso selection — [`F-006-lasso-selection.md`](F-006-lasso-selection.md) (Draft)
- F-007 Undo / redo — [`F-007-undo-redo.md`](F-007-undo-redo.md) (Draft)
- F-008 Canvas zoom and pan — [`F-008-canvas-zoom-and-pan.md`](F-008-canvas-zoom-and-pan.md) (Cancelled)
- F-009 Multi-page note — [`F-009-multi-page-note.md`](F-009-multi-page-note.md) (Deprecated — see F-051)
- F-010 Paper styles — [`F-010-paper-styles.md`](F-010-paper-styles.md) (Deprecated — see F-050)
- F-011 Note CRUD — [`F-011-note-crud.md`](F-011-note-crud.md) (Draft)
- F-012 Folder organization — [`F-012-folder-organization.md`](F-012-folder-organization.md) (Draft)
- F-013 Tags — [`F-013-tags.md`](F-013-tags.md) (Draft)
- F-014 Title and tag search — [`F-014-title-and-tag-search.md`](F-014-title-and-tag-search.md) (Draft)
- F-015 Handwriting search — [`F-015-handwriting-search.md`](F-015-handwriting-search.md) (Draft)
- F-016 Export to PDF — [`F-016-export-to-pdf.md`](F-016-export-to-pdf.md) (Draft)
- F-017 Export to image — [`F-017-export-to-image.md`](F-017-export-to-image.md) (Draft)
- F-018 Settings — [`F-018-settings.md`](F-018-settings.md) (Draft)
- F-047 Insert image into note — [`F-047-insert-image-into-note.md`](F-047-insert-image-into-note.md) (Deprecated — see F-050)
- F-048 Lock note — [`F-048-lock-note.md`](F-048-lock-note.md) (Draft)
- F-049 Note thumbnail — [`F-049-note-thumbnail.md`](F-049-note-thumbnail.md) (Draft)
- F-050 Create single-page personalized stationery — [`F-050-create-single-page-personalized-stationery.md`](F-050-create-single-page-personalized-stationery.md) (Draft)
- F-051 Multi-page stationery and page turning — [`F-051-multi-page-stationery-and-page-turning.md`](F-051-multi-page-stationery-and-page-turning.md) (Draft)

## Account & Cloud

Uses the custom backend, not iCloud / CloudKit.

- F-020 User sign-in (Apple / Google / Facebook / X) — [`F-020-user-sign-in.md`](F-020-user-sign-in.md) (Draft)
- F-021 User profile — [`F-021-user-profile.md`](F-021-user-profile.md) (Draft)
- F-022 Account settings (sign out, delete account) — [`F-022-account-settings.md`](F-022-account-settings.md) (Draft)
- F-023 Cross-device note sync — [`F-023-cross-device-sync.md`](F-023-cross-device-sync.md) (Draft)

## Pen Pal Social

- F-024 Add pen pal / follow — [`F-024-add-pen-pal.md`](F-024-add-pen-pal.md) (Draft)
- F-025 Pen pal list — [`F-025-pen-pal-list.md`](F-025-pen-pal-list.md) (Draft)
- F-026 Publish note as post — [`F-026-publish-note-as-post.md`](F-026-publish-note-as-post.md) (Draft)
- F-027 Pen pal feed — [`F-027-pen-pal-feed.md`](F-027-pen-pal-feed.md) (Draft)
- F-028 Profile page — [`F-028-profile-page.md`](F-028-profile-page.md) (Draft)
- F-029 Discover / explore — [`F-029-discover-explore.md`](F-029-discover-explore.md) (Draft)

## Sharing & Export

- F-030 System share sheet integration — [`F-030-system-share-sheet.md`](F-030-system-share-sheet.md) (Draft)
- F-031 Read-only share link — [`F-031-read-only-share-link.md`](F-031-read-only-share-link.md) (Draft)
- F-032 Watermark and signature — [`F-032-watermark-and-signature.md`](F-032-watermark-and-signature.md) (Draft)
- F-033 Handwriting playback export — [`F-033-handwriting-playback-export.md`](F-033-handwriting-playback-export.md) (Draft)

## Interaction

- F-034 Like — [`F-034-like.md`](F-034-like.md) (Draft)
- F-035 Comments and replies — [`F-035-comments-and-replies.md`](F-035-comments-and-replies.md) (Draft)
- F-036 Bookmark — [`F-036-bookmark.md`](F-036-bookmark.md) (Draft)
- F-037 Push notifications — [`F-037-push-notifications.md`](F-037-push-notifications.md) (Draft)

## Safety & Moderation

- F-038 Privacy controls — [`F-038-privacy-controls.md`](F-038-privacy-controls.md) (Draft)
- F-039 Block user — [`F-039-block-user.md`](F-039-block-user.md) (Draft)
- F-040 Report content — [`F-040-report-content.md`](F-040-report-content.md) (Draft)
- F-041 Moderation pipeline — [`F-041-moderation-pipeline.md`](F-041-moderation-pipeline.md) (Draft)

## Optional / Stretch

- F-042 Handwriting playback viewing — [`F-042-handwriting-playback-viewing.md`](F-042-handwriting-playback-viewing.md) (Draft)
- F-043 Collaborative notes — [`F-043-collaborative-notes.md`](F-043-collaborative-notes.md) (Draft)
- F-045 Themed events — [`F-045-themed-events.md`](F-045-themed-events.md) (Draft)
- F-046 Drift bottle — [`F-046-drift-bottle.md`](F-046-drift-bottle.md) (Draft)
