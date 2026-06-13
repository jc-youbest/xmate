// AppRoot — composition root
//
// The app's global entry view. It lives in App/ — the entry layer at the
// top of the iOS source tree, deliberately independent of every module
// folder (Editor/, Storage/, and the future Library/, Social/).
//
// Its single architectural job: decide WHICH document the editor opens
// and inject it. The editor (WritingScreen) never chooses its own
// document — document identity always flows in from outside.
//
// v1: hard-coded dev document name (load-or-create on first launch).
// Future sources resolve a Document the same way and pass it down
// unchanged:
//   • inbox  (Social module, v3+)  — a received letter
//   • drafts (Library module, v3+) — a saved document from the list
//   • new creation                 — a fresh document on chosen paper
//
// Resolution happens in onAppear (not init) so the Core Data fetch runs
// once per view lifetime, and the pattern already matches the async
// resolution the inbox will need.

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: NoteStore

    /// v1 development document name. Replaced by Library / inbox / new-
    /// creation flows when they land.
    private static let devDocumentName = "dev-default-document"

    /// The document the Content Screen edits. Resolved once on appear.
    @State private var document: Document?

    var body: some View {
        Group {
            if let document {
                WritingScreen(document: document)
            } else {
                // One-frame placeholder while the document resolves;
                // matches the editor's letterbox background.
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            // v1 hard-coded document selection — the ONLY place in the
            // app that decides which document is opened.
            if document == nil {
                document = store.loadOrCreateDocument(named: Self.devDocumentName)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(NoteStore.shared)
        .environmentObject(SettingsStore.shared)
}
