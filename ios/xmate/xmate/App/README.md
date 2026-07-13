# App — entry layer

## Responsibilities

- `@main` scene setup; injects app-wide stores (NoteStore, SettingsStore)
  into the environment.
- RootView is the composition root: it decides WHICH document is
  opened and injects it into the editor. v1: hard-coded dev document
  name resolved via `NoteStore.loadOrCreateDocument(named:)`. DEBUG builds
  may temporarily choose which preset-specific dev document to create/open
  through `DevDocumentPagePresetProbe`; this is not user-facing UI, and the
  loaded Document's stored preset remains the runtime source.
- RootView owns the App-layer editor window orientation policy: it sets the
  supported/preferred scene orientation from the validated document preset,
  while the editor still adapts to the actual viewport.
- RootView validates a resolved document before loading WritingScreen.
  Validation errors are App-layer document-open failures with stable error
  codes; the editor and orientation bridge are not loaded on failure.
- Global user preferences (SettingsStore, UserDefaults-backed).
- Future: top-level switch between Social Screen and Content Screen;
  entry flows from inbox / drafts / new creation that resolve a Document
  and hand it to the editor.

## Key files

- `xmateApp.swift` — `@main`; hosts RootView
- `RootView.swift` — composition root; document resolution
- `DocumentOpenValidation.swift` — pre-editor document validation and
  document-open error codes
- `EditorWindowOrientationPolicy.swift` — document-to-window orientation
  policy store and scene request bridge
- `SettingsStore.swift` — global preferences (PaginationStyle)

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
