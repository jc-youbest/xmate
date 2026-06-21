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

        /// Strong ref to our finger double-tap recogniser. PencilKit's private
        /// selection tap recognisers are made to `require(toFail:)` THIS one, so
        /// the app-level reset wins and PencilKit never shows its edit menu.
        var singlePageDoubleTap: UITapGestureRecognizer?
        /// PencilKit selection recognisers we've already linked, to avoid
        /// duplicate `require(toFail:)` setup. Weak, so recognisers PencilKit
        /// destroys on relayout drop out automatically and fresh ones get linked.
        let linkedSelectionRecognizers = NSHashTable<UIGestureRecognizer>.weakObjects()
        /// 2D state: true while PencilKit's finger selection taps are suppressed
        /// (page zoomed above fit). Lets scrollViewDidZoom skip the subtree walk
        /// except on a zoom-threshold crossing.
        var selectionSuppressed = false

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
            // 2D: only walk/refresh on a zoom-threshold crossing, so a pinch does
            // not re-walk the subtree every frame. refreshSelectionRecognizers
            // re-derives the zoomed state and enables/disables the selection taps.
            let zoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.0001
            if zoomed != selectionSuppressed { refreshSelectionRecognizers() }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            #if DEBUG
            print("[DT-DIAG] \(Self.dtTimestamp()) scrollViewDidEndZooming atScale=\(String(format: "%.3f", scale))")
            #endif
            // A zoom relayout can recreate PencilKit's PKSelectionGestureView and
            // its tap recognisers, so re-establish the link + zoom-state suppression
            // after each zoom (idempotent; sets the current desired state).
            refreshSelectionRecognizers()
        }

        // ── Saving ────────────────────────────────────────────────────────
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let c = canvasView as? XmateCanvasView else { return }
            DrawingSessionManager.shared.canvasDrawingChanged(c)
        }

        // ── Finger gestures ───────────────────────────────────────────────
        @objc func handleSwipeForward()  { guard scrollView?.isAtFit ?? true else { return }; parent.onSwipeForward?() }
        @objc func handleSwipeBackward() { guard scrollView?.isAtFit ?? true else { return }; parent.onSwipeBackward?() }

        /// Finger double-tap → reset to fit. This handler only drives the native
        /// zoom-out. The Select All / Insert Space menu is prevented upstream by
        /// refreshSelectionRecognizers: (2C) PencilKit's selection taps require our
        /// double-tap to fail, and (2D) while zoomed they are disabled outright.
        @objc func handleDoubleTap(_ r: UITapGestureRecognizer) {
            guard let sv = scrollView else { return }
            #if DEBUG
            dtLogDoubleTap(r, sv: sv)
            #endif
            guard sv.zoomScale > sv.minimumZoomScale + 0.0001 else { return }
            sv.setZoomScale(sv.minimumZoomScale, animated: true)
            #if DEBUG
            // Re-dump after the reset animation should have completed, to catch
            // any menu-host / first-responder churn caused by the zoom relayout.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, let c = self.canvas else { return }
                print("[DT-DIAG] \(Self.dtTimestamp()) post-reset canvas.isFR=\(c.isFirstResponder)")
                self.dtDumpSubtree(c, tag: "post-reset")
            }
            #endif
        }

        // MARK: - PencilKit selection-recogniser coordination (edit-menu fixes)
        //
        // Two cooperating fixes, both acting ONLY on the private tap recognisers
        // PencilKit hosts on PKSelectionGestureView (a descendant of the canvas):
        //
        //   2C  require(toFail:) — each selection tap is made to require OUR
        //       double-tap to FAIL, so the reset double-tap always wins and the
        //       menu never appears for a double-tap, at any zoom. Applied once
        //       per recogniser instance (deduped via `linkedSelectionRecognizers`).
        //
        //   2D  zoom-state suppression — while zoomed (zoomScale > min) the
        //       selection taps are DISABLED (isEnabled = false), so a finger
        //       single-tap can't raise the menu either; at fit they are restored
        //       (isEnabled = true) so 100% behaviour is unchanged. Reversible —
        //       the normal state is "enabled", so restore == enable.
        //
        // Re-applied on every relevant event (updateUIView, zoom-end, and zoom-
        // threshold crossings) so recognisers PencilKit recreates on a relayout
        // are re-coordinated. Never touches pan / long-press / the
        // PKDrawingGestureRecognizer, so pan, pinch and Pencil ink are unaffected.
        func refreshSelectionRecognizers() {
            guard let canvas, let ours = singlePageDoubleTap, let sv = scrollView else { return }
            let zoomed = sv.zoomScale > sv.minimumZoomScale + 0.0001
            #if DEBUG
            let transition = (zoomed != selectionSuppressed)
            #endif
            selectionSuppressed = zoomed

            var tapCount = 0
            var newlyLinked = 0
            walkSelectionTaps(in: canvas) { tap, hostName in
                tapCount += 1
                // 2C — failure link, once per recogniser instance.
                if tap !== ours, !linkedSelectionRecognizers.contains(tap) {
                    tap.require(toFail: ours)               // PK tap waits for OUR double-tap
                    linkedSelectionRecognizers.add(tap)
                    newlyLinked += 1
                    #if DEBUG
                    print("[DT-DIAG] require(toFail:) applied — \(String(describing: type(of: tap))) on \(hostName)")
                    #endif
                }
                // 2D — disable finger taps while zoomed; restore at fit.
                tap.isEnabled = !zoomed
            }
            #if DEBUG
            if transition {
                print("[DT-DIAG] zoom-state CHANGED zoomed=\(zoomed) -> selection suppression \(zoomed ? "ACTIVE" : "INACTIVE")")
            }
            print("[DT-DIAG] refreshSelectionRecognizers zoomed=\(zoomed) zoomScale=\(String(format: "%.3f", sv.zoomScale)) min=\(String(format: "%.3f", sv.minimumZoomScale)) PKSelectionGestureView taps=\(tapCount) newlyLinked=\(newlyLinked) -> \(zoomed ? "SUPPRESSED (isEnabled=false)" : "RESTORED (isEnabled=true)")")
            #endif
        }

        /// Visit every tap-like recogniser (UITapGestureRecognizer, or any whose
        /// class name contains "Tap") hosted on a PKSelectionGestureView in the
        /// canvas subtree. Pan / long-press / drawing recognisers are never visited.
        private func walkSelectionTaps(in root: UIView,
                                       _ body: (UIGestureRecognizer, String) -> Void) {
            let hostName = String(describing: type(of: root))
            if hostName.contains("PKSelectionGestureView"), let grs = root.gestureRecognizers {
                for gr in grs {
                    let name = String(describing: type(of: gr))
                    if (gr is UITapGestureRecognizer) || name.contains("Tap") {
                        body(gr, hostName)
                    }
                }
            }
            for sub in root.subviews { walkSelectionTaps(in: sub, body) }
        }

        #if DEBUG
        // MARK: - DT-DIAG (temporary edit-menu diagnosis — remove after)

        static func dtTimestamp() -> String {
            String(format: "%9.3f", ProcessInfo.processInfo.systemUptime)
        }

        /// Log the double-tap firing, the hit-test view under the tap, and the
        /// full canvas subtree (edit-menu interactions + gesture recognisers).
        func dtLogDoubleTap(_ r: UITapGestureRecognizer, sv: UIScrollView) {
            print("[DT-DIAG] \(Self.dtTimestamp()) ── Single double-tap FIRED state=\(r.state.rawValue) zoom=\(String(format: "%.3f", sv.zoomScale)) min=\(String(format: "%.3f", sv.minimumZoomScale))")
            guard let c = canvas else { print("[DT-DIAG]   canvas=nil"); return }
            let loc = r.location(in: c)
            let hit = c.hitTest(loc, with: nil)
            print("[DT-DIAG]   tapLoc=\(loc) hitTestView=\(hit.map { String(describing: type(of: $0)) } ?? "nil") canvas.isFR=\(c.isFirstResponder)")
            dtDumpSubtree(c, tag: "at-tap")
        }

        /// Recursively log each subview: UIEditMenuInteraction hosts (+ delegate),
        /// other UIInteractions, and gesture recognisers (class / state / enabled).
        /// State rawValues: 0=possible 1=began 2=changed 3=ended/recognised
        /// 4=cancelled 5=failed.
        func dtDumpSubtree(_ root: UIView, tag: String, depth: Int = 0) {
            let indent = String(repeating: "· ", count: depth)
            let mark = (root === canvas) ? "CANVAS→" : ""
            for em in root.interactions.compactMap({ $0 as? UIEditMenuInteraction }) {
                let del = em.delegate.map { String(describing: type(of: $0)) } ?? "nil"
                print("[DT-DIAG] \(tag) \(indent)\(mark)\(type(of: root)) d=\(depth) ★UIEditMenuInteraction delegate=\(del)")
            }
            let others = root.interactions.filter { !($0 is UIEditMenuInteraction) }
            if !others.isEmpty {
                print("[DT-DIAG] \(tag) \(indent)\(mark)\(type(of: root)) d=\(depth) interactions=[\(others.map { String(describing: type(of: $0)) }.joined(separator: ","))]")
            }
            if let grs = root.gestureRecognizers, !grs.isEmpty {
                let desc = grs.map { "\(type(of: $0))(st=\($0.state.rawValue),en=\($0.isEnabled))" }.joined(separator: ", ")
                print("[DT-DIAG] \(tag) \(indent)\(mark)\(type(of: root)) d=\(depth) GRs=[\(desc)]")
            }
            for sub in root.subviews { dtDumpSubtree(sub, tag: tag, depth: depth + 1) }
        }
        #endif
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

        // Finger double-tap → reset to fit. This is an app-level navigation
        // gesture, NOT a PencilKit editing tap, so it must FULLY CONSUME the
        // finger taps — otherwise the taps reach the first-responder
        // PKCanvasView and pop the system edit menu ("Select All / Insert
        // Space"). Three settings make the gesture watertight:
        //   • allowedTouchTypes = [.direct] — only fingers reach this
        //     recogniser; Apple Pencil touches bypass it entirely, so drawing
        //     is unaffected (and so the touch-consumption below can never
        //     cancel a Pencil stroke).
        //   • delaysTouchesBegan = true — the canvas does not receive the taps
        //     while the double-tap is still being detected. On a successful
        //     double-tap the withheld touches are discarded, so PencilKit never
        //     sees a completed tap → no caret/selection → no edit menu. This is
        //     what fixes the intermittent leak: previously the FIRST tap reached
        //     the canvas before the second tap was recognised.
        //   • cancelsTouchesInView = true — belt-and-braces: any touch already
        //     in flight to the canvas is cancelled (not completed) the moment
        //     the double-tap is recognised.
        // Pan and pinch belong to the scroll view's OWN recognisers, which are
        // not gated by this canvas recogniser, so zoom/pan stay unchanged.
        let dt = UITapGestureRecognizer(target: context.coordinator,
                                        action: #selector(Coordinator.handleDoubleTap(_:)))
        dt.numberOfTapsRequired = 2
        dt.allowedTouchTypes = fingerOnly
        dt.delaysTouchesBegan = true
        dt.cancelsTouchesInView = true
        canvas.addGestureRecognizer(dt)
        // Keep a strong ref so PencilKit's private selection tap recognisers can
        // be coordinated against THIS recogniser (refreshSelectionRecognizers):
        // they require it to fail (2C) and are disabled while zoomed (2D). That,
        // not the view-level delays/cancels above, is what stops the menu.
        context.coordinator.singlePageDoubleTap = dt

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

        // Establish / refresh PencilKit selection-recogniser coordination (2C
        // failure link + 2D zoom-state suppression). Deferred one runloop tick so
        // the canvas's internal PKSelectionGestureView subtree has been created.
        // Idempotent; scrollViewDidZoom/DidEndZooming re-apply it on zoom changes.
        DispatchQueue.main.async {
            context.coordinator.refreshSelectionRecognizers()
        }
    }

    static func dismantleUIView(_ scrollView: PageScrollView, coordinator: Coordinator) {
        if coordinator.isRegistered, let c = coordinator.canvas {
            DrawingSessionManager.shared.unregister(c)
            coordinator.isRegistered = false
        }
    }
}
