// PageMutationCoordinator
//
// Pure transaction planner for future page add/delete flows.
//
// Current stage: inert planning only. WritingScreen still performs storage
// mutation, current-index updates, scrollTarget changes, and zoom reset exactly
// as before. This planner records the target-page rules those flows will move
// toward when PageMutationCoordinator becomes the runtime owner.

import Foundation

enum PageMutationRequest: Hashable {
    case addPage(newPageID: UUID)
    case deletePage(pageID: UUID)
}

struct PageMutationResult: Equatable {
    enum Status: Equatable {
        case planned
        case rejected(Reason)
    }

    enum Reason: Equatable {
        case pageNotFound
        case cannotDeleteLastPage
    }

    let status: Status
    let targetPageID: UUID?
    let targetPageIndex: Int?
    let viewportCommands: [ViewportCommand]
    let drawingActivationCommands: [DrawingCommand]
    let zoomCommand: ViewportCommand?

    var shouldResetZoom: Bool {
        zoomCommand != nil
    }

    static func rejected(_ reason: Reason) -> PageMutationResult {
        PageMutationResult(
            status: .rejected(reason),
            targetPageID: nil,
            targetPageIndex: nil,
            viewportCommands: [],
            drawingActivationCommands: [],
            zoomCommand: nil
        )
    }
}

enum PageMutationCoordinator {
    static func plan(
        request: PageMutationRequest,
        pageIDs: [UUID],
        currentPageIndex: Int
    ) -> PageMutationResult {
        switch request {
        case .addPage(let newPageID):
            return planAddPage(
                newPageID: newPageID,
                existingPageCount: pageIDs.count
            )

        case .deletePage(let pageID):
            return planDeletePage(
                pageID: pageID,
                pageIDs: pageIDs,
                currentPageIndex: currentPageIndex
            )
        }
    }

    private static func planAddPage(
        newPageID: UUID,
        existingPageCount: Int
    ) -> PageMutationResult {
        let targetIndex = max(0, existingPageCount)
        let zoomCommand = ViewportCommand.resetZoom(animated: true)
        return PageMutationResult(
            status: .planned,
            targetPageID: newPageID,
            targetPageIndex: targetIndex,
            viewportCommands: [
                .preserveViewportAnchor(pageID: newPageID),
                .scrollToPage(pageID: newPageID, anchor: .centered, animated: true),
                .selectPage(pageID: newPageID),
                zoomCommand,
            ],
            drawingActivationCommands: [
                .activateDrawing(pageID: newPageID, reason: .mutation),
            ],
            zoomCommand: zoomCommand
        )
    }

    private static func planDeletePage(
        pageID: UUID,
        pageIDs: [UUID],
        currentPageIndex: Int
    ) -> PageMutationResult {
        guard pageIDs.count > 1 else {
            return .rejected(.cannotDeleteLastPage)
        }
        guard let deleteIndex = pageIDs.firstIndex(of: pageID) else {
            return .rejected(.pageNotFound)
        }

        var remaining = pageIDs
        remaining.remove(at: deleteIndex)

        let targetIndex = deleteIndex > 0 ? deleteIndex - 1 : 0
        let safeTargetIndex = min(targetIndex, remaining.count - 1)
        let targetPageID = remaining[safeTargetIndex]
        let zoomCommand = ViewportCommand.resetZoom(animated: true)

        return PageMutationResult(
            status: .planned,
            targetPageID: targetPageID,
            targetPageIndex: safeTargetIndex,
            viewportCommands: [
                .preserveViewportAnchor(pageID: pageIDs[
                    max(0, min(currentPageIndex, pageIDs.count - 1))
                ]),
                .scrollToPage(pageID: targetPageID, anchor: .centered, animated: true),
                .selectPage(pageID: targetPageID),
                zoomCommand,
            ],
            drawingActivationCommands: [
                .activateDrawing(pageID: targetPageID, reason: .mutation),
            ],
            zoomCommand: zoomCommand
        )
    }
}

