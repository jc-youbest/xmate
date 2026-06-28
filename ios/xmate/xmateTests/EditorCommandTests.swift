import Foundation
import Testing
@testable import xmate

struct EditorCommandTests {
    @Test func viewportCommandsAreStableValues() {
        let pageID = UUID()
        let command = EditorCommand.viewport(
            .scrollToPage(pageID: pageID, anchor: .centered, animated: true)
        )

        #expect(command == EditorCommand.viewport(
            .scrollToPage(pageID: pageID, anchor: .centered, animated: true)
        ))
        #expect(command.hashValue == EditorCommand.viewport(
            .scrollToPage(pageID: pageID, anchor: .centered, animated: true)
        ).hashValue)
    }

    @Test func drawingActivationCommandCarriesReason() {
        let pageID = UUID()
        let command = DrawingCommand.activateDrawing(
            pageID: pageID,
            reason: .mutation
        )

        #expect(command == .activateDrawing(pageID: pageID, reason: .mutation))
    }
}

