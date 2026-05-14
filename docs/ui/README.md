# UI Tree

The containment hierarchy of UI elements in the iOS app. This document
defines *what contains what* — not *where things are placed* or *what they
look like*. Layout, position, color, and visual style are decided per
feature and in a separate style guide later.

Features reference UI nodes by ID. Whenever a feature needs a UI element
that does not exist here, add it here first.

ID scheme: U-XXX, monotonic, never reused. A short inline description is
optional; omit when the name is self-explanatory.

## Tree

- U-001 AppRoot
  - U-045 WelcomeScreen — shown when no active session
    - U-046 SignInButton
    - U-047 ProviderPicker — modal listing Apple / Google / Facebook / X
  - U-002 NoteListScreen — browses all notes
    - U-003 NoteListToolbar
      - U-004 SearchField
      - U-005 NewNoteButton
    - U-006 FolderSidebar
      - U-007 FolderItem
      - U-034 NewFolderButton
      - U-035 FolderContextMenu — modal: rename, delete, move
    - U-008 NoteList
      - U-009 NoteListItem — title plus thumbnail (see F-049)
      - U-032 NoteContextMenu — modal: rename, duplicate, delete, move
      - U-033 RenameNoteDialog — modal
      - U-036 MoveNoteToFolderDialog — modal
    - U-055 SyncStatusIndicator
    - U-081 EventBanner — surfaces an active themed event
  - U-010 NoteEditorScreen
    - U-011 EditorTopBar
      - U-012 BackButton
      - U-013 NoteTitleField
      - U-014 ShareButton
        - U-040 ExportFormatMenu — modal: PDF, PNG, JPEG, publish, link, playback, drift bottle
          - U-061 PublishButton — entry into publishing flow
            - U-062 PublishConfirmDialog — modal preview and caption
          - U-068 CopyLinkButton
          - U-069 ExportPlaybackButton
          - U-083 DriftBottleButton — entry into drift bottle send
      - U-037 TagsField
        - U-038 TagPicker — modal
        - U-039 TagBadge
      - U-043 LockNoteButton
        - U-044 UnlockDialog — modal biometric prompt
    - U-015 PenToolbar
      - U-016 PenToolPicker
      - U-017 ColorPicker
      - U-018 ThicknessSlider
      - U-019 EraserButton
        - U-026 EraserModeMenu — pixel / stroke
      - U-020 LassoButton
        - U-027 LassoActionMenu — appears after selection: move, scale, copy, delete
      - U-021 UndoButton
      - U-022 RedoButton
      - U-041 InsertImageButton
    - U-023 Canvas — active drawing surface
      - U-042 ImageOverlay — image layer beneath strokes
    - U-024 PageNavigator
      - U-028 PageThumbnail
        - U-030 PageContextMenu — modal: delete, duplicate, reorder
      - U-029 AddPageButton
    - U-031 PaperStylePicker — modal: blank / ruled / grid / dot
  - U-025 SettingsScreen
    - U-052 AccountSection
      - U-053 SignOutButton
      - U-054 DeleteAccountButton
    - U-075 PrivacySection
      - U-076 BlockUserButton — within blocked-users list
  - U-048 ProfileScreen — own profile (editable) or other user's (read-only)
    - U-049 AvatarView
    - U-050 BioField
    - U-051 EditProfileButton
    - U-065 ProfilePostsList
    - U-077 ReportButton — only on other users' profiles
      - U-078 ReportDialog — modal reason picker
  - U-056 PenPalSearchScreen
    - U-057 PenPalSearchField
    - U-058 AddPenPalButton
  - U-059 PenPalListScreen
    - U-060 PenPalListItem
  - U-063 FeedScreen
    - U-064 FeedItem
      - U-070 LikeButton
      - U-074 BookmarkButton
      - U-071 CommentList
        - U-073 CommentItem
      - U-072 CommentInput
      - U-077 ReportButton — also available on posts
      - U-080 PlaybackPlayButton
        - U-079 PlaybackPlayer — overlay
  - U-066 DiscoverScreen
    - U-067 ExploreGrid
  - U-082 EventScreen — details of an active themed event
  - U-084 DriftBottleScreen — inbox of received bottles
  - U-085 StationeryComposerScreen — compose phase of a stationery page (F-050)
    - U-086 BackgroundColorPicker
    - U-087 LineStylePicker — blank / ruled / grid / dot
    - U-088 LayoutPresetPicker — none / photo-left / photo-right / photo-top / photo-bottom
    - U-089 AddPhotoButton
    - U-090 PhotoFrame — movable / rotatable / scalable photo container on the page
    - U-091 GenerateButton
    - U-092 GenerateConfirmDialog — modal: warns generation is final and irreversible
  - U-093 PageIndicator — current page position in a document, e.g. "1 / 3" (F-051)
  - U-094 PageTurnControl — next / previous page (F-051)
  - U-095 AddPageButton — appends a new stationery page (F-051)
  - U-096 RemovePageButton — removes the current page (F-051)

## Pending Reconciliation

The personalized-stationery model (F-050, F-051) introduces a compose phase
(U-085 and its children) and a write phase with page turning
(U-093..U-096). These were added after the original editor nodes
(U-010 NoteEditorScreen, U-023 Canvas, U-024 PageNavigator), which predate
the stationery model and assume a single scrollable note.

When the editor is reworked for the stationery model, the two structures
will be reconciled — including a proper screen-level home for U-093..U-096.
That rework must be discussed explicitly, because U-023 Canvas is referenced
by the already-implemented F-001, and the nodes U-031 PaperStylePicker,
U-041 InsertImageButton, and U-042 ImageOverlay belong to the now-deprecated
F-010 / F-047.
