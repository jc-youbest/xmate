// PageSpec
//
// Editor input model for a fixed logical page.
//
// Current stage: WritingScreen uses PagePresetCatalog.currentDocumentPageSpec,
// then PageGeometry adapts it to the existing PaperSize runtime type. Future
// storage work will make this document-specific instead of hard-coded.

struct PageSpec: Hashable {
    let size: PageSize
    let flowAxis: PageFlowAxis
}
