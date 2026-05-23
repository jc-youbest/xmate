// C-001 NoteStore
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

    // MARK: - Default document (roadmap stage v0)

    /// Load the default Document, creating it (with one empty page) on
    /// first launch.
    @discardableResult
    func loadOrCreateDefaultDocument() -> Document {
        let request = NSFetchRequest<Document>(entityName: "Document")
        request.fetchLimit = 1
        if let existing = try? viewContext.fetch(request).first {
            return existing
        }
        return createDefaultDocument()
    }

    private func createDefaultDocument() -> Document {
        let doc = Document(context: viewContext)
        doc.id = UUID()
        doc.title = "Untitled"
        doc.createdAt = Date()
        doc.updatedAt = Date()

        let page = Page(context: viewContext)
        page.id = UUID()
        page.drawingData = nil

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
        document.pages = NSOrderedSet(object: blank)
        document.updatedAt = Date()
        try? viewContext.save()
    }

    // MARK: - Drawing persistence

    /// Save the drawing data for a page. The disk write happens on a
    /// background serial queue + background context so the caller's
    /// thread (typically main) is never blocked by disk I/O, and
    /// concurrent saves can't race for the same row.
    func savePageDrawing(_ data: Data, page: Page) {
        let objectID = page.objectID
        saveQueue.async { [container] in
            let bg = container.newBackgroundContext()
            bg.performAndWait {
                guard let bgPage = try? bg.existingObject(with: objectID) as? Page else {
                    return
                }
                bgPage.drawingData = data
                bgPage.document?.updatedAt = Date()
                try? bg.save()
            }
        }
    }
}
