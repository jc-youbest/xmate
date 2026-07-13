// PageFlowAxis
//
// Editor-domain axis vocabulary for future pagination/layout policies.

import CoreGraphics
import SwiftUI

enum PageFlowAxis: Hashable {
    case vertical
    case horizontal

    var debugName: String {
        switch self {
        case .vertical: return "vertical"
        case .horizontal: return "horizontal"
        }
    }

    var swiftUIAxis: Axis {
        switch self {
        case .vertical: return .vertical
        case .horizontal: return .horizontal
        }
    }

    func primaryExtent(of size: CGSize) -> CGFloat {
        switch self {
        case .vertical: return size.height
        case .horizontal: return size.width
        }
    }

    func crossExtent(of size: CGSize) -> CGFloat {
        switch self {
        case .vertical: return size.width
        case .horizontal: return size.height
        }
    }

    func primaryOffset(of point: CGPoint) -> CGFloat {
        switch self {
        case .vertical: return point.y
        case .horizontal: return point.x
        }
    }

    func primaryContentSize(of size: CGSize) -> CGFloat {
        switch self {
        case .vertical: return size.height
        case .horizontal: return size.width
        }
    }

    func contentOffset(primary: CGFloat, cross: CGFloat = 0) -> CGPoint {
        switch self {
        case .vertical:
            return CGPoint(x: cross, y: primary)
        case .horizontal:
            return CGPoint(x: primary, y: cross)
        }
    }

    func pageOffset(delta: CGFloat, stride: CGFloat) -> CGSize {
        switch self {
        case .vertical:
            return CGSize(width: 0, height: delta * stride)
        case .horizontal:
            return CGSize(width: delta * stride, height: 0)
        }
    }
}
