import Foundation
import Testing
@testable import xmate

struct MailboxTransitionPolicyTests {
    @Test func queueMovesTheSameDraftEnvelopeToOutbox() {
        let envelope = makeEnvelope()
        let transitionDate = Date(timeIntervalSince1970: 100)

        let outcome = MailboxTransitionPolicy.queueDraft(
            envelope,
            at: transitionDate
        )

        guard case .applied(let queued) = outcome else {
            Issue.record("Expected the draft to be queued")
            return
        }
        #expect(queued.id == envelope.id)
        #expect(queued.documentID == envelope.documentID)
        #expect(queued.documentRevision == envelope.documentRevision)
        #expect(queued.mailboxLocation == .outbox)
        #expect(queued.deliveryState == .queued)
        #expect(queued.updatedAt == transitionDate)
        #expect(queued.createdAt == envelope.createdAt)
        #expect(queued.sentAt == nil)
    }

    @Test func queueDoesNotClaimRemoteSendSuccess() {
        let outcome = MailboxTransitionPolicy.queueDraft(
            makeEnvelope(),
            at: Date(timeIntervalSince1970: 100)
        )

        guard case .applied(let queued) = outcome else {
            Issue.record("Expected the draft to be queued")
            return
        }
        #expect(queued.mailboxLocation != .sent)
        #expect(queued.sentAt == nil)
    }

    @Test func queueRejectsAnEnvelopeOutsideDrafts() {
        let envelope = makeEnvelope(
            mailboxLocation: .outbox,
            deliveryState: .queued
        )

        let outcome = MailboxTransitionPolicy.queueDraft(
            envelope,
            at: Date(timeIntervalSince1970: 100)
        )

        #expect(outcome == .rejected(.queueRequiresDraft))
    }

    @Test func queueRejectsADraftThatIsNotUnsubmitted() {
        let envelope = makeEnvelope(
            mailboxLocation: .draft,
            deliveryState: .unknown
        )

        let outcome = MailboxTransitionPolicy.queueDraft(
            envelope,
            at: Date(timeIntervalSince1970: 100)
        )

        #expect(outcome == .rejected(.queueRequiresNotSubmitted))
    }

    private func makeEnvelope(
        mailboxLocation: MailboxLocation = .draft,
        deliveryState: DeliveryState = .notSubmitted
    ) -> LetterEnvelope {
        LetterEnvelope(
            id: UUID(),
            documentID: UUID(),
            title: "Draft",
            senderID: UUID(),
            recipientID: UUID(),
            mailboxLocation: mailboxLocation,
            deliveryState: deliveryState,
            documentRevision: DocumentRevision(rawValue: 3),
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            sentAt: nil,
            receivedAt: nil
        )
    }
}
