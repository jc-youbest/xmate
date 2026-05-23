// C-002 PencilKitBridge
//
// SwiftUI wrapper around PKCanvasView.
//
// Drawing policy: .pencilOnly — fingers are reserved for navigation (F-001,
// F-051). Two UISwipeGestureRecognizers (up / down, finger-only) are added
// to the canvas so WritingScreen can drive page turns.
//
// Lifecycle with page turning: WritingScreen passes `.id(page.id)` on the
// bridge, so SwiftUI creates a fresh PKCanvasView for each page. Each
// makeUIView loads the page's saved drawing. dismantleUIView flushes any
// pending strokes before the view is torn down, so no strokes are lost on
// a fast page turn.
//
// The canvas is a bounded sheet: scrolling is disabled and the logical page
// maps 1:1 to the view's bounds (F-053 bounded-page model).
//
// The system PKToolPicker covers F-002..F-007.

import SwiftUI
import PencilKit
import UIKit

struct PencilKitBridge: UIViewRepresentable {
    let page: Page
    let store: NoteStore

    /// Called when the user swipes up with a finger — advance to next page.
    var onSwipeUp: (() -> Void)?
    /// Called when the user swipes down with a finger — retreat to previous page.
    var onSwipeDown: (() -> Void)?

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var toolPicker: PKToolPicker?
        weak var canvas: PKCanvasView?
        var page: Page?
        var store: NoteStore?

        var onSwipeUp: (() -> Void)?
        var onSwipeDown: (() -> Void)?

        var saveWorkItem: DispatchWorkItem?
        private var backgroundObserver: NSObjectProtocol?

        override init() {
            super.init()
            // Force-save when the app moves to background so no strokes are
            // lost when the user homes out or the OS suspends the app.
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.saveNow()
            }
        }

        deinit {
            if let obs = backgroundObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        }

        // MARK: PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            scheduleSave()
        }

        // MARK: Gesture targets

        @objc func handleSwipeUp() { onSwipeUp?() }
        @objc func handleSwipeDown() { onSwipeDown?() }

        // MARK: Save helpers

        /// Coalesce rapid stroke changes: debounce saves by 250 ms.
        func scheduleSave() {
            saveWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.saveNow() }
            saveWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
        }

        /// Encode and persist the current canvas drawing to Core Data.
        func saveNow() {
            guard let canvas = canvas,
                  let page = page,
                  let store = store else { return }
            let data = StrokeSerializer.encode(canvas.drawing)
            store.savePageDrawing(data, page: page)
        }
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .white
        canvas.isOpaque = true

        // Keep the canvas in light mode so black ink on white stays legible
        // even when the system or iPad is in dark mode.
        canvas.overrideUserInterfaceStyle = .light

        // Only Apple Pencil draws; finger touches are reserved for navigation.
        canvas.drawingPolicy = .pencilOnly

        // Bounded page: no free panning. The page fills the view exactly.
        canvas.isScrollEnabled = false
        canvas.bounces = false

        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        context.coordinator.page = page
        context.coordinator.store = store

        // Restore saved drawing for this page.
        if let data = page.drawingData, let drawing = StrokeSerializer.decode(data) {
            canvas.drawing = drawing
        }

        // Finger-only swipe recognisers for page turning (F-051).
        // allowedTouchTypes = [.direct] excludes Apple Pencil (UITouch.TouchType.stylus).
        let fingerOnly: [NSNumber] = [NSNumber(value: UITouch.TouchType.direct.rawValue)]

        let swipeUp = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSwipeUp)
        )
        swipeUp.direction = .up
        swipeUp.allowedTouchTypes = fingerOnly
        // cancelsTouchesInView = false so the PKCanvasView still receives
        // the touch for other purposes (e.g. tap-to-focus).
        swipeUp.cancelsTouchesInView = false
        canvas.addGestureRecognizer(swipeUp)

        let swipeDown = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSwipeDown)
        )
        swipeDown.direction = .down
        swipeDown.allowedTouchTypes = fingerOnly
        swipeDown.cancelsTouchesInView = false
        canvas.addGestureRecognizer(swipeDown)

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Re-apply on update — on real devices, drawingPolicy can fail to
        // take effect before the view enters the window hierarchy.
        uiView.drawingPolicy = .pencilOnly
        uiView.isScrollEnabled = false

        // Keep coordinator callbacks current.
        context.coordinator.onSwipeUp = onSwipeUp
        context.coordinator.onSwipeDown = onSwipeDown
        context.coordinator.store = store

        // Attach the system tool picker once the canvas is in a window.
        // Deferred one runloop tick so the hosting view is fully laid out
        // before the picker attaches and the canvas becomes first responder.
        DispatchQueue.main.async {
            guard uiView.window != nil,
                  context.coordinator.toolPicker == nil else { return }
            let picker = PKToolPicker()
            picker.addObserver(uiView)
            picker.setVisible(true, forFirstResponder: uiView)
            uiView.becomeFirstResponder()
            context.coordinator.toolPicker = picker
        }
    }

    /// Called by SwiftUI when the view is removed from the hierarchy — either
    /// on page turn (because WritingScreen uses .id(page.id)) or on app exit.
    /// Flush any pending strokes so a fast page turn never loses drawing work.
    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.saveWorkItem?.cancel()
        coordinator.saveWorkItem = nil
        if let page = coordinator.page, let store = coordinator.store {
            let data = StrokeSerializer.encode(uiView.drawing)
            store.savePageDrawing(data, page: page)
        }
        coordinator.toolPicker = nil
    }
}
