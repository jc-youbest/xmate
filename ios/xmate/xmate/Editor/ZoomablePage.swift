// ZoomablePage — UIScrollView-backed zoomable page (Single Page pilot, F-059)
//
// WHY A UISCROLLVIEW. The hand-rolled momentum (a SwiftUI `.spring` on a
// @Published panOffset) could not be interrupted by a new gesture mid-flight:
// the spring and the pan recogniser were two uncoordinated writers of the same
// value, so a new pan during deceleration corrupted the animation
// ("Invalid sample …") and froze. UIScrollView owns zoomScale + contentOffset
// and coordinates its own pan/pinch recognisers with its deceleration, so a new
// touch seamlessly takes over a decelerating pan — exactly how Continuous paging
// (a native ScrollView) already behaves.
//
// This hosts ONE page's XmateCanvasView as the scroll view's zoomable content:
//   • Pencil draws on the canvas (drawingPolicy .pencilOnly).
//   • One finger pans — but only once zoomed in (scrolling is disabled at fit so
//     a one-finger drag falls through to the page-turn swipe).
//   • Two fingers pinch-zoom (fit … fit×3), with native inertia + rubber-band.
//   • Double-tap (finger) resets to fit.
//
// Pilot scope: it owns all zoom interaction itself; PageZoomModel is NOT used
// here. Top-bar percentage / HUD / reset-button wiring for Single is deferred
// until the architecture is validated on device.

import SwiftUI
import PencilKit
import UIKit

// MARK: - PageScrollView (configures fit zoom at layout time)

/// UIScrollView subclass that sets the fit/​max zoom scales once its bounds are
/// known and keeps the page centred (letterboxed) when smaller than the viewport.
final class PageScrollView: UIScrollView {
    weak var pageCanvas: XmateCanvasView?
    var paper: PaperSize?
    private var configuredViewport: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let paper, bounds.size.width > 0, bounds.size.height > 0 else { return }
        if bounds.size != configuredViewport {
            configuredViewport = bounds.size
            let fit = PageGeometry.fitScale(in: bounds.size, for: paper)
            let wasAtFit = (minimumZoomScale == 0) || zoomScale <= minimumZoomScale + 0.0001
            minimumZoomScale = fit
            maximumZoomScale = fit * PageZoomModel.maxZoom
            if wasAtFit { zoomScale = fit }   // keep showing the whole page on (re)layout
        }
        centerContent()
    }

    /// Centre the page via contentInset so it letterboxes in the viewport when
    /// the zoomed content is smaller than the bounds.
    func centerContent() {
        let bs = bounds.size
        let cs = contentSize
        let x = max(0, (bs.width  - cs.width)  / 2)
        let y = max(0, (bs.height - cs.height) / 2)
        contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }

    /// True when at (or essentially at) the fit zoom.
    var isAtFit: Bool { zoomScale <= minimumZoomScale + 0.0001 }
}

// MARK: - ZoomablePage

struct ZoomablePage: UIViewRepresentable {
    let page: Page
    let store: NoteStore
    let paper: PaperSize

    /// Page-turn swipes — only fire at fit (suspended while zoomed in).
    var swipeAxis: Axis = .vertical
    var onSwipeForward: (() -> Void)?
    var onSwipeBackward: (() -> Void)?

    /// Reports the current zoom as a 1.0…3.0 multiple of fit, for the HUD /
    /// top-bar percentage. Display only — does not drive any layout here.
    var onZoomChange: ((CGFloat) -> Void)?
    /// Bumped by the top-bar reset button to zoom back to fit (double-tap
    /// resets in-component, so it does not use this).
    var resetToken: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Coordinator

    final class Coordinator: NSObject, UIScrollViewDelegate, PKCanvasViewDelegate {
        var parent: ZoomablePage
        weak var scrollView: PageScrollView?
        weak var canvas: XmateCanvasView?
        var isRegistered = false
        var lastResetToken = 0

        init(_ parent: ZoomablePage) { self.parent = parent }

        // ── Zoom ──────────────────────────────────────────────────────────
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvas }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? PageScrollView)?.centerContent()
            // Enable scrolling only when zoomed in, so at fit a one-finger drag
            // falls through to the page-turn swipe recogniser.
            scrollView.isScrollEnabled = !((scrollView as? PageScrollView)?.isAtFit ?? true)
            // Report the zoom (1.0…3.0 multiple of fit) for the HUD / top bar.
            if scrollView.minimumZoomScale > 0 {
                parent.onZoomChange?(scrollView.zoomScale / scrollView.minimumZoomScale)
            }
        }

        // ── Saving ────────────────────────────────────────────────────────
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let c = canvasView as? XmateCanvasView else { return }
            DrawingSessionManager.shared.canvasDrawingChanged(c)
        }

        // ── Finger gestures ───────────────────────────────────────────────
        @objc func handleSwipeForward()  { guard scrollView?.isAtFit ?? true else { return }; parent.onSwipeForward?() }
        @objc func handleSwipeBackward() { guard scrollView?.isAtFit ?? true else { return }; parent.onSwipeBackward?() }
        @objc func handleDoubleTap(_ r: UITapGestureRecognizer) {
            // TEMP: edit-menu diagnosis — what's attached to the canvas?
            if let c = canvas {
                let ix = c.interactions.map { String(describing: type(of: $0)) }.joined(separator: ",")
                let gr = (c.gestureRecognizers ?? []).map { String(describing: type(of: $0)) }.joined(separator: ",")
                EditorTrace.event("doubleTap canvas.interactions=[\(ix)] canvas.recognizers=[\(gr)]")
            }
            guard let sv = scrollView else { return }
            sv.setZoomScale(sv.minimumZoomScale, animated: true)
        }
    }

    // MARK: UIViewRepresentable

    func makeUIView(context: Context) -> PageScrollView {
        let scrollView = PageScrollView()
        scrollView.paper = paper
        scrollView.delegate = context.coordinator
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.isScrollEnabled = false   // starts at fit
        // Finger-only scrolling so Apple Pencil draws instead of scrolling.
        scrollView.panGestureRecognizer.allowedTouchTypes =
            [NSNumber(value: UITouch.TouchType.direct.rawValue)]

        // Canvas at logical page size — the scroll view's zoomable content.
        let canvas = XmateCanvasView()
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.overrideUserInterfaceStyle = .light   // black ink stays legible in dark mode
        canvas.drawingPolicy = .pencilOnly
        canvas.isScrollEnabled = false
        canvas.bounces = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.delegate = context.coordinator
        canvas.pageID = page.id
        canvas.role = .single
        canvas.frame = CGRect(x: 0, y: 0, width: paper.width, height: paper.height)
        if let data = page.drawingData, let drawing = StrokeSerializer.decode(data) {
            canvas.drawing = drawing
        }
        scrollView.addSubview(canvas)
        scrollView.contentSize = canvas.bounds.size
        scrollView.pageCanvas = canvas
        context.coordinator.canvas = canvas
        context.coordinator.scrollView = scrollView

        // Page-turn swipes (finger only). They fire only at fit (guarded in the
        // handlers); at fit scrolling is disabled so the scroll-view pan does not
        // swallow them.
        let fingerOnly: [NSNumber] = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        let fwd = UISwipeGestureRecognizer(target: context.coordinator,
                                           action: #selector(Coordinator.handleSwipeForward))
        fwd.direction = (swipeAxis == .vertical) ? .up : .left
        fwd.allowedTouchTypes = fingerOnly
        scrollView.addGestureRecognizer(fwd)
        let bwd = UISwipeGestureRecognizer(target: context.coordinator,
                                           action: #selector(Coordinator.handleSwipeBackward))
        bwd.direction = (swipeAxis == .vertical) ? .down : .right
        bwd.allowedTouchTypes = fingerOnly
        scrollView.addGestureRecognizer(bwd)

        // Finger double-tap → reset to fit. Attached to the CANVAS (not the
        // scroll view) with cancelsTouchesInView = false — the same pattern
        // PencilKitBridge uses without raising the canvas edit menu. A
        // double-tap recognised on the scroll view (cancelsTouchesInView = true)
        // still let the canvas process the taps and pop "Select All / Insert
        // Space"; recognising it on the canvas itself does not.
        let dt = UITapGestureRecognizer(target: context.coordinator,
                                        action: #selector(Coordinator.handleDoubleTap(_:)))
        dt.numberOfTapsRequired = 2
        dt.allowedTouchTypes = fingerOnly
        dt.cancelsTouchesInView = false
        canvas.addGestureRecognizer(dt)

        return scrollView
    }

    func updateUIView(_ scrollView: PageScrollView, context: Context) {
        context.coordinator.parent = self
        guard let canvas = context.coordinator.canvas else { return }
        // Top-bar reset: zoom back to fit when the token bumps.
        if context.coordinator.lastResetToken != resetToken {
            context.coordinator.lastResetToken = resetToken
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.0001 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            }
        }
        // Register with DrawingSessionManager once the canvas is in a window
        // (same pattern as PencilKitBridge — activation is decided by the
        // session manager, never here).
        if !context.coordinator.isRegistered {
            DispatchQueue.main.async {
                guard canvas.window != nil, !context.coordinator.isRegistered else { return }
                context.coordinator.isRegistered = true
                DrawingSessionManager.shared.register(canvas, role: .single, visible: true)
            }
        }
    }

    static func dismantleUIView(_ scrollView: PageScrollView, coordinator: Coordinator) {
        if coordinator.isRegistered, let c = coordinator.canvas {
            DrawingSessionManager.shared.unregister(c)
            coordinator.isRegistered = false
        }
    }
}
