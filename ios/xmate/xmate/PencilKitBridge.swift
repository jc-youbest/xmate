// C-002 PencilKitBridge
//
// SwiftUI wrapper around PKCanvasView.
//
// v0 scope: hosts a single PKCanvasView with a default pen. Strokes are
// not persisted. Finger input is allowed so the iOS simulator can be
// used for testing; this will become user-configurable when F-018
// Settings is implemented.

import SwiftUI
import PencilKit

struct PencilKitBridge: UIViewRepresentable {
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        // Force light appearance so black ink on a white background
        // stays visible even when the system or iPad is in dark mode.
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Re-apply on update. On real devices, drawingPolicy can fail to
        // take effect when it's set before the view enters a window
        // hierarchy; setting it again here ensures it sticks.
        uiView.drawingPolicy = .anyInput
        uiView.tool = PKInkingTool(.pen, color: .black, width: 4)
    }
}
