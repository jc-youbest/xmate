import Foundation

/// The four fixed system mailbox locations. These values form queries over one
/// envelope store; they are not Folder entities or separate physical caches.
enum MailboxLocation: String, CaseIterable, Codable, Hashable, Sendable {
    case inbox
    case draft
    case outbox
    case sent
}
