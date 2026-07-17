import Foundation

/// A monotonic content version shared by an envelope header and its cached
/// Document descriptor. Persistence adapters must reject negative values.
struct DocumentRevision: Hashable, Comparable, Sendable {
    static let initial = DocumentRevision(rawValue: 0)

    let rawValue: Int64

    init(rawValue: Int64) {
        precondition(rawValue >= 0, "Document revision must not be negative")
        self.rawValue = rawValue
    }

    static func < (lhs: DocumentRevision, rhs: DocumentRevision) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Lightweight mailbox header. The Document payload is stored independently
/// and joined by `documentID`, never by a required object relationship.
struct LetterEnvelope: Hashable, Sendable {
    let id: UUID
    let documentID: UUID
    let title: String
    let senderID: UUID?
    let recipientID: UUID?
    let mailboxLocation: MailboxLocation
    let deliveryState: DeliveryState
    let documentRevision: DocumentRevision
    let createdAt: Date
    let updatedAt: Date
    let sentAt: Date?
    let receivedAt: Date?
}
