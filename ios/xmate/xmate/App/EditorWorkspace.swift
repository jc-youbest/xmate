import SwiftUI

enum EditorWorkspaceLayout {
    static func sidebarWidth(availableWidth: CGFloat) -> CGFloat {
        max(0, min(320, availableWidth - 500))
    }
}

/// App-owned composition of sibling Library and Editor components. Both child
/// positions stay structurally stable so opening the sidebar changes only
/// assigned width and never replaces the current WritingScreen by itself.
struct EditorWorkspace: View {
    let destination: ResolvedEditorDestination
    let accessory: EditorWorkspaceAccessory?
    let repository: LocalMailboxRepository
    let onEditorOutput: (EditorOutputIntent) -> Void
    let onMailboxOutput: (MailboxSidebarOutputIntent) -> Void

    private var isMailboxPresented: Bool {
        accessory == .mailboxSidebar
    }

    private var selectedEnvelopeID: UUID? {
        guard case .mailboxEnvelope(let id, _) = destination.route.source else {
            return nil
        }
        return id
    }

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = EditorWorkspaceLayout.sidebarWidth(
                availableWidth: geometry.size.width
            )

            HStack(spacing: 0) {
                mailboxSidebar(width: sidebarWidth)

                Divider()
                    .frame(width: isMailboxPresented ? 1 : 0)
                    .opacity(isMailboxPresented ? 1 : 0)

                WritingScreen(
                    document: destination.document,
                    onOutput: onEditorOutput
                )
                .id(destination.document.objectID)
                .allowsHitTesting(!isMailboxPresented)
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private func mailboxSidebar(width: CGFloat) -> some View {
        if isMailboxPresented {
            MailboxSidebarView(
                repository: repository,
                selectedEnvelopeID: selectedEnvelopeID,
                onOutput: onMailboxOutput
            )
            .frame(width: width)
            .clipped()
        } else {
            Color.clear
                .frame(width: 0)
                .accessibilityHidden(true)
        }
    }
}
