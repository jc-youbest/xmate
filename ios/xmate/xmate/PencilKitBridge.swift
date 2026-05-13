// C-002 PencilKitBridge
//
// SwiftUI wrapper around PKCanvasView, plus the system PKToolPicker as
// a temporary v0 tool UI.
//
// PKToolPicker delivers pen / pencil / marker / highlighter selection
// (F-002), color picking (F-003), stroke thickness (F-004), eraser
// (F-005), lasso (F-006), and undo / redo (F-007) — all from Apple's
// built-in palette. When the custom U-015 PenToolbar and its children
// are built per F-002..F-007, this PKToolPicker stand-in goes away.
//
// Strokes are still not persisted; closing the app discards them.
// Persistence comes with F-011 Note CRUD.

import SwiftUI
import PencilKit

struct PencilKitBridge: UIViewRepresentable {
    final class Coordinator {
        var toolPicker: PKToolPicker?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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

        // Attach the system tool picker once the canvas is in a window.
        // Dispatched to the next runloop tick because, on real devices,
        // updateUIView may run before SwiftUI's hosting layout has
        // actually placed the view live on screen — and PKToolPicker
        // only attaches if its first-responder canvas is fully laid out
        // in a key window.
        DispatchQueue.main.async {
            guard uiView.window != nil,
                  context.coordinator.toolPicker == nil else {
                return
            }
            let picker = PKToolPicker()
            picker.addObserver(uiView)
            picker.setVisible(true, forFirstResponder: uiView)
            uiView.becomeFirstResponder()
            context.coordinator.toolPicker = picker
        }
    }
}
