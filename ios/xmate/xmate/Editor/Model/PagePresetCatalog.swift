// PagePresetCatalog
//
// Future editor-facing preset catalogue. Kept separate from the active
// PaperPreset runtime catalogue until the layout migration is deliberate.

enum PagePresetCatalog {
    static let a4Portrait = PageSpec(
        size: PageSize(width: 595, height: 842),
        flowAxis: .vertical
    )

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

