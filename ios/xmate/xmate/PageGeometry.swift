// C-027 PageGeometry
//
// The fixed-size logical-page model (F-053 Page Geometry and Zoom).
//
// Every page has a fixed logical size in points, set by the document's
// content type. Handwriting strokes are stored in these logical
// coordinates and are therefore invariant across iPad screen sizes — a
// stroke drawn at logical (x, y) on iPad mini renders at the same
// relative position on iPad Pro 13".
//
// Each device computes its own `fitScale = min(viewport.w / logical.w,
// viewport.h / logical.h)` to project the logical page onto the
// available area. The logical size itself never changes.
//
// Stage 2 (roadmap v1) ships letter only. Postcard is defined here so
// the geometry model is complete; UI for postcard arrives in a later
// stage, with the Core Data migration that adds `contentType` to
// Document.

import Foundation
import CoreGraphics

/// Content type of a Document. Fixed at creation; determines the page
/// aspect ratio and the Content Screen orientation lock for the
/// document's lifetime.
enum ContentType {
    /// Portrait pages, aspect 1 : √2 (A4 portrait). The default.
    case letter
    /// Landscape pages, aspect 3 : 2 (4 × 6 inch postcard).
    case postcard
}

enum PageGeometry {

    // MARK: - Logical sizes

    /// Letter: portrait A4 in PDF-standard points (8.27 × 11.69 inch
    /// at 72 dpi = 595 × 842 pt). The aspect 595 : 842 ≈ 1 : 1.4151,
    /// within 0.1% of the true A4 ratio 1 : √2 ≈ 1 : 1.4142.
    static let letterLogicalSize = CGSize(width: 595, height: 842)

    /// Postcard: landscape 4 × 6 inch postcard with the 6-inch edge
    /// horizontal. 6 × 4 inch at 72 dpi = 432 × 288 pt; scaled ×2 to
    /// 864 × 576 for stroke-precision parity with letter. Aspect
    /// 864 : 576 = 3 : 2 exactly.
    static let postcardLogicalSize = CGSize(width: 864, height: 576)

    /// The logical page size for a given content type.
    static func logicalSize(for type: ContentType) -> CGSize {
        switch type {
        case .letter:   return letterLogicalSize
        case .postcard: return postcardLogicalSize
        }
    }

    // MARK: - Fit-to-viewport

    /// Uniform scale that fits a logical page of the given content type
    /// inside the given viewport while preserving aspect ratio.
    /// Returns 1.0 when the viewport is empty (defensive — avoids NaN
    /// in the very first layout pass before SwiftUI knows the size).
    static func fitScale(in viewport: CGSize, for type: ContentType) -> CGFloat {
        guard viewport.width > 0, viewport.height > 0 else { return 1.0 }
        let logical = logicalSize(for: type)
        return min(viewport.width / logical.width,
                   viewport.height / logical.height)
    }
}
