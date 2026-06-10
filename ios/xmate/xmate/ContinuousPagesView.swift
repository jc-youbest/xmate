// U-101 WritingScreen — Continuous layout (F-056 stage 3)
//
// Pages stack along paper.paginationAxis inside a free-scrolling ScrollView.
// 20 pt gaps between pages; each page has a 4 pt drop shadow. Background and
// letterbox area use Color(.systemGroupedBackground).
//
// Key design choices (informed by failed stages 3.5–3.8)
// ───────────────────────────────────────────────────────
// PLAIN VSTACK (not LazyVStack) — all canvases permanently in the hierarchy.
//   • LazyVStack recycles views out of the window when they leave the
//     viewport. PKToolPicker associates with specific UIResponder instances;
//     when iOS resigns first responder on window-detach, no reliable recovery
//     path exists on real hardware. Plain VStack eliminates this at the root.
//   • For bounded stationery documents (letters, postcards) the memory cost
//     of keeping all canvases alive is acceptable.
//
// FREE SCROLL — no snap, no auto-alignment, ever.
//   • .scrollTargetBehavior is not used: it cuts momentum and the viewAligned
//     variant does not fire on zero-velocity releases.
//   • .scrollPosition(id:) is not used: its bidirectional binding silently
//     snaps to whatever value the binding holds — combining it with a
//     scroll-geometry observer creates a perpetual snap loop.
//
// CURRENT PAGE — purely geometric.
//   • .onScrollGeometryChange (iOS 18+) maps contentOffset + containerSize
//     to the index of the page whose centre is nearest the viewport centre.
//   • The result is written into a one-way @Binding — never back into a
//     scrollPosition binding.
//
// PROGRAMMATIC SCROLL (Add Page) — one-way signal.
//   • WritingScreen sets scrollTarget to the new page's UUID; this view
//     scrolls via ScrollViewReader.scrollTo and calls onScrollTargetConsumed
//     to clear the signal. No binding write-back, no snap loop.
//
// TOOL PICKER — stays alive via C-029 ToolPickerHost.
//   • Each PencilKitBridge registers/deregisters with ToolPickerHost.
//   • With plain VStack the only removal scenario is page deletion;
//     ToolPickerHost re-anchors to the adjacent live canvas.
//   • onSwipeUp/onSwipeDown are nil → PencilKitBridge skips the
//     UISwipeGestureRecognizer additions that would fight the ScrollView.

import SwiftUI

struct ContinuousPagesView: View {

    let pages: [Page]
    let paper: PaperSize
    let store: NoteStore

    /// Current page index — updated live from scroll geometry, also written
    /// optimistically by WritingScreen after Add Page.
    @Binding var currentPageIndex: Int

    /// One-way scroll-to signal. WritingScreen sets this to a page UUID to
    /// trigger a programmatic scroll; this view clears it via
    /// onScrollTargetConsumed after firing.
    let scrollTarget: UUID?
    let onScrollTargetConsumed: () -> Void

    /// Page index to restore on first appear. Captured by WritingScreen at the
    /// moment this view is created — before onScrollGeometryChange fires for
    /// the initial offset-0 geometry and overwrites currentPageIndex to 0.
    /// Using a let constant means the restore is immune to that race.
    let restorePageIndex: Int

    /// True when userZoom > 1.0. While zoomed, scrolling is disabled and the
    /// whole stack is scaled/offset by WritingScreen so the current page fills
    /// the viewport — there is NO separate overlay canvas. Finger panning is
    /// handled by the current page's own canvas recogniser.
    let isZoomed: Bool

    /// Zoom-pan callbacks (F-053). Forwarded ONLY to the current page's
    /// PencilKitBridge while zoomed, so exactly one canvas — the same one the
    /// user writes on — owns the pan gesture. nil otherwise.
    let fingerPanChanged: ((CGSize) -> Void)?
    let fingerPanEnded: (() -> Void)?

    // MARK: - Constants

    /// Inter-page gap in display points (F-056 Visual Spec).
    private let gapPt: CGFloat = 20

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let fitScale = PageGeometry.fitScale(in: proxy.size, for: paper)
            let scaledW  = paper.width  * fitScale
            let scaledH  = paper.height * fitScale
            let vertical = paper.isPortrait  // scroll axis

            ScrollViewReader { scrollProxy in
                ScrollView(vertical ? .vertical : .horizontal,
                           showsIndicators: false) {

                    if vertical {
                        VStack(spacing: gapPt) {
                            pageItems(fitScale: fitScale,
                                      scaledW: scaledW,
                                      scaledH: scaledH)
                        }
                        // Leading padding creates symmetrical spacing so the
                        // first page's top gap matches subsequent inter-page gaps.
                        .padding(.vertical, gapPt)
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: gapPt) {
                            pageItems(fitScale: fitScale,
                                      scaledW: scaledW,
                                      scaledH: scaledH)
                        }
                        .padding(.horizontal, gapPt)
                        .frame(maxHeight: .infinity)
                    }
                }
                .background(Color(.systemGroupedBackground))
                // While zoomed, freeze scrolling: the current page is panned
                // via its own canvas finger-pan recogniser, not the ScrollView.
                .scrollDisabled(isZoomed)

                // ── Restore position on appear ─────────────────────────────
                // Scrolls to restorePageIndex (a let constant) on first
                // appear. currentPageIndex cannot be used here: by the time
                // the async fires, onScrollGeometryChange has already set it
                // to 0 for the initial offset-0 geometry.
                .onAppear {
                    // Declare the active page for the session manager so the
                    // matching canvas is promoted (flush previous → reload →
                    // first responder → ToolPicker) once it registers. This is
                    // the explicit handoff on entry / mode switch into
                    // Continuous; no canvas grabs first responder on its own.
                    let restore = (restorePageIndex >= 0 && restorePageIndex < pages.count)
                        ? restorePageIndex : 0
                    if restore < pages.count, let restoreID = pages[restore].id {
                        DrawingSessionManager.shared
                            .setDesiredActive(pageID: restoreID,
                                              role: .continuous)
                    }
                    guard restorePageIndex > 0,
                          restorePageIndex < pages.count else { return }
                    DispatchQueue.main.async {
                        scrollProxy.scrollTo(pages[restorePageIndex].id,
                                             anchor: .center)
                    }
                }

                // ── Current-page detection (iOS 18+) ──────────────────────
                // Maps scroll geometry to the page index whose centre is
                // nearest the viewport centre along the scroll axis.
                //
                // Layout math (vertical case):
                //   Page i centre (in content space) =
                //     topPadding + i * (scaledH + gap) + scaledH / 2
                //   Viewport centre (in content space) =
                //     contentOffset.y + containerSize.height / 2
                //
                //   Solve for nearest i:
                //     i ≈ (viewportCentre − topPadding − scaledH/2)
                //         / (scaledH + gap)
                //
                // containerSize from ScrollGeometry is the visible frame
                // (not the content size), so it matches our proxy.size.
                .onScrollGeometryChange(for: Int.self) { geo in
                    if vertical {
                        let fs      = PageGeometry.fitScale(
                                          in: geo.containerSize, for: paper)
                        let pageH   = paper.height * fs
                        let stride  = pageH + gapPt
                        let vpCtr   = geo.contentOffset.y
                                      + geo.containerSize.height / 2
                        let idx = Int(round(
                            (vpCtr - gapPt - pageH / 2) / stride
                        ))
                        return max(0, min(pages.count - 1, idx))
                    } else {
                        let fs      = PageGeometry.fitScale(
                                          in: geo.containerSize, for: paper)
                        let pageW   = paper.width  * fs
                        let stride  = pageW + gapPt
                        let vpCtr   = geo.contentOffset.x
                                      + geo.containerSize.width / 2
                        let idx = Int(round(
                            (vpCtr - gapPt - pageW / 2) / stride
                        ))
                        return max(0, min(pages.count - 1, idx))
                    }
                } action: { _, newIdx in
                    currentPageIndex = newIdx
                }

                // ── Re-declare active page on scroll-stop ──────────────────
                // onScrollGeometryChange only writes currentPageIndex; it does
                // NOT change which canvas is the active editor. Without this,
                // the active canvas stays on the page we entered at, so when
                // that page scrolls off (or a pinch / OS event resigns it) the
                // ToolPicker has no first responder and disappears with no
                // recovery. onChange fires once per page-boundary crossing
                // (distinct values only), so it does not thrash mid-scroll.
                // setDesiredActive promotes the now-current page's canvas:
                // flush previous → reload → first responder → bind ToolPicker.
                .onChange(of: currentPageIndex) { _, idx in
                    guard idx >= 0, idx < pages.count,
                          let id = pages[idx].id else { return }
                    DrawingSessionManager.shared
                        .setDesiredActive(pageID: id, role: .continuous)
                }

                // ── Programmatic scroll (Add Page) ─────────────────────────
                // One-way: WritingScreen sets scrollTarget; we scroll and
                // immediately clear the signal. This is the only safe
                // programmatic scroll path — no binding write-back, no snap.
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        scrollProxy.scrollTo(target, anchor: .center)
                    }
                    onScrollTargetConsumed()
                }
            }
        }
        // Extend below the home indicator so the PKToolPicker floats above
        // the full writable area.
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Page items

    @ViewBuilder
    private func pageItems(fitScale: CGFloat,
                           scaledW: CGFloat,
                           scaledH: CGFloat) -> some View {
        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
            // Pan callbacks go ONLY to the current page while zoomed, so the
            // single canvas the user writes on is also the one that pans. All
            // other pages (and the unzoomed state) get nil → no pan recogniser.
            let isCurrent = (index == currentPageIndex)
            let panChanged = (isZoomed && isCurrent) ? fingerPanChanged : nil
            let panEnded   = (isZoomed && isCurrent) ? fingerPanEnded   : nil

            PencilKitBridge(
                page: page,
                store: store,
                role: .continuous,
                onSwipeUp: nil,    // nil → no UISwipeGestureRecognizers added
                onSwipeDown: nil,  //       (they fight the ScrollView pan)
                fingerPanChanged: panChanged,
                fingerPanEnded: panEnded
            )
            // Frame 1: logical paper dimensions — PencilKit records strokes
            // in this coordinate space, preserving them across all iPad sizes.
            .frame(width: paper.width, height: paper.height)
            // Visual scale: fits the page to the viewport's cross axis.
            .scaleEffect(fitScale)
            // Frame 2: corrects the layout size. scaleEffect is visual-only
            // and does not update the SwiftUI layout frame; without this, the
            // LazyVStack uses the unscaled logical dimensions for spacing.
            .frame(width: scaledW, height: scaledH)
            // Drop shadow reinforces the "independent sheet" feel (F-056
            // Visual Spec: 4 pt radius, opacity ~0.15, no offset).
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 0)
            .id(page.id)
        }
    }
}
