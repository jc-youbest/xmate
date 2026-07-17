import Foundation

enum MailboxTransitionRejection: Hashable, Sendable {
    case queueRequiresDraft
    case queueRequiresNotSubmitted
}

enum MailboxTransitionOutcome: Hashable, Sendable {
    case applied(LetterEnvelope)
    case rejected(MailboxTransitionRejection)
}

/// Pure local envelope transition policy. Recipient/send eligibility remains a
/// Social responsibility and is checked before App invokes this operation.
enum MailboxTransitionPolicy {
    static func queueDraft(
        _ envelope: LetterEnvelope,
        at transitionDate: Date
    ) -> MailboxTransitionOutcome {
        guard envelope.mailboxLocation == .draft else {
            return .rejected(.queueRequiresDraft)
        }
        guard envelope.deliveryState == .notSubmitted else {
            return .rejected(.queueRequiresNotSubmitted)
        }

        return .applied(LetterEnvelope(
            id: envelope.id,
            documentID: envelope.documentID,
            title: envelope.title,
            senderID: envelope.senderID,
            recipientID: envelope.recipientID,
            mailboxLocation: .outbox,
            deliveryState: .queued,
            documentRevision: envelope.documentRevision,
            createdAt: envelope.createdAt,
            updatedAt: transitionDate,
            sentAt: envelope.sentAt,
            receivedAt: envelope.receivedAt
        ))
    }
}
