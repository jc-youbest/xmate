// Core Data entity: Document — a multi-page letter.
// Lifecycle and storage are managed by NoteStore.

import Foundation
import CoreData

@objc(Document)
public class Document: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Document> {
        NSFetchRequest<Document>(entityName: "Document")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pages: NSOrderedSet
}
