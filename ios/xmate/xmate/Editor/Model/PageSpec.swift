// PageSpec
//
// Future editor input model for a fixed logical page. This is a structural
// placeholder only; current documents still flow through WritingScreen's
// PaperPreset.letter stage limitation.

struct PageSpec: Hashable {
    let size: PageSize
    let flowAxis: PageFlowAxis
}

