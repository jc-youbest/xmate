// PageMutationPolicy
//
// Placeholder for future add/delete behavior around zoomed or scrolled
// viewports. Current page mutation still lives in WritingScreen.

struct PageMutationPolicy: Equatable {
    var resetsZoomBeforeMutation: Bool = false
}

