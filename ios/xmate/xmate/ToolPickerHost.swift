// C-029 ToolPickerHost
//
// App-wide PKToolPicker singleton. As of the object-lifecycle rework it is a
// THIN owner of the single picker — it no longer tracks first responder or
// guesses who to re-anchor to. The authoritative "which canvas is editing
// which page" decision lives entirely in C-030 DrawingSessionManager, which
// drives this host through `setActiveCanvas(_:)`.
//
// Why the split:
//   • Previously this host kept a set of registered canvases plus a single
//     `anchor`, and on anchor loss looped the set picking the first canvas
//     that accepted becomeFirstResponder. With a hidden Continuous canvas and
//     a Zoom-overlay canvas both registered, that loop could (and did) bind
//     the picker to an invisible canvas — the toolbar "jumped".
//   • Now the picker is only ever made visible for the canvas the session
//     manager has explicitly designated active and visible. Invisible /
//     inactive canvases are never chosen.
//
// ContinuousPagesView still uses a plain VStack (not LazyVStack) so all page
// canvases stay window-attached; that remains a deliberate choice so the
// picker's PKToolPicker observers are never torn off the window underneath us.
//
// Thread safety: all methods must be called on the main thread.

import UIKit
import PencilKit

// MARK: - XmateCanvasView

/// PKCanvasView subclass used by all PencilKitBridge instances.
///
/// Carries its identity (`pageID`, `role`) so C-030 DrawingSessionManager can
/// reason about it without a side table keyed on the UIView, and overrides the
/// first-responder transitions to notify the session manager — the only
/// reliable way to know which of several simultaneously visible canvases the
/// Pencil is currently focused on.
final class XmateCanvasView: PKCanvasView {

    /// The Page this canvas edits. Set once in PencilKitBridge.makeUIView.
    /// Implicitly-unwrapped because every canvas is created for a concrete
    /// page; reading it before assignment is a programmer error.
    var pageID: UUID!

    /// Whether this canvas lives in the Single, Continuous, or (legacy) Overlay
    /// slot. Used by the session manager for diagnostics and policy.
    var role: CanvasRole = .single

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            DrawingSessionManager.shared.canvasBecameFirstResponder(self)
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            DrawingSessionManager.shared.canvasResignedFirstResponder(self)
        }
        return resigned
    }
}

// MARK: - ToolPickerHost

/// C-029 ToolPickerHost — owns the single app-wide PKToolPicker.
///
/// Singleton. All methods are main-thread only. Has no opinion about which
/// canvas is active; it merely reflects the session manager's decisions.
final class ToolPickerHost {
    static let shared = ToolPickerHost()
    private init() {}

    /// The one PKToolPicker for the entire app. PencilKitBridge never
    /// creates its own instance.
    let picker = PKToolPicker()

    /// Start observing a canvas so the picker can show its tools when this
    /// canvas (later) becomes the active first responder. Does NOT make the
    /// picker visible — that only happens via `setActiveCanvas`.
    func register(_ canvas: XmateCanvasView) {
        picker.addObserver(canvas)
    }

    /// Stop observing a canvas. Called from DrawingSessionManager.unregister.
    func unregister(_ canvas: XmateCanvasView) {
        picker.removeObserver(canvas)
    }

    /// Bind the picker to the one canvas the session manager has designated
    /// active. This is the ONLY place the picker is made visible, so it can
    /// never end up anchored to a hidden or inactive canvas.
    func setActiveCanvas(_ canvas: XmateCanvasView) {
        picker.setVisible(true, forFirstResponder: canvas)
    }
}
