// Core Data entity: Document — a multi-page letter.
// Lifecycle and storage are managed by NoteStore.

import Foundation
import CoreData
import CoreGraphics

@objc(Document)
public class Document: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Document> {
        NSFetchRequest<Document>(entityName: "Document")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pagePresetID: String?
    @NSManaged public var logicalPageWidth: Double
    @NSManaged public var logicalPageHeight: Double
    /// Monotonic version of the complete cached Document payload. This is
    /// separate from each Page's drawing-write version.
    @NSManaged public var contentRevision: Int64
    @NSManaged public var pages: NSOrderedSet
}

enum DocumentPageSpecSource: String {
    case persisted
    case dimensions
    case fallback
}

struct DocumentPageSpecResolution: Equatable {
    let pageSpec: PageSpec
    let presetID: String?
    let source: DocumentPageSpecSource
}

extension Document {
    var pageSpecResolution: DocumentPageSpecResolution {
        DocumentPageSpecResolver.resolve(
            presetID: pagePresetID,
            logicalPageWidth: logicalPageWidth,
            logicalPageHeight: logicalPageHeight
        )
    }

    var resolvedPageSpec: PageSpec {
        pageSpecResolution.pageSpec
    }

    func applyPageSpec(_ pageSpec: PageSpec, presetID: String?) {
        pagePresetID = presetID
        logicalPageWidth = Double(pageSpec.size.width)
        logicalPageHeight = Double(pageSpec.size.height)
    }
}

private enum DocumentPageSpecResolver {
    static func resolve(
        presetID: String?,
        logicalPageWidth: Double,
        logicalPageHeight: Double
    ) -> DocumentPageSpecResolution {
        let dimensions = validDimensions(
            width: logicalPageWidth,
            height: logicalPageHeight
        )

        if let preset = PagePresetCatalog.preset(forID: presetID),
           let dimensions,
           matches(dimensions, preset.spec.size) {
            return DocumentPageSpecResolution(
                pageSpec: preset.spec,
                presetID: preset.id,
                source: .persisted
            )
        }

        if let dimensions {
            return DocumentPageSpecResolution(
                pageSpec: PageSpec(
                    size: dimensions.size,
                    flowAxis: dimensions.flowAxis
                ),
                presetID: presetID,
                source: .dimensions
            )
        }

        return DocumentPageSpecResolution(
            pageSpec: PagePresetCatalog.currentDocumentPageSpec,
            presetID: PagePresetCatalog.currentDocumentPagePresetID,
            source: .fallback
        )
    }

    private struct ValidDimensions {
        let size: PageSize
        let flowAxis: PageFlowAxis
    }

    private static func validDimensions(
        width: Double,
        height: Double
    ) -> ValidDimensions? {
        guard width.isFinite,
              height.isFinite,
              width > 0,
              height > 0 else {
            return nil
        }

        let size = PageSize(
            width: CGFloat(width),
            height: CGFloat(height)
        )
        return ValidDimensions(
            size: size,
            flowAxis: width > height ? .horizontal : .vertical
        )
    }

    private static func matches(
        _ dimensions: ValidDimensions,
        _ pageSize: PageSize
    ) -> Bool {
        dimensions.size.width == pageSize.width
            && dimensions.size.height == pageSize.height
    }
}
