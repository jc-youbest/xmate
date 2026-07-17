import Foundation
import Testing
@testable import xmate

struct MailboxDocumentCacheResolutionTests {
    @Test func matchingDocumentAndRevisionIsACacheHit() {
        let envelope = makeEnvelope(revision: 4)
        let cached = CachedDocumentDescriptor(
            documentID: envelope.documentID,
            revision: DocumentRevision(rawValue: 4)
        )

        let resolution = MailboxDocumentCacheResolver.resolve(
            envelope: envelope,
            cachedDocument: cached
        )

        #expect(resolution == .hit(cached))
    }

    @Test func absentDocumentProducesTypedCacheRequirement() {
        let envelope = makeEnvelope(revision: 7)

        let resolution = MailboxDocumentCacheResolver.resolve(
            envelope: envelope,
            cachedDocument: nil
        )

        #expect(resolution == .missing(DocumentCacheRequirement(
            documentID: envelope.documentID,
            revision: DocumentRevision(rawValue: 7)
        )))
    }

    @Test func revisionMismatchNeverInjectsCachedDocument() {
        let envelope = makeEnvelope(revision: 8)
        let cached = CachedDocumentDescriptor(
            documentID: envelope.documentID,
            revision: DocumentRevision(rawValue: 7)
        )

        let resolution = MailboxDocumentCacheResolver.resolve(
            envelope: envelope,
            cachedDocument: cached
        )

        #expect(resolution == .stale(
            cached: cached,
            required: DocumentCacheRequirement(
                documentID: envelope.documentID,
                revision: DocumentRevision(rawValue: 8)
            )
        ))
    }

    @Test func mismatchedDocumentIDIsAnInvalidAssociation() {
        let envelope = makeEnvelope(revision: 1)
        let unrelatedID = UUID()

        let resolution = MailboxDocumentCacheResolver.resolve(
            envelope: envelope,
            cachedDocument: CachedDocumentDescriptor(
                documentID: unrelatedID,
                revision: envelope.documentRevision
            )
        )

        #expect(resolution == .invalidAssociation(
            expectedDocumentID: envelope.documentID,
            cachedDocumentID: unrelatedID
        ))
    }

    private func makeEnvelope(revision: Int64) -> LetterEnvelope {
        LetterEnvelope(
            id: UUID(),
            documentID: UUID(),
            title: "Draft",
            senderID: nil,
            recipientID: nil,
            mailboxLocation: .draft,
            deliveryState: .notSubmitted,
            documentRevision: DocumentRevision(rawValue: revision),
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            sentAt: nil,
            receivedAt: nil
        )
    }
}
