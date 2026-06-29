import Testing
@testable import xmate

struct EditorOperationStateTests {
    @Test func normalViewportStartsStructuralOperationImmediately() {
        let transition = EditorOperationStateMachine.request(
            .addPage,
            viewportState: .normal
        )

        #expect(transition.phase == .applying(pendingOperation: .addPage))
        #expect(transition.viewportState == .normal)
        #expect(transition.events.isEmpty)
    }

    @Test func zoomedViewportRequestsResetBeforeAddPage() {
        let transition = EditorOperationStateMachine.request(
            .addPage,
            viewportState: .zoomed(owner: .singlePage)
        )

        #expect(transition.phase == .waitingForZoomReset(pendingOperation: .addPage))
        #expect(transition.viewportState == .resettingZoom(
            owner: .singlePage,
            reason: .beforeAddPage
        ))
        #expect(transition.events == [
            .resetZoomRequested(reason: .beforeAddPage),
        ])
    }

    @Test func zoomResetCompletionAppliesPendingOperation() {
        let transition = EditorOperationStateMachine.handle(
            .zoomResetCompleted,
            phase: .waitingForZoomReset(pendingOperation: .deletePage),
            viewportState: .resettingZoom(
                owner: .continuousStack,
                reason: .beforeDeletePage
            )
        )

        #expect(transition.phase == .applying(pendingOperation: .deletePage))
        #expect(transition.viewportState == .normal)
        #expect(transition.events.isEmpty)
    }

    @Test func alreadyNormalViewportModelsResetAsNoOpCompletion() {
        let transition = EditorOperationStateMachine.request(
            .deletePage,
            viewportState: .normal
        )

        #expect(transition.phase == .applying(pendingOperation: .deletePage))
        #expect(!transition.events.contains(.resetZoomRequested(reason: .beforeDeletePage)))
    }
}
