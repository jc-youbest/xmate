import Testing
@testable import xmate

struct EditorWorkspaceLayoutTests {
    @Test func compactFullScreenWidthProtectsFiveHundredPointEditor() {
        let sidebarWidth = EditorWorkspaceLayout.sidebarWidth(
            availableWidth: 768
        )

        #expect(sidebarWidth == 268)
        #expect(768 - sidebarWidth == 500)
    }

    @Test func regularWidthCapsMailboxSidebar() {
        let sidebarWidth = EditorWorkspaceLayout.sidebarWidth(
            availableWidth: 1_024
        )

        #expect(sidebarWidth == 320)
        #expect(1_024 - sidebarWidth == 704)
    }

    @Test func narrowerWidthProtectsEditorBeforeSidebarWidth() {
        let sidebarWidth = EditorWorkspaceLayout.sidebarWidth(
            availableWidth: 600
        )

        #expect(sidebarWidth == 100)
        #expect(600 - sidebarWidth == 500)
    }
}

struct EditorInteractionModeTests {
    @Test func writingAllowsPencilAndFingerNavigation() {
        let policy = EditorInteractionMode.writing.policy

        #expect(policy.pencilWrites)
        #expect(policy.fingersNavigate)
    }

    @Test func readOnlyKeepsNavigationWithoutPencilWriting() {
        let policy = EditorInteractionMode.readOnly.policy

        #expect(!policy.pencilWrites)
        #expect(policy.fingersNavigate)
    }

    @Test func workspaceSuspensionRejectsAllEditorInteraction() {
        let policy = EditorInteractionMode.workspaceSuspended.policy

        #expect(!policy.pencilWrites)
        #expect(!policy.fingersNavigate)
    }

    @Test func mailboxPresentationSuspendsEditorAndShowsSidebar() {
        let presentation = EditorWorkspacePresentation.mailboxBrowsing

        #expect(presentation.accessory == .mailboxSidebar)
        #expect(presentation.editorInteractionMode == .workspaceSuspended)
    }
}
