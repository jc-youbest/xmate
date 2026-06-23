// ContinuousNativePagesView — feature-flagged native Continuous prototype
//
// Stage 2: feature-flag routing plus 100% layout/scroll parity, now with one
// persistent inner UIScrollView host and one persistent XmateCanvasView per
// page. Inner hosts are locked to zoomScale 1.0 and reject their pan gesture,
// so the outer native UIScrollView remains the sole finger-scroll owner. There
// is deliberately no native pinch zoom or zoomed one-finger pan yet; legacy
// "SwiftUI transform reset; no native zoom" tracing remains expected until
// Stage 3 adds native zoom.

import SwiftUI
import UIKit
import PencilKit

struct ContinuousNativePagesView: View {
    let pages: [Page]
    let paper: PaperSize
    let store: NoteStore

    @Binding var currentPageIndex: Int

    let scrollTarget: UUID?
    let onScrollTargetConsumed: () -> Void
    let restorePageIndex: Int

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
                diagnostics: diagnostics,
                onCurrentPageChange: { report in
                    diagnostics.recordPageReport(report)
                    guard report.index != currentPageIndex else { return }
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
        .onDisappear { diagnostics.logSummary() }
    }

    private func syncDesiredActive(reason: String) {
        guard currentPageIndex >= 0, currentPageIndex < pages.count,
              let id = pages[currentPageIndex].id else { return }
        diagnostics.logActiveRequest(index: currentPageIndex,
                                     pageID: id,
                                     reason: reason)
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
    let diagnostics: ContinuousNativeSessionDiagnostics
    let onCurrentPageChange: (ContinuousNativePageReport) -> Void
    let onScrollTargetConsumed: () -> Void

    func makeUIViewController(context: Context) -> ContinuousNativeScrollController {
        let content = makeContent()
        let controller = ContinuousNativeScrollController(content: content)
        controller.configure(
            pageIDs: pages.compactMap(\.id),
            pageHeight: paper.height * fitScale,
            gapPt: gapPt,
            restorePageIndex: restorePageIndex,
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
    let diagnostics: ContinuousNativeSessionDiagnostics

    var body: some View {
        let scaledW = paper.width * fitScale
        let scaledH = paper.height * fitScale

        VStack(spacing: gapPt) {
            ForEach(pages, id: \.id) { page in
                ContinuousNativePageHost(
                    page: page,
                    store: store,
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

// MARK: - Persistent inner page host (Stage 2, zoom locked at 1.0)

/// One stable native host per page ID. SwiftUI's surrounding `ForEach` is keyed
/// by Page.id, so normal outer scrolling does not recreate this scroll view or
/// its single canvas.
private struct ContinuousNativePageHost: UIViewRepresentable {
    let page: Page
    let store: NoteStore
    let diagnostics: ContinuousNativeSessionDiagnostics

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        weak var canvas: XmateCanvasView?
        var isRegistered = false

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let canvas = canvasView as? XmateCanvasView else { return }
            DrawingSessionManager.shared.canvasDrawingChanged(canvas)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ContinuousNativeInnerScrollView {
        let inner = ContinuousNativeInnerScrollView()
        inner.pageID = page.id
        inner.diagnostics = diagnostics
        inner.minimumZoomScale = 1.0
        inner.maximumZoomScale = 1.0
        inner.zoomScale = 1.0
        inner.bounces = false
        inner.bouncesZoom = false
        inner.showsVerticalScrollIndicator = false
        inner.showsHorizontalScrollIndicator = false
        inner.contentInsetAdjustmentBehavior = .never
        inner.backgroundColor = .white
        // Pinch is intentionally unavailable until Stage 3. The pan recognizer
        // stays present only so the host can explicitly reject and trace any
        // attempt to steal the outer scroll's 100% finger gesture.
        inner.pinchGestureRecognizer?.isEnabled = false
        inner.panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue)
        ]

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

        inner.addSubview(canvas)
        inner.pageCanvas = canvas
        context.coordinator.canvas = canvas

        diagnostics.hostCreated(pageID: page.id, canvas: canvas)

        return inner
    }

    func updateUIView(_ inner: ContinuousNativeInnerScrollView,
                      context: Context) {
        guard let canvas = context.coordinator.canvas else { return }

        // The logical page remains 1:1 inside its host. The surrounding SwiftUI
        // stack applies only the fit-scale visual transform used in Stage 0/1.
        canvas.frame = inner.bounds
        inner.contentSize = inner.bounds.size
        inner.minimumZoomScale = 1.0
        inner.maximumZoomScale = 1.0
        if inner.zoomScale != 1.0 { inner.zoomScale = 1.0 }
        inner.pinchGestureRecognizer?.isEnabled = false

        canvas.drawingPolicy = .pencilOnly
        canvas.isScrollEnabled = false
        canvas.pageID = page.id
        canvas.role = .continuous
        inner.pageID = page.id
        inner.diagnostics = diagnostics

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
        if coordinator.isRegistered, let canvas = coordinator.canvas {
            DrawingSessionManager.shared.unregister(canvas)
            coordinator.isRegistered = false
        }
    }

}

/// Inner page scroll host. At Stage 2 its pan must always fail so the enclosing
/// Continuous scroll view receives normal vertical finger navigation.
private final class ContinuousNativeInnerScrollView: UIScrollView {
    var pageID: UUID?
    weak var pageCanvas: XmateCanvasView?
    weak var diagnostics: ContinuousNativeSessionDiagnostics?

    override func layoutSubviews() {
        super.layoutSubviews()
        pageCanvas?.frame = bounds
        contentSize = bounds.size
    }

    override func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            diagnostics?.innerPanAttempt(pageID: pageID,
                                         zoomScale: zoomScale,
                                         allowed: false)
            return false
        }
        if gestureRecognizer === pinchGestureRecognizer {
            return false
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

    #if DEBUG
    private var createdByPage: [UUID: Int] = [:]
    private var reusedByPage: [UUID: Int] = [:]
    private var panAttemptsByPage: [UUID: Int] = [:]
    private var lastReportedIndex: Int?
    private var lastTransition: (from: Int, to: Int, time: TimeInterval)?
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

    func recordPageReport(_ report: ContinuousNativePageReport) {
        #if DEBUG
        guard let from = lastReportedIndex else {
            lastReportedIndex = report.index
            latestActiveContext = "initial geometry"
            return
        }
        guard from != report.index else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let oscillating: Bool
        if let lastTransition {
            oscillating = lastTransition.from == report.index
                && lastTransition.to == from
                && now - lastTransition.time < 0.75
        } else {
            oscillating = false
        }
        let phase = report.isDragging ? "drag"
            : (report.isDecelerating ? "deceleration" : "programmatic/layout")
        latestActiveContext = oscillating ? "boundary oscillation" : "normal page crossing"
        print("[CONT-ACTIVE] \(from)->\(report.index) page=\(shortID(report.pageID)) raw=\(String(format: "%.3f", report.rawIndex)) offsetY=\(Int(report.contentOffsetY)) phase=\(phase) oscillation=\(oscillating)")
        lastTransition = (from, report.index, now)
        lastReportedIndex = report.index
        #endif
    }

    func logActiveRequest(index: Int, pageID: UUID, reason: String) {
        #if DEBUG
        print("[CONT-ACTIVE] setDesiredActive index=\(index) page=\(shortID(pageID)) reason=\(reason)")
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
        #endif
    }

    #if DEBUG
    private func shortID(_ id: UUID) -> String {
        String(id.uuidString.prefix(4))
    }
    #endif
}

// MARK: - UIKit owner

private final class ContinuousNativeScrollController: UIViewController,
                                                      UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let host: UIHostingController<ContinuousNativePageStack>

    private var pageIDs: [UUID] = []
    private var pageHeight: CGFloat = 0
    private var gapPt: CGFloat = 0
    private var restorePageIndex: Int = 0
    private var onCurrentPageChange: ((ContinuousNativePageReport) -> Void)?

    private var didRestoreInitialPosition = false
    private var lastReportedIndex: Int?
    private var handledScrollTarget: UUID?

    init(content: ContinuousNativePageStack) {
        host = UIHostingController(rootView: content)
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
        // The outer Continuous scroll is navigation-only. Apple Pencil touches
        // must pass through to the persistent PKCanvasViews unchanged.
        scrollView.panGestureRecognizer.allowedTouchTypes = [
            NSNumber(value: UITouch.TouchType.direct.rawValue)
        ]

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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didRestoreInitialPosition, !pageIDs.isEmpty else { return }
        view.layoutIfNeeded()
        scrollToPage(index: restorePageIndex, animated: false)
        didRestoreInitialPosition = true
        reportCurrentPage(force: true)
    }

    func updateContent(_ content: ContinuousNativePageStack) {
        host.rootView = content
    }

    func configure(pageIDs: [UUID],
                   pageHeight: CGFloat,
                   gapPt: CGFloat,
                   restorePageIndex: Int,
                   onCurrentPageChange: @escaping (ContinuousNativePageReport) -> Void) {
        self.pageIDs = pageIDs
        self.pageHeight = pageHeight
        self.gapPt = gapPt
        self.restorePageIndex = restorePageIndex
        self.onCurrentPageChange = onCurrentPageChange
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
        reportCurrentPage()
    }

    private func reportCurrentPage(force: Bool = false) {
        guard !pageIDs.isEmpty, pageHeight > 0 else { return }
        let viewportCenter = scrollView.contentOffset.y + scrollView.bounds.height / 2
        let stride = pageHeight + gapPt
        let raw = (viewportCenter - gapPt - pageHeight / 2) / stride
        let index = max(0, min(pageIDs.count - 1, Int(raw.rounded())))
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
