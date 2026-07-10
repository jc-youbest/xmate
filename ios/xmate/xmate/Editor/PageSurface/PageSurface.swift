// PageSurface
//
// Layer-ready rendering container for one fixed logical page.
//
// Current stage: preserves the existing plain white page plus PencilKit drawing
// layer. Future stationery/backgrounds, content objects, and overlays get their
// own layers here instead of being folded into PencilKit.

import SwiftUI

struct PageSurface<DrawingLayer: View>: View {
    private let backgroundColor: Color
    private let drawingLayer: DrawingLayer

    init(
        backgroundColor: Color = .white,
        @ViewBuilder drawingLayer: () -> DrawingLayer
    ) {
        self.backgroundColor = backgroundColor
        self.drawingLayer = drawingLayer()
    }

    var body: some View {
        ZStack {
            // 1. Background layer: today's plain paper fill.
            backgroundColor

            // 2. Future content object layer placeholder.
            EmptyView()

            // 3. PencilKit drawing layer.
            drawingLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 4. Future overlay/selection layer placeholder.
            EmptyView()
        }
    }
}

