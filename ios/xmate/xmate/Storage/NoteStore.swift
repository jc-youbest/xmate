// NoteStore
//
// Core Data store managing Document and Page entities. The persistent
// store lives in Library/Application Support/, app-private and not
// exposed to the Files app. This is F-011's Core Data storage layer;
// it replaced the earlier single-file canvas.drawing persistence.
//
// Scope (roadmap stage v1): single implicit "default document" with
// multi-page support — add, delete, and query pages (F-051). The full
// note-list CRUD UI (F-011) and Stationery / PhotoFrame / ImageAsset
// entities are still ahead.

import Foundation
import CoreData

final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    let container: NSPersistentContainer

    /// Serial queue for save operations, so concurrent writes can't race.
    private let saveQueue = DispatchQueue(
        label: "xmate.noteStore.save",
        qos: .utility
    )

    private init() {
        container = NSPersistentContainer(name: "xmate")

        // Route the persistent store into Library/Application Support/
        // so it's app-private and invisible to the Files app.
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )
        let storeURL = appSupport.appendingPathComponent("xmate.sqlite")

        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                // Store load failure during development is a bug, not a
                // runtime condition we recover from.
                fatalError("NoteStore failed to load store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Document lookup / creation

    /// Load the Document with the given name (title), creating it (with one
    /// empty page) if it doesn't exist. The App layer decides the name —
    /// Storage never decides which document the app opens.
    ///
    /// Legacy adoption: earlier builds used an anonymous "first document"
    /// lookup. If no document matches the name but one exists from those
    /// builds, it is renamed and adopted so existing handwriting survives.
    @discardableResult
    func loadOrCreateDocument(named name: String) -> Document {
        let request = NSFetchRequest<Document>(entityName: "Document")
        request.predicate = NSPredicate(format: "title == %@", name)
        request.fetchLimit = 1
        if let existing = try? viewContext.fetch(request).first {
            return existing
        }

        let any = NSFetchRequest<Document>(entityName: "Document")
        any.fetchLimit = 1
        if let legacy = try? viewContext.fetch(any).first {
            legacy.title = name
            try? viewContext.save()
            return legacy
        }

        return createDocument(named: name)
    }

    private func createDocument(named name: String) -> Document {
        let doc = Document(context: viewContext)
        doc.id = UUID()
        doc.title = name
        doc.createdAt = Date()
        doc.updatedAt = Date()

        let page = Page(context: viewContext)
        page.id = UUID()
        page.drawingData = nil
        page.version = 0

        doc.pages = NSOrderedSet(object: page)

        try? viewContext.save()
        return doc
    }

    /// Return the first page of the given document.
    /// Defensive: creates a page if the document somehow has none.
    func currentPage(of document: Document) -> Page {
        if let first = document.pages.firstObject as? Page {
            return first
        }
        return appendPage(to: document)
    }

    // MARK: - Multi-page API (F-051)

    /// Return all pages of the document in their stored order.
    func pages(of document: Document) -> [Page] {
        document.pages.array.compactMap { $0 as? Page }
    }

    /// Append a new blank page at the end of the document and return it.
    @discardableResult
    func appendPage(to document: Document) -> Page {
        let page = Page(context: viewContext)
        page.id = UUID()
        page.drawingData = nil
        page.version = 0

        let mutable = document.pages.mutableCopy() as! NSMutableOrderedSet
        mutable.add(page)
        document.pages = mutable as NSOrderedSet
        document.updatedAt = Date()
        try? viewContext.save()
        return page
    }

    /// Remove a page from the document. The caller must ensure at least one
    /// page will remain — enforced by the UI (delete page disabled when count == 1).
    func deletePage(_ page: Page, from document: Document) {
        let mutable = document.pages.mutableCopy() as! NSMutableOrderedSet
        mutable.remove(page)
        document.pages = mutable as NSOrderedSet
        document.updatedAt = Date()
        viewContext.delete(page)
        try? viewContext.save()
    }

    /// Delete all pages and recreate a single blank page.
    /// v1 placeholder for F-011 "delete document" — in v3 this will
    /// dismiss to the note list instead.
    func resetDocument(_ document: Document) {
        let allPages = pages(of: document)
        for page in allPages {
            viewContext.delete(page)
        }
        let blank = Page(context: viewContext)
        blank.id = UUID()
        blank.drawingData = nil
        blank.version = 0
        document.pages = NSOrderedSet(object: blank)
        document.updatedAt = Date()
        try? viewContext.save()
    }

    // MARK: - Drawing persistence
    //
    // All writes are addressed by the page's UUID (not a managed-object
    // reference) so the only caller — DrawingSessionManager — never has
    // to hold a main-context Page across threads. Every write carries a
    // monotonic `version`; the store accepts it only when it is strictly
    // greater than the stored version (see `writeDrawing`). Combined with the
    // session manager's single-active-canvas gating, this guarantees a stale
    // (inactive) canvas can never overwrite newer handwriting.

    /// Read the current drawing blob and version for a page, on the main
    /// view context. Returns nil if no page with that id exists.
    /// Called by DrawingSessionManager when (re)loading a canvas so its
    /// in-memory version stamp is seeded from the canonical store value.
    func drawing(forPageID id: UUID) -> (data: Data?, version: Int64)? {
        let request = NSFetchRequest<Page>(entityName: "Page")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let page = try? viewContext.fetch(request).first else { return nil }
        return (page.drawingData, page.version)
    }

    /// Asynchronous, debounced save path (drawing-changed while writing).
    /// Hops onto the serial save queue + a background context so the main
    /// thread is never blocked by disk I/O.
    func savePageDrawing(_ data: Data, pageID: UUID, version: Int64) {
        saveQueue.async { [container] in
            let bg = container.newBackgroundContext()
            bg.performAndWait {
                Self.writeDrawing(data, pageID: pageID, version: version, in: bg)
            }
        }
    }

    /// Synchronous flush path. Used for the mode-switch / page-turn / overlay
    /// handoffs and `willResignActive`, where the next step (reloading another
    /// canvas of the same page, or app suspension) must observe this write as
    /// already committed. Blocks the caller until the background context saves.
    func savePageDrawingSync(_ data: Data, pageID: UUID, version: Int64) {
        let bg = container.newBackgroundContext()
        bg.performAndWait {
            Self.writeDrawing(data, pageID: pageID, version: version, in: bg)
        }
    }

    /// Core write with the optimistic-concurrency guard. Runs inside the
    /// given background context's queue. A write whose `version` is not
    /// strictly greater than the stored version is dropped — this is the
    /// last-line backstop against a stale canvas clobbering newer strokes.
    private static func writeDrawing(_ data: Data,
                                     pageID: UUID,
                                     version: Int64,
                                     in ctx: NSManagedObjectContext) {
        let request = NSFetchRequest<Page>(entityName: "Page")
        request.predicate = NSPredicate(format: "id == %@", pageID as CVarArg)
        request.fetchLimit = 1
        guard let page = try? ctx.fetch(request).first else { return }
        guard version > page.version else {
            // Stale or duplicate write — ignore so newer handwriting survives.
            return
        }
        page.drawingData = data
        page.version = version
        page.document?.updatedAt = Date()
        try? ctx.save()
    }
}
