import Foundation

/// Stable value returned when an envelope has been joined with the state of
/// its independent local Document cache entry.
struct MailboxEnvelopeDocumentResolution: Hashable, Sendable {
    let envelope: LetterEnvelope
    let documentCache: MailboxDocumentCacheResolution
}

enum LocalMailboxRepositoryError: Error, Hashable, Sendable {
    case invalidEnvelopeRecord(id: UUID?)
    case invalidCachedDocument(expectedDocumentID: UUID)
}

/// Local-only Mailbox facade over Storage. Managed objects are decoded and
/// discarded at this boundary; callers receive immutable domain values.
@MainActor
final class LocalMailboxRepository {
    private let store: NoteStore

    init(store: NoteStore = .shared) {
        self.store = store
    }

    func envelopes(in location: MailboxLocation) throws -> [LetterEnvelope] {
        try store
            .envelopeRecords(mailboxLocationRawValue: location.rawValue)
            .map(Self.decodeEnvelope)
    }

    func envelope(id: UUID) throws -> LetterEnvelope? {
        guard let record = try store.envelopeRecord(id: id) else {
            return nil
        }
        return try Self.decodeEnvelope(record)
    }

    /// Resolves only local availability and revision validity. A missing or
    /// stale payload remains a typed result; this repository never fabricates
    /// a Document or starts remote work.
    func resolveEnvelope(
        id: UUID
    ) throws -> MailboxEnvelopeDocumentResolution? {
        guard let envelope = try envelope(id: id) else {
            return nil
        }

        let cachedDocument: CachedDocumentDescriptor?
        if let document = try store.document(id: envelope.documentID) {
            guard document.id == envelope.documentID,
                  document.contentRevision >= 0 else {
                throw LocalMailboxRepositoryError.invalidCachedDocument(
                    expectedDocumentID: envelope.documentID
                )
            }
            cachedDocument = CachedDocumentDescriptor(
                documentID: envelope.documentID,
                revision: DocumentRevision(
                    rawValue: document.contentRevision
                )
            )
        } else {
            cachedDocument = nil
        }

        return MailboxEnvelopeDocumentResolution(
            envelope: envelope,
            documentCache: MailboxDocumentCacheResolver.resolve(
                envelope: envelope,
                cachedDocument: cachedDocument
            )
        )
    }

    private static func decodeEnvelope(
        _ record: LetterEnvelopeRecord
    ) throws -> LetterEnvelope {
        guard let id = record.id,
              let documentID = record.documentID,
              let title = record.title,
              let mailboxLocationRawValue = record.mailboxLocationRawValue,
              let mailboxLocation = MailboxLocation(
                rawValue: mailboxLocationRawValue
              ),
              let deliveryStateRawValue = record.deliveryStateRawValue,
              let deliveryState = DeliveryState(
                rawValue: deliveryStateRawValue
              ),
              record.documentRevision >= 0,
              let createdAt = record.createdAt,
              let updatedAt = record.updatedAt else {
            throw LocalMailboxRepositoryError.invalidEnvelopeRecord(
                id: record.id
            )
        }

        return LetterEnvelope(
            id: id,
            documentID: documentID,
            title: title,
            senderID: record.senderID,
            recipientID: record.recipientID,
            mailboxLocation: mailboxLocation,
            deliveryState: deliveryState,
            documentRevision: DocumentRevision(
                rawValue: record.documentRevision
            ),
            createdAt: createdAt,
            updatedAt: updatedAt,
            sentAt: record.sentAt,
            receivedAt: record.receivedAt
        )
    }
}
