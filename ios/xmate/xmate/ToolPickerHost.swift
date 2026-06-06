// C-029 ToolPickerHost
//
// App-wide PKToolPicker singleton.
//
// ContinuousPagesView uses a plain VStack (not LazyVStack) so all page
// canvases are permanently in the window hierarchy. This is a deliberate
// architectural choice: PKToolPicker associates with specific UIResponder
// instances via addObserver(_:) and setVisible(true, forFirstResponder:).
// LazyVStack recycles canvases out of the hierarchy — iOS resigns first
// responder on window-detach, and no reliable recovery exists on real
// hardware. Plain VStack eliminates the problem at the root.
//
// With multiple live canvases, one shared PKToolPicker is registered with
// all of them. This host:
//   • Tracks which canvas currently holds first responder (anchor).
//   • Prevents every newly-registered canvas from stealing FR from the
//     active anchor during initial layout — PencilKitBridge checks
//     needsFirstResponder before calling becomeFirstResponder.
//   • Re-anchors to another live canvas when the anchor is deleted
//     (page deletion is the only scenario where a canvas leaves the
//     hierarchy in v1). With plain VStack all remaining canvases are
//     window-attached so the first becomeFirstResponder attempt succeeds.
//
// XmateCanvasView overrides becomeFirstResponder / resignFirstResponder
// to notify this host — the only reliable way to track which of several
// simultaneously visible canvases holds Pencil focus.
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

    /// Defers one runloop tick, then tries each window-attached registered
    /// canvas until one accepts becomeFirstResponder.
    ///
    /// Called only when the anchor canvas is deleted. With plain VStack all
    /// remaining canvases are in the window, so the first attempt in the loop
    /// normally succeeds immediately. The one-tick deferral and the
    /// `anchor == nil` guard handle the case where another canvas was already
    /// promoted to FR before this block runs.
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
