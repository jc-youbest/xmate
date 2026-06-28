// EditorMutationPhase
//
// Inert phase vocabulary for future page mutation transactions.
//
// Current stage: runtime views do not read this value yet. A later
// PageMutationCoordinator migration can use it to temporarily suppress
// viewport tracking, zoom tracking, and drawing activation while add/delete
// transactions move through a single ordered sequence.

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
