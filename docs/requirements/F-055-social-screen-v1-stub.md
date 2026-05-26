# F-055 Social Screen v1 Stub

One of v1's two top-level full-screen surfaces — the home of the inbox,
the feed, the pen-pal layer, and any other social functions. v1 ships
only its structural shell: explicit navigation to and from the Content
Screen, an empty layout grid prepared for sub-areas, and orientation
locking. The screen's concrete contents are designed in v3+.

## Flow

When the app launches and a session exists:
- The app opens directly to U-101 WritingScreen on the user's most
  recent document (v0 / v1 behaviour). U-106 SocialScreen is reached
  explicitly from U-101's U-107 BackToSocialButton.

When user taps U-107 BackToSocialButton on U-102 WritingTopBar (F-051):
- C-001 NoteStore flushes the current page.
- The app transitions to U-106 SocialScreen.

When U-106 SocialScreen appears:
- The screen is locked to portrait orientation
  (`UIInterfaceOrientationMask.portrait`).
- U-108 SocialLayoutGrid renders the layout grid — a top-level structural
  divider that will host sub-areas (inbox, feed, pen-pal list,
  discover, drift bottle, etc.) in v3+. In v1 every sub-area is an
  empty placeholder.
- U-109 SocialTopBar shows a single forward-to-content button —
  U-110 OpenContentButton — that returns to the most recent document.

When user taps U-110 OpenContentButton on U-109 SocialTopBar:
- The app transitions back to U-101 WritingScreen, restoring the last
  document and page.

## Notes

v1 ships the navigation structure only. None of the social sub-areas
have concrete content yet, and there is no list of "received letters" or
"sent letters" the user can browse — those depend on the backend
(F-023, F-026, F-027) and arrive starting in v3.

The single forward-to-content button is a v1 simplification: with no
document list yet, there is exactly one document the user can resume.
When F-011 Note CRUD adds proper document management, U-110 is replaced
by a document picker / list inside U-108 SocialLayoutGrid.

Portrait lock on U-106 SocialScreen mirrors the v1 rule that the app
never adapts in-content UI to device grip. Once v5 evaluates broader
orientation support, U-106 is a natural first candidate to relax, since
it carries no handwriting.
