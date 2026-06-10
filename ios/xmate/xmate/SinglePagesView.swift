// U-101 WritingScreen — Single Page layout
//
// One full page fills the viewport at a time. Finger swipes (up/down for
// portrait paper, left/right for landscape) flip discretely between pages.
//
// This is the stage-2 behaviour extracted into its own view so WritingScreen
// can route cleanly between Single Page and Continuous (F-056).
//
// Geometry: the PencilKitBridge is framed at the paper's logical dimensions
// (C-027), then .scaleEffect(fitScale * userZoom) projects it uniformly onto
// the viewport at the combined base + user zoom. zoomPanOffset shifts the
// scaled page within the viewport when userZoom > 1.0. A surrounding ZStack
// fills the letterbox area with Color(.systemGroupedBackground) — matching
// ContinuousPagesView so both pagination styles share the same background and
// drop-shadow appearance.
//
// Zoom (F-053): when userZoom > 1.0 (zoomed state), swipe callbacks are
// passed nil to PencilKitBridge so its UISwipeGestureRecognizers are never
// added. Finger gestures then reach WritingScreen's DragGesture for panning
// instead of triggering page turns. Returning to userZoom == 1.0 (fit)
// restores normal swipe-to-turn navigation.
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

    /// Zoom multiplier supplied by WritingScreen (1.0 = fit, minimum).
    let userZoom: CGFloat
    /// Pan offset applied when userZoom > 1.0, bounded by WritingScreen.
    let zoomPanOffset: CGSize
    /// Zoom-pan callbacks (F-053). Non-nil when userZoom > 1.0; forwarded
    /// directly to PencilKitBridge which attaches the recogniser to the canvas.
    let fingerPanChanged: ((CGSize) -> Void)?
    let fingerPanEnded: (() -> Void)?

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
                // Letterbox fill — matches ContinuousPagesView so both
                // pagination styles share the same neutral background.
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if let page = currentPage {
                    PencilKitBridge(
                        page: page,
                        store: store,
                        role: .single,
                        // Nil when zoomed — disables swipe recognisers so finger
                        // gestures go to the canvas's pan recogniser instead.
                        onSwipeUp:        userZoom > 1.0 ? nil : handleSwipeUp,
                        onSwipeDown:      userZoom > 1.0 ? nil : handleSwipeDown,
                        fingerPanChanged: fingerPanChanged,
                        fingerPanEnded:   fingerPanEnded
                    )
                    // Frame at logical paper dimensions — PKCanvasView stores
                    // strokes here so they reload identically on any iPad.
                    .frame(width: paper.width, height: paper.height)
                    // Project the logical page onto the viewport at the
                    // combined base + user zoom.
                    .scaleEffect(fitScale * userZoom)
                    // Shift the scaled page within the viewport while zoomed.
                    .offset(zoomPanOffset)
                    // Drop shadow — same spec as ContinuousPagesView (F-056
                    // Visual Spec: 4 pt radius, opacity ~0.15, no offset).
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 0)
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
            // Center the scaled page in the viewport.
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // Explicit active-canvas handoff (F-051 / F-053 / F-056): tell the
        // session manager which page should be edited on appear and after
        // every page turn. The single canvas for that page is then promoted —
        // it flushes the outgoing page, reloads the latest drawing, takes first
        // responder and binds the ToolPicker, in that order.
        .onAppear { syncDesiredActive() }
        .onChange(of: currentPageIndex) { _, _ in syncDesiredActive() }
    }

    private func syncDesiredActive() {
        guard let id = currentPage?.id else { return }
        DrawingSessionManager.shared.setDesiredActive(pageID: id, role: .single)
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
