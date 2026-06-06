// C-029 ToolPickerHost
//
// App-wide PKToolPicker singleton. Solves the "picker disappears in
// Continuous mode" trap that caused stages 3.5–3.8 to fail, plus two
// bugs found in hardware testing:
//
//   Bug A — scheduleReanchor gave up after the first candidate even when
//   becomeFirstResponder returned false, leaving anchor permanently nil.
//   Fix: iterate all window-attached candidates until one succeeds.
//
//   Bug B — every canvas entering the LazyVStack viewport called
//   becomeFirstResponder(), which forced the active anchor to resign FR
//   → canvasResignedFirstResponder → anchor=nil → scheduleReanchor. If
//   the new canvas's own become call then failed for any reason, anchor
//   stayed nil. Fix: in Continuous mode only become FR when no anchor
//   exists. PencilKitBridge checks needsFirstResponder before calling
//   becomeFirstResponder from its deferred-registration block.
//
// Root cause of the original trap
// ──────────────────────────────────
// PKToolPicker only stays visible while a registered canvas is first
// responder. In Continuous mode LazyVStack recycles canvases as the user
// scrolls: iOS auto-resigns first responder on a canvas when it is
// detached from the window, and this fires BEFORE SwiftUI's
// dismantleUIView. Without a host that immediately re-anchors first
// responder to another live canvas, the picker disappears every time the
// "anchor" canvas leaves the screen edge.
//
// Architecture
// ────────────
// • One PKToolPicker for the app lifetime, owned here.
// • Every XmateCanvasView registers via register(_:) when it enters a
//   window, and deregisters via unregister(_:) from dismantleUIView.
// • register(_:) calls addObserver(_:) + setVisible(true, forFirstResponder:)
//   so the picker is primed to show for any registered canvas.
// • PencilKitBridge calls becomeFirstResponder only when needsFirstResponder
//   is true (no anchor), avoiding FR theft in Continuous mode.
// • XmateCanvasView overrides becomeFirstResponder / resignFirstResponder
//   to notify canvasBecameFirstResponder / canvasResignedFirstResponder.
// • When the anchor resigns, scheduleReanchor() tries all window-attached
//   registered canvases in turn until one accepts becomeFirstResponder.
//
// Thread safety: all methods must be called on the main thread.

import UIKit
import PencilKit

// MARK: - XmateCanvasView

/// PKCanvasView subclass used by all PencilKitBridge instances.
///
/// Overrides becomeFirstResponder / resignFirstResponder to notify
/// ToolPickerHost. This is the only reliable way to track which canvas
/// among several simultaneously visible ones holds the Pencil focus.
final class XmateCanvasView: PKCanvasView {

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            ToolPickerHost.shared.canvasBecameFirstResponder(self)
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            ToolPickerHost.shared.canvasResignedFirstResponder(self)
        }
        return resigned
    }
}

// MARK: - ToolPickerHost

/// C-029 ToolPickerHost — owns the single app-wide PKToolPicker.
///
/// Singleton. All methods are main-thread only.
final class ToolPickerHost {
    static let shared = ToolPickerHost()
    private init() {}

    // MARK: - Public surface

    /// The one PKToolPicker for the entire app. PencilKitBridge never
    /// creates its own instance.
    let picker = PKToolPicker()

    /// True when no canvas currently holds first responder in our tracking.
    /// PencilKitBridge reads this before deciding whether to call
    /// becomeFirstResponder after registration — avoids stealing FR in
    /// Continuous mode when a live anchor already exists.
    var needsFirstResponder: Bool { anchor == nil }

    // MARK: - Private state

    /// Weak references to all currently registered canvases. NSHashTable
    /// with .weakObjects() clears entries automatically when a canvas
    /// is deallocated.
    private let canvases = NSHashTable<XmateCanvasView>.weakObjects()

    /// The canvas that currently holds first responder, or nil.
    private weak var anchor: XmateCanvasView?

    // MARK: - Registration

    /// Register a canvas with the picker. Call once from PencilKitBridge's
    /// updateUIView deferred block, after confirming canvas.window != nil.
    ///
    /// After calling this, call canvas.becomeFirstResponder() only if
    /// needsFirstResponder is true — otherwise the canvas is primed to show
    /// the picker when it naturally becomes FR (e.g. Pencil tap) without
    /// stealing FR from the currently active canvas.
    func register(_ canvas: XmateCanvasView) {
        canvases.add(canvas)
        picker.addObserver(canvas)
        picker.setVisible(true, forFirstResponder: canvas)
    }

    /// Deregister a canvas. Call from PencilKitBridge.dismantleUIView.
    ///
    /// Do NOT manually resign first responder before this call — iOS
    /// already resigned it on window detach, which fires before
    /// dismantleUIView. Calling resignFirstResponder() here would be a
    /// no-op at best and a race at worst.
    func unregister(_ canvas: XmateCanvasView) {
        canvases.remove(canvas)
        picker.removeObserver(canvas)
        if anchor === canvas {
            anchor = nil
            scheduleReanchor()
        }
    }

    // MARK: - FR notifications (called by XmateCanvasView)

    /// Called by XmateCanvasView.becomeFirstResponder after super returns true.
    func canvasBecameFirstResponder(_ canvas: XmateCanvasView) {
        anchor = canvas
    }

    /// Called by XmateCanvasView.resignFirstResponder after super returns true.
    func canvasResignedFirstResponder(_ canvas: XmateCanvasView) {
        guard anchor === canvas else { return }
        anchor = nil
        scheduleReanchor()
    }

    // MARK: - Re-anchor

    /// Defers to the next runloop tick: if no canvas has taken first responder
    /// by then, tries each window-attached registered canvas in turn until one
    /// accepts becomeFirstResponder.
    ///
    /// Iterating all candidates (rather than stopping after the first attempt)
    /// handles the case where a canvas is still present in the hash table but
    /// returns false from becomeFirstResponder — e.g. because it's in the
    /// process of being detached. Checking the return value ensures we don't
    /// silently give up on the first failed attempt and leave anchor nil.
    ///
    /// The one-tick delay handles the ordering trap: iOS resigns FR (step 1)
    /// before dismantleUIView (step 2), and a new canvas registers on its own
    /// async tick (step 3). By the time this block fires, a new anchor may
    /// already be set — the `anchor == nil` guard handles that.
    private func scheduleReanchor() {
        DispatchQueue.main.async { [weak self] in
            guard let self, anchor == nil else { return }
            for canvas in canvases.allObjects where canvas.window != nil {
                if canvas.becomeFirstResponder() {
                    return  // success — canvasBecameFirstResponder already set anchor
                }
            }
        }
    }
}
