// LayoutPolicy
//
// Current editor layout defaults, expressed in v2 vocabulary.
//
// This is partially bridged today: WritingScreen uses `pageFlowAxis` through
// PageSpec -> PaperSize adaptation, while existing Single / Continuous views
// keep their local 20 pt gap constants until the next safe layout step.

import CoreGraphics

struct LayoutPolicy: Equatable {
    enum FitBehavior: Equatable {
        /// Match current PageGeometry.fitScale behavior: uniformly fit the whole
        /// fixed page inside the viewport.
        case fitWithinViewport
    }

    /// Presentation is still driven by SettingsStore.paginationStyle. This value
    /// records the current default for the future editor configuration layer only.
    var presentationStyle: PagePresentationStyle = .singlePage

    /// Current A4 portrait behavior is vertical. Horizontal flow lands later.
    var pageFlowAxis: PageFlowAxis = .vertical

    /// Current visual gap used by Single and Continuous views.
    var pageGap: CGFloat = 20

    /// Current fit-scale behavior.
    var fitBehavior: FitBehavior = .fitWithinViewport
}
