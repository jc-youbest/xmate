// EditorMutationPhase
//
// Phase vocabulary for future page mutation transactions.
//
// Current stage: WritingScreen uses this value only to suppress Continuous
// current-page tracking while legacy add/delete flows restore their target
// viewport. Zoom tracking and drawing activation are not gated by it yet.

enum EditorMutationPhase: String, CaseIterable, Hashable {
    case idle
    case planningPageMutation
    case applyingPageMutation
    case restoringViewport
    case activatingDrawing

    var suppressesViewportTracking: Bool {
        self != .idle
    }

    var suppressesZoomTracking: Bool {
        self != .idle
    }

    var suppressesDrawingActivation: Bool {
        switch self {
        case .idle, .activatingDrawing:
            return false
        case .planningPageMutation, .applyingPageMutation, .restoringViewport:
            return true
        }
    }
}
