// ZoomPolicy
//
// Placeholder for future zoom limits and reset behavior. Current zoom behavior
// remains owned by PageZoomModel, ZoomablePage, and the Continuous native
// prototype.

import CoreGraphics

struct ZoomPolicy: Equatable {
    var minimumZoom: CGFloat = 1
    var maximumZoom: CGFloat = 3
}

