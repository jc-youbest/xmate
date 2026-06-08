// U-101 WritingScreen
//
// The writing-mode screen for roadmap stage v1 (F-051) — the writing
// variant of the Content Screen.
//
// Layout:
//   U-102 WritingTopBar   — thin top bar (page indicator, add, overflow menu)
//   Canvas area           — routed to SinglePagesView or ContinuousPagesView
//                           based on C-028 SettingsStore.paginationStyle (F-056)
//
// Pagination Style routing (F-056, stage 3):
//   .singlePage  → SinglePagesView: one full page, finger swipe to flip.
//   .continuous  → ContinuousPagesView: free-scroll VStack with 20 pt
//                  inter-page gaps and geometric current-page detection.
//
// Current page index is shared between both layouts via @State. In Single
// Page mode it is set by swipe handlers; in Continuous mode it is derived
// from scroll geometry via onScrollGeometryChange (iOS 18+).
//
// Add Page in Continuous mode uses a one-way scrollTarget UUID signal:
// WritingScreen sets it; ContinuousPagesView scrolls and clears it.
// .scrollPosition(id:) is deliberately avoided — its bidirectional binding
// silently snaps to the binding value and creates a perpetual snap loop.
//
// Zoom (F-053):
//   userZoom ranges from 1.0 (fit) upward — no maximum cap.
//   MagnificationGesture and DragGesture are attached as .simultaneousGesture
//   on the canvas ZStack so they fire alongside (not instead of) child
//   gesture recognisers. PKCanvasView's drawingPolicy = .pencilOnly means
//   finger touches are never consumed by PencilKit, so the gestures reliably
//   receive all finger events.
//
//   When userZoom > 1.0 (zoomed state):
//     • Single Page: swipe callbacks are passed nil → no pagination.
//     • Continuous: ContinuousZoomOverlay is laid over the ScrollView, filling
//       the viewport and blocking it from receiving the finger pan. Pencil
//       input still reaches the underlying PKCanvasView via Apple Pencil's
//       separate event path (independent of UITouch).
//
//   Zoom and pan are reset to their neutral values whenever the current page
//   changes (onChange(of: currentPageIndex)) so every page opens at fit.
//
// Delete document (v1 stub): resets to a single blank page. F-011 will
// replace this with navigation to U-002 NoteListScreen in v3.
//
// Paper: hard-coded to PaperPreset.letter for stage 3. Per-document paper
// arrives with a Core Data migration in a later increment.

import SwiftUI

struct WritingScreen: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var settings: SettingsStore

    // MARK: - State

    @State private var document: Document?
    @State private var pages: [Page] = []
    @State private var currentPageIndex: Int = 0

    /// Direction of the most recent page turn; drives the slide transition
    /// edge in Single Page mode.
    @State private var turningForward: Bool = true

    /// One-way scroll signal for Continuous mode Add Page.
    /// WritingScreen sets this to the new page's UUID; ContinuousPagesView
    /// scrolls there and calls the consumed callback to clear it.
    @State private var scrollTarget: UUID?

    @State private var showDeletePageAlert: Bool = false
    @State private var showDeleteDocumentAlert: Bool = false

    // MARK: - Zoom state (F-053)

    /// User-controlled zoom multiplier on top of fitScale. 1.0 = fit (minimum).
    /// No upper cap. Reset to 1.0 on every page change.
    @State private var userZoom: CGFloat = 1.0
    /// Zoom level captured at the start of each MagnificationGesture session.
    @State private var gestureBaseZoom: CGFloat = 1.0
    /// Pan offset applied when userZoom > 1.0. Bounded by the half-overflow
    /// on each axis so the page edge never passes the viewport edge.
    @State private var zoomPanOffset: CGSize = .zero
    /// Pan offset captured at the start of each DragGesture session.
    @State private var gestureBasePan: CGSize = .zero

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // U-102 WritingTopBar — only shown once pages are loaded.
            if !pages.isEmpty {
                WritingTopBar(
                    currentIndex: currentPageIndex,
                    pageCount: pages.count,
                    paginationStyle: $settings.paginationStyle,
                    onAddPage: handleAddPage,
                    onDeletePage: { showDeletePageAlert = true },
                    onDeleteDocument: { showDeleteDocumentAlert = true }
                )
            }

            // Canvas area — routed by Pagination Style.
            // Wrapped in GeometryReader so we can compute pan bounds from the
            // live viewport size when userZoom > 1.0.
            GeometryReader { proxy in
                let fitScale = PageGeometry.fitScale(in: proxy.size,
                                                     for: PaperPreset.letter)
                // Half-overflow: how many points the scaled page extends past
                // each edge of the viewport. Clamped to ≥ 0 so the formula
                // never produces an inverted bound at fit.
                let halfOverflowX = max(0,
                    (PaperPreset.letter.width  * fitScale * userZoom
                     - proxy.size.width)  / 2)
                let halfOverflowY = max(0,
                    (PaperPreset.letter.height * fitScale * userZoom
                     - proxy.size.height) / 2)

                ZStack {
                    switch settings.paginationStyle {

                    case .singlePage:
                        SinglePagesView(
                            pages: pages,
                            paper: PaperPreset.letter,
                            store: store,
                            currentPageIndex: $currentPageIndex,
                            turningForward: $turningForward,
                            userZoom: userZoom,
                            zoomPanOffset: zoomPanOffset
                        )

                    case .continuous:
                        ContinuousPagesView(
                            pages: pages,
                            paper: PaperPreset.letter,
                            store: store,
                            currentPageIndex: $currentPageIndex,
                            scrollTarget: scrollTarget,
                            onScrollTargetConsumed: { scrollTarget = nil },
                            restorePageIndex: currentPageIndex
                        )
                    }

                    // Continuous zoom overlay — shown when Continuous mode is
                    // active and the user has zoomed in. The overlay covers the
                    // full viewport, blocking the ScrollView from receiving
                    // finger pan events while zoomed. Pencil input still reaches
                    // the underlying PKCanvasView via Apple Pencil's separate
                    // event path.
                    if settings.paginationStyle == .continuous,
                       userZoom > 1.0,
                       !pages.isEmpty,
                       currentPageIndex < pages.count {
                        ContinuousZoomOverlay(
                            page: pages[currentPageIndex],
                            paper: PaperPreset.letter,
                            store: store,
                            fitScale: fitScale,
                            userZoom: userZoom,
                            zoomPanOffset: zoomPanOffset
                        )
                    }
                }
                // ── Pinch-to-zoom ─────────────────────────────────────────
                // .simultaneousGesture fires alongside child gesture
                // recognisers — PencilKit's drawingPolicy = .pencilOnly
                // means finger touches are never consumed by the canvas, so
                // this reliably receives all two-finger pinches.
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let candidate = gestureBaseZoom * value
                            userZoom = max(1.0, candidate)
                            // Snap pan to zero the moment we return to fit.
                            if userZoom <= 1.0 {
                                zoomPanOffset = .zero
                                gestureBasePan = .zero
                            }
                        }
                        .onEnded { value in
                            let final = max(1.0, gestureBaseZoom * value)
                            userZoom = final
                            gestureBaseZoom = final
                            if final <= 1.0 {
                                gestureBaseZoom = 1.0
                                zoomPanOffset = .zero
                                gestureBasePan = .zero
                            }
                        }
                )
                // ── Pan while zoomed ──────────────────────────────────────
                // No-op guard when at fit so the ScrollView / swipe
                // recognisers receive the gesture unimpeded.
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard userZoom > 1.0 else { return }
                            zoomPanOffset = CGSize(
                                width:  (gestureBasePan.width
                                         + value.translation.width)
                                        .clamped(to: -halfOverflowX...halfOverflowX),
                                height: (gestureBasePan.height
                                         + value.translation.height)
                                        .clamped(to: -halfOverflowY...halfOverflowY)
                            )
                        }
                        .onEnded { _ in
                            guard userZoom > 1.0 else { return }
                            gestureBasePan = zoomPanOffset
                        }
                )
            }
            .ignoresSafeArea(edges: .bottom)

            // Reset zoom and pan when the user navigates to a different page
            // so every page opens at fit (userZoom == 1.0).
            .onChange(of: currentPageIndex) { _, _ in
                userZoom = 1.0
                gestureBaseZoom = 1.0
                zoomPanOffset = .zero
                gestureBasePan = .zero
            }
        }
        .onAppear(perform: loadDocument)

        // MARK: - Alerts

        .alert("Delete Page?", isPresented: $showDeletePageAlert) {
            Button("Delete", role: .destructive, action: handleDeletePage)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This page and its handwriting will be permanently removed.")
        }

        .alert("Delete Document?", isPresented: $showDeleteDocumentAlert) {
            Button("Delete", role: .destructive, action: handleDeleteDocument)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All pages in this document will be permanently deleted.")
        }
    }

    // MARK: - Load

    private func loadDocument() {
        let doc = store.loadOrCreateDefaultDocument()
        document = doc
        pages = store.pages(of: doc)
        currentPageIndex = 0
    }

    // MARK: - Page CRUD (F-051)

    private func handleAddPage() {
        guard let doc = document else { return }
        let newPage = store.appendPage(to: doc)
        pages = store.pages(of: doc)
        let newIndex = pages.count - 1

        switch settings.paginationStyle {
        case .singlePage:
            turningForward = true
            withAnimation(.easeInOut(duration: 0.18)) {
                currentPageIndex = newIndex
            }
        case .continuous:
            // Optimistic index update so PageIndicator reflects the new page
            // immediately; geometric calculation will confirm it after scroll.
            currentPageIndex = newIndex
            // One-way scroll signal — ContinuousPagesView clears it after firing.
            scrollTarget = newPage.id
        }
    }

    private func handleDeletePage() {
        guard let doc = document, pages.count > 1 else { return }
        let deleteIndex = currentPageIndex
        let pageToDelete = pages[deleteIndex]
        let newIndex = max(0, deleteIndex - 1)

        // dismantleUIView in PencilKitBridge flushes the departing page's
        // drawing before the PKCanvasView is torn down.
        store.deletePage(pageToDelete, from: doc)
        let newPages = store.pages(of: doc)
        let safeIndex = min(newIndex, newPages.count - 1)

        switch settings.paginationStyle {
        case .singlePage:
            // Slide toward the target page then swap content.
            turningForward = false
            withAnimation(.easeInOut(duration: 0.18)) {
                pages = newPages
                currentPageIndex = safeIndex
            }

        case .continuous:
            // Update pages and index first so SwiftUI removes the deleted
            // page from the ForEach. Then issue a one-way scroll signal to
            // bring the target page into view. Without the scroll signal the
            // content height shrinks but the scroll position stays fixed, so
            // the viewport drifts to show whatever page fills the gap —
            // not the intended target.
            pages = newPages
            currentPageIndex = safeIndex
            if safeIndex < newPages.count {
                scrollTarget = newPages[safeIndex].id
            }
        }
    }

    private func handleDeleteDocument() {
        guard let doc = document else { return }
        // v1 stub: clear all pages and start fresh with one blank page.
        // F-011 will replace this with navigation to U-002 NoteListScreen (v3).
        store.resetDocument(doc)
        pages = store.pages(of: doc)
        currentPageIndex = 0
    }
}

// MARK: - ContinuousZoomOverlay

/// Full-viewport overlay shown when Continuous mode is active and
/// `userZoom > 1.0`. It renders only the current page (centred and scaled)
/// and intercepts all finger touches so the underlying ScrollView cannot
/// scroll while zoomed. Apple Pencil input travels a separate UIEvent path
/// and still reaches the PKCanvasView beneath the overlay unchanged.
private struct ContinuousZoomOverlay: View {
    let page: Page
    let paper: PaperSize
    let store: NoteStore
    let fitScale: CGFloat
    let userZoom: CGFloat
    let zoomPanOffset: CGSize

    var body: some View {
        ZStack {
            // Same letterbox colour as ContinuousPagesView.
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            PencilKitBridge(
                page: page,
                store: store,
                onSwipeUp: nil,
                onSwipeDown: nil
            )
            .frame(width: paper.width, height: paper.height)
            .scaleEffect(fitScale * userZoom)
            .offset(zoomPanOffset)
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 0)
        }
        // Transparent hit-test surface covers the whole overlay, preventing
        // finger touches from falling through to the ScrollView below.
        .contentShape(Rectangle())
    }
}

// MARK: - Comparable clamped helper

private extension Comparable {
    /// Returns the value clamped to the closed range [lo, hi].
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    WritingScreen()
        .environmentObject(NoteStore.shared)
        .environmentObject(SettingsStore.shared)
}
