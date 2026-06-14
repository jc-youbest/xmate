// WritingScreen
//
// The writing-mode screen for roadmap stage v1 (F-051) — the writing
// variant of the Content Screen.
//
// Layout:
//   WritingTopBar   — thin top bar (page indicator, zoom reset, add,
//                           overflow menu). Always visible — the canvas area
//                           below is clipped, so a zoomed page can never
//                           paint over the bar.
//   Canvas area           — routed to SinglePagesView or ContinuousPagesView
//                           based on SettingsStore.paginationStyle
//                           (F-056), with ZoomHUD overlaid centered.
//
// Pagination Style routing (F-056):
//   .singlePage  → SinglePagesView: persistent offset carousel — all page
//                  canvases stay alive; a flip animates offsets only (no
//                  canvas destruction → no flicker). Flip axis derives from
//                  paper.paginationAxis.
//   .continuous  → ContinuousPagesView: free-scroll stack along
//                  paper.paginationAxis with 20 pt gaps and geometric
//                  current-page detection.
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
// Zoom (F-053) — state and math live in PageZoomModel:
//   • userZoom 1.0 (fit) … 3.0 (300% cap). Pinch via MagnificationGesture
//     attached as .simultaneousGesture.
//   • ZoomHUD: centered translucent percentage readout, visible while
//     pinching, fades 1 s after the fingers lift.
//   • Reset to 100%: finger double-tap on the page, or ZoomResetButton
//     in the top bar (shows the live percentage while zoomed).
//   • Panning: a UIPanGestureRecognizer with allowedTouchTypes = [.direct]
//     attached directly to PKCanvasView inside PencilKitBridge — the only
//     reliable way to accept finger panning while writing with Pencil
//     (see header for why covering views fail).
//   • While zoomed, Single Page suspends swipe pagination (nil callbacks)
//     and Continuous freezes its ScrollView; in both styles the SAME
//     current-page canvas keeps editing and owns the finger pan, upholding
//     the one-authoritative-canvas-per-Page invariant.
//   • Zoom resets (without HUD flash) on page change so every page opens
//     at fit.
//
// Document identity is INJECTED — this screen never decides which
// document it edits. AppRoot (RootView, App/) resolves the document
// (v1: hard-coded default) and passes it in; future sources (inbox,
// drafts, new creation) resolve a Document the same way.
//
// Delete document (v1 stub): resets to a single blank page. F-011 will
// replace this with navigation to NoteListScreen in v3.
//
// Paper: hard-coded to PaperPreset.letter for now. Per-document paper
// arrives with a Core Data migration in a later increment; nothing in the
// pagination / zoom layers branches on the paper's name, so that increment
// only swaps where `paper` comes from.

import SwiftUI

struct WritingScreen: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var settings: SettingsStore

    /// The document being edited — injected by the composition root
    /// (AppRoot). See file header.
    let document: Document

    /// Stage limitation: per-document paper lands with the Core Data
    /// migration. Everything below derives behaviour from this value alone.
    private let paper = PaperPreset.letter

    // MARK: - State

    @State private var pages: [Page] = []
    @State private var currentPageIndex: Int = 0

    /// One-way scroll signal for Continuous mode Add Page.
    /// WritingScreen sets this to the new page's UUID; ContinuousPagesView
    /// scrolls there and calls the consumed callback to clear it.
    @State private var scrollTarget: UUID?

    @State private var showDeletePageAlert: Bool = false
    @State private var showDeleteDocumentAlert: Bool = false

    /// Zoom state + gesture math (F-053).
    @StateObject private var zoom = PageZoomModel()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Build the top bar AND the pagination view only once pages are
            // loaded. The pagination views (SinglePagesView / ContinuousPagesView)
            // declare the desired-active page in their one-shot `onAppear`; if
            // that fired while `pages` was still empty (the pre-loadPages frame),
            // `syncDesiredActive`'s `guard !pages.isEmpty` bailed, the desired
            // page was never set, no canvas was ever promoted, and the
            // PKToolPicker never bound — it only appeared after a page turn
            // re-declared the desired page. Gating the canvas area here means the
            // pagination view is created once, with pages present, so its
            // onAppear declares the desired page and activation runs at launch.
            if !pages.isEmpty {
                WritingTopBar(
                    currentIndex: currentPageIndex,
                    pageCount: pages.count,
                    paginationStyle: $settings.paginationStyle,
                    zoomPercent: zoom.isZoomed ? zoom.percent : nil,
                    onResetZoom: resetZoom,
                    onAddPage: handleAddPage,
                    onDeletePage: { showDeletePageAlert = true },
                    onDeleteDocument: { showDeleteDocumentAlert = true }
                )

                // Canvas area extracted into a helper to keep body small enough
                // for the Swift type checker (the GeometryReader + gesture tree
                // would otherwise exceed the compiler's expression-complexity limit).
                canvasArea
            } else {
                // Pages not resolved yet — show the letterbox background, never
                // an empty-page pagination view (see comment above).
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
        }
        .onAppear(perform: loadPages)

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

    /// GeometryReader wrapper that computes the pan bounds, then hosts the
    /// ZStack. Gestures and modifiers are attached here so they share the
    /// same proxy size without re-entering a closure in body.
    @ViewBuilder
    private var canvasArea: some View {
        GeometryReader { proxy in
            let fitScale = PageGeometry.fitScale(in: proxy.size, for: paper)
            // Half-overflow: how far the scaled page extends past each viewport
            // edge. Clamped to ≥ 0 so the bound is never inverted at fit.
            let halfOverflow = CGSize(
                width: max(0, (paper.width * fitScale * zoom.userZoom
                               - proxy.size.width) / 2),
                height: max(0, (paper.height * fitScale * zoom.userZoom
                                - proxy.size.height) / 2)
            )

            canvasZStack(halfOverflow: halfOverflow)
                // MagnificationGesture is two-finger; never conflicts with Pencil.
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { zoom.pinchChanged($0) }
                        .onEnded { zoom.pinchEnded($0) }
                )
                // ZoomHUD — centered, transient, touch-transparent.
                .overlay {
                    if zoom.hudVisible {
                        ZoomHUD(percent: zoom.percent)
                    }
                }
        }
        // The zoomed page overflows its slot; clip so it never paints over
        // WritingTopBar (F-053).
        .clipped()
        .ignoresSafeArea(edges: .bottom)
        // Reset zoom and pan on every page change so each page opens at fit.
        .onChange(of: currentPageIndex) { _, _ in
            zoom.reset()
        }
    }

    /// ZStack contents: the active pagination view. Pan callbacks are forwarded
    /// to the PencilKitBridge inside each view. There is no separate zoom
    /// overlay canvas — both styles transform existing canvases so a Page is
    /// never edited by two canvases at once (object-lifecycle invariant).
    @ViewBuilder
    private func canvasZStack(halfOverflow: CGSize) -> some View {
        // Pan callbacks: non-nil only when zoomed. Closures close over the
        // current halfOverflow bounds from the enclosing GeometryReader.
        let panChanged: ((CGSize) -> Void)? = zoom.isZoomed ? { translation in
            zoom.panChanged(translation: translation, halfOverflow: halfOverflow)
        } : nil
        let panEnded: (() -> Void)? = zoom.isZoomed ? {
            zoom.panEnded()
        } : nil

        ZStack {
            switch settings.paginationStyle {
            case .singlePage:
                SinglePagesView(
                    pages: pages,
                    paper: paper,
                    store: store,
                    currentPageIndex: $currentPageIndex,
                    userZoom: zoom.userZoom,
                    zoomPanOffset: zoom.panOffset,
                    fingerPanChanged: panChanged,
                    fingerPanEnded: panEnded,
                    onFingerDoubleTap: resetZoom
                )
            case .continuous:
                // Continuous zoom (F-053): no overlay canvas. When zoomed we
                // freeze the ScrollView and scale/offset the whole stack so the
                // current page fills the viewport, while the SAME current-page
                // canvas keeps editing and owns the finger-pan gesture. This
                // preserves the one-canvas-per-Page invariant — there is never a
                // second, independently-savable drawing for the page.
                ContinuousPagesView(
                    pages: pages,
                    paper: paper,
                    store: store,
                    currentPageIndex: $currentPageIndex,
                    scrollTarget: scrollTarget,
                    onScrollTargetConsumed: { scrollTarget = nil },
                    restorePageIndex: currentPageIndex,
                    isZoomed: zoom.isZoomed,
                    fingerPanChanged: panChanged,
                    fingerPanEnded: panEnded,
                    onFingerDoubleTap: resetZoom
                )
                // userZoom on top of the per-page fitScale already applied
                // inside ContinuousPagesView; identity when not zoomed.
                .scaleEffect(zoom.userZoom)
                .offset(zoom.panOffset)
            }
        }
    }

    // MARK: - Zoom reset (F-053)

    /// Shared by the finger double-tap and ZoomResetButton.
    private func resetZoom() {
        guard zoom.isZoomed else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            zoom.reset(flashHUD: true)
        }
    }

    // MARK: - Load

    private func loadPages() {
        pages = store.pages(of: document)
        currentPageIndex = 0
    }

    // MARK: - Page CRUD (F-051)

    private func handleAddPage() {
        let newPage = store.appendPage(to: document)
        pages = store.pages(of: document)
        let newIndex = pages.count - 1

        switch settings.paginationStyle {
        case .singlePage:
            // Carousel: animating the index slides the new page in; the
            // direction falls out of the offset math.
            withAnimation(.easeInOut(duration: 0.25)) {
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
        guard pages.count > 1 else { return }
        let deleteIndex = currentPageIndex
        let pageToDelete = pages[deleteIndex]
        let newIndex = max(0, deleteIndex - 1)

        // dismantleUIView in PencilKitBridge flushes the departing page's
        // drawing before the PKCanvasView is torn down.
        store.deletePage(pageToDelete, from: document)
        let newPages = store.pages(of: document)
        let safeIndex = min(newIndex, newPages.count - 1)

        switch settings.paginationStyle {
        case .singlePage:
            // Carousel: removing the page from the ForEach and animating the
            // index slides the neighbour into place.
            withAnimation(.easeInOut(duration: 0.25)) {
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
        // v1 stub: clear all pages and start fresh with one blank page.
        // F-011 will replace this with navigation to NoteListScreen (v3).
        store.resetDocument(document)
        pages = store.pages(of: document)
        currentPageIndex = 0
    }
}

#Preview {
    // Same name the App layer uses, so the preview never renames/adopts
    // another document via the legacy-adoption fallback.
    WritingScreen(document: NoteStore.shared.loadOrCreateDocument(named: "dev-default-document"))
        .environmentObject(NoteStore.shared)
        .environmentObject(SettingsStore.shared)
}
