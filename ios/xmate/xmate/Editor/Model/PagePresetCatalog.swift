// PagePresetCatalog
//
// Editor-facing preset catalogue.
//
// Only `currentDocumentPageSpec` is used by the runtime today, preserving the
// existing A4 portrait vertical behavior. Other presets remain data only until
// landscape/postcard support is intentionally wired.

enum PagePresetCatalog {
    static let a4Portrait = PageSpec(
        size: .a4Portrait,
        flowAxis: .vertical
    )

    /// Temporary v2 bridge: the current document/page paper specification.
    /// Replaces WritingScreen's direct PaperPreset.letter dependency without
    /// changing the visible page size or pagination direction.
    static let currentDocumentPageSpec = a4Portrait

    static let a4Landscape = PageSpec(
        size: PageSize(width: 842, height: 595),
        flowAxis: .horizontal
    )

    static let postcardPortrait = PageSpec(
        size: PageSize(width: 576, height: 864),
        flowAxis: .vertical
    )

    static let postcardLandscape = PageSpec(
        size: PageSize(width: 864, height: 576),
        flowAxis: .horizontal
    )
}
