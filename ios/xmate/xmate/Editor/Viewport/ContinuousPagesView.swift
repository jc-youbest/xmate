// WritingScreen — Continuous layout (F-056 stage 3)
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
// TOOL PICKER — stays alive via ToolPickerHost.
//   • Each PencilKitBridge registers/deregisters with ToolPickerHost.
//   • With plain VStack the only removal scenario is page deletion;
//     ToolPickerHost re-anchors to the adjacent live canvas.
//   • enableSwipeNavigation is false → PencilKitBridge skips the
//     UISwipeGestureRecognizer additions that would fight the ScrollView.

import SwiftUI

struct ContinuousPagesView: View, Equatable {

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

    /// The zoom model — held as a PLAIN reference, NOT `@ObservedObject`: this
    /// view must not re-render when `userZoom`/`panOffset` change every frame
    /// (that was the per-frame updateUIView storm). The live transform is
    /// applied by WritingScreen as a container modifier; here `zoom` is used
    /// only to wire the current page's finger-pan and double-tap to the model.
    /// `isZoomed` (a plain Bool compared in `==`) is what re-renders this view
    /// when zoom crosses the 1.0 boundary, to enable/disable the pan recogniser.
    let zoom: PageZoomModel

    // MARK: - Constants

    /// Inter-page gap in display points (F-056 Visual Spec).
    private let gapPt: CGFloat = 20

    // MARK: - Equatable
    //
    // Skip re-rendering (and the per-page updateUIView) when nothing that
    // affects the body changed. This deliberately EXCLUDES the zoom transform
    // (userZoom/panOffset) and all closures, so a pinch/pan — which re-runs
    // WritingScreen.body every frame — does not rebuild the canvases here; only
    // the container `.scaleEffect/.offset` modifier re-applies. `store` and
    // `zoom` are stable references; `onScrollTargetConsumed` is stale-safe.
    static func == (lhs: ContinuousPagesView, rhs: ContinuousPagesView) -> Bool {
        lhs.pages.map(\.id) == rhs.pages.map(\.id)
            && lhs.currentPageIndex == rhs.currentPageIndex
            && lhs.scrollTarget == rhs.scrollTarget
            && lhs.isZoomed == rhs.isZoomed
            && lhs.restorePageIndex == rhs.restorePageIndex
            && lhs.paper.width == rhs.paper.width
            && lhs.paper.height == rhs.paper.height
    }

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
                            pageItems(viewport: proxy.size,
                                      fitScale: fitScale,
                                      scaledW: scaledW,
                                      scaledH: scaledH)
                        }
                        // Leading padding creates symmetrical spacing so the
                        // first page's top gap matches subsequent inter-page gaps.
                        .padding(.vertical, gapPt)
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: gapPt) {
                            pageItems(viewport: proxy.size,
                                      fitScale: fitScale,
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
                    // While zoomed the ScrollView is frozen, but the container
                    // .scaleEffect/.offset still perturbs the reported geometry.
                    // Letting that drive currentPageIndex oscillates it →
                    // setDesiredActive → makeActive churn → a first-responder loop
                    // that freezes the pan. Ignore geometry-derived index changes
                    // while zoomed; the current page is fixed then.
                    guard !isZoomed else { return }
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
    private func pageItems(viewport: CGSize,
                           fitScale: CGFloat,
                           scaledW: CGFloat,
                           scaledH: CGFloat) -> some View {
        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
            // Pan goes ONLY to the current page while zoomed, so the single
            // canvas the user writes on is also the one that pans. The bound is
            // computed at call-time from the live zoom, so these closures stay
            // correct even though this view does not re-render per frame.
            let isCurrent = (index == currentPageIndex)
            let panChanged: ((CGSize) -> Void)? = (isZoomed && isCurrent) ? { t in
                zoom.panChanged(translation: t, halfOverflow: halfOverflow(in: viewport))
            } : nil
            let panEnded: ((CGSize) -> Void)? = (isZoomed && isCurrent) ? { v in
                zoom.panEnded(velocity: v, halfOverflow: halfOverflow(in: viewport))
            } : nil

            PageSurface {
                PencilKitBridge(
                    page: page,
                    store: store,
                    role: .continuous,
                    // false → no UISwipeGestureRecognizers added
                    // (they fight the ScrollView pan)
                    enableSwipeNavigation: false,
                    onFingerDoubleTap: { print("[DT-CONT] closure -> zoom.resetAnimated()"); zoom.resetAnimated() },  // TEMP DT-DIAG
                    fingerPanChanged: panChanged,
                    fingerPanEnded: panEnded
                )
            }
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

    /// Half-overflow pan bound at the current zoom (≥ 0 per axis): how far the
    /// scaled current page extends past each viewport edge. Read live from
    /// `zoom.userZoom` so it is correct without re-rendering the view.
    private func halfOverflow(in viewport: CGSize) -> CGSize {
        let fit = PageGeometry.fitScale(in: viewport, for: paper)
        return CGSize(
            width:  max(0, (paper.width  * fit * zoom.userZoom - viewport.width)  / 2),
            height: max(0, (paper.height * fit * zoom.userZoom - viewport.height) / 2)
        )
    }
}
