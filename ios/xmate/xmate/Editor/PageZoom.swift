// PageZoomModel
//
// Whole-page zoom state for the Content Screen (F-053), extracted from
// WritingScreen so both Pagination Styles — and any future paper preset —
// consume one zoom implementation. The model owns:
//
//   • userZoom — multiplier on top of fitScale. 1.0 = fit (minimum),
//     capped at 3.0 (300%) per roadmap v1. The HUD shows 100%–300%.
//   • panOffset — page shift while zoomed, clamped by the caller-supplied
//     half-overflow bounds so the page edge never passes the viewport edge.
//   • HUD visibility — a transient centered percentage readout.
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

    /// Whether the percentage HUD (ZoomHUD) is currently shown.
    @Published private(set) var hudVisible: Bool = false

    // MARK: Gesture session bases

    private var gestureBaseZoom: CGFloat = 1.0
    private var gestureBasePan: CGSize = .zero
    private var hudHideWork: DispatchWorkItem?

    // MARK: Derived

    /// True when zoomed past fit — pagination is suspended, panning enabled.
    var isZoomed: Bool { userZoom > 1.0 }

    /// Integer percentage for the HUD and the top-bar reset button.
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
    //
    // Physics (F-059), all constants tunable on device:
    //   • drag — rubber-band past the edge: identity inside the bound, then
    //     diminishing resistance, so the page can be pulled a little past the
    //     edge instead of stopping dead;
    //   • release — project a landing point from the gesture velocity, clamp it
    //     into bounds, and spring there: inertial glide inside the bounds and a
    //     soft bounce back from any overshoot, like Continuous scroll hitting
    //     its end.

    /// Beyond-edge resistance shape.
    private static let overshootResistance: CGFloat = 0.55
    private static let overshootCap: CGFloat = 120        // pt the overshoot asymptotes toward
    /// Release momentum: seconds of projected travel at the release velocity,
    /// and the spring that carries the page to the landing point / back from an
    /// overshoot.
    private static let momentumScale: CGFloat = 0.20 // orignal 0.10: Claude suggests the bigger the scale, smoother
    private static let springResponse: CGFloat = 0.60 // original 0.45
    private static let springDamping: CGFloat = 0.82

    /// `translation` is the total translation since the gesture began;
    /// `halfOverflow` is the per-axis bound (≥ 0) computed by the caller
    /// from the current viewport and paper dimensions.
    func panChanged(translation: CGSize, halfOverflow: CGSize) {
        panOffset = CGSize(
            width: Self.rubberBand(gestureBasePan.width + translation.width,
                                   limit: halfOverflow.width),
            height: Self.rubberBand(gestureBasePan.height + translation.height,
                                    limit: halfOverflow.height)
        )
    }

    /// Called on finger-up with the gesture's release velocity (pt/s).
    func panEnded(velocity: CGSize, halfOverflow: CGSize) {
        let target = CGSize(
            width: (panOffset.width + velocity.width * Self.momentumScale)
                .clamped(to: -halfOverflow.width...halfOverflow.width),
            height: (panOffset.height + velocity.height * Self.momentumScale)
                .clamped(to: -halfOverflow.height...halfOverflow.height)
        )
        gestureBasePan = target
        withAnimation(.spring(response: Self.springResponse,
                              dampingFraction: Self.springDamping)) {
            panOffset = target
        }
    }

    /// Identity inside `[-limit, limit]`, diminishing resistance beyond it.
    private static func rubberBand(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        guard limit >= 0 else { return 0 }
        if value >  limit { return  limit + overshoot(value - limit) }
        if value < -limit { return -limit - overshoot(-value - limit) }
        return value
    }

    private static func overshoot(_ excess: CGFloat) -> CGFloat {
        excess * overshootResistance / (1 + excess / overshootCap)
    }

    // MARK: - Reset (double-tap / top-bar button / page change)

    /// Animated reset to 100% with a one-shot HUD flash — the standard
    /// response to the top-bar reset button and the finger double-tap. Owning
    /// the animation here keeps callers (incl. the pagination views) from
    /// passing a closure, so those views can stay `Equatable` and skip the
    /// per-frame re-render during zoom/pan.
    func resetAnimated() {
        guard isZoomed else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            reset(flashHUD: true)
        }
    }

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

// MARK: - ZoomHUD

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
