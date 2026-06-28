// PageSize
//
// Logical fixed page dimensions for the v2 editor layout model.
//
// This is now the data source for the current A4 portrait page spec, but the
// runtime still bridges back through PaperSize / PageGeometry while the older
// Single and Continuous views are migrated incrementally.

import CoreGraphics

struct PageSize: Hashable {
    let width: CGFloat
    let height: CGFloat

    /// Current xmate writing page: A4 portrait in PDF-standard points.
    /// 8.27 x 11.69 in at 72 dpi = 595 x 842 pt.
    static let a4Portrait = PageSize(width: 595, height: 842)

    var orientation: PageOrientation {
        if height > width { return .portrait }
        if width > height { return .landscape }
        return .square
    }
}
