import CoreData
import Foundation
import Testing
@testable import xmate

@MainActor
struct AppFlowCoordinatorTests {
    @Test func validDocumentReachesTypedEditorRouteAfterPolicyApplication() {
        let document = makeUnmanagedDocument()
        let request = DocumentOpenRequest(
            source: .developmentDocument(name: "test-document")
        )
        let editorPolicy = EditorWindowOrientationPolicy(
            preferredInterfaceOrientations: [.landscapeLeft, .landscapeRight],
            debugName: "landscape"
        )
        var appliedPolicies: [ComponentWindowLayoutPolicy] = []

        let coordinator = AppFlowCoordinator(
            validateDocument: { _ in nil },
            resolveEditorPolicy: { _ in editorPolicy },
            applyWindowPolicy: { appliedPolicies.append($0) }
        )

        coordinator.start(request: request) { document }

        guard case .ready(.editor(let destination)) = coordinator.state else {
            Issue.record("Expected a ready destination")
            return
        }

        #expect(destination.document === document)
        #expect(destination.route.source == request.source)
        #expect(destination.route.windowLayoutPolicy == .documentDirected(editorPolicy))
        #expect(appliedPolicies == [.documentDirected(editorPolicy)])
        #expect(coordinator.presentedOpenError == nil)
    }

    @Test func editorSocialReturnRestoresDocumentAndPoliciesInOrder() {
        let document = makeUnmanagedDocument()
        let editorPolicy = EditorWindowOrientationPolicy(
            preferredInterfaceOrientations: [.landscapeLeft, .landscapeRight],
            debugName: "landscape"
        )
        let componentEditorPolicy = ComponentWindowLayoutPolicy.documentDirected(
            editorPolicy
        )
        var appliedPolicies: [ComponentWindowLayoutPolicy] = []
        let coordinator = AppFlowCoordinator(
            validateDocument: { _ in nil },
            resolveEditorPolicy: { _ in editorPolicy },
            applyWindowPolicy: { appliedPolicies.append($0) }
        )

        coordinator.start(
            request: DocumentOpenRequest(
                source: .developmentDocument(name: "return-document")
            )
        ) {
            document
        }
        coordinator.handleEditorOutput(.showSocial)

        guard case .ready(.social(let socialRoute)) = coordinator.state else {
            Issue.record("Expected the Social destination")
            return
        }
        #expect(socialRoute.windowLayoutPolicy == .systemResponsive)

        coordinator.handleSocialOutput(.returnToEditor)

        guard case .ready(.editor(let returnedDestination)) = coordinator.state else {
            Issue.record("Expected the returned Editor destination")
            return
        }
        #expect(returnedDestination.document === document)
        #expect(returnedDestination.route.windowLayoutPolicy == componentEditorPolicy)
        #expect(appliedPolicies == [
            componentEditorPolicy,
            .systemResponsive,
            componentEditorPolicy
        ])
    }

    @Test func componentOutputsAreIgnoredOutsideTheirOwningDestination() {
        let document = makeUnmanagedDocument()
        let editorPolicy = EditorWindowOrientationPolicy(
            preferredInterfaceOrientations: [.portrait, .portraitUpsideDown],
            debugName: "portrait"
        )
        var appliedPolicyCount = 0
        let coordinator = AppFlowCoordinator(
            validateDocument: { _ in nil },
            resolveEditorPolicy: { _ in editorPolicy },
            applyWindowPolicy: { _ in appliedPolicyCount += 1 }
        )

        coordinator.start(
            request: DocumentOpenRequest(
                source: .developmentDocument(name: "guard-document")
            )
        ) {
            document
        }
        coordinator.handleSocialOutput(.returnToEditor)
        coordinator.handleEditorOutput(.showSocial)
        coordinator.handleEditorOutput(.showSocial)

        #expect(appliedPolicyCount == 2)
        guard case .ready(.social) = coordinator.state else {
            Issue.record("Expected repeated or foreign intents to be ignored")
            return
        }
    }

    @Test func invalidDocumentStopsBeforePolicyResolutionAndEditorPresentation() {
        let document = makeUnmanagedDocument()
        let error = DocumentOpenError(
            code: .invalidDocumentPreset,
            message: "Invalid document preset."
        )
        var editorPolicyResolutionCount = 0
        var appliedPolicyCount = 0

        let coordinator = AppFlowCoordinator(
            validateDocument: { _ in error },
            resolveEditorPolicy: { _ in
                editorPolicyResolutionCount += 1
                return EditorWindowOrientationPolicy(
                    preferredInterfaceOrientations: .all,
                    debugName: "unused"
                )
            },
            applyWindowPolicy: { _ in appliedPolicyCount += 1 }
        )

        coordinator.start(
            request: DocumentOpenRequest(
                source: .developmentDocument(name: "invalid-document")
            )
        ) {
            document
        }

        guard case .failed(let stateError) = coordinator.state else {
            Issue.record("Expected a failed state")
            return
        }

        #expect(stateError == error)
        #expect(coordinator.presentedOpenError == error)
        #expect(editorPolicyResolutionCount == 0)
        #expect(appliedPolicyCount == 0)
    }

    @Test func startResolvesInitialRouteOnlyOnce() {
        let document = makeUnmanagedDocument()
        var resolutionCount = 0
        let coordinator = AppFlowCoordinator(
            validateDocument: { _ in nil },
            resolveEditorPolicy: { _ in
                EditorWindowOrientationPolicy(
                    preferredInterfaceOrientations: [.portrait, .portraitUpsideDown],
                    debugName: "portrait"
                )
            },
            applyWindowPolicy: { _ in }
        )
        let request = DocumentOpenRequest(
            source: .developmentDocument(name: "test-document")
        )

        coordinator.start(request: request) {
            resolutionCount += 1
            return document
        }
        coordinator.start(request: request) {
            resolutionCount += 1
            return document
        }

        #expect(resolutionCount == 1)
    }

    @Test func mailboxSelectionCommitsItsWindowPolicyOnlyWhenSidebarCloses() throws {
        let store = makeStore()
        let initialDocument = try makeStoredDocument(
            in: store,
            named: "Initial"
        )
        let selectedDocument = try makeStoredDocument(
            in: store,
            named: "Selected"
        )
        let envelope = try makeEnvelope(for: selectedDocument)
        let initialPolicy = EditorWindowOrientationPolicy(
            preferredInterfaceOrientations: [.portrait, .portraitUpsideDown],
            debugName: "portrait"
        )
        let selectedPolicy = EditorWindowOrientationPolicy(
            preferredInterfaceOrientations: [.landscapeLeft, .landscapeRight],
            debugName: "landscape"
        )
        let initialComponentPolicy = ComponentWindowLayoutPolicy.documentDirected(
            initialPolicy
        )
        let selectedComponentPolicy = ComponentWindowLayoutPolicy.documentDirected(
            selectedPolicy
        )
        var appliedPolicies: [ComponentWindowLayoutPolicy] = []
        let coordinator = AppFlowCoordinator(
            validateDocument: { _ in nil },
            resolveEditorPolicy: { document in
                document === selectedDocument ? selectedPolicy : initialPolicy
            },
            applyWindowPolicy: { appliedPolicies.append($0) }
        )
        coordinator.start(
            request: DocumentOpenRequest(
                source: .developmentDocument(name: "Initial")
            )
        ) {
            initialDocument
        }
        coordinator.handleEditorOutput(.showMailbox)

        #expect(coordinator.editorWorkspaceAccessory == .mailboxSidebar)
        #expect(appliedPolicies == [initialComponentPolicy])

        let outcome = coordinator.selectMailboxEnvelope(
            id: envelope.id,
            resolveEnvelope: { _ in self.hitResolution(envelope) },
            resolveCachedDocument: { try store.document(id: $0) }
        )

        #expect(outcome == .applied)
        guard case .ready(.editor(let destination)) = coordinator.state else {
            Issue.record("Expected the selected Editor destination")
            return
        }
        #expect(destination.document === selectedDocument)
        #expect(destination.route.source == .mailboxEnvelope(
            id: envelope.id,
            location: envelope.mailboxLocation
        ))
        #expect(destination.route.windowLayoutPolicy == initialComponentPolicy)
        #expect(appliedPolicies == [initialComponentPolicy])
        #expect(coordinator.editorWorkspaceAccessory == .mailboxSidebar)

        coordinator.handleMailboxSidebarOutput(.closeSidebar)

        #expect(coordinator.editorWorkspaceAccessory == nil)
        #expect(appliedPolicies == [
            initialComponentPolicy,
            selectedComponentPolicy,
        ])
        guard case .ready(.editor(let committed)) = coordinator.state else {
            Issue.record("Expected the full-screen Editor destination")
            return
        }
        #expect(committed.document === selectedDocument)
        #expect(committed.route.windowLayoutPolicy == selectedComponentPolicy)
    }

    @Test func mailboxCacheMissPreservesCurrentEditorDocument() throws {
        let store = makeStore()
        let currentDocument = try makeStoredDocument(
            in: store,
            named: "Current"
        )
        let envelope = makeEnvelope(
            documentID: UUID(),
            revision: .initial
        )
        let coordinator = makeStartedCoordinator(document: currentDocument)
        coordinator.handleEditorOutput(.showMailbox)
        let missing = MailboxDocumentCacheResolution.missing(
            DocumentCacheRequirement(
                documentID: envelope.documentID,
                revision: envelope.documentRevision
            )
        )

        let outcome = coordinator.selectMailboxEnvelope(
            id: envelope.id,
            resolveEnvelope: { _ in MailboxEnvelopeDocumentResolution(
                envelope: envelope,
                documentCache: missing
            ) },
            resolveCachedDocument: { _ in
                Issue.record("A cache miss must not request a Document")
                return nil
            }
        )

        #expect(outcome == .rejected(.cacheUnavailable(missing)))
        expectEditorDocument(currentDocument, in: coordinator)
    }

    @Test func mailboxSelectionRequiresTheSidebarWorkspace() {
        let document = makeUnmanagedDocument()
        let coordinator = makeStartedCoordinator(document: document)

        let outcome = coordinator.selectMailboxEnvelope(
            id: UUID(),
            resolveEnvelope: { _ in
                Issue.record("Selection must stop before repository lookup")
                return nil
            },
            resolveCachedDocument: { _ in nil }
        )

        #expect(outcome == .rejected(.requiresMailboxSidebar))
        expectEditorDocument(document, in: coordinator)
    }

    @Test func staleMailboxDocumentPreservesCurrentEditorDocument() throws {
        let store = makeStore()
        let currentDocument = try makeStoredDocument(
            in: store,
            named: "Current"
        )
        let envelope = makeEnvelope(
            documentID: UUID(),
            revision: DocumentRevision(rawValue: 2)
        )
        let stale = MailboxDocumentCacheResolution.stale(
            cached: CachedDocumentDescriptor(
                documentID: envelope.documentID,
                revision: DocumentRevision(rawValue: 1)
            ),
            required: DocumentCacheRequirement(
                documentID: envelope.documentID,
                revision: envelope.documentRevision
            )
        )
        let coordinator = makeStartedCoordinator(document: currentDocument)
        coordinator.handleEditorOutput(.showMailbox)

        let outcome = coordinator.selectMailboxEnvelope(
            id: envelope.id,
            resolveEnvelope: { _ in MailboxEnvelopeDocumentResolution(
                envelope: envelope,
                documentCache: stale
            ) },
            resolveCachedDocument: { _ in
                Issue.record("A stale cache must not request a Document")
                return nil
            }
        )

        #expect(outcome == .rejected(.cacheUnavailable(stale)))
        expectEditorDocument(currentDocument, in: coordinator)
    }

    @Test func invalidSelectedDocumentPreservesCurrentEditorDocument() throws {
        let store = makeStore()
        let currentDocument = try makeStoredDocument(
            in: store,
            named: "Current"
        )
        let invalidDocument = try makeStoredDocument(
            in: store,
            named: "Invalid"
        )
        let envelope = try makeEnvelope(for: invalidDocument)
        let validationError = DocumentOpenError(
            code: .invalidDocumentPreset,
            message: "Invalid selected document."
        )
        let coordinator = AppFlowCoordinator(
            validateDocument: { document in
                document === invalidDocument ? validationError : nil
            },
            resolveEditorPolicy: { _ in
                EditorWindowOrientationPolicy(
                    preferredInterfaceOrientations: .all,
                    debugName: "test"
                )
            },
            applyWindowPolicy: { _ in }
        )
        coordinator.start(
            request: DocumentOpenRequest(
                source: .developmentDocument(name: "Current")
            )
        ) {
            currentDocument
        }
        coordinator.handleEditorOutput(.showMailbox)

        let outcome = coordinator.selectMailboxEnvelope(
            id: envelope.id,
            resolveEnvelope: { _ in self.hitResolution(envelope) },
            resolveCachedDocument: { try store.document(id: $0) }
        )

        #expect(outcome == .rejected(.invalidDocument(validationError)))
        expectEditorDocument(currentDocument, in: coordinator)
        #expect(coordinator.editorWorkspaceAccessory == .mailboxSidebar)
    }

    @Test func socialTransitionIsIgnoredWhileMailboxSidebarIsOpen() {
        let document = makeUnmanagedDocument()
        let coordinator = makeStartedCoordinator(document: document)

        coordinator.handleEditorOutput(.showMailbox)
        coordinator.handleEditorOutput(.showSocial)

        #expect(coordinator.editorWorkspaceAccessory == .mailboxSidebar)
        expectEditorDocument(document, in: coordinator)
    }

    @Test func systemResponsivePolicyAcceptsAllSystemOrientations() {
        let policy = ComponentWindowLayoutPolicy.systemResponsive

        #expect(policy.supportedInterfaceOrientations == .all)
        #expect(policy.debugName == "system-responsive")
    }

    private func makeUnmanagedDocument() -> Document {
        let entity = NSEntityDescription()
        entity.name = "Document"
        entity.managedObjectClassName = NSStringFromClass(Document.self)
        return Document(entity: entity, insertInto: nil)
    }

    private func makeStore() -> NoteStore {
        NoteStore(
            storeURL: URL(fileURLWithPath: "/dev/null"),
            storeType: NSInMemoryStoreType
        )
    }

    private func makeStoredDocument(
        in store: NoteStore,
        named name: String
    ) throws -> Document {
        let preset = try #require(PagePresetCatalog.presets.first)
        return store.loadOrCreateDocument(
            named: name,
            pagePreset: preset
        )
    }

    private func makeEnvelope(for document: Document) throws -> LetterEnvelope {
        LetterEnvelope(
            id: UUID(),
            documentID: try #require(document.id),
            title: document.title ?? "",
            senderID: nil,
            recipientID: nil,
            mailboxLocation: .draft,
            deliveryState: .notSubmitted,
            documentRevision: DocumentRevision(
                rawValue: document.contentRevision
            ),
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            sentAt: nil,
            receivedAt: nil
        )
    }

    private func makeEnvelope(
        documentID: UUID,
        revision: DocumentRevision
    ) -> LetterEnvelope {
        LetterEnvelope(
            id: UUID(),
            documentID: documentID,
            title: "Envelope",
            senderID: nil,
            recipientID: nil,
            mailboxLocation: .draft,
            deliveryState: .notSubmitted,
            documentRevision: revision,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            sentAt: nil,
            receivedAt: nil
        )
    }

    private func hitResolution(
        _ envelope: LetterEnvelope
    ) -> MailboxEnvelopeDocumentResolution {
        let descriptor = CachedDocumentDescriptor(
            documentID: envelope.documentID,
            revision: envelope.documentRevision
        )
        return MailboxEnvelopeDocumentResolution(
            envelope: envelope,
            documentCache: .hit(descriptor)
        )
    }

    private func makeStartedCoordinator(
        document: Document
    ) -> AppFlowCoordinator {
        let coordinator = AppFlowCoordinator(
            validateDocument: { _ in nil },
            resolveEditorPolicy: { _ in
                EditorWindowOrientationPolicy(
                    preferredInterfaceOrientations: .all,
                    debugName: "test"
                )
            },
            applyWindowPolicy: { _ in }
        )
        coordinator.start(
            request: DocumentOpenRequest(
                source: .developmentDocument(name: "Current")
            )
        ) {
            document
        }
        return coordinator
    }

    private func expectEditorDocument(
        _ expected: Document,
        in coordinator: AppFlowCoordinator
    ) {
        guard case .ready(.editor(let destination)) = coordinator.state else {
            Issue.record("Expected the current Editor destination to remain")
            return
        }
        #expect(destination.document === expected)
    }
}
