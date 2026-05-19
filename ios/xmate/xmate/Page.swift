// Core Data entity: Page — one page inside a Document.
// Lifecycle and storage are managed by C-001 NoteStore.

import Foundation
import CoreData

@objc(Page)
public class Page: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Page> {
        NSFetchRequest<Page>(entityName: "Page")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var drawingData: Data?
    @NSManaged public var document: Document?
}
