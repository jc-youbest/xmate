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
