import CoreData
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

        guard case .ready(let destination) = coordinator.state else {
            Issue.record("Expected a ready destination")
            return
        }
        guard case .editor(let route) = destination.route else {
            Issue.record("Expected an Editor route")
            return
        }

        #expect(destination.document === document)
        #expect(route.source == request.source)
        #expect(route.windowLayoutPolicy == .documentDirected(editorPolicy))
        #expect(appliedPolicies == [.documentDirected(editorPolicy)])
        #expect(coordinator.presentedOpenError == nil)
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
}
