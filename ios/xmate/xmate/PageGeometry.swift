// C-027 PageGeometry
//
// The fixed-size logical-page model (F-053 Page Geometry and Zoom).
//
// xmate's writable surface is a paper sheet with fixed logical
// dimensions in points. Handwriting strokes are stored in these
// logical coordinates, so the same drawing data re-fits identically
// onto any iPad screen size — a stroke at logical (x, y) on iPad mini
// renders at the same relative position on iPad Pro 13".
//
// Each device computes its own `fitScale = min(viewport.w / paper.w,
// viewport.h / paper.h)` to project the paper onto the available
// area. The paper's logical size itself never changes.
//
// Architecturally there is no "content type" enum — letter, postcard,
// and any future paper kind are all values of the same `PaperSize`
// struct. Orientation lock, pagination scroll axis, and aspect ratio
// are all derived from the paper's dimensions, never branched on a
// name. Named presets (PaperPreset.letter, PaperPreset.postcard, …)
// live as static data so adding a new paper kind requires only one
// new entry in the preset catalogue.
//
// Stage 2 (roadmap v1) writes on PaperPreset.letter only. Postcard
// and any other preset arrive later with the Core Data migration that
// records a document's paper dimensions per-document.

import Foundation
import CoreGraphics
import UIKit
import SwiftUI

/// A writable sheet's fixed logical dimensions in points.
/// All orientation / direction behaviour derives from these dimensions —
/// never from a separate "content type" identifier.
struct PaperSize: Hashable {
    let width: CGFloat
    let height: CGFloat

    // MARK: - Derived

    /// True when the sheet is taller than it is wide.
    var isPortrait: Bool { height > width }

    /// True when the sheet is wider than it is tall. A square paper
    /// is treated as neither portrait nor landscape (both false).
    var isLandscape: Bool { width > height }

    /// width / height.
    var aspectRatio: CGFloat { width / height }

    /// The orientation the Content Screen locks to when this paper is
    /// displayed. Derived from paper dimensions, not from a name.
    var orientationLock: UIInterfaceOrientationMask {
        isPortrait ? .portrait : .landscape
    }

    /// The axis along which Continuous Pagination Style scrolls (F-056).
    /// Portrait paper → vertical scroll; landscape paper → horizontal.
    var paginationAxis: Axis {
        isPortrait ? .vertical : .horizontal
    }
}

/// Named paper presets — the user-facing catalogue of writable sheets.
/// To add a new preset (e.g. an A5 note, a square greeting card),
/// add one static let and one row to `catalog`. No other code changes.
enum PaperPreset {

    /// Letter: portrait A4 in PDF-standard points (8.27 × 11.69 inch
    /// at 72 dpi = 595 × 842 pt). Aspect 595 : 842 ≈ 1 : 1.4151,
    /// within 0.1% of the true A4 ratio 1 : √2 ≈ 1 : 1.4142.
    static let letter = PaperSize(width: 595, height: 842)

    /// Postcard: landscape 4 × 6 inch postcard with the 6-inch edge
    /// horizontal. 6 × 4 inch at 72 dpi = 432 × 288 pt; scaled ×2 to
    /// 864 × 576 for stroke-precision parity with letter. Aspect
    /// 864 : 576 = 3 : 2 exactly.
    static let postcard = PaperSize(width: 864, height: 576)

    /// Display catalogue for the paper picker UI. Order is the order
    /// shown to the user. Adding a new paper kind = add one row.
    static let catalog: [(name: String, size: PaperSize)] = [
        ("Letter",   letter),
        ("Postcard", postcard),
    ]

    /// The friendly name for a paper, or nil if it isn't in the catalogue.
    /// Used by the UI to label custom paper sheets gracefully.
    static func name(for paper: PaperSize) -> String? {
        catalog.first(where: { $0.size == paper })?.name
    }
}

enum PageGeometry {

    /// Uniform scale that fits a paper inside the given viewport while
    /// preserving aspect ratio. Returns 1.0 when the viewport is empty
    /// (defensive — avoids NaN in the very first SwiftUI layout pass
    /// before the geometry proxy has a size).
    static func fitScale(in viewport: CGSize, for paper: PaperSize) -> CGFloat {
        guard viewport.width > 0, viewport.height > 0 else { return 1.0 }
        return min(viewport.width / paper.width,
                   viewport.height / paper.height)
    }
}
