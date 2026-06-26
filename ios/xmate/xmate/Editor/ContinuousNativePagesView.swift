// ContinuousNativePagesView — feature-flagged native Continuous prototype
//
// Native Continuous A/B prototype with one persistent host/canvas per page:
//   • perPage (Design A) retains the smooth Stage 3 experiment for comparison,
//     but it failed viewport semantics when two page fragments were visible;
//   • stack (Design B candidate) keeps inner hosts at 1x and lets the outer
//     native UIScrollView own raw stack zoom, which preserves viewport-level
//     meaning without per-frame SwiftUI transforms. Bounded-session clamping is
//     deliberately not enabled yet.

import SwiftUI
import UIKit
import PencilKit

#if DEBUG
/// Flip to `true` temporarily when chasing per-frame Continuous native zoom,
/// hysteresis, or PencilKit private-recognizer timing. Keep `false` for normal
/// device testing so logs stay readable enough to judge performance.
private let continuousNativeVerboseDiagnostics = false
#endif

struct ContinuousNativePagesView: View {
    let pages: [Page]
    let paper: PaperSize
    let store: NoteStore

    @Binding var currentPageIndex: Int

    let scrollTarget: UUID?
    let onScrollTargetConsumed: () -> Void
    let restorePageIndex: Int
    let zoomPrototype: ContinuousNativeZoomPrototype
    let resetToken: Int
    let onZoomChange: ((CGFloat) -> Void)?

    private let gapPt: CGFloat = 20
    @StateObject private var diagnostics = ContinuousNativeSessionDiagnostics()

    var body: some View {
        GeometryReader { proxy in
            let fitScale = PageGeometry.fitScale(in: proxy.size, for: paper)

            ContinuousNativeScrollContainer(
                pages: pages,
                paper: paper,
                store: store,
                viewport: proxy.size,
                fitScale: fitScale,
                gapPt: gapPt,
                restorePageIndex: restorePageIndex,
                scrollTarget: scrollTarget,
                zoomPrototype: zoomPrototype,
                resetToken: resetToken,
                onZoomChange: onZoomChange,
                diagnostics: diagnostics,
                onCurrentPageChange: { report in
                    let displayedChanged = report.index != currentPageIndex
                    diagnostics.recordPageReport(
                        report,
                        displayedChanged: displayedChanged
                    )
                    guard displayedChanged else { return }
                    currentPageIndex = report.index
                },
                onScrollTargetConsumed: onScrollTargetConsumed
            )
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .bottom)
        .onAppear { syncDesiredActive(reason: "entry") }
        .onChange(of: currentPageIndex) { _, _ in
            syncDesiredActive(reason: diagnostics.latestActiveContext)
        }
        .onDisappear {
            diagnostics.clearStackTrackingState()
            diagnostics.logSummary()
        }
    }

    private func syncDesiredActive(reason: String) {
        guard currentPageIndex >= 0, currentPageIndex < pages.count,
              let id = pages[currentPageIndex].id else { return }

        diagnostics.logActiveRequest(index: currentPageIndex,
                                     pageID: id,
                                     reason: reason)
        diagnostics.setCurrentPage(id)
        // No Pencil stroke begin/end state is currently tracked by the existing
        // canvas/session path, so Stage 2.5 deliberately does not infer one.
        DrawingSessionManager.shared
            .setDesiredActive(pageID: id, role: .continuous)
    }
}

// MARK: - Native scroll container

private struct ContinuousNativeScrollContainer: UIViewControllerRepresentable {
    let pages: [Page]
    let paper: PaperSize
    let store: NoteStore
    let viewport: CGSize
    let fitScale: CGFloat
    let gapPt: CGFloat
    let restorePageIndex: Int
    let scrollTarget: UUID?
    let zoomPrototype: ContinuousNativeZoomPrototype
    let resetToken: Int
    let onZoomChange: ((CGFloat) -> Void)?
    let diagnostics: ContinuousNativeSessionDiagnostics
    let onCurrentPageChange: (ContinuousNativePageReport) -> Void
    let onScrollTargetConsumed: () -> Void

    func makeUIViewController(context: Context) -> ContinuousNativeScrollController {
        let content = makeContent()
        let controller = ContinuousNativeScrollController(
            content: content,
            diagnostics: diagnostics,
            zoomPrototype: zoomPrototype,
            onZoomChange: onZoomChange
        )
        controller.configure(
            pageIDs: pages.compactMap(\.id),
            pageHeight: paper.height * fitScale,
            gapPt: gapPt,
            restorePageIndex: restorePageIndex,
            resetToken: resetToken,
            onCurrentPageChange: onCurrentPageChange
        )
        return controller
    }

    func updateUIViewController(_ controller: ContinuousNativeScrollController,
                                context: Context) {
        controller.updateContent(makeContent())
        controller.configure(
            pageIDs: pages.compactMap(\.id),
            pageHeight: paper.height * fitScale,
            gapPt: gapPt,
            restorePageIndex: restorePageIndex,
            resetToken: resetToken,
            onCurrentPageChange: onCurrentPageChange
        )
        controller.handleScrollTarget(scrollTarget) {
            onScrollTargetConsumed()
        }
    }

    private func makeContent() -> ContinuousNativePageStack {
        ContinuousNativePageStack(
            pages: pages,
            paper: paper,
            store: store,
            viewport: viewport,
            fitScale: fitScale,
            gapPt: gapPt,
            zoomPrototype: zoomPrototype,
            diagnostics: diagnostics
        )
    }
}

// MARK: - Persistent SwiftUI page stack hosted by the native scroll view

private struct ContinuousNativePageStack: View {
    let pages: [Page]
    let paper: PaperSize
    let store: NoteStore
    let viewport: CGSize
    let fitScale: CGFloat
    let gapPt: CGFloat
    let zoomPrototype: ContinuousNativeZoomPrototype
    let diagnostics: ContinuousNativeSessionDiagnostics

    var body: some View {
        let scaledW = paper.width * fitScale
        let scaledH = paper.height * fitScale

        VStack(spacing: gapPt) {
            ForEach(pages, id: \.id) { page in
                ContinuousNativePageHost(
                    page: page,
                    store: store,
                    zoomPrototype: zoomPrototype,
                    diagnostics: diagnostics
                )
                .frame(width: paper.width, height: paper.height)
                .scaleEffect(fitScale)
                .frame(width: scaledW, height: scaledH)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 0)
                .id(page.id)
            }
        }
        .padding(.vertical, gapPt)
        .frame(width: viewport.width)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Persistent inner page host (Stage 3 native pinch)

/// One stable native host per page ID. SwiftUI's surrounding `ForEach` is keyed
/// by Page.id, so normal outer scrolling does not recreate this scroll view or
/// its single canvas.
private struct ContinuousNativePageHost: UIViewRepresentable {
    let page: Page
    let store: NoteStore
    let zoomPrototype: ContinuousNativeZoomPrototype
    let diagnostics: ContinuousNativeSessionDiagnostics

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        weak var canvas: XmateCanvasView?
        weak var inner: ContinuousNativeInnerScrollView?
        weak var zoomContent: UIView?
        var pageID: UUID?
        var zoomPrototype: ContinuousNativeZoomPrototype = .stack
        weak var diagnostics: ContinuousNativeSessionDiagnostics?
        var isRegistered = false

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let canvas = canvasView as? XmateCanvasView else { return }
            DrawingSessionManager.shared.canvasDrawingChanged(canvas)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            zoomPrototype == .perPage ? zoomContent : nil
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView,
                                        with view: UIView?) {
            diagnostics?.zoomBegan(pageID: pageID)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let pageID else { return }
            diagnostics?.zoomChanged(pageID: pageID,
                                     scale: scrollView.zoomScale)
            if scrollView.zoomScale > 1.0001 {
                diagnostics?.lockZoomOwner(pageID)
            }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView,
                                     with view: UIView?,
                                     atScale scale: CGFloat) {
            guard let pageID else { return }
            diagnostics?.zoomEnded(pageID: pageID, scale: scale)
            if scale <= 1.0001 {
                scrollView.setZoomScale(1.0, animated: false)
            } else {
                diagnostics?.lockZoomOwner(pageID)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ContinuousNativeInnerScrollView {
        let inner = ContinuousNativeInnerScrollView()
        inner.pageID = page.id
        inner.zoomPrototype = zoomPrototype
        inner.diagnostics = diagnostics
        inner.delegate = context.coordinator
        inner.minimumZoomScale = 1.0
        inner.maximumZoomScale = zoomPrototype == .perPage ? 3.0 : 1.0
        inner.zoomScale = 1.0
        inner.bounces = false
        inner.bouncesZoom = false
        inner.showsVerticalScrollIndicator = false
        inner.showsHorizontalScrollIndicator = false
        inner.contentInsetAdjustmentBehavior = .never
        inner.backgroundColor = .white
        // Every host keeps its pinch recognizer available so a non-current
        // attempt reaches gestureRecognizerShouldBegin and can be diagnosed.
        // Only the current/owner page is allowed to begin.
        inner.pinchGestureRecognizer?.isEnabled = (zoomPrototype == .perPage)
        inner.panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue)
        ]
        inner.panGestureRecognizer.maximumNumberOfTouches = 1

        let canvas = XmateCanvasView()
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = .pencilOnly
        canvas.isScrollEnabled = false
        canvas.bounces = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.delegate = context.coordinator
        canvas.pageID = page.id
        canvas.role = .continuous
        if let data = page.drawingData,
           let drawing = StrokeSerializer.decode(data) {
            canvas.drawing = drawing
        }

        let zoomContent = UIView()
        zoomContent.backgroundColor = .white
        zoomContent.addSubview(canvas)
        inner.addSubview(zoomContent)
        inner.pageCanvas = canvas
        inner.zoomContentView = zoomContent
        context.coordinator.canvas = canvas
        context.coordinator.inner = inner
        context.coordinator.zoomContent = zoomContent
        context.coordinator.pageID = page.id
        context.coordinator.zoomPrototype = zoomPrototype
        context.coordinator.diagnostics = diagnostics
        diagnostics.registerInnerHost(inner, pageID: page.id)

        diagnostics.hostCreated(pageID: page.id, canvas: canvas)

        return inner
    }

    func updateUIView(_ inner: ContinuousNativeInnerScrollView,
                      context: Context) {
        guard let canvas = context.coordinator.canvas else { return }

        // The logical page remains 1:1 inside its host. The surrounding SwiftUI
        // stack applies only the fit-scale visual transform used in Stage 0/1.
        if inner.zoomScale <= 1.0001 {
            inner.zoomContentView?.frame = inner.bounds
            inner.contentSize = inner.bounds.size
        }
        if let content = inner.zoomContentView {
            canvas.frame = content.bounds
        }
        inner.minimumZoomScale = 1.0
        inner.maximumZoomScale = zoomPrototype == .perPage ? 3.0 : 1.0
        if zoomPrototype == .stack, inner.zoomScale != 1.0 {
            inner.setZoomScale(1.0, animated: false)
        }
        inner.pinchGestureRecognizer?.isEnabled = (zoomPrototype == .perPage)

        canvas.drawingPolicy = .pencilOnly
        canvas.isScrollEnabled = false
        canvas.pageID = page.id
        canvas.role = .continuous
        inner.pageID = page.id
        inner.zoomPrototype = zoomPrototype
        inner.diagnostics = diagnostics
        context.coordinator.pageID = page.id
        context.coordinator.zoomPrototype = zoomPrototype
        context.coordinator.diagnostics = diagnostics

        diagnostics.hostReused(pageID: page.id, canvas: canvas)

        if !context.coordinator.isRegistered {
            DispatchQueue.main.async {
                guard canvas.window != nil,
                      !context.coordinator.isRegistered else { return }
                context.coordinator.isRegistered = true
                DrawingSessionManager.shared
                    .register(canvas, role: .continuous, visible: true)
            }
        }
    }

    static func dismantleUIView(_ inner: ContinuousNativeInnerScrollView,
                                coordinator: Coordinator) {
        coordinator.diagnostics?.unregisterInnerHost(inner,
                                                     pageID: coordinator.pageID)
        if coordinator.isRegistered, let canvas = coordinator.canvas {
            DrawingSessionManager.shared.unregister(canvas)
            coordinator.isRegistered = false
        }
    }

}

/// Inner page scroll host. Its pan fails at 1x so the enclosing Continuous
/// scroll receives navigation; above 1x the native inner scroll may pan its
/// zoomed content while the outer scroll is frozen.
private final class ContinuousNativeInnerScrollView: UIScrollView {
    var pageID: UUID?
    var zoomPrototype: ContinuousNativeZoomPrototype = .stack
    weak var pageCanvas: XmateCanvasView?
    weak var zoomContentView: UIView?
    weak var diagnostics: ContinuousNativeSessionDiagnostics?

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale <= 1.0001 {
            zoomContentView?.frame = bounds
            contentSize = bounds.size
        }
        if let content = zoomContentView {
            pageCanvas?.frame = content.bounds
        }
    }

    override func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let allowed = zoomPrototype == .perPage
                && zoomScale > 1.0001
                && (diagnostics?.isZoomOwner(pageID) ?? false)
            diagnostics?.innerPanAttempt(pageID: pageID,
                                         zoomScale: zoomScale,
                                         allowed: allowed)
            return allowed
        }
        if gestureRecognizer === pinchGestureRecognizer {
            guard zoomPrototype == .perPage else { return false }
            return diagnostics?.shouldBeginZoom(pageID) ?? false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

// MARK: - Stage 2.5 diagnostics

private struct ContinuousNativePageReport {
    let index: Int
    let pageID: UUID
    let rawIndex: CGFloat
    let contentOffsetY: CGFloat
    let isDragging: Bool
    let isDecelerating: Bool
}

/// One counter set per lifetime of ContinuousNativePagesView. It is deliberately
/// diagnostic-only: no counters participate in layout, routing, or activation.
private final class ContinuousNativeSessionDiagnostics: ObservableObject {
    private(set) var latestActiveContext = "initial"
    private var currentPageID: UUID?
    private var zoomOwnerPageID: UUID?
    private weak var outerScrollView: UIScrollView?
    private var innerHosts: [UUID: WeakContinuousInnerHost] = [:]
    private var lastGeometryPageIndex: Int?
    private var lastGeometryTransition: (from: Int, to: Int, time: TimeInterval)?

    #if DEBUG
    private var createdByPage: [UUID: Int] = [:]
    private var reusedByPage: [UUID: Int] = [:]
    private var panAttemptsByPage: [UUID: Int] = [:]
    private var menuRefreshCount = 0
    private var menuVisitedTapCount = 0
    private var menuLinkedTapCount = 0
    #endif

    func hostCreated(pageID: UUID?, canvas: XmateCanvasView) {
        #if DEBUG
        guard let pageID else { return }
        createdByPage[pageID, default: 0] += 1
        let count = createdByPage[pageID, default: 0]
        print("[CONT-HOST] page=\(shortID(pageID)) created=\(count) canvas=\(ObjectIdentifier(canvas)) recreated=\(count > 1)")
        #endif
    }

    func hostReused(pageID: UUID?, canvas: XmateCanvasView) {
        #if DEBUG
        guard let pageID else { return }
        reusedByPage[pageID, default: 0] += 1
        let count = reusedByPage[pageID, default: 0]
        if count == 1 {
            print("[CONT-HOST] page=\(shortID(pageID)) reused=1 canvas=\(ObjectIdentifier(canvas))")
        }
        #endif
    }

    func innerPanAttempt(pageID: UUID?, zoomScale: CGFloat, allowed: Bool) {
        #if DEBUG
        guard let pageID else { return }
        panAttemptsByPage[pageID, default: 0] += 1
        let count = panAttemptsByPage[pageID, default: 0]
        print("[CONT-INNER] panAttempt=\(count) page=\(shortID(pageID)) zoom=\(String(format: "%.2f", zoomScale)) allowed=\(allowed) owner=outer")
        #endif
    }

    func registerInnerHost(_ host: ContinuousNativeInnerScrollView,
                           pageID: UUID?) {
        guard let pageID else { return }
        innerHosts[pageID] = WeakContinuousInnerHost(host)
    }

    func unregisterInnerHost(_ host: ContinuousNativeInnerScrollView,
                             pageID: UUID?) {
        guard let pageID, innerHosts[pageID]?.value === host else { return }
        innerHosts[pageID] = nil
        if zoomOwnerPageID == pageID {
            releaseZoomOwner(pageID)
        }
    }

    func attachOuterScrollView(_ scrollView: UIScrollView) {
        outerScrollView = scrollView
    }

    func setCurrentPage(_ pageID: UUID) {
        guard currentPageID != pageID else { return }
        currentPageID = pageID
        // An owner normally prevents outer page movement. This defensive reset
        // enforces the invariant if a programmatic mutation changes the current
        // page while another host is still zoomed.
        if let owner = zoomOwnerPageID, owner != pageID {
            innerHosts[owner]?.value?.setZoomScale(1.0, animated: false)
            releaseZoomOwner(owner)
        }
    }

    func clearStackTrackingState() {
        if let owner = zoomOwnerPageID {
            releaseZoomOwner(owner)
        } else {
            setOuterScrollEnabled(true, reason: "view disappeared")
        }
        currentPageID = nil
        lastGeometryPageIndex = nil
        lastGeometryTransition = nil
        latestActiveContext = "initial"
    }

    func refreshStackSelectionRecognizers(
        stackDoubleTap: UITapGestureRecognizer?,
        linkedRecognizers: NSHashTable<UIGestureRecognizer>,
        zoomed: Bool
    ) {
        guard let stackDoubleTap else { return }
        #if DEBUG
        var visited = 0
        var linked = 0
        #endif
        for host in innerHosts.values {
            guard let canvas = host.value?.pageCanvas else { continue }
            walkSelectionTaps(in: canvas) { tap, _ in
                #if DEBUG
                visited += 1
                #endif
                if tap !== stackDoubleTap,
                   !linkedRecognizers.contains(tap) {
                    tap.require(toFail: stackDoubleTap)
                    linkedRecognizers.add(tap)
                    #if DEBUG
                    linked += 1
                    #endif
                }
                tap.isEnabled = !zoomed
            }
        }
        #if DEBUG
        menuRefreshCount += 1
        menuVisitedTapCount += visited
        menuLinkedTapCount += linked
        if continuousNativeVerboseDiagnostics {
            print("[CONT-STACK-MENU] configured selection taps count=\(visited) linked=\(linked) zoomed=\(zoomed) refresh=\(menuRefreshCount)")
        } else if linked > 0 {
            print("[CONT-STACK-MENU] configured selection taps count=\(visited) linked=\(linked) zoomed=\(zoomed)")
        }
        #endif
    }

    private func walkSelectionTaps(in root: UIView,
                                   _ body: (UIGestureRecognizer, String) -> Void) {
        let hostName = String(describing: type(of: root))
        if hostName.contains("PKSelectionGestureView"),
           let recognizers = root.gestureRecognizers {
            for recognizer in recognizers {
                let name = String(describing: type(of: recognizer))
                if recognizer is UITapGestureRecognizer || name.contains("Tap") {
                    body(recognizer, hostName)
                }
            }
        }
        for subview in root.subviews {
            walkSelectionTaps(in: subview, body)
        }
    }

    func shouldBeginZoom(_ pageID: UUID?) -> Bool {
        guard let pageID else { return false }
        let allowed = pageID == currentPageID
            && (zoomOwnerPageID == nil || zoomOwnerPageID == pageID)
        #if DEBUG
        if !allowed {
            print("[CONT-ZOOM] rejected non-current page=\(shortID(pageID)) current=\(currentPageID.map(shortID) ?? "----") owner=\(zoomOwnerPageID.map(shortID) ?? "----")")
        }
        #endif
        return allowed
    }

    func isZoomOwner(_ pageID: UUID?) -> Bool {
        guard let pageID else { return false }
        return zoomOwnerPageID == pageID
    }

    func zoomBegan(pageID: UUID?) {
        guard let pageID else { return }
        #if DEBUG
        print("[CONT-ZOOM] begin page=\(shortID(pageID))")
        #endif
        setOuterScrollEnabled(false, reason: "active pinch")
    }

    func zoomChanged(pageID: UUID, scale: CGFloat) {
        #if DEBUG
        print("[CONT-ZOOM] changed page=\(shortID(pageID)) scale=\(String(format: "%.3f", scale))")
        #endif
    }

    func zoomEnded(pageID: UUID, scale: CGFloat) {
        #if DEBUG
        print("[CONT-ZOOM] end page=\(shortID(pageID)) scale=\(String(format: "%.3f", scale))")
        #endif
        if scale <= 1.0001 {
            releaseZoomOwner(pageID)
        } else {
            setOuterScrollEnabled(false, reason: "zoom owner above minimum")
        }
    }

    func lockZoomOwner(_ pageID: UUID) {
        guard zoomOwnerPageID != pageID else { return }
        guard zoomOwnerPageID == nil, currentPageID == pageID else { return }
        zoomOwnerPageID = pageID
        #if DEBUG
        print("[CONT-ZOOM] owner locked page=\(shortID(pageID))")
        #endif
        setOuterScrollEnabled(false, reason: "owner locked")
    }

    func releaseZoomOwner(_ pageID: UUID) {
        guard zoomOwnerPageID == pageID else {
            // A pinch that never crossed above 1x has no owner, but still froze
            // the outer scroll in zoomBegan.
            if zoomOwnerPageID == nil {
                setOuterScrollEnabled(true, reason: "pinch ended at minimum")
            }
            return
        }
        zoomOwnerPageID = nil
        #if DEBUG
        print("[CONT-ZOOM] owner released page=\(shortID(pageID))")
        #endif
        setOuterScrollEnabled(true, reason: "owner released")
    }

    private func setOuterScrollEnabled(_ enabled: Bool, reason: String) {
        guard let outerScrollView else { return }
        if outerScrollView.isScrollEnabled != enabled {
            outerScrollView.isScrollEnabled = enabled
        }
        #if DEBUG
        print("[CONT-ZOOM] outerScroll enabled=\(enabled) reason=\(reason)")
        #endif
    }

    func recordPageReport(_ report: ContinuousNativePageReport,
                          displayedChanged: Bool) {
        guard displayedChanged else {
            if lastGeometryPageIndex == nil {
                lastGeometryPageIndex = report.index
            }
            #if DEBUG
            print("[CONT-DISPLAY] unchanged index=\(report.index) page=\(shortID(report.pageID)) raw=\(String(format: "%.3f", report.rawIndex))")
            #endif
            return
        }

        guard let from = lastGeometryPageIndex else {
            lastGeometryPageIndex = report.index
            latestActiveContext = "entry"
            #if DEBUG
            print("[CONT-DISPLAY] changed previous=nil next=\(report.index) page=\(shortID(report.pageID)) raw=\(String(format: "%.3f", report.rawIndex)) reason=entry")
            #endif
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let oscillating: Bool
        if let lastGeometryTransition {
            oscillating = lastGeometryTransition.from == report.index
                && lastGeometryTransition.to == from
                && now - lastGeometryTransition.time < 0.75
        } else {
            oscillating = false
        }
        latestActiveContext = oscillating
            ? "boundary oscillation"
            : "normal page crossing"

        #if DEBUG
        let phase = report.isDragging ? "drag"
            : (report.isDecelerating ? "deceleration" : "programmatic/layout")
        print("[CONT-DISPLAY] changed previous=\(from) next=\(report.index) page=\(shortID(report.pageID)) raw=\(String(format: "%.3f", report.rawIndex)) phase=\(phase) oscillation=\(oscillating)")
        #endif

        lastGeometryTransition = (from, report.index, now)
        lastGeometryPageIndex = report.index
    }

    func logActiveRequest(index: Int, pageID: UUID, reason: String) {
        #if DEBUG
        print("[CONT-ACTIVE] setDesiredActive=true index=\(index) page=\(shortID(pageID)) reason=\(reason)")
        #endif
    }

    func logSummary() {
        #if DEBUG
        let pageIDs = Set(createdByPage.keys)
            .union(reusedByPage.keys)
            .union(panAttemptsByPage.keys)
            .sorted { $0.uuidString < $1.uuidString }
        for pageID in pageIDs {
            print("[CONT-HOST-SUMMARY] page=\(shortID(pageID)) created=\(createdByPage[pageID, default: 0]) reused=\(reusedByPage[pageID, default: 0]) panAttempts=\(panAttemptsByPage[pageID, default: 0])")
        }
        if menuRefreshCount > 0 {
            print("[CONT-STACK-MENU-SUMMARY] refreshes=\(menuRefreshCount) visited=\(menuVisitedTapCount) linked=\(menuLinkedTapCount)")
        }
        #endif
    }

    #if DEBUG
    private func shortID(_ id: UUID) -> String {
        String(id.uuidString.prefix(4))
    }
    #endif
}

private final class WeakContinuousInnerHost {
    weak var value: ContinuousNativeInnerScrollView?
    init(_ value: ContinuousNativeInnerScrollView) { self.value = value }
}

// MARK: - UIKit owner

private final class ContinuousNativeScrollController: UIViewController,
                                                      UIScrollViewDelegate,
                                                      UIGestureRecognizerDelegate {
    private let scrollView = UIScrollView()
    private let host: UIHostingController<ContinuousNativePageStack>

    private var pageIDs: [UUID] = []
    private var pageHeight: CGFloat = 0
    private var gapPt: CGFloat = 0
    private var restorePageIndex: Int = 0
    private var resetToken: Int = 0
    private var lastHandledResetToken: Int = 0
    private var onCurrentPageChange: ((ContinuousNativePageReport) -> Void)?
    private var onZoomChange: ((CGFloat) -> Void)?

    private var didRestoreInitialPosition = false
    private var lastReportedIndex: Int?
    private var handledScrollTarget: UUID?
    private var stackZoomAnchorIndex: Int?
    private var stackTrackingFrozen = false
    private var stackResetInProgress = false
    private var stackDoubleTapReset: UITapGestureRecognizer?
    private let linkedStackSelectionRecognizers =
        NSHashTable<UIGestureRecognizer>.weakObjects()
    private var stackMenuSuppressionState: Bool?
    #if DEBUG
    private var stackZoomChangedSamples = 0
    private var stackHysteresisSuppressedTotal = 0
    private var stackHysteresisAcceptedTotal = 0
    private var stackHysteresisSuppressedSinceAccepted = 0
    #endif
    private var didLogStackZoomView = false
    /// Stateful displayed-page tracker for Design B. A page transition must
    /// clear the midpoint by this fraction of one page stride.
    private var stackDisplayedPageIndex: Int?
    private let stackPageHysteresis: CGFloat = 0.08

    private let diagnostics: ContinuousNativeSessionDiagnostics
    private let zoomPrototype: ContinuousNativeZoomPrototype

    init(content: ContinuousNativePageStack,
         diagnostics: ContinuousNativeSessionDiagnostics,
         zoomPrototype: ContinuousNativeZoomPrototype,
         onZoomChange: ((CGFloat) -> Void)?) {
        host = UIHostingController(rootView: content)
        self.diagnostics = diagnostics
        self.zoomPrototype = zoomPrototype
        self.onZoomChange = onZoomChange
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground
        scrollView.backgroundColor = .systemGroupedBackground
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        diagnostics.attachOuterScrollView(scrollView)
        // Design B: the outer native scroll owns the persistent stack's zoom.
        // Inner page hosts remain at 1x. Bounded-session clamping is deliberately
        // deferred, so this is the raw native stack-zoom experiment.
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = zoomPrototype == .stack ? 3.0 : 1.0
        scrollView.zoomScale = 1.0
        scrollView.bouncesZoom = false
        scrollView.pinchGestureRecognizer?.isEnabled = (zoomPrototype == .stack)
        // The outer Continuous scroll is navigation-only. Apple Pencil touches
        // must pass through to the persistent PKCanvasViews unchanged.
        scrollView.panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue)
        ]
        // Two fingers belong exclusively to the current inner page's native
        // pinch recognizer; the outer scroll remains a one-finger navigator.
        scrollView.panGestureRecognizer.maximumNumberOfTouches = 1

        if zoomPrototype == .stack {
            let resetTap = UITapGestureRecognizer(
                target: self,
                action: #selector(handleStackDoubleTapReset(_:))
            )
            resetTap.numberOfTapsRequired = 2
            resetTap.numberOfTouchesRequired = 1
            resetTap.allowedTouchTypes = [
                NSNumber(value: UITouch.TouchType.direct.rawValue)
            ]
            resetTap.cancelsTouchesInView = true
            resetTap.delaysTouchesBegan = true
            resetTap.delegate = self
            scrollView.addGestureRecognizer(resetTap)
            stackDoubleTapReset = resetTap
        }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear

        view.addSubview(scrollView)
        addChild(host)
        scrollView.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        #if DEBUG
        if zoomPrototype == .stack {
            print("[CONT-STACK] outer zoom owner prepared scale=1.0 pinchEnabled=true")
        }
        #endif
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        guard zoomPrototype == .stack else { return nil }
        #if DEBUG
        if !didLogStackZoomView {
            didLogStackZoomView = true
            print("[CONT-STACK-ZOOM] viewForZooming stackContent")
        }
        #endif
        return host.view
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView,
                                    with view: UIView?) {
        guard zoomPrototype == .stack else { return }
        #if DEBUG
        stackZoomChangedSamples = 0
        print("[CONT-STACK-ZOOM] begin scale=\(String(format: "%.3f", scrollView.zoomScale))")
        #endif

        // Capture once for the complete >1x zoom session. A second pinch while
        // already zoomed retains the original anchor until scale returns to 1x.
        if stackZoomAnchorIndex == nil {
            let anchor = lastReportedIndex ?? currentPageIndexForGeometry()
            stackZoomAnchorIndex = anchor
            if pageIDs.indices.contains(anchor) {
                #if DEBUG
                print("[CONT-STACK-ZOOM] anchor page=\(shortPageID(pageIDs[anchor]))")
                #endif
            }
        }
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard zoomPrototype == .stack else { return }
        reportStackZoomDisplay(scrollView.zoomScale)
        #if DEBUG
        stackZoomChangedSamples += 1
        if continuousNativeVerboseDiagnostics {
            print("[CONT-STACK-ZOOM] changed scale=\(String(format: "%.3f", scrollView.zoomScale))")
        }
        #endif
        if scrollView.zoomScale > 1.0001, !stackTrackingFrozen {
            stackTrackingFrozen = true
            #if DEBUG
            print("[CONT-STACK-ZOOM] current tracking frozen")
            #endif
        }
        refreshStackSelectionRecognizersIfNeeded(
            zoomed: scrollView.zoomScale > 1.0001
        )
        if stackResetInProgress, scrollView.zoomScale <= 1.0001 {
            completeStackResetIfNeeded()
        }
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView,
                                 with view: UIView?,
                                 atScale scale: CGFloat) {
        guard zoomPrototype == .stack else { return }
        #if DEBUG
        print("[CONT-STACK-ZOOM] end scale=\(String(format: "%.3f", scale)) changedSamples=\(stackZoomChangedSamples)")
        #endif
        guard scale <= 1.0001 else { return }

        if stackResetInProgress {
            completeStackResetIfNeeded()
            return
        }
        refreshStackSelectionRecognizersIfNeeded(zoomed: false, force: true)
        releaseStackZoomTrackingAndReport()
    }

    @objc private func handleStackDoubleTapReset(
        _ recognizer: UITapGestureRecognizer
    ) {
        guard zoomPrototype == .stack,
              recognizer.state == .recognized else { return }

        #if DEBUG
        print("[CONT-STACK-RESET] doubleTap received scale=\(String(format: "%.3f", scrollView.zoomScale))")
        #endif

        guard scrollView.zoomScale > scrollView.minimumZoomScale + 0.0001 else {
            #if DEBUG
            print("[CONT-STACK-RESET] ignored at minimum")
            #endif
            return
        }

        stackResetInProgress = true
        #if DEBUG
        print("[CONT-STACK-RESET] setZoomScale 1.0 animated=true")
        #endif
        resetStackZoomAnimated()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer {
            return zoomPrototype == .stack && touch.type == .direct
        }
        return true
    }

    private func completeStackResetIfNeeded() {
        guard stackResetInProgress else { return }
        stackResetInProgress = false
        #if DEBUG
        print("[CONT-STACK-RESET] completed scale=\(String(format: "%.3f", scrollView.zoomScale))")
        #endif
        refreshStackSelectionRecognizersIfNeeded(zoomed: false, force: true)
        releaseStackZoomTrackingAndReport()
    }

    private func releaseStackZoomTrackingAndReport() {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        reportStackZoomDisplay(scrollView.minimumZoomScale)
        stackZoomAnchorIndex = nil
        if stackTrackingFrozen {
            stackTrackingFrozen = false
            #if DEBUG
            print("[CONT-STACK-ZOOM] current tracking released")
            #endif
        }
        // Reconcile the page once native zoom has fully returned to 1x.
        reportCurrentPage(force: true)
    }

    private func resetStackZoomAnimated() {
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
    }

    private func reportStackZoomDisplay(_ scale: CGFloat) {
        guard zoomPrototype == .stack else { return }
        let minScale = max(scrollView.minimumZoomScale, 0.0001)
        let multiple = (scale / minScale)
            .clamped(to: PageZoomModel.minZoom...PageZoomModel.maxZoom)
        onZoomChange?(multiple)
    }

    private func handleResetTokenIfNeeded() {
        guard zoomPrototype == .stack else { return }
        guard resetToken != lastHandledResetToken else { return }
        lastHandledResetToken = resetToken
        guard scrollView.zoomScale > scrollView.minimumZoomScale + 0.0001 else {
            reportStackZoomDisplay(scrollView.minimumZoomScale)
            return
        }
        stackResetInProgress = true
        resetStackZoomAnimated()
    }

    private func refreshStackSelectionRecognizersIfNeeded(
        zoomed: Bool,
        force: Bool = false
    ) {
        guard zoomPrototype == .stack else { return }
        guard force || stackMenuSuppressionState != zoomed else { return }
        stackMenuSuppressionState = zoomed
        diagnostics.refreshStackSelectionRecognizers(
            stackDoubleTap: stackDoubleTapReset,
            linkedRecognizers: linkedStackSelectionRecognizers,
            zoomed: zoomed
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didRestoreInitialPosition, !pageIDs.isEmpty else { return }
        view.layoutIfNeeded()
        scrollToPage(index: restorePageIndex, animated: false)
        didRestoreInitialPosition = true
        reportCurrentPage(force: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        logControllerSummary()
    }

    func updateContent(_ content: ContinuousNativePageStack) {
        host.rootView = content
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let zoomed = self.scrollView.zoomScale > 1.0001
            self.refreshStackSelectionRecognizersIfNeeded(
                zoomed: zoomed,
                force: zoomed
            )
        }
    }

    func configure(pageIDs: [UUID],
                   pageHeight: CGFloat,
                   gapPt: CGFloat,
                   restorePageIndex: Int,
                   resetToken: Int,
                   onCurrentPageChange: @escaping (ContinuousNativePageReport) -> Void) {
        self.pageIDs = pageIDs
        self.pageHeight = pageHeight
        self.gapPt = gapPt
        self.restorePageIndex = restorePageIndex
        self.resetToken = resetToken
        self.onCurrentPageChange = onCurrentPageChange
        handleResetTokenIfNeeded()
    }

    func handleScrollTarget(_ target: UUID?, consumed: @escaping () -> Void) {
        guard let target else {
            handledScrollTarget = nil
            return
        }
        guard target != handledScrollTarget,
              let index = pageIDs.firstIndex(of: target) else { return }
        handledScrollTarget = target
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()
            self.scrollToPage(index: index, animated: true)
            consumed()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard didRestoreInitialPosition else { return }
        if zoomPrototype == .stack, scrollView.zoomScale > 1.0001 {
            return
        }
        reportCurrentPage()
    }

    private func reportCurrentPage(force: Bool = false) {
        guard !pageIDs.isEmpty, pageHeight > 0 else { return }
        let viewportCenter = scrollView.contentOffset.y + scrollView.bounds.height / 2
        let stride = pageHeight + gapPt
        let raw = (viewportCenter - gapPt - pageHeight / 2) / stride
        let index: Int
        if zoomPrototype == .stack {
            guard let resolved = resolveStackDisplayedPageIndex(for: raw) else {
                return  // inside the hysteresis dead band: no binding write
            }
            index = resolved
        } else {
            // Preserve the Design A comparison path exactly as tested.
            index = max(0, min(pageIDs.count - 1, Int(raw.rounded())))
        }
        guard force || index != lastReportedIndex else { return }
        lastReportedIndex = index
        let report = ContinuousNativePageReport(
            index: index,
            pageID: pageIDs[index],
            rawIndex: raw,
            contentOffsetY: scrollView.contentOffset.y,
            isDragging: scrollView.isDragging,
            isDecelerating: scrollView.isDecelerating
        )
        // Initial reporting can originate during UIKit layout. Defer the SwiftUI
        // binding write so it never mutates view state inside a representable
        // update/layout pass.
        DispatchQueue.main.async { [weak self] in
            self?.onCurrentPageChange?(report)
        }
    }

    /// Resolve a stack displayed-page transition with deterministic hysteresis.
    /// Returns nil when movement is inside the dead band, which prevents the
    /// SwiftUI displayed-page binding write. Accepted stack transitions still
    /// use the normal pre-B1 `setDesiredActive` path; this prototype must not
    /// keep separate active-canvas promotion state across mode switches.
    /// Repeated threshold checks safely consume a fast multi-page jump.
    private func resolveStackDisplayedPageIndex(for rawIndex: CGFloat) -> Int? {
        let lastIndex = pageIDs.count - 1
        let nearestCandidate = max(0, min(lastIndex, Int(rawIndex.rounded())))

        guard let previous = stackDisplayedPageIndex else {
            stackDisplayedPageIndex = nearestCandidate
            #if DEBUG
            stackHysteresisAcceptedTotal += 1
            print("[CONT-HYST] raw=\(String(format: "%.3f", rawIndex)) previous=nil candidate=\(nearestCandidate) accepted=true displayedChanged=initial")
            #endif
            return nearestCandidate
        }

        let forwardThreshold = CGFloat(previous) + 0.5 + stackPageHysteresis
        let backwardThreshold = CGFloat(previous) - 0.5 - stackPageHysteresis
        var acceptedIndex = previous

        while acceptedIndex < lastIndex,
              rawIndex >= CGFloat(acceptedIndex) + 0.5 + stackPageHysteresis {
            acceptedIndex += 1
        }
        while acceptedIndex > 0,
              rawIndex <= CGFloat(acceptedIndex) - 0.5 - stackPageHysteresis {
            acceptedIndex -= 1
        }

        if acceptedIndex != previous {
            stackDisplayedPageIndex = acceptedIndex
            #if DEBUG
            stackHysteresisAcceptedTotal += 1
            if stackHysteresisSuppressedSinceAccepted > 0 {
                print("[CONT-HYST-SUMMARY] suppressed=\(stackHysteresisSuppressedSinceAccepted) accepted=1 previous=\(previous) next=\(acceptedIndex) raw=\(String(format: "%.3f", rawIndex))")
                stackHysteresisSuppressedSinceAccepted = 0
            } else if continuousNativeVerboseDiagnostics {
                print("[CONT-HYST] raw=\(String(format: "%.3f", rawIndex)) previous=\(previous) candidate=\(nearestCandidate) forward=\(String(format: "%.3f", forwardThreshold)) backward=\(String(format: "%.3f", backwardThreshold)) accepted=true next=\(acceptedIndex) displayedChanged=true")
            }
            #endif
            return acceptedIndex
        }

        // Log only meaningful suppression: the nearest-page rounding would have
        // changed pages, but hysteresis deliberately retained the previous one.
        if nearestCandidate != previous {
            #if DEBUG
            stackHysteresisSuppressedTotal += 1
            stackHysteresisSuppressedSinceAccepted += 1
            if continuousNativeVerboseDiagnostics {
                print("[CONT-HYST] raw=\(String(format: "%.3f", rawIndex)) previous=\(previous) candidate=\(nearestCandidate) forward=\(String(format: "%.3f", forwardThreshold)) backward=\(String(format: "%.3f", backwardThreshold)) accepted=false suppressed=true displayedChanged=false")
            }
            #endif
        }
        return nil
    }

    private func currentPageIndexForGeometry() -> Int {
        guard !pageIDs.isEmpty, pageHeight > 0 else { return 0 }
        let viewportCenter = scrollView.contentOffset.y + scrollView.bounds.height / 2
        let stride = pageHeight + gapPt
        let raw = (viewportCenter - gapPt - pageHeight / 2) / stride
        return max(0, min(pageIDs.count - 1, Int(raw.rounded())))
    }

    private func shortPageID(_ id: UUID) -> String {
        String(id.uuidString.prefix(4))
    }

    private func logControllerSummary() {
        #if DEBUG
        guard zoomPrototype == .stack else { return }
        print("[CONT-HYST-SUMMARY] suppressedTotal=\(stackHysteresisSuppressedTotal) acceptedTotal=\(stackHysteresisAcceptedTotal)")
        #endif
    }

    private func scrollToPage(index: Int, animated: Bool) {
        guard !pageIDs.isEmpty, pageHeight > 0 else { return }
        let safeIndex = max(0, min(pageIDs.count - 1, index))
        let pageCenter = gapPt + CGFloat(safeIndex) * (pageHeight + gapPt)
            + pageHeight / 2
        let proposedY = pageCenter - scrollView.bounds.height / 2
        let maximumY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let targetY = proposedY.clamped(to: 0...maximumY)
        scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: animated)
    }
}
