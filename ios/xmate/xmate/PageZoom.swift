// C-031 PageZoomModel
//
// Whole-page zoom state for the Content Screen (F-053), extracted from
// WritingScreen so both Pagination Styles — and any future paper preset —
// consume one zoom implementation. The model owns:
//
//   • userZoom — multiplier on top of fitScale. 1.0 = fit (minimum),
//     capped at 3.0 (300%) per roadmap v1. The HUD shows 100%–300%.
//   • panOffset — page shift while zoomed, clamped by the caller-supplied
//     half-overflow bounds so the page edge never passes the viewport edge.
//   • HUD visibility — a transient centered percentage readout (U-112).
//     Visible while pinching; hides 1.0 s after the fingers lift. Reset
//     (double-tap / top-bar button) flashes it once so the user sees "100%".
//
// All gesture math that previously lived inline in WritingScreen
// (gestureBaseZoom / gestureBasePan bookkeeping, clamping) lives here.
// The model is paper-agnostic: viewport-dependent bounds are passed in
// per-call, never stored, so it works unchanged for letter, postcard,
// and any future paper size.
//
// Main-thread only, like every UI-facing module in this codebase.

import SwiftUI

// MARK: - PageZoomModel

final class PageZoomModel: ObservableObject {

    /// Fit — the minimum. The user can never zoom below the fitted page.
    static let minZoom: CGFloat = 1.0
    /// 300% cap (roadmap v1: zoom is 1×–3×).
    static let maxZoom: CGFloat = 3.0
    /// HUD lingers this long after the fingers lift, then fades.
    static let hudLinger: TimeInterval = 1.0

    // MARK: Published state

    /// User zoom multiplier on top of fitScale. 1.0 = fit.
    @Published private(set) var userZoom: CGFloat = 1.0

    /// Pan offset of the zoomed page within the viewport. .zero at fit.
    @Published private(set) var panOffset: CGSize = .zero

    /// Whether the percentage HUD (U-112 ZoomHUD) is currently shown.
    @Published private(set) var hudVisible: Bool = false

    // MARK: Gesture session bases

    private var gestureBaseZoom: CGFloat = 1.0
    private var gestureBasePan: CGSize = .zero
    private var hudHideWork: DispatchWorkItem?

    // MARK: Derived

    /// True when zoomed past fit — pagination is suspended, panning enabled.
    var isZoomed: Bool { userZoom > 1.0 }

    /// Integer percentage for the HUD and the top-bar reset button (U-113).
    var percent: Int { Int((userZoom * 100).rounded()) }

    // MARK: - Pinch (MagnificationGesture)

    func pinchChanged(_ value: CGFloat) {
        userZoom = (gestureBaseZoom * value)
            .clamped(to: Self.minZoom...Self.maxZoom)
        if !isZoomed {
            panOffset = .zero
            gestureBasePan = .zero
        }
        showHUD()
    }

    func pinchEnded(_ value: CGFloat) {
        userZoom = (gestureBaseZoom * value)
            .clamped(to: Self.minZoom...Self.maxZoom)
        gestureBaseZoom = userZoom
        if !isZoomed {
            panOffset = .zero
            gestureBasePan = .zero
        }
        scheduleHUDHide()
    }

    // MARK: - Finger pan (forwarded from the canvas recogniser)

    /// `translation` is the total translation since the gesture began;
    /// `halfOverflow` is the per-axis bound (≥ 0) computed by the caller
    /// from the current viewport and paper dimensions.
    func panChanged(translation: CGSize, halfOverflow: CGSize) {
        panOffset = CGSize(
            width: (gestureBasePan.width + translation.width)
                .clamped(to: -halfOverflow.width...halfOverflow.width),
            height: (gestureBasePan.height + translation.height)
                .clamped(to: -halfOverflow.height...halfOverflow.height)
        )
    }

    func panEnded() {
        gestureBasePan = panOffset
    }

    // MARK: - Reset (double-tap / top-bar button / page change)

    /// Back to 100% (fit). `flashHUD: true` shows "100%" briefly as feedback
    /// for an explicit user reset; page-change resets pass false.
    /// Animation is the caller's choice via withAnimation.
    func reset(flashHUD: Bool = false) {
        userZoom = 1.0
        gestureBaseZoom = 1.0
        panOffset = .zero
        gestureBasePan = .zero
        if flashHUD {
            showHUD()
            scheduleHUDHide()
        } else {
            hudHideWork?.cancel()
            hudVisible = false
        }
    }

    // MARK: - HUD scheduling

    private func showHUD() {
        hudHideWork?.cancel()
        hudHideWork = nil
        if !hudVisible {
            withAnimation(.easeIn(duration: 0.1)) { hudVisible = true }
        }
    }

    private func scheduleHUDHide() {
        hudHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.hudVisible = false }
        }
        hudHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hudLinger,
                                      execute: work)
    }
}

// MARK: - U-112 ZoomHUD

/// Transient centered percentage readout shown while pinch-zooming (F-053).
/// Semi-transparent capsule, never intercepts touches. WritingScreen overlays
/// it on the canvas area and drives visibility via PageZoomModel.hudVisible.
struct ZoomHUD: View {
    let percent: Int

    var body: some View {
        Text("\(percent)%")
            .font(.title2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

// MARK: - Comparable clamped helper

extension Comparable {
    /// Returns the value clamped to the closed range [lo, hi].
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
