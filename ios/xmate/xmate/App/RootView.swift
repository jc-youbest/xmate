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

#if DEBUG
/// DEBUG-only document preset probe. Keep `presetID` nil for the normal dev
/// A4 portrait document; set it to one of PagePresetCatalog's ids to create
/// and reopen a separate persisted dev document with that page spec.
private enum DevDocumentPagePresetProbe {
    static let presetID: String? = "a4-landscape"
    // static let presetID: String? = "postcard-portrait"
    // static let presetID: String? = "postcard-landscape"
    // static let presetID: String? = nil

    static var preset: PagePresetCatalog.Preset? {
        PagePresetCatalog.preset(forID: presetID)
    }

    static func documentName(for preset: PagePresetCatalog.Preset) -> String {
        "dev-\(preset.id)-document"
    }
}
#endif

struct RootView: View {
    @EnvironmentObject var store: NoteStore

    /// v1 development document name. Replaced by Library / inbox / new-
    /// creation flows when they land.
    private static let devDocumentName = "dev-default-document"

    /// The document open result. Resolved and validated once on appear before
    /// the editor is allowed to load.
    @State private var documentState: DocumentState = .resolving
    @State private var presentedOpenError: DocumentOpenError?

    var body: some View {
        Group {
            if case .ready(let document) = documentState {
                WritingScreen(document: document)
            } else if case .failed(let error) = documentState {
                DocumentOpenErrorView(error: error)
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
            if case .resolving = documentState {
                resolveAndValidateDevDocument()
            }
        }
        .alert(
            "Cannot Open Document",
            isPresented: Binding(
                get: { presentedOpenError != nil },
                set: { if !$0 { presentedOpenError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let presentedOpenError {
                Text("\(presentedOpenError.message)\nCode: \(presentedOpenError.code.rawValue)")
            }
        }
        .background {
            if case .ready(let document) = documentState {
                WindowOrientationPolicyBridge(
                    policy: .preferred(for: document)
                )
                .frame(width: 0, height: 0)
            }
        }
    }

    private enum DocumentState {
        case resolving
        case ready(Document)
        case failed(DocumentOpenError)
    }

    private func resolveAndValidateDevDocument() {
        let resolvedDocument = resolveDevDocument()
        if let error = DocumentOpenValidator.validate(resolvedDocument) {
            documentState = .failed(error)
            presentedOpenError = error
        } else {
            documentState = .ready(resolvedDocument)
        }
    }

    private func resolveDevDocument() -> Document {
        #if DEBUG
        if let preset = DevDocumentPagePresetProbe.preset {
            let name = DevDocumentPagePresetProbe.documentName(for: preset)
            print("[DEV-PAGE-PRESET] document=\(name) preset=\(preset.name)")
            return store.loadOrCreateDocument(
                named: name,
                pagePreset: preset,
                allowsLegacyAdoption: false
            )
        }
        #endif

        return store.loadOrCreateDocument(named: Self.devDocumentName)
    }
}

private struct DocumentOpenErrorView: View {
    let error: DocumentOpenError

    var body: some View {
        VStack(spacing: 12) {
            Text("Cannot Open Document")
                .font(.headline)
            Text(error.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Code: \(error.code.rawValue)")
                .font(.footnote)
                .monospaced()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    RootView()
        .environmentObject(NoteStore.shared)
        .environmentObject(SettingsStore.shared)
}
