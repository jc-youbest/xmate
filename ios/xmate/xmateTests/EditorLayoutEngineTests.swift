import CoreGraphics
import Testing
@testable import xmate

struct EditorLayoutEngineTests {
    @Test func continuousA4PortraitMatchesCurrentVerticalMath() {
        let viewport = CGSize(width: 820, height: 1180)
        let pageSpec = PagePresetCatalog.currentDocumentPageSpec
        let policy = LayoutPolicy()

        let result = EditorLayoutEngine.layout(
            pageSpec: pageSpec,
            layoutPolicy: policy,
            viewportSize: viewport,
            pageCount: 3,
            presentationStyle: .continuous
        )

        let expectedFit = min(viewport.width / 595, viewport.height / 842)
        let expectedPageWidth = 595 * expectedFit
        let expectedPageHeight = 842 * expectedFit

        #expect(result.fitScale == expectedFit)
        #expect(result.pageGap == 20)
        #expect(result.pageFlowAxis == .vertical)
        #expect(result.presentationStyle == .continuous)
        #expect(result.pageFrames.count == 3)
        #expect(result.pageFrames[0].frame == CGRect(
            x: (viewport.width - expectedPageWidth) / 2,
            y: 20,
            width: expectedPageWidth,
            height: expectedPageHeight
        ))
        #expect(result.pageFrames[1].frame.minY == 20 + expectedPageHeight + 20)
        #expect(result.contentSize == CGSize(
            width: viewport.width,
            height: 20 * 2 + expectedPageHeight * 3 + 20 * 2
        ))
    }

    @Test func currentPageResolverUsesNearestPageCenter() {
        let viewport = CGSize(width: 820, height: 1180)
        let result = EditorLayoutEngine.layout(
            pageSpec: PagePresetCatalog.currentDocumentPageSpec,
            layoutPolicy: LayoutPolicy(),
            viewportSize: viewport,
            pageCount: 3,
            presentationStyle: .continuous
        )

        let secondPageOffset = CGPoint(
            x: 0,
            y: result.pageFrames[1].frame.midY - viewport.height / 2
        )

        #expect(CurrentPageResolver.currentPageIndex(
            contentOffset: secondPageOffset,
            viewportSize: viewport,
            layout: result
        ) == 1)
    }
}
