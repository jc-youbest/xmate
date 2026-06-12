// C-002 PencilKitBridge
//
// SwiftUI wrapper around XmateCanvasView (a PKCanvasView subclass).
//
// Drawing policy: .pencilOnly — fingers are reserved for navigation (F-001,
// F-051). In Single Page mode two UISwipeGestureRecognizers (finger-only) are
// added to the canvas so SinglePagesView can drive page turns. Their
// directions derive from swipeAxis (paper.paginationAxis): vertical paper →
// up/down, horizontal (landscape) paper → left/right. Forward = next page
// (swipe up / swipe left); backward = previous page (swipe down / right).
// In Continuous mode enableSwipeNavigation is false and no swipe recognisers
// are added — they would fight the enclosing ScrollView's pan gesture.
//
// The recognisers are attached whenever enableSwipeNavigation is true, even
// if the callbacks are momentarily nil (e.g. created while zoomed): dispatch
// goes through the Coordinator, whose callbacks updateUIView keeps current,
// so nil callbacks are a no-op rather than a missing recogniser.
//
// A finger-only double-tap recogniser is always attached (both roles). It
// forwards to onFingerDoubleTap — used by F-053 to reset zoom to 100%.
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
// Editing identity & saving: owned by C-030 DrawingSessionManager. This bridge
// no longer saves directly, never decides first responder for itself, and never
// touches the ToolPicker. In makeUIView it stamps the canvas with its pageID /
// role; in updateUIView (deferred, once the canvas has a window) it REGISTERS
// with the session manager; the session manager decides if/when this canvas
// becomes the active editor (see DrawingSessionManager.makeActive /
// setDesiredActive). Drawing changes are forwarded to the session manager,
// which gates saving so only the active canvas writes.
//
// Lifecycle with page turning / recycling:
//   makeUIView      — creates canvas, stamps pageID/role, loads saved drawing.
//   updateUIView    — deferred once: register with DrawingSessionManager.
//   dismantleUIView — DrawingSessionManager.unregister flushes (if active) and
//                     deregisters from the ToolPicker. iOS has already resigned
//                     first responder on the canvas before SwiftUI fires
//                     dismantleUIView (window-detach order).
//
// The canvas is a bounded sheet: scrolling is disabled and the logical page
// maps 1:1 to the view's bounds (F-053 bounded-page model).

import SwiftUI
import PencilKit
import UIKit

struct PencilKitBridge: UIViewRepresentable {
    let page: Page
    let store: NoteStore

    /// Which structural slot this canvas occupies (Single vs Continuous).
    /// Forwarded to the canvas + DrawingSessionManager so the active-canvas
    /// policy can reason about it. Defaults to .single.
    var role: CanvasRole = .single

    /// Attach finger-swipe recognisers for Single Page navigation (F-051).
    /// False in Continuous mode — recognisers would interfere with the
    /// enclosing ScrollView's pan gesture.
    var enableSwipeNavigation: Bool = false

    /// Axis the swipe navigation runs along — paper.paginationAxis.
    /// .vertical → up/down swipes; .horizontal → left/right swipes.
    var swipeAxis: Axis = .vertical

    /// Swipe callbacks (F-051). Forward = next page (swipe up on portrait
    /// paper, swipe left on landscape paper); backward = previous page.
    /// Pass nil while zoomed (F-053) — pagination is suspended; the
    /// recognisers stay attached but dispatch becomes a no-op.
    var onSwipeForward: (() -> Void)?
    var onSwipeBackward: (() -> Void)?

    /// Finger double-tap callback (F-053). Used to reset zoom to 100%.
    var onFingerDoubleTap: (() -> Void)?

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

        var onSwipeForward: (() -> Void)?
        var onSwipeBackward: (() -> Void)?
        var onFingerDoubleTap: (() -> Void)?

        var fingerPanChanged: ((CGSize) -> Void)?
        var fingerPanEnded: (() -> Void)?
        /// Weak ref so we can enable/disable the recogniser in updateUIView.
        weak var fingerPanRecognizer: UIPanGestureRecognizer?

        /// True once the canvas has been registered with DrawingSessionManager.
        /// Prevents duplicate registration on subsequent updateUIView calls.
        var isRegistered: Bool = false

        // MARK: PKCanvasViewDelegate

        /// Forward to the session manager, which gates saving so only the
        /// active canvas for this page actually writes to Core Data.
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let canvas = canvasView as? XmateCanvasView else { return }
            DrawingSessionManager.shared.canvasDrawingChanged(canvas)
        }

        // MARK: Gesture targets

        @objc func handleSwipeForward()  { onSwipeForward?()  }
        @objc func handleSwipeBackward() { onSwipeBackward?() }
        @objc func handleDoubleTap()     { onFingerDoubleTap?() }

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

        // Stamp the canvas with its editing identity so DrawingSessionManager
        // and ToolPickerHost can reason about it without a side table.
        canvas.pageID = page.id
        canvas.role   = role

        // Restore saved drawing for this page (fast first paint). The session
        // manager may reload from the canonical store when it makes this canvas
        // active, which supersedes this snapshot if a newer one exists.
        if let data = page.drawingData, let drawing = StrokeSerializer.decode(data) {
            canvas.drawing = drawing
        }

        // allowedTouchTypes = [.direct] excludes Apple Pencil.
        let fingerOnly: [NSNumber] = [NSNumber(value: UITouch.TouchType.direct.rawValue)]

        // Finger-only swipe recognisers for page turning in Single Page mode.
        // Attached whenever swipe navigation is enabled — even if callbacks
        // are momentarily nil — so a canvas created while zoomed still turns
        // pages once the zoom resets (Coordinator dispatch no-ops on nil).
        // Skipped in Continuous mode (enableSwipeNavigation == false): they
        // would interfere with the enclosing ScrollView's pan gesture.
        if enableSwipeNavigation {
            // Forward = next page: swipe up (vertical) / swipe left (horizontal).
            let forward = UISwipeGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleSwipeForward)
            )
            forward.direction = (swipeAxis == .vertical) ? .up : .left
            forward.allowedTouchTypes = fingerOnly
            // cancelsTouchesInView = false so the PKCanvasView still receives
            // the touch for other purposes (e.g. tap-to-focus).
            forward.cancelsTouchesInView = false
            canvas.addGestureRecognizer(forward)

            // Backward = previous page: swipe down (vertical) / right (horizontal).
            let backward = UISwipeGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleSwipeBackward)
            )
            backward.direction = (swipeAxis == .vertical) ? .down : .right
            backward.allowedTouchTypes = fingerOnly
            backward.cancelsTouchesInView = false
            canvas.addGestureRecognizer(backward)
        }

        // Finger-only double-tap recogniser (F-053 zoom reset). Always
        // attached, both roles; dispatch no-ops when the callback is nil.
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap)
        )
        doubleTap.numberOfTapsRequired = 2
        doubleTap.allowedTouchTypes = fingerOnly
        doubleTap.cancelsTouchesInView = false
        canvas.addGestureRecognizer(doubleTap)

        // Finger-only pan recogniser for zoom panning (F-053).
        // Always attached so it can be toggled without makeUIView re-running.
        // Starts disabled; updateUIView enables it when fingerPanChanged is set.
        // maximumNumberOfTouches = 1 ensures it doesn't fire during a two-finger
        // pinch (MagnificationGesture in WritingScreen).
        // cancelsTouchesInView = false keeps touch delivery to PencilKit intact.
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
        context.coordinator.onSwipeForward    = onSwipeForward
        context.coordinator.onSwipeBackward   = onSwipeBackward
        context.coordinator.onFingerDoubleTap = onFingerDoubleTap
        context.coordinator.fingerPanChanged  = fingerPanChanged
        context.coordinator.fingerPanEnded    = fingerPanEnded

        // Keep identity current in case the same canvas is reused for a
        // different page (defensive — Single uses .id(page.id) so this is
        // normally a fresh canvas, but Continuous reuse must stay correct).
        uiView.pageID = page.id
        uiView.role   = role

        // Enable the finger pan recogniser only when pan callbacks are provided
        // (i.e. when userZoom > 1.0). Disabling it at fit ensures it cannot
        // compete with the swipe recognisers for page-navigation gestures.
        context.coordinator.fingerPanRecognizer?.isEnabled = (fingerPanChanged != nil)

        // Register with DrawingSessionManager once, deferred one runloop tick so
        // the hosting view is fully laid out and the canvas has a window.
        //
        // We never call becomeFirstResponder here. The session manager decides
        // activation: a view declares its intended active page via
        // setDesiredActive, and register() promotes the matching canvas. This
        // removes the old "whoever registers with a nil anchor grabs FR" race.
        DispatchQueue.main.async {
            guard uiView.window != nil,
                  !context.coordinator.isRegistered else { return }
            context.coordinator.isRegistered = true
            DrawingSessionManager.shared.register(uiView, role: role, visible: true)
        }
    }

    /// Called by SwiftUI when the view is removed from the hierarchy — on page
    /// turn (Single Page uses .id(page.id)), on mode switch, or on app exit.
    ///
    /// DrawingSessionManager.unregister synchronously flushes this canvas IF it
    /// is still the active editor of its page (so its strokes are committed
    /// before teardown), then deregisters it from the ToolPicker. An inactive
    /// canvas — e.g. the old single canvas after a mode switch already handed
    /// the page to a continuous canvas — is NOT flushed, so it cannot overwrite
    /// the new active canvas's newer drawing.
    static func dismantleUIView(_ uiView: XmateCanvasView, coordinator: Coordinator) {
        if coordinator.isRegistered {
            DrawingSessionManager.shared.unregister(uiView)
            coordinator.isRegistered = false
        }
    }
}
