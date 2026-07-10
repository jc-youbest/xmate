// PageFlowAxis
//
// Editor-domain axis vocabulary for future pagination/layout policies.

enum PageFlowAxis: Hashable {
    case vertical
    case horizontal

    var debugName: String {
        switch self {
        case .vertical: return "vertical"
        case .horizontal: return "horizontal"
        }
    }
}
