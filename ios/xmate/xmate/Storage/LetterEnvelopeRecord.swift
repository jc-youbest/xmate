// Core Data record for cached LetterEnvelope metadata. Mailbox owns the domain
// semantics; Storage owns this raw persistence representation.

import Foundation
import CoreData

@objc(LetterEnvelopeRecord)
public class LetterEnvelopeRecord: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LetterEnvelopeRecord> {
        NSFetchRequest<LetterEnvelopeRecord>(entityName: "LetterEnvelopeRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var documentID: UUID?
    @NSManaged public var title: String?
    @NSManaged public var senderID: UUID?
    @NSManaged public var recipientID: UUID?
    @NSManaged public var mailboxLocationRawValue: String?
    @NSManaged public var deliveryStateRawValue: String?
    @NSManaged public var documentRevision: Int64
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var sentAt: Date?
    @NSManaged public var receivedAt: Date?
}
