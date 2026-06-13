// ToolPickerHost
//
// App-wide PKToolPicker singleton. As of the object-lifecycle rework it is a
// THIN owner of the single picker — it no longer tracks first responder or
// guesses who to re-anchor to. The authoritative "which canvas is editing
// which page" decision lives entirely in DrawingSessionManager, which
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
/// Carries its identity (`pageID`, `role`) so DrawingSessionManager can
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

/// ToolPickerHost — owns the single app-wide PKToolPicker.
///
/// Singleton. All methods are main-thread only. Has no opinion about which
/// canvas is active; it merely reflects the session manager's decisions.
///
/// EXPLICIT TOOL PUSH — why this host is itself a PKToolPickerObserver:
///
///   PKCanvasView adopts the picker's selected tool through PencilKit's
///   implicit observer/first-responder delivery. That delivery proved
///   unreliable under Single Page's flip + zoom churn: a pinch makes
///   PencilKit resign the canvas's first responder, our recovery re-promotes
///   it asynchronously, and a tool change landing inside that window can be
///   missed by the canvas the user is writing on. Symptom on device: color
///   changes silently ignored (the canvas keeps drawing with its stale
///   `tool`) while the picker UI shows the new selection — writing itself
///   never needs first responder, so nothing else looks wrong.
///
///   The fix makes tool state CONVERGENT instead of delivery-dependent:
///   1. this host observes the picker and pushes every selected-tool change
///      explicitly into ALL registered canvases' `tool`;
///   2. `register` and `setActiveCanvas` stamp the canvas with the picker's
///      current tool, so a canvas that missed notifications (or was just
///      created) adopts the current selection at the next handoff.
///   Assigning `tool` is idempotent, so double delivery (implicit + push)
///   is harmless.
///
/// NSObject subclass because PKToolPickerObserver is an @objc protocol.
final class ToolPickerHost: NSObject, PKToolPickerObserver {
    static let shared = ToolPickerHost()

    /// The one PKToolPicker for the entire app. PencilKitBridge never
    /// creates its own instance.
    let picker = PKToolPicker()

    /// All registered canvases (weak). Target set for the explicit tool push.
    private let canvases = NSHashTable<XmateCanvasView>.weakObjects()

    private override init() {
        super.init()
        picker.addObserver(self)
    }

    /// Start observing a canvas so the picker can show its tools when this
    /// canvas (later) becomes the active first responder. Does NOT make the
    /// picker visible — that only happens via `setActiveCanvas`. Stamps the
    /// canvas with the picker's current tool so it never starts stale.
    func register(_ canvas: XmateCanvasView) {
        picker.addObserver(canvas)
        canvases.add(canvas)
        canvas.tool = picker.selectedTool
    }

    /// Stop observing a canvas. Called from DrawingSessionManager.unregister.
    func unregister(_ canvas: XmateCanvasView) {
        picker.removeObserver(canvas)
        canvases.remove(canvas)
    }

    /// Bind the picker to the one canvas the session manager has designated
    /// active. This is the ONLY place the picker is made visible, so it can
    /// never end up anchored to a hidden or inactive canvas. Re-stamps the
    /// canvas with the current tool — the convergence point that heals any
    /// notification missed during first-responder churn.
    func setActiveCanvas(_ canvas: XmateCanvasView) {
        canvas.tool = picker.selectedTool
        // TEMP DIAGNOSTIC [TP] — is the canvas already first responder when we
        // call setVisible? If not (and makeActive's becomeFirstResponder then
        // succeeds), the picker may fail to present on the FIRST binding.
        tpLog("setVisible(true) page=\(canvas.pageID?.uuidString.prefix(4) ?? "----") isFR(before)=\(canvas.isFirstResponder)")
        picker.setVisible(true, forFirstResponder: canvas)
    }

    // MARK: PKToolPickerObserver — explicit tool push

    /// Push every selected-tool change to all live canvases, regardless of
    /// first-responder state. This is what makes a color change reach the
    /// canvas being written on even mid resign/become churn.
    func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        let tool = toolPicker.selectedTool
        for canvas in canvases.allObjects {
            canvas.tool = tool
        }
    }
}
