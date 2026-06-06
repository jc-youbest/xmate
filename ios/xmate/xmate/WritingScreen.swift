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
//   .continuous  → ContinuousPagesView: free-scroll LazyVStack with 20 pt
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
            // Both views share the same currentPageIndex binding so the
            // PageIndicator in WritingTopBar stays in sync regardless of style.
            Group {
                switch settings.paginationStyle {

                case .singlePage:
                    SinglePagesView(
                        pages: pages,
                        paper: PaperPreset.letter,
                        store: store,
                        currentPageIndex: $currentPageIndex,
                        turningForward: $turningForward
                    )

                case .continuous:
                    ContinuousPagesView(
                        pages: pages,
                        paper: PaperPreset.letter,
                        store: store,
                        currentPageIndex: $currentPageIndex,
                        scrollTarget: scrollTarget,
                        onScrollTargetConsumed: { scrollTarget = nil }
                    )
                }
            }
            .ignoresSafeArea(edges: .bottom)
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

#Preview {
    WritingScreen()
        .environmentObject(NoteStore.shared)
        .environmentObject(SettingsStore.shared)
}
