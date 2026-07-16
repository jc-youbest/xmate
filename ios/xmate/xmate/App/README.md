# App — entry layer

## Responsibilities

- `@main` scene setup; injects app-wide stores (NoteStore, SettingsStore)
  into the environment.
- Cross-component flow coordination: typed routes, back/return behavior, and
  mapping Editor/Library/Social output intents to transitions. The settled
  contract is in `docs/architecture.md` (App component coordination).
- Active-component window policy: the coordinator knows whether a component
  follows iPadOS orientation or, for Editor, follows the validated Document
  orientation. It replaces the policy at component transitions; each component
  owns only its internal adaptive layout. See `docs/architecture.md`
  (Component orientation and adaptive layout contract).
- RootView is the composition root: it decides WHICH document is
  opened and injects it into the editor. v1: hard-coded dev document
  name resolved via `NoteStore.loadOrCreateDocument(named:)`. DEBUG builds
  may temporarily choose which preset-specific dev document to create/open
  through `DevDocumentPagePresetProbe`; this is not user-facing UI, and the
  loaded Document's stored preset remains the runtime source.
- Current runtime: RootView owns the App-layer editor window orientation
  policy. The flow coordinator will generalize this into the active component
  policy while preserving Editor's validated document-directed behavior.
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
- Editor transaction state, toolbar panels, social delivery rules, or mailbox
  query/presentation details.

## Next step (current stage)

- Introduce the smallest App flow coordinator while preserving the current
  single development-document startup exactly; then use it for the Social
  Screen stub and explicit surface switch.

## Notes for AI changes

- No module may import from App/ — dependency arrows point outward only.
- Document selection logic belongs HERE (or future navigation flows),
  never inside the editor.
- Routes carry stable ids, not Core Data managed objects. Components emit
  typed intents upward and never construct/call sibling components.
- A route owns one window-layout policy. Apply it only while that component is
  active and restore/replace it when the active component changes.
- `PaginationStyle` lives in `Shared/Types.swift` (used by both App and
  Editor), not in SettingsStore.
