// PageMutationPolicy
//
// Preparation for future add/delete behavior around zoomed or scrolled
// viewports. Current page mutation still lives in WritingScreen, and these
// values are not dispatched by the runtime yet.

struct PageMutationPolicy: Equatable {
    var mutationZoomPolicy: MutationZoomPolicy = .preserveZoom

    func zoomCommand(
        for mutationKind: PageMutationKind,
        context: PageMutationZoomContext?
    ) -> ViewportCommand? {
        mutationZoomPolicy.zoomCommand(
            for: mutationKind,
            context: context
        )
    }
}

enum PageMutationKind: Equatable {
    case addPage
    case deletePage
}

enum MutationZoomPolicy: Equatable {
    case preserveZoom
    case resetZoomBeforeMutation
    case resetContinuousStackZoomBeforeMutation

    func zoomCommand(
        for mutationKind: PageMutationKind,
        context: PageMutationZoomContext?
    ) -> ViewportCommand? {
        guard let context, context.isZoomed else { return nil }

        switch self {
        case .preserveZoom:
            return nil
        case .resetZoomBeforeMutation:
            return .resetZoom(animated: true)
        case .resetContinuousStackZoomBeforeMutation:
            guard context.presentationStyle == .continuous,
                  context.zoomOwner.isContinuousStackOwner else {
                return nil
            }
            return .resetZoom(animated: true)
        }
    }
}

struct PageMutationZoomContext: Equatable {
    var presentationStyle: PagePresentationStyle
    var zoomOwner: PageMutationZoomOwner
    var isZoomed: Bool
}

enum PageMutationZoomOwner: Equatable {
    case singlePage
    case continuousSwiftUIStack
    case continuousNativeStack
    case unknown

    var isContinuousStackOwner: Bool {
        switch self {
        case .continuousSwiftUIStack, .continuousNativeStack:
            return true
        case .singlePage, .unknown:
            return false
        }
    }
}
