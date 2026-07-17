import Foundation

/// Minimal local delivery vocabulary for F-062.
///
/// Remote sending, retry, delivery, and failure states are intentionally not
/// modeled. `.unknown` supports restored or deterministic history without
/// pretending the local build observed a transport outcome.
enum DeliveryState: String, Codable, Hashable, Sendable {
    case notSubmitted
    case queued
    case unknown
}
