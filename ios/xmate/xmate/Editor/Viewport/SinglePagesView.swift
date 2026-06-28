// WritingScreen — Single Page layout
//
// One full page fills the viewport at a time. Finger swipes flip discretely
// between pages along paper.paginationAxis: up/down for portrait paper,
// left/right for landscape paper (F-051 / F-056 Direction by Paper
// Orientation). Nothing in this file branches on a paper's name — the flip
// axis, stride, and swipe directions all derive from the paper's dimensions,
// so postcard (and any future preset) needs no code change here.
//
// PERSISTENT OFFSET CAROUSEL — the stage-4 redesign that removed the flicker.
//
//   The previous design kept ONE canvas and used .id(page.id) to force
//   SwiftUI to destroy and recreate the PKCanvasView on every page turn.
//   Canvas teardown + recreation mid-transition caused a visible flash and
//   threw away a warm PencilKit surface ~every flip.
//
//   Now ALL page canvases live permanently in a ZStack — the same
//   all-canvases-alive decision ContinuousPagesView already made for the
//   PKToolPicker (see F-056 "why plain VStack"). Each page is offset along
//   the pagination axis by (index − currentPageIndex) × stride, where
//   stride = viewport extent + gap, so exactly one page is on-screen.
//   A page turn just animates currentPageIndex → every offset shifts by one
//   stride. No canvas is created or destroyed → zero flicker, and the
//   departing page needs no emergency flush (it stays alive;
//   DrawingSessionManager hands the active-editor role over explicitly).
//
//   Memory: bounded stationery documents (letters, postcards), same
//   acceptance as Continuous.
//
// Zoom (F-059): each page is a `ZoomablePage` — a UIScrollView that owns its
// own pinch / pan / inertia / rubber-band natively and is fully gesture-
// interruptible (the hand-rolled SwiftUI spring it replaced could not be
// interrupted mid-animation and froze). The scroll view clips the zoomed page
// to its viewport slot, so it never overflows into neighbours or the top bar.
// Page-turn swipes fire only at fit (suspended once zoomed in).
//
// Active-canvas handoff: identical to Continuous — this view declares the
// desired active page via DrawingSessionManager.setDesiredActive on appear
// and on every page change; the manager promotes that page's canvas
// (flush previous → reload → first responder → bind ToolPicker).

import SwiftUI

struct SinglePagesView: View, Equatable {
    let pages: [Page]
    let paper: PaperSize
    let store: NoteStore

    @Binding var currentPageIndex: Int

    /// Reports the current page's zoom (1.0…3.0 × fit) for the HUD / top bar.
    let onZoomChange: ((CGFloat) -> Void)?
    /// Bumped by the top-bar reset button to zoom the current page back to fit.
    let resetToken: Int

    // MARK: - Equatable
    //
    // Skip re-rendering (which would rebuild every ZoomablePage) when only the
    // displayed zoom % changes: ZoomablePage reports zoom every frame during a
    // pinch, which updates PageZoomModel (for the HUD) and re-runs WritingScreen's
    // body — but the canvases must not rebuild. == ignores the closures and
    // compares only what affects the body.
    static func == (lhs: SinglePagesView, rhs: SinglePagesView) -> Bool {
        lhs.pages.map(\.id) == rhs.pages.map(\.id)
            && lhs.currentPageIndex == rhs.currentPageIndex
            && lhs.resetToken == rhs.resetToken
            && lhs.paper.width == rhs.paper.width
            && lhs.paper.height == rhs.paper.height
    }

    // MARK: - Constants

    /// Gap between adjacent pages in display points. Off-screen by
    /// definition in Single Page; it only shows transiently mid-animation,
    /// matching the Continuous inter-page gap for visual consistency.
    private let gapPt: CGFloat = 20

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let vertical = (paper.paginationAxis == .vertical)
            // One full viewport per page: the next page sits exactly one
            // stride away along the pagination axis.
            let stride = (vertical ? proxy.size.height : proxy.size.width) + gapPt

            ZStack {
                // Letterbox fill — matches ContinuousPagesView so both
                // pagination styles share the same neutral background.
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    let delta = CGFloat(index - currentPageIndex)

                    // Each page is a UIScrollView-backed zoomable page: it fits
                    // the page to the viewport and owns its own pinch / pan /
                    // inertia / rubber-band natively (F-059). The scroll view
                    // clips the zoomed page to its slot, so it never overflows
                    // into the neighbours or the top bar — no zIndex needed.
                    ZoomablePage(
                        page: page,
                        store: store,
                        paper: paper,
                        swipeAxis: paper.paginationAxis,
                        onSwipeForward: handleSwipeForward,
                        onSwipeBackward: handleSwipeBackward,
                        onZoomChange: onZoomChange,
                        resetToken: resetToken
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(x: vertical ? 0 : delta * stride,
                            y: vertical ? delta * stride : 0)
                }
            }
            // Center the carousel in the viewport.
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // Explicit active-canvas handoff (F-051 / F-053 / F-056): tell the
        // session manager which page should be edited on appear and after
        // every page turn. That page's canvas is then promoted — it flushes
        // the outgoing page, reloads the latest drawing, takes first
        // responder and binds the ToolPicker, in that order.
        .onAppear { syncDesiredActive() }
        .onChange(of: currentPageIndex) { _, _ in syncDesiredActive() }
    }

    private func syncDesiredActive() {
        guard !pages.isEmpty, currentPageIndex < pages.count,
              let id = pages[currentPageIndex].id else { return }
        DrawingSessionManager.shared.setDesiredActive(pageID: id, role: .single)
    }

    // MARK: - Navigation
    //
    // Forward = next page (swipe up on portrait paper / swipe left on
    // landscape paper); backward = previous. The carousel offsets animate;
    // no canvas is created or destroyed.

    private func handleSwipeForward() {
        guard currentPageIndex < pages.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPageIndex += 1
        }
    }

    private func handleSwipeBackward() {
        guard currentPageIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPageIndex -= 1
        }
    }
}
