// AppRoot — composition root
//
// The app's global entry view. It lives in App/ — the entry layer at the
// top of the iOS source tree, deliberately independent of every module
// folder (Editor/, Storage/, and the future Library/, Social/).
//
// It renders AppFlowCoordinator state and supplies the current v1
// source-specific development-document resolver. The coordinator owns the
// resolve -> validate -> window policy -> present sequence. The editor
// (WritingScreen) never chooses its own document.
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
/// DEBUG-only document creation probe. This is not a layout source: it only
/// picks which persisted dev document to create/open. Once the Document is
/// loaded, its stored `pagePresetID` is the source for validation, editor
/// layout, and window orientation.
private enum DevDocumentPagePresetProbe {
    // Keep deterministic while F-061 device acceptance verifies both document
    // orientations. Switch deliberately instead of relying on Bool.random(),
    // which can repeatedly select the already-tested path across app launches.
    static let creationPresetID: String? = "a4-landscape"
    // static let creationPresetID: String? = "a4-portrait"
    // static let creationPresetID: String? = "postcard-landscape"
    // static let creationPresetID: String? = nil

    static var preset: PagePresetCatalog.Preset? {
        PagePresetCatalog.preset(forID: creationPresetID)
    }

    static func documentName(for preset: PagePresetCatalog.Preset) -> String {
        "dev-\(preset.id)-document"
    }
}
#endif

struct RootView: View {
    @EnvironmentObject var store: NoteStore
    @StateObject private var coordinator = AppFlowCoordinator()

    /// v1 development document name. Replaced by Library / inbox / new-
    /// creation flows when they land.
    private static let devDocumentName = "dev-default-document"

    var body: some View {
        Group {
            switch coordinator.state {
            case .ready(let destination):
                destinationView(destination)
            case .failed(let error):
                DocumentOpenErrorView(error: error)
            case .resolving:
                // One-frame placeholder while the document resolves;
                // matches the editor's letterbox background.
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            coordinator.start(
                request: devDocumentOpenRequest,
                resolveDocument: resolveDevDocument
            )
        }
        .alert(
            "Cannot Open Document",
            isPresented: Binding(
                get: { coordinator.presentedOpenError != nil },
                set: { if !$0 { coordinator.dismissOpenError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let presentedOpenError = coordinator.presentedOpenError {
                Text("\(presentedOpenError.message)\nCode: \(presentedOpenError.code.rawValue)")
            }
        }
        .background {
            if case .ready(let destination) = coordinator.state {
                WindowOrientationPolicyBridge(
                    policy: destination.route.windowLayoutPolicy
                )
                .frame(width: 0, height: 0)
            }
        }
    }

    @ViewBuilder
    private func destinationView(
        _ destination: ResolvedAppDestination
    ) -> some View {
        switch destination.route {
        case .editor:
            WritingScreen(document: destination.document)
        }
    }

    private var devDocumentOpenRequest: DocumentOpenRequest {
        #if DEBUG
        if let preset = DevDocumentPagePresetProbe.preset {
            return DocumentOpenRequest(
                source: .developmentDocument(
                    name: DevDocumentPagePresetProbe.documentName(for: preset)
                )
            )
        }
        #endif

        return DocumentOpenRequest(
            source: .developmentDocument(name: Self.devDocumentName)
        )
    }

    private func resolveDevDocument() -> Document {
        #if DEBUG
        if let preset = DevDocumentPagePresetProbe.preset {
            let name = DevDocumentPagePresetProbe.documentName(for: preset)
            print("[DEV-PAGE-PRESET] createOrOpen=\(name) creationPreset=\(preset.name)")
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
