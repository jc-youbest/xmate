// PageSpec
//
// Editor input model for a fixed logical page.
//
// WritingScreen resolves this from the injected Document, then PageGeometry
// adapts it to the existing PaperSize runtime type.

struct PageSpec: Hashable {
    let size: PageSize
    let flowAxis: PageFlowAxis
}
