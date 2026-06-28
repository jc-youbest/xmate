// PageSize
//
// Lightweight editor-layout vocabulary for future page specifications.
// Not wired into the runtime path yet; current behavior still uses
// PaperSize / PaperPreset in PageGeometry.

import CoreGraphics

struct PageSize: Hashable {
    let width: CGFloat
    let height: CGFloat

    var orientation: PageOrientation {
        if height > width { return .portrait }
        if width > height { return .landscape }
        return .square
    }
}

