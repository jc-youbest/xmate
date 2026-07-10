// EditorLayoutEngine
//
// Pure layout math for the future v2 editor viewport pipeline.
//
// Current stage: this mirrors the existing A4 portrait vertical Single /
// Continuous math but is not yet the runtime source for those views.
// PageGeometry remains the compatibility bridge consumed by current view code.

import CoreGraphics

struct PageFrame: Hashable {
    let pageIndex: Int
    let frame: CGRect
    let anchor: PageAnchor
}

enum PageAnchor: Hashable {
    /// The fitted page is centered across the non-flow axis.
    case centered
}

struct EditorLayoutResult: Equatable {
    let pageFrames: [PageFrame]
    let contentSize: CGSize
    let fitScale: CGFloat
    let pageGap: CGFloat
    let pageFlowAxis: PageFlowAxis
    let presentationStyle: PagePresentationStyle
}

enum EditorLayoutEngine {
    static func layout(
        pageSpec: PageSpec,
        layoutPolicy: LayoutPolicy,
        viewportSize: CGSize,
        pageCount: Int,
        presentationStyle: PagePresentationStyle
    ) -> EditorLayoutResult {
        let safePageCount = max(0, pageCount)
        let paper = PageGeometry.paperSize(for: pageSpec, layoutPolicy: layoutPolicy)
        let fitScale = PageGeometry.fitScale(in: viewportSize, for: paper)
        let scaledPageSize = CGSize(
            width: pageSpec.size.width * fitScale,
            height: pageSpec.size.height * fitScale
        )

        switch presentationStyle {
        case .singlePage:
            return singlePageLayout(
                viewportSize: viewportSize,
                pageCount: safePageCount,
                fitScale: fitScale,
                pageGap: layoutPolicy.pageGap,
                pageFlowAxis: layoutPolicy.pageFlowAxis
            )

        case .continuous:
            return continuousLayout(
                viewportSize: viewportSize,
                scaledPageSize: scaledPageSize,
                pageCount: safePageCount,
                fitScale: fitScale,
                pageGap: layoutPolicy.pageGap,
                pageFlowAxis: layoutPolicy.pageFlowAxis
            )
        }
    }

    private static func singlePageLayout(
        viewportSize: CGSize,
        pageCount: Int,
        fitScale: CGFloat,
        pageGap: CGFloat,
        pageFlowAxis: PageFlowAxis
    ) -> EditorLayoutResult {
        let stride = flowExtent(of: viewportSize, axis: pageFlowAxis) + pageGap
        let frames = (0..<pageCount).map { index in
            let origin: CGPoint
            switch pageFlowAxis {
            case .vertical:
                origin = CGPoint(x: 0, y: CGFloat(index) * stride)
            case .horizontal:
                origin = CGPoint(x: CGFloat(index) * stride, y: 0)
            }
            return PageFrame(
                pageIndex: index,
                frame: CGRect(origin: origin, size: viewportSize),
                anchor: .centered
            )
        }

        // Single Page is not a native scroll content area today; each page lives
        // in a viewport-sized carousel slot. Report the current viewport as the
        // content size to avoid implying a scrollable document stack.
        return EditorLayoutResult(
            pageFrames: frames,
            contentSize: viewportSize,
            fitScale: fitScale,
            pageGap: pageGap,
            pageFlowAxis: pageFlowAxis,
            presentationStyle: .singlePage
        )
    }

    private static func continuousLayout(
        viewportSize: CGSize,
        scaledPageSize: CGSize,
        pageCount: Int,
        fitScale: CGFloat,
        pageGap: CGFloat,
        pageFlowAxis: PageFlowAxis
    ) -> EditorLayoutResult {
        let frames = (0..<pageCount).map { index in
            PageFrame(
                pageIndex: index,
                frame: continuousPageFrame(
                    index: index,
                    viewportSize: viewportSize,
                    scaledPageSize: scaledPageSize,
                    pageGap: pageGap,
                    pageFlowAxis: pageFlowAxis
                ),
                anchor: .centered
            )
        }

        return EditorLayoutResult(
            pageFrames: frames,
            contentSize: continuousContentSize(
                viewportSize: viewportSize,
                scaledPageSize: scaledPageSize,
                pageCount: pageCount,
                pageGap: pageGap,
                pageFlowAxis: pageFlowAxis
            ),
            fitScale: fitScale,
            pageGap: pageGap,
            pageFlowAxis: pageFlowAxis,
            presentationStyle: .continuous
        )
    }

    private static func continuousPageFrame(
        index: Int,
        viewportSize: CGSize,
        scaledPageSize: CGSize,
        pageGap: CGFloat,
        pageFlowAxis: PageFlowAxis
    ) -> CGRect {
        switch pageFlowAxis {
        case .vertical:
            let x = (viewportSize.width - scaledPageSize.width) / 2
            let y = pageGap + CGFloat(index) * (scaledPageSize.height + pageGap)
            return CGRect(x: x, y: y, width: scaledPageSize.width, height: scaledPageSize.height)
        case .horizontal:
            let x = pageGap + CGFloat(index) * (scaledPageSize.width + pageGap)
            let y = (viewportSize.height - scaledPageSize.height) / 2
            return CGRect(x: x, y: y, width: scaledPageSize.width, height: scaledPageSize.height)
        }
    }

    private static func continuousContentSize(
        viewportSize: CGSize,
        scaledPageSize: CGSize,
        pageCount: Int,
        pageGap: CGFloat,
        pageFlowAxis: PageFlowAxis
    ) -> CGSize {
        guard pageCount > 0 else { return viewportSize }

        switch pageFlowAxis {
        case .vertical:
            let height = pageGap * 2
                + CGFloat(pageCount) * scaledPageSize.height
                + CGFloat(max(0, pageCount - 1)) * pageGap
            return CGSize(width: viewportSize.width, height: height)
        case .horizontal:
            let width = pageGap * 2
                + CGFloat(pageCount) * scaledPageSize.width
                + CGFloat(max(0, pageCount - 1)) * pageGap
            return CGSize(width: width, height: viewportSize.height)
        }
    }

    private static func flowExtent(of size: CGSize, axis: PageFlowAxis) -> CGFloat {
        switch axis {
        case .vertical: return size.height
        case .horizontal: return size.width
        }
    }
}

enum CurrentPageResolver {
    static func currentPageIndex(
        contentOffset: CGPoint,
        viewportSize: CGSize,
        layout: EditorLayoutResult
    ) -> Int {
        guard !layout.pageFrames.isEmpty else { return 0 }

        let viewportCenter: CGFloat
        switch layout.pageFlowAxis {
        case .vertical:
            viewportCenter = contentOffset.y + viewportSize.height / 2
        case .horizontal:
            viewportCenter = contentOffset.x + viewportSize.width / 2
        }

        return layout.pageFrames.min { lhs, rhs in
            abs(flowMidpoint(of: lhs.frame, axis: layout.pageFlowAxis) - viewportCenter)
                < abs(flowMidpoint(of: rhs.frame, axis: layout.pageFlowAxis) - viewportCenter)
        }?.pageIndex ?? 0
    }

    private static func flowMidpoint(of frame: CGRect, axis: PageFlowAxis) -> CGFloat {
        switch axis {
        case .vertical: return frame.midY
        case .horizontal: return frame.midX
        }
    }
}

