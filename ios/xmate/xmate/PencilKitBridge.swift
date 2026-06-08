// C-002 PencilKitBridge
//
// SwiftUI wrapper around XmateCanvasView (a PKCanvasView subclass).
//
// Drawing policy: .pencilOnly — fingers are reserved for navigation (F-001,
// F-051). In Single Page mode two UISwipeGestureRecognizers (up/down,
// finger-only) are added to the canvas so WritingScreen can drive page turns.
// In Continuous mode onSwipeUp/onSwipeDown are nil and no gesture recognisers
// are added — they would fight the enclosing ScrollView's pan gesture.
//
// Zoom pan (F-053): when fingerPanChanged/fingerPanEnded are provided,
// a UIPanGestureRecognizer restricted to allowedTouchTypes = [.direct]
// (finger only) is permanently attached to the canvas. The recogniser is
// disabled when the callbacks are nil (userZoom == 1.0) and enabled when
// they are set (userZoom > 1.0). Because the recogniser lives on the same
// UIView as PencilKit, there is no view blocking pencil events — PencilKit
// handles .pencil touches internally, the pan handles .direct (finger)
// touches, and they never interfere.
//
// Tool picker: owned by C-029 ToolPickerHost (app-wide singleton). This bridge
// registers its canvas with ToolPickerHost in updateUIView (once the canvas
// has a window) and deregisters in dismantleUIView. The picker therefore stays
// visible across the LazyVStack recycling that Continuous mode performs.
//
// Lifecycle with page turning / recycling:
//   makeUIView      — creates canvas, loads saved drawing.
//   updateUIView    — deferred once: register with ToolPickerHost + becomeFirstResponder.
//   dismantleUIView — flush pending strokes; unregister from ToolPickerHost.
//                     iOS has already resigned first responder on the canvas
//                     before SwiftUI fires dismantleUIView (window-detach order).
//
// The canvas is a bounded sheet: scrolling is disabled and the logical page
// maps 1:1 to the view's bounds (F-053 bounded-page model).

import SwiftUI
import PencilKit
import UIKit

struct PencilKitBridge: UIViewRepresentable {
    let page: Page
    let store: NoteStore

    /// Finger-swipe callbacks for Single Page navigation (F-051).
    /// Pass nil in Continuous mode — no gesture recognisers are added,
    /// which prevents interference with the enclosing ScrollView.
    var onSwipeUp: (() -> Void)?
    var onSwipeDown: (() -> Void)?

    /// Zoom-pan callbacks (F-053). When non-nil, a finger-only
    /// UIPanGestureRecognizer is enabled on the canvas.
    ///   onChanged — called with the total translation (in window / screen
    ///               coordinates) since the gesture began.
    ///   onEnded   — called once on gesture end/cancel.
    /// Pass nil when userZoom == 1.0 to keep the recogniser disabled so it
    /// cannot compete with the swipe recognisers for page navigation.
    var fingerPanChanged: ((CGSize) -> Void)?
    var fingerPanEnded: (() -> Void)?

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        weak var canvas: XmateCanvasView?
        var page: Page?
        var store: NoteStore?

        var onSwipeUp: (() -> Void)?
        var onSwipeDown: (() -> Void)?

        var fingerPanChanged: ((CGSize) -> Void)?
        var fingerPanEnded: (() -> Void)?
        /// Weak ref so we can enable/disable the recogniser in updateUIView.
        weak var fingerPanRecognizer: UIPanGestureRecognizer?

        var saveWorkItem: DispatchWorkItem?
        private var backgroundObserver: NSObjectProtocol?

        /// True once the canvas has been registered with ToolPickerHost.
        /// Prevents duplicate registration on subsequent updateUIView calls.
        var isRegistered: Bool = false

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

        @objc func handleSwipeUp()   { onSwipeUp?()   }
        @objc func handleSwipeDown() { onSwipeDown?() }

        @objc func handleFingerPan(_ r: UIPanGestureRecognizer) {
            // translation(in: nil) returns window coordinates, which equal
            // SwiftUI layout coordinates for a portrait-locked app.
            let t = r.translation(in: nil)
            switch r.state {
            case .changed:
                fingerPanChanged?(CGSize(width: t.x, height: t.y))
            case .ended, .cancelled, .failed:
                fingerPanEnded?()
            default:
                break
            }
        }

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
                  let page   = page,
                  let store  = store else { return }
            let data = StrokeSerializer.encode(canvas.drawing)
            store.savePageDrawing(data, page: page)
        }
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> XmateCanvasView {
        let canvas = XmateCanvasView()
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
        context.coordinator.page   = page
        context.coordinator.store  = store

        // Restore saved drawing for this page.
        if let data = page.drawingData, let drawing = StrokeSerializer.decode(data) {
            canvas.drawing = drawing
        }

        // Finger-only swipe recognisers for page turning in Single Page mode.
        // Skipped entirely when callbacks are nil (Continuous mode) — adding
        // them would interfere with the enclosing ScrollView's pan gesture.
        if onSwipeUp != nil || onSwipeDown != nil {
            // allowedTouchTypes = [.direct] excludes Apple Pencil.
            let fingerOnly: [NSNumber] = [NSNumber(value: UITouch.TouchType.direct.rawValue)]

            if onSwipeUp != nil {
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
            }

            if onSwipeDown != nil {
                let swipeDown = UISwipeGestureRecognizer(
                    target: context.coordinator,
                    action: #selector(Coordinator.handleSwipeDown)
                )
                swipeDown.direction = .down
                swipeDown.allowedTouchTypes = fingerOnly
                swipeDown.cancelsTouchesInView = false
                canvas.addGestureRecognizer(swipeDown)
            }
        }

        // Finger-only pan recogniser for zoom panning (F-053).
        // Always attached so it can be toggled without makeUIView re-running.
        // Starts disabled; updateUIView enables it when fingerPanChanged is set.
        // maximumNumberOfTouches = 1 ensures it doesn't fire during a two-finger
        // pinch (MagnificationGesture in WritingScreen).
        // cancelsTouchesInView = false keeps touch delivery to PencilKit intact.
        let fingerOnly: [NSNumber] = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleFingerPan(_:))
        )
        pan.allowedTouchTypes = fingerOnly
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.isEnabled = false
        canvas.addGestureRecognizer(pan)
        context.coordinator.fingerPanRecognizer = pan

        return canvas
    }

    func updateUIView(_ uiView: XmateCanvasView, context: Context) {
        // Re-apply on update — on real devices, drawingPolicy can fail to
        // take effect before the view enters the window hierarchy.
        uiView.drawingPolicy = .pencilOnly
        uiView.isScrollEnabled = false

        // Keep coordinator callbacks current.
        context.coordinator.onSwipeUp        = onSwipeUp
        context.coordinator.onSwipeDown      = onSwipeDown
        context.coordinator.fingerPanChanged = fingerPanChanged
        context.coordinator.fingerPanEnded   = fingerPanEnded
        context.coordinator.store            = store

        // Enable the finger pan recogniser only when pan callbacks are provided
        // (i.e. when userZoom > 1.0). Disabling it at fit ensures it cannot
        // compete with the swipe recognisers for page-navigation gestures.
        context.coordinator.fingerPanRecognizer?.isEnabled = (fingerPanChanged != nil)

        // Register with ToolPickerHost once, deferred one runloop tick so
        // the hosting view is fully laid out and the canvas has a window.
        //
        // becomeFirstResponder is called only when the host has no current
        // anchor (needsFirstResponder == true). This prevents each newly-
        // entering LazyVStack canvas from stealing FR away from the canvas
        // the user is actively writing on. In Single Page mode the old
        // canvas is always dismantled before the new one registers, so
        // anchor is nil and the new canvas becomes FR correctly. In
        // Continuous mode a canvas that enters view without an anchor
        // (e.g. app launch, style switch) becomes FR; all later ones rely
        // on PKCanvasView's own becomeFirstResponder-on-Pencil-touch to
        // update the anchor when the user taps a different page.
        DispatchQueue.main.async {
            guard uiView.window != nil,
                  !context.coordinator.isRegistered else { return }
            context.coordinator.isRegistered = true
            ToolPickerHost.shared.register(uiView)
            if ToolPickerHost.shared.needsFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }

    /// Called by SwiftUI when the view is removed from the hierarchy — on page
    /// turn (Single Page uses .id(page.id)), on LazyVStack recycling (Continuous
    /// mode), or on app exit.
    ///
    /// iOS first-responder / dismantleUIView ordering: iOS resigns first
    /// responder on the canvas when it detaches from the window, BEFORE SwiftUI
    /// calls dismantleUIView. XmateCanvasView.resignFirstResponder already
    /// notified ToolPickerHost and scheduled a re-anchor. Here we only flush
    /// strokes and remove the canvas from the host registry.
    static func dismantleUIView(_ uiView: XmateCanvasView, coordinator: Coordinator) {
        coordinator.saveWorkItem?.cancel()
        coordinator.saveWorkItem = nil
        if let page = coordinator.page, let store = coordinator.store {
            let data = StrokeSerializer.encode(uiView.drawing)
            store.savePageDrawing(data, page: page)
        }
        if coordinator.isRegistered {
            ToolPickerHost.shared.unregister(uiView)
            coordinator.isRegistered = false
        }
    }
}
