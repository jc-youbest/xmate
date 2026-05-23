// U-101 WritingScreen
//
// The writing-mode screen for roadmap stage v1 (F-051).
//
// Layout:
//   U-102 WritingTopBar    — thin top bar (page indicator, add, overflow menu)
//   U-104 WritingSidebar   — structural placeholder (hidden, zero width).
//                            When the sidebar is wired in, the canvas reflows
//                            into the remaining horizontal space automatically.
//   U-023 Canvas           — active drawing surface via C-002 PencilKitBridge
//
// Page navigation (F-051):
//   • Finger swipe up   → next page  (gesture inside PencilKitBridge)
//   • Finger swipe down → previous page
//   • Only Apple Pencil draws; finger is reserved for navigation (F-001).
//
// Page identity: PencilKitBridge is keyed with .id(currentPage?.id) — the
// page's UUID. Changing currentPage always creates a fresh PKCanvasView with
// the new page's saved drawing. dismantleUIView in PencilKitBridge flushes
// the departing page before teardown, so no strokes are ever lost on a fast
// page turn.
//
// Delete document (v1 stub): resets to a single blank page instead of
// navigating to a note list, because U-002 NoteListScreen does not exist
// until v3. F-011 will replace this with proper navigation.

import SwiftUI

struct WritingScreen: View {
    @EnvironmentObject var store: NoteStore

    // MARK: - State

    @State private var document: Document?
    @State private var pages: [Page] = []
    @State private var currentPageIndex: Int = 0

    /// Direction of the most recent page turn; drives the slide transition edge.
    @State private var turningForward: Bool = true

    @State private var showDeletePageAlert: Bool = false
    @State private var showDeleteDocumentAlert: Bool = false

    // MARK: - Derived

    private var currentPage: Page? {
        guard !pages.isEmpty, currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // U-102 WritingTopBar — only shown once pages are loaded.
            if !pages.isEmpty {
                WritingTopBar(
                    currentIndex: currentPageIndex,
                    pageCount: pages.count,
                    onAddPage: handleAddPage,
                    onDeletePage: { showDeletePageAlert = true },
                    onDeleteDocument: { showDeleteDocumentAlert = true }
                )
            }

            // Canvas area. U-104 WritingSidebar will share this HStack
            // when it is introduced; the canvas reflows automatically.
            HStack(spacing: 0) {

                // U-104 WritingSidebar — reserved, zero width for now.

                // U-023 Canvas via C-002 PencilKitBridge.
                // Keyed by page UUID so every page change yields a fresh
                // PKCanvasView (loading that page's saved drawing), while
                // dismantleUIView ensures the departing page is flushed first.
                if let page = currentPage {
                    PencilKitBridge(
                        page: page,
                        store: store,
                        onSwipeUp: handleSwipeUp,
                        onSwipeDown: handleSwipeDown
                    )
                    // Extend the canvas below the home indicator so the
                    // PKToolPicker floats above full writable space.
                    .ignoresSafeArea(edges: .bottom)
                    // Slide the incoming page in from the correct edge.
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: turningForward ? .bottom : .top),
                            removal:   .move(edge: turningForward ? .top   : .bottom)
                        )
                    )
                    // View identity keyed by page UUID. Any page change —
                    // navigation, add, or delete — recreates the bridge and
                    // triggers the slide transition.
                    .id(page.id)
                }
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

    // MARK: - Page CRUD (F-051)

    private func handleAddPage() {
        guard let doc = document else { return }
        store.appendPage(to: doc)
        pages = store.pages(of: doc)
        turningForward = true
        withAnimation(.easeInOut(duration: 0.18)) {
            currentPageIndex = pages.count - 1
        }
    }

    private func handleDeletePage() {
        guard let doc = document, pages.count > 1 else { return }
        let deleteIndex = currentPageIndex
        let pageToDelete = pages[deleteIndex]
        let newIndex = max(0, deleteIndex - 1)

        // Animate toward the adjacent page, then delete.
        // dismantleUIView in PencilKitBridge flushes the departing page's
        // drawing before the PKCanvasView is torn down.
        turningForward = false
        store.deletePage(pageToDelete, from: doc)
        withAnimation(.easeInOut(duration: 0.18)) {
            pages = store.pages(of: doc)
            currentPageIndex = min(newIndex, pages.count - 1)
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
}
