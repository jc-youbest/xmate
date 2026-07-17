import CoreData
import Foundation
import Testing
@testable import xmate

@MainActor
struct NoteStoreEnvelopePersistenceTests {
    @Test func newDocumentIsCreatedWithOneDraftEnvelopeAtomically() throws {
        let store = makeInMemoryStore()

        let document = store.loadOrCreateDocument(named: "Atomic Draft")
        let documentID = try #require(document.id)
        let storedEnvelope = try store.envelopeRecord(documentID: documentID)
        let envelope = try #require(storedEnvelope)

        #expect(envelope.id != nil)
        #expect(envelope.documentID == documentID)
        #expect(envelope.title == "Atomic Draft")
        #expect(envelope.mailboxLocationRawValue == MailboxLocation.draft.rawValue)
        #expect(envelope.deliveryStateRawValue == DeliveryState.notSubmitted.rawValue)
        #expect(envelope.documentRevision == 0)
        #expect(document.contentRevision == 0)
        #expect(store.pages(of: document).count == 1)
        let initialEnvelopeCount = try store.envelopeRecords().count
        #expect(initialEnvelopeCount == 1)

        let loadedAgain = store.loadOrCreateDocument(named: "Atomic Draft")
        #expect(loadedAgain === document)
        let finalEnvelopeCount = try store.envelopeRecords().count
        #expect(finalEnvelopeCount == 1)
    }

    @Test func structuralMutationAdvancesDocumentAndEnvelopeRevisionTogether() throws {
        let store = makeInMemoryStore()
        let document = store.loadOrCreateDocument(named: "Revision Draft")
        let documentID = try #require(document.id)

        store.appendPage(to: document)

        let storedEnvelope = try store.envelopeRecord(documentID: documentID)
        let envelope = try #require(storedEnvelope)
        #expect(document.contentRevision == 1)
        #expect(envelope.documentRevision == 1)
        #expect(envelope.updatedAt == document.updatedAt)
    }

    @Test func acceptedDrawingWriteAdvancesDocumentAndEnvelopeRevisionTogether() throws {
        let store = makeInMemoryStore()
        let document = store.loadOrCreateDocument(named: "Drawing Revision")
        let documentID = try #require(document.id)
        let pageID = try #require(store.currentPage(of: document).id)

        store.savePageDrawingSync(Data([0xCA, 0xFE]), pageID: pageID, version: 1)
        store.viewContext.reset()

        let storedDocument = try store.document(id: documentID)
        let reloadedDocument = try #require(storedDocument)
        let storedEnvelope = try store.envelopeRecord(documentID: documentID)
        let envelope = try #require(storedEnvelope)
        let drawing = store.drawing(forPageID: pageID)

        #expect(drawing?.data == Data([0xCA, 0xFE]))
        #expect(drawing?.version == 1)
        #expect(reloadedDocument.contentRevision == 1)
        #expect(envelope.documentRevision == 1)
        #expect(envelope.updatedAt == reloadedDocument.updatedAt)
    }

    @Test func v2MigrationBackfillsDraftAndPreservesOrderedDrawingData() throws {
        let fixture = try makeV2StoreFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        let store = NoteStore(storeURL: fixture.storeURL)
        let storedDocument = try store.document(id: fixture.documentID)
        let document = try #require(storedDocument)
        let pages = store.pages(of: document)
        let storedEnvelope = try store.envelopeRecord(
            documentID: fixture.documentID
        )
        let envelope = try #require(storedEnvelope)

        #expect(document.title == fixture.title)
        #expect(document.pagePresetID == fixture.pagePresetID)
        #expect(document.logicalPageWidth == fixture.pageWidth)
        #expect(document.logicalPageHeight == fixture.pageHeight)
        #expect(document.contentRevision == 0)
        #expect(pages.map(\.id) == fixture.pageIDs.map(Optional.some))
        #expect(pages.map(\.drawingData) == fixture.drawingData.map(Optional.some))
        #expect(pages.map(\.version) == fixture.pageVersions)

        #expect(envelope.id != nil)
        #expect(envelope.documentID == fixture.documentID)
        #expect(envelope.title == fixture.title)
        #expect(envelope.senderID == nil)
        #expect(envelope.recipientID == nil)
        #expect(envelope.mailboxLocationRawValue == MailboxLocation.draft.rawValue)
        #expect(envelope.deliveryStateRawValue == DeliveryState.notSubmitted.rawValue)
        #expect(envelope.documentRevision == 0)
        #expect(envelope.createdAt == fixture.createdAt)
        #expect(envelope.updatedAt == fixture.updatedAt)
        #expect(envelope.sentAt == nil)
        #expect(envelope.receivedAt == nil)
        let envelopeCount = try store.envelopeRecords().count
        #expect(envelopeCount == 1)
    }

    private func makeInMemoryStore() -> NoteStore {
        NoteStore(
            storeURL: URL(fileURLWithPath: "/dev/null"),
            storeType: NSInMemoryStoreType
        )
    }

    private func makeV2StoreFixture() throws -> V2StoreFixture {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xmate-v2-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let storeURL = directoryURL.appendingPathComponent("xmate.sqlite")

        let modelBundle = Bundle(for: Document.self)
        let modelDirectoryURL = try #require(
            modelBundle.url(forResource: "xmate", withExtension: "momd")
        )
        let modelURL = modelDirectoryURL.appendingPathComponent("xmate 2.mom")
        let model = try #require(NSManagedObjectModel(contentsOf: modelURL))

        let container = NSPersistentContainer(
            name: "xmate-v2-fixture",
            managedObjectModel: model
        )
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldInferMappingModelAutomatically = false
        description.shouldMigrateStoreAutomatically = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError { throw loadError }

        let documentID = UUID()
        let pageIDs = [UUID(), UUID()]
        let drawingData = [Data([0x01, 0x02, 0x03]), Data([0xA0, 0xB0])]
        let pageVersions: [Int64] = [4, 9]
        let title = "Migrated Letter"
        let pagePresetID = "a4-landscape"
        let pageWidth = 842.0
        let pageHeight = 595.0
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let context = container.viewContext

        let documentEntity = try #require(model.entitiesByName["Document"])
        let document = NSManagedObject(entity: documentEntity, insertInto: context)
        document.setValue(documentID, forKey: "id")
        document.setValue(title, forKey: "title")
        document.setValue(createdAt, forKey: "createdAt")
        document.setValue(updatedAt, forKey: "updatedAt")
        document.setValue(pagePresetID, forKey: "pagePresetID")
        document.setValue(pageWidth, forKey: "logicalPageWidth")
        document.setValue(pageHeight, forKey: "logicalPageHeight")

        let pageEntity = try #require(model.entitiesByName["Page"])
        let pages = zip(pageIDs, zip(drawingData, pageVersions)).map {
            pageID, payload in
            let page = NSManagedObject(entity: pageEntity, insertInto: context)
            page.setValue(pageID, forKey: "id")
            page.setValue(payload.0, forKey: "drawingData")
            page.setValue(payload.1, forKey: "version")
            page.setValue(document, forKey: "document")
            return page
        }
        document.setValue(NSOrderedSet(array: pages), forKey: "pages")
        try context.save()

        for persistentStore in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(persistentStore)
        }

        return V2StoreFixture(
            directoryURL: directoryURL,
            storeURL: storeURL,
            documentID: documentID,
            pageIDs: pageIDs,
            drawingData: drawingData,
            pageVersions: pageVersions,
            title: title,
            pagePresetID: pagePresetID,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct V2StoreFixture {
    let directoryURL: URL
    let storeURL: URL
    let documentID: UUID
    let pageIDs: [UUID]
    let drawingData: [Data]
    let pageVersions: [Int64]
    let title: String
    let pagePresetID: String
    let pageWidth: Double
    let pageHeight: Double
    let createdAt: Date
    let updatedAt: Date
}
