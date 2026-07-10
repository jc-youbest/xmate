// EditorConfiguration
//
// Lightweight aggregate for editor layout/configuration.
//
// Current stage: WritingScreen owns a local default configuration and only uses
// its PageSpec/LayoutPolicy through PageGeometry compatibility adapters. This
// keeps runtime behavior unchanged while giving future layout work one place to
// grow.

struct EditorConfiguration: Equatable {
    var pageSpec = PagePresetCatalog.currentDocumentPageSpec
    var layoutPolicy = LayoutPolicy()
    var zoomPolicy = ZoomPolicy()
    var interactionPolicy = InteractionPolicy()
    var pageMutationPolicy = PageMutationPolicy()

    static let currentDefault = EditorConfiguration()
}
