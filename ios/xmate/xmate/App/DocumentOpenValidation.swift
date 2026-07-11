// DocumentOpenValidation
//
// App-layer gate before a resolved Document is injected into the editor.
// Storage can load raw persisted data, but the App layer decides whether that
// document is safe to open as an editor session.

import Foundation

enum DocumentOpenErrorCode: String {
    case invalidDocumentOrientation = "XMATE-DOC-0001"
}

struct DocumentOpenError: Identifiable, Equatable {
    var id: String { code.rawValue }

    let code: DocumentOpenErrorCode
    let message: String
}

enum DocumentOpenValidator {
    static func validate(_ document: Document) -> DocumentOpenError? {
        let pageSpec = document.resolvedPageSpec
        guard pageSpec.size.orientation != .square else {
            return DocumentOpenError(
                code: .invalidDocumentOrientation,
                message: "Invalid document orientation."
            )
        }
        return nil
    }
}
