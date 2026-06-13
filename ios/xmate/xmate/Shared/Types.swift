// Shared module — truly cross-module small types only.
// Before adding here, prove at least two modules need the symbol.

import Foundation

// MARK: - PaginationStyle

/// The two Pagination Styles available on the Content Screen (F-056).
/// Persisted by SettingsStore (App); consumed by WritingScreen routing (Editor).
/// Stored as a raw String in UserDefaults so future values round-trip safely.
enum PaginationStyle: String {
    /// One full page fills the screen at a time; finger swipe flips between
    /// pages. Direction derived from paper.paginationAxis. Default.
    case singlePage = "singlePage"
    /// Pages stack and scroll continuously along paper.paginationAxis.
    /// Truly free scroll — no snap, no auto-alignment.
    case continuous = "continuous"
}

// MARK: - Comparable clamped helper

extension Comparable {
    /// Returns the value clamped to the closed range [lo, hi].
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
