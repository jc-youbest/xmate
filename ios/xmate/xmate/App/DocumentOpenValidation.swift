// DocumentOpenValidation
//
// App-layer gate before a resolved Document is injected into the editor.
// Storage can load raw persisted data, but the App layer decides whether that
// document is safe to open as an editor session.

import Foundation

enum DocumentOpenErrorCode: String {
    case invalidDocumentOrientation = "XMATE-DOC-0001"
    case invalidDocumentPreset = "XMATE-DOC-0002"
    case invalidDocumentPageSize = "XMATE-DOC-0003"
}

struct DocumentOpenError: Identifiable, Equatable {
    var id: String { code.rawValue }

    let code: DocumentOpenErrorCode
    let message: String
}

enum DocumentOpenValidator {
    /// Presets the current editor can open. Future presets become valid by
    /// adding their ids here once their page layout behavior has shipped.
    private static let supportedPresetIDs: Set<String> = [
        "a4-portrait",
        "a4-landscape",
        "postcard-landscape",
    ]

    static func validate(_ document: Document) -> DocumentOpenError? {
        guard let presetID = document.pagePresetID,
              supportedPresetIDs.contains(presetID),
              let preset = PagePresetCatalog.preset(forID: presetID) else {
            return DocumentOpenError(
                code: .invalidDocumentPreset,
                message: "Invalid document preset."
            )
        }

        guard storedPageSizeMatchesPreset(document, preset: preset) else {
            return DocumentOpenError(
                code: .invalidDocumentPageSize,
                message: "Invalid document page size."
            )
        }

        let pageSpec = preset.spec
        guard pageSpec.size.orientation != .square else {
            return DocumentOpenError(
                code: .invalidDocumentOrientation,
                message: "Invalid document orientation."
            )
        }
        return nil
    }

    private static func storedPageSizeMatchesPreset(
        _ document: Document,
        preset: PagePresetCatalog.Preset
    ) -> Bool {
        document.logicalPageWidth == Double(preset.spec.size.width)
            && document.logicalPageHeight == Double(preset.spec.size.height)
    }
}
