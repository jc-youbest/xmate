import CoreData
import Foundation
import Testing
@testable import xmate

@MainActor
struct LocalMailboxRepositoryTests {
    @Test func fixedLocationQueryReturnsMappedValuesInStorageOrder() throws {
        let store = makeStore()
        let older = try makeEnvelope(
            in: store,
            title: "Older Inbox",
            location: .inbox,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let newer = try makeEnvelope(
            in: store,
            title: "Newer Inbox",
            location: .inbox,
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        _ = try makeEnvelope(
            in: store,
            title: "Draft",
            location: .draft,
            updatedAt: Date(timeIntervalSince1970: 30)
        )
        _ = try makeEnvelope(
            in: store,
            title: "Outbox",
            location: .outbox,
            updatedAt: Date(timeIntervalSince1970: 40)
        )
        _ = try makeEnvelope(
            in: store,
            title: "Sent",
            location: .sent,
            updatedAt: Date(timeIntervalSince1970: 50)
        )

        let repository = LocalMailboxRepository(store: store)
        let envelopes = try repository.envelopes(in: .inbox)

        #expect(envelopes.map(\.id) == [newer.envelopeID, older.envelopeID])
        #expect(envelopes.map(\.title) == ["Newer Inbox", "Older Inbox"])
        #expect(envelopes.allSatisfy { $0.mailboxLocation == .inbox })
        #expect(try repository.envelopes(in: .draft).count == 1)
        #expect(try repository.envelopes(in: .outbox).count == 1)
        #expect(try repository.envelopes(in: .sent).count == 1)
    }

    @Test func matchingCachedDocumentProducesAHit() throws {
        let store = makeStore()
        let fixture = try makeEnvelope(
            in: store,
            title: "Cached Draft",
            location: .draft,
            updatedAt: Date(timeIntervalSince1970: 10)
        )

        let result = try LocalMailboxRepository(store: store)
            .resolveEnvelope(id: fixture.envelopeID)
        let resolution = try #require(result)

        #expect(resolution.envelope.documentID == fixture.documentID)
        #expect(resolution.documentCache == .hit(CachedDocumentDescriptor(
            documentID: fixture.documentID,
            revision: .initial
        )))
    }

    @Test func absentDocumentProducesAMissingRequirement() throws {
        let store = makeStore()
        let fixture = try makeEnvelope(
            in: store,
            title: "Metadata Only",
            location: .inbox,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let document = try #require(try store.document(id: fixture.documentID))
        store.viewContext.delete(document)
        try store.viewContext.save()

        let result = try LocalMailboxRepository(store: store)
            .resolveEnvelope(id: fixture.envelopeID)
        let resolution = try #require(result)

        #expect(resolution.documentCache == .missing(
            DocumentCacheRequirement(
                documentID: fixture.documentID,
                revision: .initial
            )
        ))
    }

    @Test func revisionMismatchProducesAStaleResult() throws {
        let store = makeStore()
        let fixture = try makeEnvelope(
            in: store,
            title: "Stale Draft",
            location: .draft,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let record = try #require(
            try store.envelopeRecord(id: fixture.envelopeID)
        )
        record.documentRevision = 4
        try store.viewContext.save()

        let result = try LocalMailboxRepository(store: store)
            .resolveEnvelope(id: fixture.envelopeID)
        let resolution = try #require(result)

        #expect(resolution.documentCache == .stale(
            cached: CachedDocumentDescriptor(
                documentID: fixture.documentID,
                revision: .initial
            ),
            required: DocumentCacheRequirement(
                documentID: fixture.documentID,
                revision: DocumentRevision(rawValue: 4)
            )
        ))
    }

    @Test func malformedStorageValueIsRejectedAtTheBoundary() throws {
        let store = makeStore()
        let fixture = try makeEnvelope(
            in: store,
            title: "Malformed",
            location: .draft,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let record = try #require(
            try store.envelopeRecord(id: fixture.envelopeID)
        )
        record.deliveryStateRawValue = "delivered"
        try store.viewContext.save()

        #expect(throws: LocalMailboxRepositoryError.invalidEnvelopeRecord(
            id: fixture.envelopeID
        )) {
            try LocalMailboxRepository(store: store)
                .envelope(id: fixture.envelopeID)
        }
    }

    private func makeStore() -> NoteStore {
        NoteStore(
            storeURL: URL(fileURLWithPath: "/dev/null"),
            storeType: NSInMemoryStoreType
        )
    }

    private func makeEnvelope(
        in store: NoteStore,
        title: String,
        location: MailboxLocation,
        updatedAt: Date
    ) throws -> EnvelopeFixture {
        let preset = try #require(PagePresetCatalog.presets.first)
        let document = store.loadOrCreateDocument(
            named: title,
            pagePreset: preset
        )
        let documentID = try #require(document.id)
        let record = try #require(
            try store.envelopeRecord(documentID: documentID)
        )
        let envelopeID = try #require(record.id)
        record.mailboxLocationRawValue = location.rawValue
        record.deliveryStateRawValue = deliveryState(for: location).rawValue
        record.updatedAt = updatedAt
        try store.viewContext.save()
        return EnvelopeFixture(
            envelopeID: envelopeID,
            documentID: documentID
        )
    }

    private func deliveryState(for location: MailboxLocation) -> DeliveryState {
        switch location {
        case .draft:
            .notSubmitted
        case .outbox:
            .queued
        case .inbox, .sent:
            .unknown
        }
    }
}

private struct EnvelopeFixture {
    let envelopeID: UUID
    let documentID: UUID
}
