// EditorLayoutContext
//
// Resolved editor layout for one WritingScreen render path.
//
// This is intentionally a small value, not global state and not an observable
// object. Runtime views still use the PageGeometry/PaperSize compatibility
// bridge through this context while the v2 layout model becomes authoritative.

import CoreGraphics
import SwiftUI

struct EditorLayoutContext: Equatable {
    let pageSpec: PageSpec
    let pageSize: PageSize
    let pageOrientation: PageOrientation
    let flowAxis: PageFlowAxis
    let presentationStyle: PagePresentationStyle
    let layoutPolicy: LayoutPolicy
    let paper: PaperSize
    let presetName: String?

    init(
        configuration: EditorConfiguration,
        presentationStyle: PagePresentationStyle
    ) {
        let pageSpec = configuration.pageSpec
        let layoutPolicy = configuration.resolvedLayoutPolicy(
            presentationStyle: presentationStyle
        )

        self.pageSpec = pageSpec
        self.pageSize = pageSpec.size
        self.pageOrientation = pageSpec.size.orientation
        self.flowAxis = layoutPolicy.pageFlowAxis
        self.presentationStyle = layoutPolicy.presentationStyle
        self.layoutPolicy = layoutPolicy
        self.paper = PageGeometry.paperSize(
            for: pageSpec,
            layoutPolicy: layoutPolicy
        )
        self.presetName = PagePresetCatalog.name(for: pageSpec)
    }

    var paginationAxis: Axis {
        paper.paginationAxis
    }

    func fitScale(in viewport: CGSize) -> CGFloat {
        PageGeometry.fitScale(in: viewport, for: paper)
    }

    var debugDescription: String {
        let name = presetName ?? "custom"
        return "preset=\(name) "
            + "page=\(Int(pageSize.width))x\(Int(pageSize.height)) "
            + "flowAxis=\(flowAxis.debugName) "
            + "presentation=\(presentationStyle.debugName) "
            + "orientation=\(pageOrientation.debugName)"
    }
}
