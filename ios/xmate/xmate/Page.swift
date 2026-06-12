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
    /// Monotonic save counter used as an optimistic-concurrency stamp by
    /// C-001 NoteStore / C-030 DrawingSessionManager. The store only accepts a
    /// write whose incoming version is strictly greater than the stored one,
    /// so a stale (inactive) canvas can never overwrite newer handwriting.
    @NSManaged public var version: Int64
    @NSManaged public var document: Document?
}
