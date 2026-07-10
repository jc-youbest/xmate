import Foundation
import Testing
@testable import xmate

struct PageMutationCoordinatorTests {
    @Test func addPageTargetsNewLastPage() {
        let existing = [UUID(), UUID()]
        let newPageID = UUID()

        let result = PageMutationCoordinator.plan(
            request: .addPage(newPageID: newPageID),
            pageIDs: existing,
            currentPageIndex: 0
        )

        #expect(result.status == .planned)
        #expect(result.targetPageID == newPageID)
        #expect(result.targetPageIndex == 2)
        #expect(!result.shouldResetZoom)
        #expect(result.viewportCommands.contains(
            .scrollToPage(pageID: newPageID, anchor: .centered, animated: true)
        ))
        #expect(result.drawingActivationCommands == [
            .activateDrawing(pageID: newPageID, reason: .mutation),
        ])
    }

    @Test func deleteCurrentPageSelectsPreviousPageWhenPossible() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let result = PageMutationCoordinator.plan(
            request: .deletePage(pageID: third),
            pageIDs: [first, second, third],
            currentPageIndex: 2
        )

        #expect(result.status == .planned)
        #expect(result.targetPageID == second)
        #expect(result.targetPageIndex == 1)
    }

    @Test func deleteFirstPageSelectsNextRemainingPage() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let result = PageMutationCoordinator.plan(
            request: .deletePage(pageID: first),
            pageIDs: [first, second, third],
            currentPageIndex: 0
        )

        #expect(result.status == .planned)
        #expect(result.targetPageID == second)
        #expect(result.targetPageIndex == 0)
    }

    @Test func deleteLastRemainingPageIsRejected() {
        let onlyPage = UUID()

        let result = PageMutationCoordinator.plan(
            request: .deletePage(pageID: onlyPage),
            pageIDs: [onlyPage],
            currentPageIndex: 0
        )

        #expect(result.status == .rejected(.cannotDeleteLastPage))
        #expect(result.targetPageID == nil)
        #expect(result.viewportCommands.isEmpty)
        #expect(result.drawingActivationCommands.isEmpty)
    }

    @Test func continuousStackZoomPolicyRequestsResetOnlyWhenZoomed() {
        let existing = [UUID(), UUID()]
        let newPageID = UUID()
        let policy = PageMutationPolicy(
            mutationZoomPolicy: .resetContinuousStackZoomBeforeMutation
        )

        let zoomedResult = PageMutationCoordinator.plan(
            request: .addPage(newPageID: newPageID),
            pageIDs: existing,
            currentPageIndex: 0,
            pageMutationPolicy: policy,
            zoomContext: PageMutationZoomContext(
                presentationStyle: .continuous,
                zoomOwner: .continuousNativeStack,
                isZoomed: true
            )
        )

        #expect(zoomedResult.zoomCommand == .resetZoom(animated: true))
        #expect(zoomedResult.viewportCommands.contains(.resetZoom(animated: true)))

        let unzoomedResult = PageMutationCoordinator.plan(
            request: .addPage(newPageID: newPageID),
            pageIDs: existing,
            currentPageIndex: 0,
            pageMutationPolicy: policy,
            zoomContext: PageMutationZoomContext(
                presentationStyle: .continuous,
                zoomOwner: .continuousNativeStack,
                isZoomed: false
            )
        )

        #expect(unzoomedResult.zoomCommand == nil)
        #expect(!unzoomedResult.shouldResetZoom)
    }

    @Test func continuousStackZoomPolicyDoesNotResetSinglePageZoom() {
        let first = UUID()
        let second = UUID()
        let policy = PageMutationPolicy(
            mutationZoomPolicy: .resetContinuousStackZoomBeforeMutation
        )

        let result = PageMutationCoordinator.plan(
            request: .deletePage(pageID: second),
            pageIDs: [first, second],
            currentPageIndex: 1,
            pageMutationPolicy: policy,
            zoomContext: PageMutationZoomContext(
                presentationStyle: .singlePage,
                zoomOwner: .singlePage,
                isZoomed: true
            )
        )

        #expect(result.status == .planned)
        #expect(result.zoomCommand == nil)
        #expect(!result.shouldResetZoom)
    }

    @Test func genericZoomPolicyRequestsResetForAnyZoomedPresentation() {
        let first = UUID()
        let second = UUID()
        let policy = PageMutationPolicy(
            mutationZoomPolicy: .resetZoomBeforeMutation
        )

        let result = PageMutationCoordinator.plan(
            request: .deletePage(pageID: second),
            pageIDs: [first, second],
            currentPageIndex: 1,
            pageMutationPolicy: policy,
            zoomContext: PageMutationZoomContext(
                presentationStyle: .singlePage,
                zoomOwner: .singlePage,
                isZoomed: true
            )
        )

        #expect(result.status == .planned)
        #expect(result.zoomCommand == .resetZoom(animated: true))
    }
}
