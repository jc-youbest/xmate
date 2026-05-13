// C-002 PencilKitBridge
//
// SwiftUI wrapper around PKCanvasView. Hosts the canvas, attaches the
// system PKToolPicker as a v0 tool UI, and auto-persists strokes to
// Documents/canvas.drawing using a debounced background-write scheme.
//
// PKToolPicker delivers the v0 versions of F-002..F-007 in one shot.
// When F-011 Note CRUD proper is built, this file's persistence logic
// is replaced by a call into C-001 NoteStore.

import SwiftUI
import PencilKit
import UIKit

struct PencilKitBridge: UIViewRepresentable {
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var toolPicker: PKToolPicker?
        weak var canvas: PKCanvasView?
        private var saveWorkItem: DispatchWorkItem?
        private var backgroundObserver: NSObjectProtocol?

        /// Serial queue for disk writes. Ensures saves don't race each
        /// other; the latest serialized drawing always wins.
        private static let saveQueue = DispatchQueue(
            label: "xmate.canvas.save",
            qos: .utility
        )

        static var canvasFileURL: URL {
            FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("canvas.drawing")
        }

        override init() {
            super.init()
            // Force-save when the app moves to background so we never
            // lose strokes when the user backgrounds or quits.
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.saveNow()
            }
        }

        deinit {
            if let observer = backgroundObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        // PKCanvasViewDelegate
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            scheduleSave()
        }

        /// Coalesce rapid changes: cancel any pending save and schedule
        /// a new one 250 ms ahead. Continued writing keeps postponing;
        /// only after 250 ms of no further change does the save fire.
        private func scheduleSave() {
            saveWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.saveNow()
            }
            saveWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.25,
                execute: workItem
            )
        }

        /// Capture the current drawing on the main thread, then encode
        /// and write on a background serial queue so writing is never
        /// blocked and concurrent saves don't race.
        private func saveNow() {
            guard let canvas = canvas else { return }
            let drawing = canvas.drawing  // PKDrawing is a value type
            let url = Coordinator.canvasFileURL
            Coordinator.saveQueue.async {
                let data = StrokeSerializer.encode(drawing)
                try? data.write(to: url, options: .atomic)
            }
        }
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

        // Wire up persistence: hand the canvas to the coordinator and
        // restore any previously saved drawing.
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        if let savedData = try? Data(contentsOf: Coordinator.canvasFileURL),
           let drawing = StrokeSerializer.decode(savedData) {
            canvas.drawing = drawing
        }

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Re-apply on update. On real devices, drawingPolicy can fail to
        // take effect when it's set before the view enters a window
        // hierarchy; setting it again here ensures it sticks.
        uiView.drawingPolicy = .anyInput

        // Attach the system tool picker once the canvas is in a window.
        // Dispatched to the next runloop tick so SwiftUI's hosting view
        // is fully laid out before the picker tries to attach.
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
