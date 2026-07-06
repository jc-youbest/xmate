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

    @Test func userResetOnNormalViewportCompletesAsNoOp() {
        let transition = EditorOperationStateMachine.handle(
            .resetZoomRequested(reason: .toolbar),
            phase: .idle,
            viewportState: .normal
        )

        #expect(transition.phase == .idle)
        #expect(transition.viewportState == .normal)
        #expect(transition.events == [.zoomResetCompleted])
    }

    @Test func userResetOnZoomedViewportRequestsOwnerReset() {
        let transition = EditorOperationStateMachine.handle(
            .resetZoomRequested(reason: .userGesture),
            phase: .idle,
            viewportState: .zoomed(owner: .continuousStack)
        )

        #expect(transition.phase == .idle)
        #expect(transition.viewportState == .resettingZoom(
            owner: .continuousStack,
            reason: .userGesture
        ))
        #expect(transition.events == [
            .resetZoomRequested(reason: .userGesture),
        ])
    }

    @Test func userResetCompletionReturnsIdleViewportToNormal() {
        let transition = EditorOperationStateMachine.handle(
            .zoomResetCompleted,
            phase: .idle,
            viewportState: .resettingZoom(
                owner: .singlePage,
                reason: .toolbar
            )
        )

        #expect(transition.phase == .idle)
        #expect(transition.viewportState == .normal)
        #expect(transition.events.isEmpty)
    }

    @Test func observedViewportMapsSinglePageZoomOwner() {
        let state = EditorViewportState.observed(
            paginationStyle: .singlePage,
            isSinglePageZoomed: true,
            isContinuousNativeStackActive: false,
            isContinuousNativeStackZoomed: false,
            isLegacyContinuousTransformZoomed: false
        )

        #expect(state == .zoomed(owner: .singlePage))
    }

    @Test func observedViewportMapsContinuousNativeStackOwner() {
        let state = EditorViewportState.observed(
            paginationStyle: .continuous,
            isSinglePageZoomed: false,
            isContinuousNativeStackActive: true,
            isContinuousNativeStackZoomed: true,
            isLegacyContinuousTransformZoomed: false
        )

        #expect(state == .zoomed(owner: .continuousStack))
    }

    @Test func observedViewportMapsLegacyContinuousTransformOwner() {
        let state = EditorViewportState.observed(
            paginationStyle: .continuous,
            isSinglePageZoomed: false,
            isContinuousNativeStackActive: false,
            isContinuousNativeStackZoomed: false,
            isLegacyContinuousTransformZoomed: true
        )

        #expect(state == .zoomed(owner: .legacyContinuousTransform))
    }

    @Test func observedViewportIsNormalWhenActiveOwnerIsNotZoomed() {
        let state = EditorViewportState.observed(
            paginationStyle: .continuous,
            isSinglePageZoomed: true,
            isContinuousNativeStackActive: true,
            isContinuousNativeStackZoomed: false,
            isLegacyContinuousTransformZoomed: true
        )

        #expect(state == .normal)
    }
}
