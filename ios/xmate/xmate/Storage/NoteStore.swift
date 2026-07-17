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

    private convenience init() {
        self.init(storeURL: Self.defaultStoreURL())
    }

    /// Internal initializer used by persistence and migration tests with an
    /// isolated store. Production uses the app-private default URL above.
    init(storeURL: URL, storeType: String = NSSQLiteStoreType) {
        container = NSPersistentContainer(name: "xmate")

        if storeType == NSSQLiteStoreType {
            try? FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = storeType
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions = [description]

        var storeLoadError: Error?
        container.loadPersistentStores { _, error in
            storeLoadError = error
        }
        if let storeLoadError {
            fatalError("NoteStore failed to load store: \(storeLoadError)")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true

        do {
            try Self.backfillLegacyEnvelopeRecords(in: container.viewContext)
        } catch {
            fatalError("NoteStore failed to prepare envelope records: \(error)")
        }
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    private static func defaultStoreURL() -> URL {
        // Route the persistent store into Library/Application Support/ so it
        // stays app-private and invisible to the Files app.
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("xmate.sqlite")
    }

    // MARK: - Envelope persistence primitives (F-062)

    /// Idempotently wraps every legacy orphan Document in Draft envelope
    /// metadata. The Document/Page objects and drawing blobs are never copied
    /// or normalized.
    private static func backfillLegacyEnvelopeRecords(
        in context: NSManagedObjectContext
    ) throws {
        let documents = try context.fetch(Document.fetchRequest())
        let existingEnvelopes = try context.fetch(
            LetterEnvelopeRecord.fetchRequest()
        )
        var representedDocumentIDs = Set(
            existingEnvelopes.compactMap(\.documentID)
        )

        for document in documents {
            let documentID: UUID
            if let existingID = document.id {
                documentID = existingID
            } else {
                let generatedID = UUID()
                document.id = generatedID
                documentID = generatedID
            }

            guard representedDocumentIDs.insert(documentID).inserted else {
                continue
            }

            let createdAt = document.createdAt ?? Date()
            let updatedAt = document.updatedAt ?? createdAt
            let envelope = LetterEnvelopeRecord(context: context)
            envelope.id = UUID()
            envelope.documentID = documentID
            envelope.title = document.title ?? ""
            envelope.senderID = nil
            envelope.recipientID = nil
            envelope.mailboxLocationRawValue = "draft"
            envelope.deliveryStateRawValue = "notSubmitted"
            envelope.documentRevision = max(document.contentRevision, 0)
            envelope.createdAt = createdAt
            envelope.updatedAt = updatedAt
            envelope.sentAt = nil
            envelope.receivedAt = nil
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func envelopeRecords(
        mailboxLocationRawValue: String? = nil
    ) throws -> [LetterEnvelopeRecord] {
        let request = LetterEnvelopeRecord.fetchRequest()
        if let mailboxLocationRawValue {
            request.predicate = NSPredicate(
                format: "mailboxLocationRawValue == %@",
                mailboxLocationRawValue
            )
        }
        request.sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: false),
        ]
        return try viewContext.fetch(request)
    }

    func envelopeRecord(id: UUID) throws -> LetterEnvelopeRecord? {
        let request = LetterEnvelopeRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try viewContext.fetch(request).first
    }

    func envelopeRecord(documentID: UUID) throws -> LetterEnvelopeRecord? {
        let request = LetterEnvelopeRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "documentID == %@",
            documentID as CVarArg
        )
        request.fetchLimit = 1
        return try viewContext.fetch(request).first
    }

    func document(id: UUID) throws -> Document? {
        let request = Document.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try viewContext.fetch(request).first
    }

    // MARK: - Document lookup / creation

    /// Load the Document with the given name (title), creating it as the
    /// default A4 portrait document if it doesn't exist. The App layer decides
    /// the name — Storage never decides which document the app opens.
    ///
    /// Legacy adoption: earlier builds used an anonymous "first document"
    /// lookup. If no document matches the name but one exists from those
    /// builds, it is renamed and adopted so existing handwriting survives.
    @discardableResult
    func loadOrCreateDocument(named name: String) -> Document {
        loadOrCreateDocument(
            named: name,
            pageSpec: PagePresetCatalog.currentDocumentPageSpec,
            presetID: PagePresetCatalog.currentDocumentPagePresetID,
            allowsLegacyAdoption: true
        )
    }

    /// Load or create a named document using an explicit page preset. Existing
    /// documents keep their persisted spec; the preset is applied only when a
    /// new document is created.
    @discardableResult
    func loadOrCreateDocument(
        named name: String,
        pagePreset: PagePresetCatalog.Preset,
        allowsLegacyAdoption: Bool = false
    ) -> Document {
        loadOrCreateDocument(
            named: name,
            pageSpec: pagePreset.spec,
            presetID: pagePreset.id,
            allowsLegacyAdoption: allowsLegacyAdoption
        )
    }

    private func loadOrCreateDocument(
        named name: String,
        pageSpec: PageSpec,
        presetID: String?,
        allowsLegacyAdoption: Bool
    ) -> Document {
        let request = NSFetchRequest<Document>(entityName: "Document")
        request.predicate = NSPredicate(format: "title == %@", name)
        request.fetchLimit = 1
        if let existing = try? viewContext.fetch(request).first {
            return existing
        }

        if allowsLegacyAdoption {
            let any = NSFetchRequest<Document>(entityName: "Document")
            any.fetchLimit = 1
            if let legacy = try? viewContext.fetch(any).first {
                let now = Date()
                legacy.title = name
                legacy.updatedAt = now
                if let documentID = legacy.id,
                   let envelope = try? envelopeRecord(documentID: documentID) {
                    envelope.title = name
                    envelope.updatedAt = now
                }
                saveViewContextOrFail(operation: "adopt legacy document")
                return legacy
            }
        }

        return createDocument(
            named: name,
            pageSpec: pageSpec,
            presetID: presetID
        )
    }

    private func createDocument(
        named name: String,
        pageSpec: PageSpec,
        presetID: String?
    ) -> Document {
        let now = Date()
        let documentID = UUID()
        let doc = Document(context: viewContext)
        doc.id = documentID
        doc.title = name
        doc.createdAt = now
        doc.updatedAt = now
        doc.contentRevision = 0
        doc.applyPageSpec(pageSpec, presetID: presetID)

        let page = Page(context: viewContext)
        page.id = UUID()
        page.drawingData = nil
        page.version = 0

        doc.pages = NSOrderedSet(object: page)

        let envelope = LetterEnvelopeRecord(context: viewContext)
        envelope.id = UUID()
        envelope.documentID = documentID
        envelope.title = name
        envelope.senderID = nil
        envelope.recipientID = nil
        envelope.mailboxLocationRawValue = "draft"
        envelope.deliveryStateRawValue = "notSubmitted"
        envelope.documentRevision = 0
        envelope.createdAt = now
        envelope.updatedAt = now
        envelope.sentAt = nil
        envelope.receivedAt = nil

        saveViewContextOrFail(operation: "create draft envelope and document")
        return doc
    }

    private func saveViewContextOrFail(operation: String) {
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            fatalError("NoteStore failed to \(operation): \(error)")
        }
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
        let now = Date()
        let page = Page(context: viewContext)
        page.id = UUID()
        page.drawingData = nil
        page.version = 0

        let mutable = document.pages.mutableCopy() as! NSMutableOrderedSet
        mutable.add(page)
        document.pages = mutable as NSOrderedSet
        markDocumentContentChangedOrFail(document, at: now)
        saveViewContextOrFail(operation: "append page")
        return page
    }

    /// Remove a page from the document. The caller must ensure at least one
    /// page will remain — enforced by the UI (delete page disabled when count == 1).
    func deletePage(_ page: Page, from document: Document) {
        let now = Date()
        let mutable = document.pages.mutableCopy() as! NSMutableOrderedSet
        mutable.remove(page)
        document.pages = mutable as NSOrderedSet
        viewContext.delete(page)
        markDocumentContentChangedOrFail(document, at: now)
        saveViewContextOrFail(operation: "delete page")
    }

    /// Delete all pages and recreate a single blank page.
    /// v1 placeholder for F-011 "delete document" — once the Library document
    /// manager lands, this will dismiss to the list instead.
    func resetDocument(_ document: Document) {
        let now = Date()
        let allPages = pages(of: document)
        for page in allPages {
            viewContext.delete(page)
        }
        let blank = Page(context: viewContext)
        blank.id = UUID()
        blank.drawingData = nil
        blank.version = 0
        document.pages = NSOrderedSet(object: blank)
        markDocumentContentChangedOrFail(document, at: now)
        saveViewContextOrFail(operation: "reset document")
    }

    private func markDocumentContentChangedOrFail(
        _ document: Document,
        at date: Date
    ) {
        do {
            try Self.markDocumentContentChanged(
                document,
                at: date,
                in: viewContext
            )
        } catch {
            viewContext.rollback()
            fatalError("NoteStore failed to update document revision: \(error)")
        }
    }

    private static func markDocumentContentChanged(
        _ document: Document,
        at date: Date,
        in context: NSManagedObjectContext
    ) throws {
        document.updatedAt = date
        document.contentRevision += 1

        guard let documentID = document.id else { return }
        let request = LetterEnvelopeRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "documentID == %@",
            documentID as CVarArg
        )
        request.fetchLimit = 1
        if let envelope = try context.fetch(request).first {
            envelope.documentRevision = document.contentRevision
            envelope.updatedAt = date
        }
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
        do {
            if let document = page.document {
                try markDocumentContentChanged(
                    document,
                    at: Date(),
                    in: ctx
                )
            }
            try ctx.save()
        } catch {
            assertionFailure("NoteStore failed to persist drawing: \(error)")
        }
    }
}
