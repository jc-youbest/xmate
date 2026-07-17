import Foundation

/// Metadata for a locally cached Document payload. Mailbox resolves this value;
/// App receives the actual managed Document only after the persistence adapter
/// has produced a cache hit.
struct CachedDocumentDescriptor: Hashable, Sendable {
    let documentID: UUID
    let revision: DocumentRevision
}

struct DocumentCacheRequirement: Hashable, Sendable {
    let documentID: UUID
    let revision: DocumentRevision
}

enum MailboxDocumentCacheResolution: Hashable, Sendable {
    case hit(CachedDocumentDescriptor)
    case missing(DocumentCacheRequirement)
    /// Any revision inequality is stale for injection. The envelope manifest
    /// is authoritative; the caller must not guess which side should win.
    case stale(
        cached: CachedDocumentDescriptor,
        required: DocumentCacheRequirement
    )
    case invalidAssociation(expectedDocumentID: UUID, cachedDocumentID: UUID)
}

enum MailboxDocumentCacheResolver {
    static func resolve(
        envelope: LetterEnvelope,
        cachedDocument: CachedDocumentDescriptor?
    ) -> MailboxDocumentCacheResolution {
        let requirement = DocumentCacheRequirement(
            documentID: envelope.documentID,
            revision: envelope.documentRevision
        )

        guard let cachedDocument else {
            return .missing(requirement)
        }
        guard cachedDocument.documentID == envelope.documentID else {
            return .invalidAssociation(
                expectedDocumentID: envelope.documentID,
                cachedDocumentID: cachedDocument.documentID
            )
        }
        guard cachedDocument.revision == envelope.documentRevision else {
            return .stale(cached: cachedDocument, required: requirement)
        }
        return .hit(cachedDocument)
    }
}
