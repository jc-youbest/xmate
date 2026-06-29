// EditorOperationState
//
// Inert operation/viewport state vocabulary for future structural editor
// transactions. Runtime add/delete flows still live in WritingScreen.
//
// Architecture rule encoded here: structural document/page operations require
// a normal viewport. If the viewport is zoomed, request zoom reset first, wait
// for completion, then apply the pending operation.

enum EditorViewportState: Hashable {
    case normal
    case zoomed(owner: EditorZoomOwner)
    case resettingZoom(owner: EditorZoomOwner, reason: EditorZoomResetReason)
    case restoringViewport

    var isNormal: Bool {
        self == .normal
    }
}

enum EditorZoomOwner: Hashable {
    case singlePage
    case continuousStack
    case legacyContinuousTransform
}

enum EditorZoomResetReason: Hashable {
    case userGesture
    case toolbar
    case beforeAddPage
    case beforeDeletePage
    case beforeChangeTemplate
    case beforeInsertObject
    case test
    case recovery
}

enum EditorOperationRequest: Hashable {
    case addPage
    case deletePage
    case duplicatePage
    case reorderPage
    case changePageSize
    case changePageOrientation
    case changePageBackground
    case insertObject

    var requiresNormalViewport: Bool {
        true
    }

    var zoomResetReason: EditorZoomResetReason {
        switch self {
        case .addPage:
            return .beforeAddPage
        case .deletePage:
            return .beforeDeletePage
        case .changePageBackground:
            return .beforeChangeTemplate
        case .insertObject:
            return .beforeInsertObject
        case .duplicatePage, .reorderPage, .changePageSize, .changePageOrientation:
            return .beforeChangeTemplate
        }
    }
}

enum EditorOperationPhase: Hashable {
    case idle
    case waitingForZoomReset(pendingOperation: EditorOperationRequest)
    case applying(pendingOperation: EditorOperationRequest)
    case restoringViewport(pendingOperation: EditorOperationRequest)
}

enum EditorEvent: Hashable {
    case addPageRequested
    case deletePageRequested
    case resetZoomRequested(reason: EditorZoomResetReason)
    case zoomResetCompleted
    case viewportRestoreCompleted
}

struct EditorOperationTransition: Hashable {
    var phase: EditorOperationPhase
    var viewportState: EditorViewportState
    var events: [EditorEvent]
}

enum EditorOperationStateMachine {
    static func request(
        _ operation: EditorOperationRequest,
        viewportState: EditorViewportState
    ) -> EditorOperationTransition {
        switch viewportState {
        case .normal:
            return EditorOperationTransition(
                phase: .applying(pendingOperation: operation),
                viewportState: .normal,
                events: []
            )

        case .zoomed(let owner):
            let reason = operation.zoomResetReason
            return EditorOperationTransition(
                phase: .waitingForZoomReset(pendingOperation: operation),
                viewportState: .resettingZoom(owner: owner, reason: reason),
                events: [.resetZoomRequested(reason: reason)]
            )

        case .resettingZoom(let owner, let reason):
            return EditorOperationTransition(
                phase: .waitingForZoomReset(pendingOperation: operation),
                viewportState: .resettingZoom(owner: owner, reason: reason),
                events: []
            )

        case .restoringViewport:
            return EditorOperationTransition(
                phase: .restoringViewport(pendingOperation: operation),
                viewportState: .restoringViewport,
                events: []
            )
        }
    }

    static func handle(
        _ event: EditorEvent,
        phase: EditorOperationPhase,
        viewportState: EditorViewportState
    ) -> EditorOperationTransition {
        switch (event, phase) {
        case (.zoomResetCompleted, .waitingForZoomReset(let operation)):
            return EditorOperationTransition(
                phase: .applying(pendingOperation: operation),
                viewportState: .normal,
                events: []
            )

        case (.viewportRestoreCompleted, .restoringViewport):
            return EditorOperationTransition(
                phase: .idle,
                viewportState: .normal,
                events: []
            )

        default:
            return EditorOperationTransition(
                phase: phase,
                viewportState: viewportState,
                events: []
            )
        }
    }
}
