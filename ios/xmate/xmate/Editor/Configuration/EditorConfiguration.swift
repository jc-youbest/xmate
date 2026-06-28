// EditorConfiguration
//
// Lightweight aggregate for future editor configuration. This is intentionally
// not injected anywhere yet.

struct EditorConfiguration: Equatable {
    var layoutPolicy = LayoutPolicy()
    var zoomPolicy = ZoomPolicy()
    var interactionPolicy = InteractionPolicy()
    var pageMutationPolicy = PageMutationPolicy()
}

