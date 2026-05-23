// C-002 PencilKitBridge
//
// SwiftUI wrapper around PKCanvasView, with the system PKToolPicker
// attached as a temporary tool UI for roadmap stage v0.
//
// PKToolPicker covers F-002..F-007 in one shot. Stroke persistence
// routes through C-001 NoteStore (Core Data); see F-011's
// Implementation Status — no standalone file.

import SwiftUI
import PencilKit
import UIKit

struct PencilKitBridge: UIViewRepresentable {
    let page: Page
    let store: NoteStore

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var toolPicker: PKToolPicker?
        weak var canvas: PKCanvasView?
        var page: Page?
        var store: NoteStore?

        private var saveWorkItem: DispatchWorkItem?
        private var backgroundObserver: NSObjectProtocol?

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

        /// Encode the current drawing on the main thread (fast — it's
        /// just an in-memory blob), then hand off to NoteStore which
        /// dispatches the disk write to its own background queue.
        private func saveNow() {
            guard let canvas = canvas,
                  let page = page,
                  let store = store else { return }
            let data = StrokeSerializer.encode(canvas.drawing)
            store.savePageDrawing(data, page: page)
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

        // Wire up persistence: hand the canvas + page + store to the
        // coordinator and restore any previously saved drawing.
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        context.coordinator.page = page
        context.coordinator.store = store
        if let savedData = page.drawingData,
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
        context.coordinator.page = page
        context.coordinator.store = store

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
