// PagePresetCatalog
//
// Editor-facing preset catalogue.
//
// Only `currentDocumentPageSpec` is used by the runtime today, preserving the
// existing A4 portrait vertical behavior. Other presets remain data only until
// landscape/postcard support is intentionally wired.

enum PagePresetCatalog {
    struct Preset: Hashable {
        let id: String
        let name: String
        let spec: PageSpec
    }

    static let a4Portrait = PageSpec(
        size: .a4Portrait,
        flowAxis: .vertical
    )

    static let defaultPresetID = "a4-portrait"

    /// Temporary v2 bridge: the current document/page paper specification.
    /// Replaces WritingScreen's direct PaperPreset.letter dependency without
    /// changing the visible page size or pagination direction.
    static let currentDocumentPageSpec = a4Portrait
    static let currentDocumentPagePresetID = defaultPresetID

    static let a4Landscape = PageSpec(
        size: .a4Landscape,
        flowAxis: .horizontal
    )

    static let postcardPortrait = PageSpec(
        size: .postcardPortrait,
        flowAxis: .vertical
    )

    static let postcardLandscape = PageSpec(
        size: .postcardLandscape,
        flowAxis: .horizontal
    )

    static let presets: [Preset] = [
        Preset(id: "a4-portrait", name: "A4 Portrait", spec: a4Portrait),
        Preset(id: "a4-landscape", name: "A4 Landscape", spec: a4Landscape),
        Preset(id: "postcard-portrait", name: "Postcard Portrait", spec: postcardPortrait),
        Preset(id: "postcard-landscape", name: "Postcard Landscape", spec: postcardLandscape),
    ]

    static func name(for spec: PageSpec) -> String? {
        presets.first(where: { $0.spec == spec })?.name
    }

    static func preset(forID id: String?) -> Preset? {
        guard let id else { return nil }
        return presets.first(where: { $0.id == id })
    }

    static func presetID(for spec: PageSpec) -> String? {
        presets.first(where: { $0.spec == spec })?.id
    }
}
