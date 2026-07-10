// EditorCommand
//
// Lightweight command vocabulary for future editor transactions.
//
// Current stage: these are inert value types. WritingScreen, viewport views,
// PencilKitBridge, DrawingSessionManager, ToolPickerHost, and zoom hosts still
// use their existing direct state paths. A later PageMutationCoordinator can
// interpret these commands to make add/delete/zoom/activation changes explicit
// and ordered.

import Foundation

enum EditorCommand: Hashable {
    case viewport(ViewportCommand)
    case drawing(DrawingCommand)
    case pageMutation(PageMutationCommand)
}

enum ViewportCommand: Hashable {
    /// Programmatically move the viewport to a page.
    case scrollToPage(pageID: UUID, anchor: PageAnchor, animated: Bool)

    /// Reset whichever zoom owner applies to the current presentation style.
    case resetZoom(animated: Bool)

    /// Update displayed/current page identity without implying drawing focus.
    case selectPage(pageID: UUID)

    /// Preserve the visible page anchor across a future page-array mutation.
    case preserveViewportAnchor(pageID: UUID)
}

enum DrawingCommand: Hashable {
    /// Request drawing activation for a page. This describes intent only; it does
    /// not call DrawingSessionManager in this step.
    case activateDrawing(pageID: UUID, reason: DrawingActivationReason)
}

enum PageMutationCommand: Hashable {
    /// Future transaction wrapper for add/delete flows. Not interpreted yet.
    case prepareForMutation(anchorPageID: UUID?)
}

enum DrawingActivationReason: String, Hashable {
    case entry
    case pageSelection
    case scrollSettled
    case modeSwitch
    case mutation
    case recovery
}

