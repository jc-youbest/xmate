// U-101 WritingScreen — Single Page layout
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
//   departing page needs no emergency flush (it stays alive; C-030
//   DrawingSessionManager hands the active-editor role over explicitly).
//
//   Memory: bounded stationery documents (letters, postcards), same
//   acceptance as Continuous.
//
// Zoom (F-053): only the CURRENT page scales by userZoom and receives the
// pan offset / pan callbacks; .zIndex keeps it above its neighbours while
// it overflows the viewport. Swipe callbacks are nil while zoomed —
// pagination suspended — but the recognisers stay attached (no-op dispatch),
// so no canvas recreation is needed when zoom toggles. WritingScreen clips
// the canvas area so the zoomed page never paints over the top bar.
//
// Active-canvas handoff: identical to Continuous — this view declares the
// desired active page via DrawingSessionManager.setDesiredActive on appear
// and on every page change; the manager promotes that page's canvas
// (flush previous → reload → first responder → bind ToolPicker).

import SwiftUI

struct SinglePagesView: View {
    let pages: [Page]
    let paper: PaperSize
    let store: NoteStore

    @Binding var currentPageIndex: Int

    /// Zoom multiplier supplied by WritingScreen (1.0 = fit, max 3.0).
    let userZoom: CGFloat
    /// Pan offset applied to the current page when zoomed, bounded by
    /// WritingScreen.
    let zoomPanOffset: CGSize
    /// Zoom-pan callbacks (F-053). Non-nil when zoomed; forwarded to the
    /// CURRENT page's PencilKitBridge only, which attaches the recogniser
    /// to the canvas.
    let fingerPanChanged: ((CGSize) -> Void)?
    let fingerPanEnded: (() -> Void)?
    /// Finger double-tap → reset zoom to 100% (F-053).
    let onFingerDoubleTap: (() -> Void)?

    // MARK: - Constants

    /// Gap between adjacent pages in display points. Off-screen by
    /// definition in Single Page; it only shows transiently mid-animation,
    /// matching the Continuous inter-page gap for visual consistency.
    private let gapPt: CGFloat = 20

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let fitScale = PageGeometry.fitScale(in: proxy.size, for: paper)
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
                    let isCurrent = (index == currentPageIndex)
                    let delta = CGFloat(index - currentPageIndex)
                    // Carousel placement + zoom pan (current page only).
                    let offsetX = (vertical ? 0 : delta * stride)
                        + (isCurrent ? zoomPanOffset.width : 0)
                    let offsetY = (vertical ? delta * stride : 0)
                        + (isCurrent ? zoomPanOffset.height : 0)

                    PencilKitBridge(
                        page: page,
                        store: store,
                        role: .single,
                        enableSwipeNavigation: true,
                        swipeAxis: paper.paginationAxis,
                        // Nil while zoomed — pagination suspended (F-053).
                        onSwipeForward:  userZoom > 1.0 ? nil : handleSwipeForward,
                        onSwipeBackward: userZoom > 1.0 ? nil : handleSwipeBackward,
                        onFingerDoubleTap: onFingerDoubleTap,
                        // Pan goes ONLY to the current page while zoomed, so
                        // the canvas the user writes on is the one that pans.
                        fingerPanChanged: isCurrent ? fingerPanChanged : nil,
                        fingerPanEnded:   isCurrent ? fingerPanEnded   : nil
                    )
                    // Frame at logical paper dimensions — PKCanvasView stores
                    // strokes here so they reload identically on any iPad.
                    .frame(width: paper.width, height: paper.height)
                    // Project onto the viewport: base fit, plus userZoom on
                    // the current page only.
                    .scaleEffect(fitScale * (isCurrent ? userZoom : 1.0))
                    .offset(x: offsetX, y: offsetY)
                    // Drop shadow — same spec as ContinuousPagesView (F-056
                    // Visual Spec: 4 pt radius, opacity ~0.15, no offset).
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 0)
                    // The zoomed current page overflows the viewport; keep it
                    // above its (unscaled) neighbours.
                    .zIndex(isCurrent ? 1 : 0)
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
