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
                onCurrentPageChange: { newIndex in
                    guard newIndex != currentPageIndex else { return }
                    currentPageIndex = newIndex
                },
                onScrollTargetConsumed: onScrollTargetConsumed
            )
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .bottom)
        .onAppear { syncDesiredActive() }
        .onChange(of: currentPageIndex) { _, _ in syncDesiredActive() }
    }

    private func syncDesiredActive() {
        guard currentPageIndex >= 0, currentPageIndex < pages.count,
              let id = pages[currentPageIndex].id else { return }
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
    let onCurrentPageChange: (Int) -> Void
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
            gapPt: gapPt
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

    var body: some View {
        let scaledW = paper.width * fitScale
        let scaledH = paper.height * fitScale

        VStack(spacing: gapPt) {
            ForEach(pages, id: \.id) { page in
                ContinuousNativePageHost(
                    page: page,
                    store: store
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

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        weak var canvas: XmateCanvasView?
        var isRegistered = false
        var didLogReuse = false

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let canvas = canvasView as? XmateCanvasView else { return }
            DrawingSessionManager.shared.canvasDrawingChanged(canvas)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ContinuousNativeInnerScrollView {
        let inner = ContinuousNativeInnerScrollView()
        inner.pageID = page.id
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

        #if DEBUG
        print("[CONT-INNER] host created page=\(shortPageID(page.id)) canvas=recreated")
        #endif

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

        #if DEBUG
        if !context.coordinator.didLogReuse {
            context.coordinator.didLogReuse = true
            print("[CONT-INNER] host update page=\(shortPageID(page.id)) canvas=reused")
        }
        #endif

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

    private func shortPageID(_ id: UUID?) -> String {
        id.map { String($0.uuidString.prefix(4)) } ?? "----"
    }
}

/// Inner page scroll host. At Stage 2 its pan must always fail so the enclosing
/// Continuous scroll view receives normal vertical finger navigation.
private final class ContinuousNativeInnerScrollView: UIScrollView {
    var pageID: UUID?
    weak var pageCanvas: XmateCanvasView?

    override func layoutSubviews() {
        super.layoutSubviews()
        pageCanvas?.frame = bounds
        contentSize = bounds.size
    }

    override func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            #if DEBUG
            let shortID = pageID.map { String($0.uuidString.prefix(4)) } ?? "----"
            print("[CONT-INNER] pan blocked at 100% page=\(shortID)")
            #endif
            return false
        }
        if gestureRecognizer === pinchGestureRecognizer {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
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
    private var onCurrentPageChange: ((Int) -> Void)?

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
                   onCurrentPageChange: @escaping (Int) -> Void) {
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
        // Initial reporting can originate during UIKit layout. Defer the SwiftUI
        // binding write so it never mutates view state inside a representable
        // update/layout pass.
        DispatchQueue.main.async { [weak self] in
            self?.onCurrentPageChange?(index)
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
