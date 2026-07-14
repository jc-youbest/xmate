// PagePresentationStyle
//
// Editor-domain presentation vocabulary. This intentionally does not replace
// the existing Shared.PaginationStyle runtime preference yet.

enum PagePresentationStyle: Hashable {
    case singlePage
    case continuous

    init(_ paginationStyle: PaginationStyle) {
        switch paginationStyle {
        case .singlePage:
            self = .singlePage
        case .continuous:
            self = .continuous
        }
    }

    var debugName: String {
        switch self {
        case .singlePage: return "singlePage"
        case .continuous: return "continuous"
        }
    }
}
