// U-101 WritingScreen
//
// The writing-mode screen for roadmap stage v1 (F-051) — the writing
// variant of the Content Screen. v1 stage 2 introduces fixed-size
// logical pages (F-053) projected onto each iPad's screen.
//
// Layout:
//   U-102 WritingTopBar    — thin top bar (page indicator, add, overflow menu)
//   U-023 Canvas           — active drawing surface via C-002 PencilKitBridge,
//                            sized to the document's logical page (C-027
//                            PageGeometry) and uniformly scaled to fit the
//                            available area, centered horizontally and
//                            vertically.
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
// Geometry (stage 2, F-053):
//   The PencilKitBridge is framed at the page's logical dimensions
//   (C-027 PageGeometry.letterLogicalSize for letters), then visually
//   scaled with .scaleEffect(fitScale) to fit the viewport. Apple Pencil
//   input lands at logical coordinates regardless of fitScale, so strokes
//   are stored and reload identically on any iPad.
//
// Orientation: the app is locked to portrait at the Info.plist level for
// stage 2. When postcard support arrives (with a Core Data migration
// adding `contentType` to Document), orientation will become per-screen.
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

            // U-023 Canvas area — fixed-size logical page projected onto
            // the available viewport via C-002 PencilKitBridge and
            // C-027 PageGeometry (F-053 stage 2).
            //
            // Stage 2 (letter only): contentType is hard-coded to
            // .letter. When the Document.contentType field arrives with
            // postcard support, read it from the current document.
            GeometryReader { proxy in
                let contentType: ContentType = .letter
                let logical = PageGeometry.logicalSize(for: contentType)
                let fitScale = PageGeometry.fitScale(in: proxy.size,
                                                     for: contentType)

                ZStack {
                    if let page = currentPage {
                        PencilKitBridge(
                            page: page,
                            store: store,
                            onSwipeUp: handleSwipeUp,
                            onSwipeDown: handleSwipeDown
                        )
                        // Frame the canvas at its logical dimensions —
                        // PKCanvasView records strokes in this
                        // coordinate space, so the same drawing data
                        // re-loads identically on any iPad.
                        .frame(width: logical.width, height: logical.height)
                        // Project the logical page onto the viewport
                        // by a uniform scale that preserves aspect.
                        .scaleEffect(fitScale)
                        // Slide the incoming page in from the correct
                        // edge; .id-driven recreation triggers the
                        // transition on every page change.
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: turningForward ? .bottom : .top),
                                removal:   .move(edge: turningForward ? .top   : .bottom)
                            )
                        )
                        .id(page.id)
                    }
                }
                // Center the scaled page in the viewport. Letterbox
                // strips on the leftover area inherit the screen
                // background.
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            // Extend the canvas area below the home indicator so the
            // PKToolPicker floats above full writable space.
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
