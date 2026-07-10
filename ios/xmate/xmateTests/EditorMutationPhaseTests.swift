import Testing
@testable import xmate

struct EditorMutationPhaseTests {
    @Test func mutationPhasesKeepExpectedOrder() {
        #expect(EditorMutationPhase.allCases == [
            .idle,
            .planningPageMutation,
            .applyingPageMutation,
            .restoringViewport,
            .activatingDrawing,
        ])
    }

    @Test func idleDoesNotSuppressTracking() {
        #expect(!EditorMutationPhase.idle.suppressesViewportTracking)
        #expect(!EditorMutationPhase.idle.suppressesZoomTracking)
        #expect(!EditorMutationPhase.idle.suppressesDrawingActivation)
    }

    @Test func mutationPhasesDescribeSuppressionIntent() {
        #expect(EditorMutationPhase.planningPageMutation.suppressesViewportTracking)
        #expect(EditorMutationPhase.applyingPageMutation.suppressesZoomTracking)
        #expect(EditorMutationPhase.restoringViewport.suppressesDrawingActivation)
        #expect(!EditorMutationPhase.activatingDrawing.suppressesDrawingActivation)
    }
}
