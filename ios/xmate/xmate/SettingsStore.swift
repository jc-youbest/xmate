// C-028 SettingsStore
//
// Global app preferences persisted via UserDefaults (F-056).
//
// Usage: inject as .environmentObject(SettingsStore.shared) at the scene
// root (xmateApp), then read/write via @EnvironmentObject var settings: SettingsStore.

import Foundation

// MARK: - PaginationStyle

/// The two Pagination Styles available on the Content Screen (F-056).
/// Stored as a raw String in UserDefaults so future values round-trip safely.
enum PaginationStyle: String {
    /// One full page fills the screen at a time; finger swipe flips between
    /// pages. Direction derived from paper.paginationAxis. Default.
    case singlePage = "singlePage"
    /// Pages stack and scroll continuously along paper.paginationAxis.
    /// Truly free scroll — no snap, no auto-alignment.
    case continuous = "continuous"
}

// MARK: - SettingsStore

/// C-028 SettingsStore — global app preferences persisted via UserDefaults.
///
/// All preferences are global (not per-document). The preference is
/// applied immediately: switching Pagination Style re-renders the current
/// Content Screen in the new style without losing the current page.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private static let paginationStyleKey = "xmate.paginationStyle"

    /// The active Pagination Style. Writing persists to UserDefaults immediately.
    @Published var paginationStyle: PaginationStyle {
        didSet {
            UserDefaults.standard.set(paginationStyle.rawValue,
                                      forKey: Self.paginationStyleKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.paginationStyleKey) ?? ""
        paginationStyle = PaginationStyle(rawValue: raw) ?? .singlePage
    }
}
