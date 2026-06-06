// C-029 ToolPickerHost
//
// App-wide PKToolPicker singleton. Solves the "picker disappears in
// Continuous mode" trap that caused stages 3.5–3.8 to fail.
//
// Root cause of the trap
// ──────────────────────
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
// • Every XmateCanvasView (see below) registers via register(_:) when it
//   enters a window, and deregisters via unregister(_:) from dismantleUIView.
// • register(_:) calls addObserver(_:) + setVisible(true, forFirstResponder:)
//   so the picker follows first responder across all registered canvases.
// • XmateCanvasView overrides becomeFirstResponder / resignFirstResponder
//   to notify canvasBecameFirstResponder / canvasResignedFirstResponder.
// • When the anchor resigns (window detach or otherwise), scheduleReanchor()
//   posts a one-tick async check: if still no anchor, promote any live
//   (window-attached) registered canvas to first responder.
//
// Thread safety: all methods must be called on the main thread. All callers
// (SwiftUI lifecycle, UIKit delegate callbacks) already satisfy this.

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
    /// After calling this, call canvas.becomeFirstResponder() so the picker
    /// becomes visible.
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
    /// by then, promotes the first window-attached registered canvas.
    ///
    /// The one-tick delay handles the ordering trap: iOS resigns FR (step 1)
    /// before dismantleUIView (step 2), and a new canvas registers on its own
    /// async tick (step 3). By the time this async block fires, step 3 may
    /// have already produced a new anchor — the `anchor == nil` guard prevents
    /// a redundant becomeFirstResponder call.
    private func scheduleReanchor() {
        DispatchQueue.main.async { [weak self] in
            guard let self, anchor == nil else { return }
            for canvas in canvases.allObjects where canvas.window != nil {
                _ = canvas.becomeFirstResponder()
                return
            }
        }
    }
}
