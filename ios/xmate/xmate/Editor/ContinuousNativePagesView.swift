// ContinuousNativePagesView — feature-flagged native Continuous prototype
//
// Stage 0/1 only: feature-flag routing plus 100% layout/scroll parity. A native
// UIScrollView owns ordinary Continuous scrolling, while the persistent page
// stack continues to use the existing PencilKitBridge / DrawingSessionManager
// path. There is deliberately no native pinch zoom, zoomed pan, or inner page
// UIScrollView yet; legacy "SwiftUI transform reset; no native zoom" tracing is
// expected until Stage 3 adds native zoom.

import SwiftUI
import UIKit

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
                PencilKitBridge(
                    page: page,
                    store: store,
                    role: .continuous,
                    enableSwipeNavigation: false
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
