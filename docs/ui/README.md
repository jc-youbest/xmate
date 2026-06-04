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
  - U-101 WritingScreen — the writing variant of the Content Screen; the app opens straight into it (F-051)
    - U-102 WritingTopBar — thin top bar
      - U-107 BackToSocialButton — exits to U-106 SocialScreen (F-051 / F-055)
      - U-093 PageIndicator — current page position in a document, e.g. "1 / 3" (F-051)
      - U-095 AddPageButton — appends a new blank page (F-051)
      - U-103 WritingOverflowMenu — modal: pagination style, delete page, delete document (F-051 / F-011 / F-056)
        - U-111 PaginationStylePicker — toggle between Single Page and Continuous; reflects and updates the global setting (F-056)
    - U-023 Canvas — active drawing surface, sized to the document's logical page (F-053)
  - U-106 SocialScreen — the second top-level surface; v1 stub (F-055)
    - U-109 SocialTopBar — thin top bar
      - U-110 OpenContentButton — returns to U-101 WritingScreen on the last document (F-055)
    - U-108 SocialLayoutGrid — structural placeholder for inbox / feed / pen-pal / discover / drift-bottle sub-areas; concrete contents land in v3+ (F-055)
  - U-098 StationeryLibraryScreen — browse and pick locked stationery (F-052)
    - U-099 StationeryLibraryItem — one library entry, with preview
      - U-100 StationeryLibraryItemMenu — modal: rename, delete

## Retired Nodes

IDs are never reused. These nodes were defined for an earlier design and
are kept only for history.

- U-094 PageTurnControl — page turning is now a finger swipe gesture, with
  no on-screen control.
- U-096 RemovePageButton — removing a page is now an item in U-103
  WritingOverflowMenu.
- U-097 AddPageSourceMenu — v1 add-page appends a blank page; choosing a
  stationery source returns with the stationery model in v2.
- U-042 ImageOverlay — belonged to the deprecated F-047; the writing-mode
  media of F-054 will define its own nodes.
- U-104 WritingSidebar — v1 retired the overlay-sidebar concept on the
  Content Screen. Browsing happens on U-106 SocialScreen instead, reached
  explicitly via U-107 BackToSocialButton. See F-053 / F-055 for the
  decision context.

## Pending Reconciliation

The v1 app now has two top-level screens — U-101 WritingScreen (writing
variant of the Content Screen) and U-106 SocialScreen — switched
explicitly via U-107 BackToSocialButton and U-110 OpenContentButton.
U-104 WritingSidebar has been retired.

Still unreconciled are the original single-note editor nodes — U-010
NoteEditorScreen, U-011 EditorTopBar and its children, U-015 PenToolbar and
its children, U-024 PageNavigator and its children, and U-031
PaperStylePicker. They predate the current model, were never built, and
overlap newer structures: the system PKToolPicker now covers F-002..F-007,
U-024 belonged to the deprecated F-009, U-031 belonged to the deprecated
F-010, and U-041 belonged to the deprecated F-047. Sorting them out is a
separate cleanup, to be done when those areas are next touched; it does not
block v1.
