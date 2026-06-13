// DrawingSessionManager
//
// The single arbiter of canvas editing identity. Enforces the core invariant
// of the object-lifecycle design:
//
//     A Page is canonical data; XmateCanvasView / PKCanvasView is an editor.
//     At any moment a given Page has at most ONE authoritative editing canvas
//     (its "active" canvas). Only the active canvas may save. Any number of
//     views may DISPLAY a Page, but an inactive canvas can neither write to
//     Core Data, nor hold the ToolPicker, nor (once made inactive) clobber
//     newer handwriting.
//
// Responsibilities
// ────────────────
//   • Registry of every live canvas (weak), keyed by ObjectIdentifier, with
//     its pageID, role, visibility and active flag, plus an in-memory monotonic
//     `version` stamp mirrored to NoteStore.
//   • Save gating: Coordinator forwards every drawing change here; only the
//     active canvas's change schedules a (debounced) write. Inactive canvases
//     are silently dropped.
//   • Explicit handoff (`makeActive`): flush the previous active canvas of the
//     SAME page synchronously, reload this canvas from the canonical store,
//     mark it active, take first responder, and bind the ToolPicker — in that
//     order, so no stale drawing is ever read or written.
//   • Bootstrap: views declare their intended active page via
//     `setDesiredActive(pageID:)`; whichever matching canvas registers first
//     is promoted. This decouples activation from SwiftUI's async view
//     creation order.
//
// Save path: Coordinator → DrawingSessionManager → NoteStore.
// No Coordinator ever talks to NoteStore directly.
//
// Threading: main-thread only (like ToolPickerHost). Every entry point
// runs on the main thread — SwiftUI callbacks, UIView first-responder
// transitions, and the willResignActive observer (queued on .main). Disk I/O is
// delegated to NoteStore which hops to a background context.

import UIKit
import PencilKit

// ───────────────────────────────────────────────────────────────────────────
// TEMP DIAGNOSTIC — ToolPicker-missing-on-first-page-at-launch bug.
// Remove after the device-log run: grep "[TP]" to find every line to delete
// (this helper + its call sites here and in ToolPickerHost.swift).
// Each line prints a monotonic timestamp and the current applicationState, so
// the cold-launch log and the page-turn log can be compared event-by-event.
func tpLog(_ msg: @autoclosure () -> String) {
    let t = String(format: "%9.3f", ProcessInfo.processInfo.systemUptime)
    let state: String
    switch UIApplication.shared.applicationState {
    case .active:     state = "active"
    case .inactive:   state = "inactive"
    case .background: state = "background"
    @unknown default: state = "?"
    }
    print("[TP] \(t) app=\(state) \(msg())")
}
// ───────────────────────────────────────────────────────────────────────────

// MARK: - CanvasRole

/// Which structural slot a canvas occupies. Distinct PKDrawing writers for the
/// same page must never coexist; role makes the (rare, legacy) overlay case
/// explicit and greppable.
enum CanvasRole {
    case single
    case continuous
    case overlay
}

// MARK: - CanvasReg

/// Per-canvas registration record. A class (not a struct) so the weak canvas
/// reference and the mutable flags/work-item live in one shared box.
private final class CanvasReg {
    weak var canvas: XmateCanvasView?
    let pageID: UUID
    let role: CanvasRole
    var isVisible: Bool
    var isActive: Bool = false
    /// In-memory mirror of the page's persisted `version`. Incremented locally
    /// on every issued write; seeded from the store on register / reload.
    var version: Int64 = 0
    /// Pending debounced save for this canvas.
    var saveWork: DispatchWorkItem?

    init(canvas: XmateCanvasView, pageID: UUID, role: CanvasRole, isVisible: Bool) {
        self.canvas = canvas
        self.pageID = pageID
        self.role = role
        self.isVisible = isVisible
    }
}

// MARK: - DrawingSessionManager

final class DrawingSessionManager {
    static let shared = DrawingSessionManager()

    /// All live canvases, keyed by identity.
    private var regs: [ObjectIdentifier: CanvasReg] = [:]
    /// The authoritative editor per page (at most one).
    private var activeByPage: [UUID: ObjectIdentifier] = [:]
    /// The canvas currently bound to the ToolPicker / holding focus.
    private weak var anchor: XmateCanvasView?
    /// The page + role a view wants edited; used to bootstrap activation across
    /// SwiftUI's async canvas creation. Keyed on BOTH so a mode switch can
    /// promote the incoming (e.g. continuous) canvas even while the outgoing
    /// (e.g. single) canvas is still the active editor of the same page.
    private var desiredActivePageID: UUID?
    private var desiredActiveRole: CanvasRole?

    /// Debounce window for drawing-change saves (matches the previous
    /// Coordinator value).
    private let saveDebounce: TimeInterval = 0.25

    private init() {
        // Force-flush every active canvas when the app is about to suspend so
        // no strokes are lost on home-out / OS suspension.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushAllActive()
        }

        // TEMP DIAGNOSTIC [TP] — log the launch/foreground active edge to see
        // whether it fires before or after register / setDesiredActive.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            tpLog("didBecomeActive desiredPage=\(self?.desiredActivePageID?.uuidString.prefix(4) ?? "nil") anchorSet=\(self?.anchor != nil)")
        }
    }

    // MARK: - Registration

    /// Register a freshly window-attached canvas. Idempotent. Seeds the version
    /// stamp from the store and, if this canvas matches the desired active page
    /// and that page has no active editor yet, promotes it.
    func register(_ canvas: XmateCanvasView, role: CanvasRole, visible: Bool) {
        let id = ObjectIdentifier(canvas)
        tpLog("register page=\(canvas.pageID.uuidString.prefix(4)) role=\(role) visible=\(visible)")  // [TP]
        if regs[id] == nil {
            let reg = CanvasReg(canvas: canvas,
                                pageID: canvas.pageID,
                                role: role,
                                isVisible: visible)
            if let snap = NoteStore.shared.drawing(forPageID: canvas.pageID) {
                reg.version = snap.version
            }
            regs[id] = reg
            ToolPickerHost.shared.register(canvas)
        } else {
            regs[id]?.isVisible = visible
        }

        if let wantPage = desiredActivePageID,
           let wantRole = desiredActiveRole,
           wantPage == canvas.pageID,
           wantRole == canvas.role,
           activeByPage[canvas.pageID] != ObjectIdentifier(canvas) {
            // Promote this freshly-registered canvas even if another canvas
            // (the outgoing mode's, same page) is still active — makeActive
            // flushes and demotes it first.
            tpLog("  register→promote page=\(canvas.pageID.uuidString.prefix(4))")  // [TP]
            makeActive(canvas)
        }
    }

    /// Remove a canvas. If it was active it is flushed synchronously first, so
    /// its strokes are committed before teardown. Never auto-reanchors — the
    /// next active canvas is chosen explicitly by a view via setDesiredActive /
    /// makeActive, or by a Pencil tap.
    func unregister(_ canvas: XmateCanvasView) {
        let id = ObjectIdentifier(canvas)
        guard let reg = regs[id] else {
            ToolPickerHost.shared.unregister(canvas)
            return
        }
        if reg.isActive {
            flush(reg, sync: true)
            reg.isActive = false
        }
        if activeByPage[reg.pageID] == id {
            activeByPage[reg.pageID] = nil
        }
        reg.saveWork?.cancel()
        reg.saveWork = nil
        regs[id] = nil
        ToolPickerHost.shared.unregister(canvas)
        if anchor === canvas { anchor = nil }
    }

    // MARK: - Activation

    /// Declare which page + role should be edited. Called by the pagination
    /// views on appear / page change / mode switch. If a matching canvas is
    /// already registered and visible, it is promoted immediately (makeActive
    /// flushes/demotes any other active canvas of the same page first);
    /// otherwise the next matching `register` does it.
    func setDesiredActive(pageID: UUID, role: CanvasRole) {
        desiredActivePageID = pageID
        desiredActiveRole = role
        tpLog("setDesiredActive page=\(pageID.uuidString.prefix(4)) role=\(role)")  // [TP]
        for reg in regs.values
        where reg.pageID == pageID && reg.role == role && reg.isVisible {
            guard let c = reg.canvas else { continue }
            if activeByPage[pageID] != ObjectIdentifier(c) {
                tpLog("  setDesiredActive→promote page=\(pageID.uuidString.prefix(4))")  // [TP]
                makeActive(c)
            }
            break
        }
    }

    /// Explicit handoff to `canvas`. Order matters:
    ///   1. flush the previous active canvas of the SAME page (sync) so the
    ///      store holds the newest strokes;
    ///   2. reload THIS canvas from the store so it shows those strokes (and
    ///      never a stale makeUIView snapshot);
    ///   3. mark active + bind ToolPicker;
    ///   4. take first responder.
    func makeActive(_ canvas: XmateCanvasView) {
        let id = ObjectIdentifier(canvas)
        guard let reg = regs[id], reg.isVisible else { return }
        let pid = reg.pageID

        // 1. Flush + demote any other active canvas of the same page.
        if let prevID = activeByPage[pid], prevID != id, let prev = regs[prevID] {
            flush(prev, sync: true)
            prev.isActive = false
        }
        activeByPage[pid] = nil

        // 2. Reload from canonical store (post-flush, so it's the latest).
        reload(reg)

        // 3. Mark active + bind picker.
        reg.isActive = true
        activeByPage[pid] = id
        anchor = canvas
        ToolPickerHost.shared.setActiveCanvas(canvas)

        // 4. Take first responder (idempotent w.r.t. the FR override below).
        let became = canvas.becomeFirstResponder()  // [TP]
        tpLog("makeActive page=\(pid.uuidString.prefix(4)) role=\(reg.role) becameFR=\(became) isFR=\(canvas.isFirstResponder) inWindow=\(canvas.window != nil) keyWin=\(canvas.window?.isKeyWindow ?? false)")  // [TP]
    }

    // MARK: - First-responder notifications (from XmateCanvasView)

    /// The user tapped this canvas with the Pencil (or makeActive drove it).
    /// Make it the active editor of its page and bind the picker. For a tap on
    /// a DIFFERENT page than the current active one, that other page keeps its
    /// own active canvas — only the global picker anchor moves here.
    func canvasBecameFirstResponder(_ canvas: XmateCanvasView) {
        tpLog("canvasBecameFR page=\(canvas.pageID.uuidString.prefix(4)) role=\(canvas.role)")  // [TP]
        let id = ObjectIdentifier(canvas)
        guard let reg = regs[id], reg.isVisible else { return }
        if anchor === canvas && reg.isActive { return }   // already current
        let pid = reg.pageID

        if let prevID = activeByPage[pid], prevID != id, let prev = regs[prevID] {
            flush(prev, sync: true)
            prev.isActive = false
        }
        reg.isActive = true
        activeByPage[pid] = id
        anchor = canvas
        ToolPickerHost.shared.setActiveCanvas(canvas)
    }

    /// The canvas lost first responder (window detach, scroll, pinch, or the
    /// OS resigning an off-screen view). We never auto-promote a RANDOM canvas
    /// — that was the toolbar-jump bug the rework removed — but we DO restore
    /// the picker deterministically: re-promote the canvas a view has
    /// explicitly declared via `setDesiredActive` (the current visible page),
    /// which is unique and visible, never a hidden canvas.
    ///
    /// Without this, once the active canvas resigned for any reason the
    /// PKToolPicker had no first responder and stayed gone until the user
    /// tapped with the Pencil. The recovery is async (runs after the resign
    /// settles, so it can't recurse into a resign↔become loop) and bails if
    /// another canvas has meanwhile taken the anchor.
    func canvasResignedFirstResponder(_ canvas: XmateCanvasView) {
        tpLog("canvasResignedFR page=\(canvas.pageID.uuidString.prefix(4)) anchorMatch=\(anchor === canvas)")  // [TP]
        guard anchor === canvas else { return }
        anchor = nil
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Someone already became first responder — nothing to recover.
            guard self.anchor == nil else { return }
            guard let wantPage = self.desiredActivePageID,
                  let wantRole = self.desiredActiveRole else { return }
            for reg in self.regs.values
            where reg.pageID == wantPage && reg.role == wantRole && reg.isVisible {
                guard let c = reg.canvas else { continue }
                self.makeActive(c)
                break
            }
        }
    }

    // MARK: - Save gating

    /// Coordinator forwards every `canvasViewDrawingDidChange` here. Only the
    /// active canvas's change is persisted; inactive canvases are dropped.
    func canvasDrawingChanged(_ canvas: XmateCanvasView) {
        let id = ObjectIdentifier(canvas)
        guard let reg = regs[id], reg.isActive else { return }
        scheduleSave(reg)
    }

    // MARK: - Save internals

    private func scheduleSave(_ reg: CanvasReg) {
        reg.saveWork?.cancel()
        let work = DispatchWorkItem { [weak self, weak reg] in
            guard let self, let reg else { return }
            self.flush(reg, sync: false)
        }
        reg.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounce, execute: work)
    }

    /// Encode and persist a canvas's drawing under a freshly incremented,
    /// monotonic version. `sync` uses NoteStore's blocking path for handoffs /
    /// suspension; otherwise the async debounced path.
    private func flush(_ reg: CanvasReg, sync: Bool) {
        reg.saveWork?.cancel()
        reg.saveWork = nil
        guard let canvas = reg.canvas else { return }
        let data = StrokeSerializer.encode(canvas.drawing)
        reg.version += 1
        let v = reg.version
        if sync {
            NoteStore.shared.savePageDrawingSync(data, pageID: reg.pageID, version: v)
        } else {
            NoteStore.shared.savePageDrawing(data, pageID: reg.pageID, version: v)
        }
    }

    /// Replace a canvas's in-memory drawing with the canonical store value and
    /// re-seed its version. Only called from makeActive — i.e. when this canvas
    /// is being (re)presented for a page, never while the user is mid-stroke on
    /// it, so it cannot wipe unsaved work.
    private func reload(_ reg: CanvasReg) {
        guard let canvas = reg.canvas else { return }
        guard let snap = NoteStore.shared.drawing(forPageID: reg.pageID) else { return }
        if let data = snap.data, let drawing = StrokeSerializer.decode(data) {
            canvas.drawing = drawing
        } else {
            canvas.drawing = PKDrawing()
        }
        reg.version = snap.version
    }

    /// Synchronously flush every active canvas (app suspension).
    private func flushAllActive() {
        for id in activeByPage.values {
            if let reg = regs[id] { flush(reg, sync: true) }
        }
    }
}
