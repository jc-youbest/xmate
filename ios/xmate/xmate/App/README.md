# App — entry layer

## Responsibilities

- `@main` scene setup; injects app-wide stores (NoteStore, SettingsStore)
  into the environment.
- RootView (U-001) is the composition root: it decides WHICH document is
  opened and injects it into the editor. v1: hard-coded dev document
  name resolved via `NoteStore.loadOrCreateDocument(named:)`.
- Global user preferences (SettingsStore / C-028, UserDefaults-backed).
- Future: top-level switch between Social Screen and Content Screen;
  entry flows from inbox / drafts / new creation that resolve a Document
  and hand it to the editor.

## Key files

- `xmateApp.swift` — `@main`; hosts RootView
- `RootView.swift` — U-001 composition root; document resolution
- `SettingsStore.swift` — C-028 global preferences (PaginationStyle)

## Not responsible for

- Editing documents (Editor), persistence details (Storage), document
  list UI (Library, v3).

## Next step (current stage)

- Add the Social Screen stub and the explicit surface switch when v1
  closes; replace the hard-coded dev document name when Library lands.

## Notes for AI changes

- No module may import from App/ — dependency arrows point outward only.
- Document selection logic belongs HERE (or future navigation flows),
  never inside the editor.
- `PaginationStyle` lives in `Shared/Types.swift` (used by both App and
  Editor), not in SettingsStore.
