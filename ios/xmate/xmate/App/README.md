# App — entry layer

## Responsibilities

- `@main` scene setup; injects app-wide stores (NoteStore, SettingsStore)
  into the environment.
- Cross-component flow coordination: `AppFlowCoordinator` owns typed Editor and
  Social route state, the document resolve/validate/policy/present pipeline,
  and explicit Editor↔Social return behavior. The settled contract is in
  `docs/architecture.md` (App component coordination).
- Active-component window policy: the coordinator knows whether a component
  follows iPadOS orientation or, for Editor, follows the validated Document
  orientation. It replaces the policy at component transitions; each component
  owns only its internal adaptive layout. See `docs/architecture.md`
  (Component orientation and adaptive layout contract).
- App-wide full-screen presentation: external Split View / Stage Manager is
  intentionally disabled so Editor can maintain the validated Document
  orientation. Internal Editor Workspace sidebars/panels remain supported.
- RootView is the composition root: it decides WHICH document is
  opened and injects it into the editor. v1: hard-coded dev document
  name resolved via `NoteStore.loadOrCreateDocument(named:)`. DEBUG builds
  may temporarily choose which preset-specific dev document to create/open
  through `DevDocumentPagePresetProbe`; this is not user-facing UI, and the
  loaded Document's stored preset remains the runtime source.
- The coordinator assigns the active `ComponentWindowLayoutPolicy` and applies
  it through the App window bridge. Editor is document-directed; ordinary
  components are system-responsive.
- AppFlowCoordinator validates a resolved document before publishing the
  WritingScreen destination. Validation errors are App-layer document-open
  failures with stable error codes; RootView renders the failure, and the
  editor/orientation bridge are not loaded.
- Mailbox-envelope selection accepts stable ids only, requires a local cache
  hit, rechecks the cached Document id/revision, and validates before replacing
  the Editor destination. Typed failures preserve the current Document, and a
  workspace selection keeps the current window policy until sidebar dismissal.
- Editor Workspace accessory state is App-owned. Opening the mailbox keeps the
  current route/policy; closing commits the selected Document's orientation
  policy before returning to full-screen Editor.
- Global user preferences (SettingsStore, UserDefaults-backed).
- Top-level switching between the Social Screen shell and Content Screen;
  future entry flows from Inbox / Drafts resolve an envelope through Mailbox,
  validate the resulting cached Document, and hand it to the editor.

## Key files

- `xmateApp.swift` — `@main`; hosts RootView
- `RootView.swift` — composition root; renders coordinator destinations and
  supplies the current development-document resolver
- `AppFlowCoordinator.swift` — typed App route/state and document-open pipeline
- `DocumentOpenValidation.swift` — pre-editor document validation and
  document-open error codes
- `EditorWindowOrientationPolicy.swift` — active component/document window
  policies, App-owned policy store, and scene request bridge
- `SettingsStore.swift` — global preferences (PaginationStyle)

## Not responsible for

- Editing documents (Editor), persistence details (Storage), mailbox/cache
  rules (Mailbox), or document list UI (Library, v3).
- Editor transaction state, toolbar panels, social delivery rules, or mailbox
  query/presentation details.

## Next step (current stage)

- Compose the Library mailbox sidebar beside the still-mounted Editor and wire
  the top-bar trigger, close intent, and ordered viewport resize transaction.

## Notes for AI changes

- No module may import from App/ — dependency arrows point outward only.
- Document selection logic belongs HERE (or future navigation flows),
  never inside the editor.
- Routes carry stable ids, not Core Data managed objects. Components emit
  typed intents upward and never construct/call sibling components.
- A route owns one window-layout policy. Apply it only while that component is
  active and restore/replace it when the active component changes.
- Workspace accessories inherit the outer route policy. App composes future
  mailbox/sidebar and Send Form UI; it must not make Editor import sibling
  modules.
- `PaginationStyle` lives in `Shared/Types.swift` (used by both App and
  Editor), not in SettingsStore.
