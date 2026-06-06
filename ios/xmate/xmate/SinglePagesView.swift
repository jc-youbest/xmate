// U-101 WritingScreen — Single Page layout
//
// One full page fills the viewport at a time. Finger swipes (up/down for
// portrait paper, left/right for landscape) flip discretely between pages.
//
// This is the stage-2 behaviour extracted into its own view so WritingScreen
// can route cleanly between Single Page and Continuous (F-056).
//
// Geometry: the PencilKitBridge is framed at the paper's logical dimensions
// (C-027), then .scaleEffect(fitScale) projects it uniformly onto the
// viewport. A surrounding ZStack absorbs the letterbox area.
//
// Page identity: .id(page.id) forces SwiftUI to create a fresh PKCanvasView
// (and a fresh Coordinator) for every page — no drawing state bleeds between
// pages. dismantleUIView in PencilKitBridge flushes the departing page before
// teardown, so no strokes are lost on a fast flip.

import SwiftUI

struct SinglePagesView: View {
    let pages: [Page]
    let paper: PaperSize
    let store: NoteStore

    @Binding var currentPageIndex: Int
    @Binding var turningForward: Bool

    // MARK: - Derived

    private var currentPage: Page? {
        guard !pages.isEmpty, currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let fitScale = PageGeometry.fitScale(in: proxy.size, for: paper)

            ZStack {
                if let page = currentPage {
                    PencilKitBridge(
                        page: page,
                        store: store,
                        onSwipeUp: handleSwipeUp,
                        onSwipeDown: handleSwipeDown
                    )
                    // Frame at logical paper dimensions — PKCanvasView stores
                    // strokes here so they reload identically on any iPad.
                    .frame(width: paper.width, height: paper.height)
                    // Project the logical page onto the viewport uniformly.
                    .scaleEffect(fitScale)
                    // Slide the incoming page in from the correct edge;
                    // .id-driven recreation triggers the transition on
                    // every page change.
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: turningForward ? .bottom : .top),
                            removal:   .move(edge: turningForward ? .top   : .bottom)
                        )
                    )
                    .id(page.id)
                }
            }
            // Center the scaled page in the viewport. Letterbox strips on the
            // unused area inherit the screen background.
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    // MARK: - Navigation

    private func handleSwipeUp() {
        guard currentPageIndex < pages.count - 1 else { return }
        turningForward = true
        withAnimation(.easeInOut(duration: 0.18)) {
            currentPageIndex += 1
        }
    }

    private func handleSwipeDown() {
        guard currentPageIndex > 0 else { return }
        turningForward = false
        withAnimation(.easeInOut(duration: 0.18)) {
            currentPageIndex -= 1
        }
    }
}
