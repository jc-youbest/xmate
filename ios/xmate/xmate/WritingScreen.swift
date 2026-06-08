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
//   MagnificationGesture is attached as .simultaneousGesture to detect pinch.
//
//   Panning: a UIPanGestureRecognizer with allowedTouchTypes = [.direct] is
//   attached directly to PKCanvasView inside PencilKitBridge. This is the
//   only reliable way to accept finger panning while writing with Pencil:
//   any covering UIView approach fails because event.allTouches is not yet
//   populated during hitTest, so the pencil-type check is unreliable and
//   pencil events get blocked. With the recogniser on the canvas itself,
//   PencilKit handles .pencil events and our pan handles .direct events;
//   they coexist on the same view without any interception.
//
//   When userZoom > 1.0 (zoomed state):
//     • Single Page: swipe callbacks → nil (no pagination); pan callbacks
//       → non-nil (finger pan enabled on canvas).
//     • Continuous: ContinuousZoomOverlay covers the ScrollView; its own
//       PencilKitBridge has the pan recogniser for writing + panning.
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
    /// Pan offset captured at the start of each finger pan gesture session.
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

            // Canvas area extracted into a helper to keep body small enough
            // for the Swift type checker (the GeometryReader + gesture tree
            // would otherwise exceed the compiler's expression-complexity limit).
            canvasArea
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

    // MARK: - Canvas area helpers
    //
    // Extracted from body to stay within Swift's expression-complexity limit.

    /// GeometryReader wrapper that computes fitScale and pan bounds, then
    /// hosts the ZStack. Gestures and modifiers are attached here so they
    /// share the same proxy size without re-entering a closure in body.
    @ViewBuilder
    private var canvasArea: some View {
        GeometryReader { proxy in
            let fitScale = PageGeometry.fitScale(in: proxy.size,
                                                 for: PaperPreset.letter)
            // Half-overflow: how far the scaled page extends past each viewport
            // edge. Clamped to ≥ 0 so the bound is never inverted at fit.
            let halfOverflowX = max(0,
                (PaperPreset.letter.width  * fitScale * userZoom
                 - proxy.size.width)  / 2)
            let halfOverflowY = max(0,
                (PaperPreset.letter.height * fitScale * userZoom
                 - proxy.size.height) / 2)

            canvasZStack(fitScale: fitScale,
                         halfOverflowX: halfOverflowX,
                         halfOverflowY: halfOverflowY)
            // MagnificationGesture is two-finger; never conflicts with Pencil.
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let candidate = gestureBaseZoom * value
                        userZoom = max(1.0, candidate)
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
        }
        .ignoresSafeArea(edges: .bottom)
        // Reset zoom and pan on every page change so each page opens at fit.
        .onChange(of: currentPageIndex) { _, _ in
            userZoom = 1.0
            gestureBaseZoom = 1.0
            zoomPanOffset = .zero
            gestureBasePan = .zero
        }
    }

    /// ZStack contents: the active pagination view and (when in Continuous mode
    /// and zoomed) the zoom overlay. Pan callbacks are forwarded to the
    /// PencilKitBridge inside each view; no covering overlay is needed.
    @ViewBuilder
    private func canvasZStack(fitScale: CGFloat,
                               halfOverflowX: CGFloat,
                               halfOverflowY: CGFloat) -> some View {
        // Pan callbacks: non-nil only when zoomed. Closures close over the
        // current halfOverflow bounds from the enclosing GeometryReader.
        let panChanged: ((CGSize) -> Void)? = userZoom > 1.0 ? { translation in
            let newX = (gestureBasePan.width + translation.width)
                .clamped(to: -halfOverflowX...halfOverflowX)
            let newY = (gestureBasePan.height + translation.height)
                .clamped(to: -halfOverflowY...halfOverflowY)
            zoomPanOffset = CGSize(width: newX, height: newY)
        } : nil
        let panEnded: (() -> Void)? = userZoom > 1.0 ? {
            gestureBasePan = zoomPanOffset
        } : nil

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
                    zoomPanOffset: zoomPanOffset,
                    fingerPanChanged: panChanged,
                    fingerPanEnded: panEnded
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

            // Continuous zoom overlay: shown when zoomed in Continuous mode.
            // It covers the ScrollView (preventing accidental scroll), hosts
            // the PKCanvasView for writing on the current page, and its
            // PencilKitBridge holds the finger pan recogniser.
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
                    zoomPanOffset: zoomPanOffset,
                    fingerPanChanged: panChanged,
                    fingerPanEnded: panEnded
                )
            }
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
/// `userZoom > 1.0`. It covers the ScrollView so accidental scrolling is
/// impossible while zoomed, renders only the current page, and hosts the
/// PencilKitBridge whose finger pan recogniser drives panning.
private struct ContinuousZoomOverlay: View {
    let page: Page
    let paper: PaperSize
    let store: NoteStore
    let fitScale: CGFloat
    let userZoom: CGFloat
    let zoomPanOffset: CGSize
    /// Forwarded to PencilKitBridge to enable the finger pan recogniser.
    let fingerPanChanged: ((CGSize) -> Void)?
    let fingerPanEnded: (() -> Void)?

    var body: some View {
        ZStack {
            // Same letterbox colour as ContinuousPagesView.
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            PencilKitBridge(
                page: page,
                store: store,
                onSwipeUp: nil,
                onSwipeDown: nil,
                fingerPanChanged: fingerPanChanged,
                fingerPanEnded: fingerPanEnded
            )
            .frame(width: paper.width, height: paper.height)
            .scaleEffect(fitScale * userZoom)
            .offset(zoomPanOffset)
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 0)
        }
        // contentShape makes the whole overlay (including letterbox area)
        // hittable, so finger touches in the margins don't fall through to
        // the ScrollView beneath this overlay.
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
