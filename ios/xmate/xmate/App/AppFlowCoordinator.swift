// AppFlowCoordinator
//
// App-owned component routing and document-open coordination. It opens Editor
// through resolve -> validate -> window policy -> present, and
// owns explicit switching between the mutually exclusive Editor and Social
// surfaces. Components emit typed intents; neither component calls the other.

import Combine
import Foundation

enum DocumentOpenSource: Equatable {
    case developmentDocument(name: String)
}

struct DocumentOpenRequest: Equatable {
    let source: DocumentOpenSource
}

struct EditorRoute: Equatable {
    let source: DocumentOpenSource
    let windowLayoutPolicy: ComponentWindowLayoutPolicy
}

struct SocialRoute: Equatable {
    let windowLayoutPolicy: ComponentWindowLayoutPolicy = .systemResponsive
}

enum AppRoute: Equatable {
    case editor(EditorRoute)
    case social(SocialRoute)

    var windowLayoutPolicy: ComponentWindowLayoutPolicy {
        switch self {
        case .editor(let route):
            route.windowLayoutPolicy
        case .social(let route):
            route.windowLayoutPolicy
        }
    }
}

struct ResolvedEditorDestination {
    let route: EditorRoute
    let document: Document
}

enum ResolvedAppDestination {
    case editor(ResolvedEditorDestination)
    case social(SocialRoute)

    var route: AppRoute {
        switch self {
        case .editor(let destination):
            .editor(destination.route)
        case .social(let route):
            .social(route)
        }
    }
}

enum AppFlowState {
    case resolving
    case ready(ResolvedAppDestination)
    case failed(DocumentOpenError)
}

@MainActor
final class AppFlowCoordinator: ObservableObject {
    typealias DocumentValidator = (Document) -> DocumentOpenError?
    typealias EditorPolicyResolver = (Document) -> EditorWindowOrientationPolicy
    typealias WindowPolicyApplier = (ComponentWindowLayoutPolicy) -> Void

    @Published private(set) var state: AppFlowState = .resolving
    @Published private(set) var presentedOpenError: DocumentOpenError?

    private let validateDocument: DocumentValidator
    private let resolveEditorPolicy: EditorPolicyResolver
    private let applyWindowPolicy: WindowPolicyApplier
    private var editorReturnDestination: ResolvedEditorDestination?

    init(
        validateDocument: @escaping DocumentValidator = DocumentOpenValidator.validate,
        resolveEditorPolicy: @escaping EditorPolicyResolver = EditorWindowOrientationPolicy.preferred,
        applyWindowPolicy: @escaping WindowPolicyApplier = {
            AppWindowLayoutPolicyStore.shared.apply($0)
        }
    ) {
        self.validateDocument = validateDocument
        self.resolveEditorPolicy = resolveEditorPolicy
        self.applyWindowPolicy = applyWindowPolicy
    }

    /// Resolves the initial route once per coordinator lifetime. RootView still
    /// supplies the v1 development-document lookup; the coordinator owns every
    /// step after the source-specific resolver returns.
    func start(
        request: DocumentOpenRequest,
        resolveDocument: () -> Document
    ) {
        guard case .resolving = state else { return }
        openDocument(request: request, resolveDocument: resolveDocument)
    }

    func dismissOpenError() {
        presentedOpenError = nil
    }

    func handleEditorOutput(_ intent: EditorOutputIntent) {
        switch intent {
        case .showSocial:
            guard case .ready(.editor(let editorDestination)) = state else {
                return
            }

            editorReturnDestination = editorDestination
            present(.social(SocialRoute()))
        }
    }

    func handleSocialOutput(_ intent: SocialScreenOutputIntent) {
        switch intent {
        case .returnToEditor:
            guard case .ready(.social) = state,
                  let editorReturnDestination else {
                return
            }

            self.editorReturnDestination = nil
            present(.editor(editorReturnDestination))
        }
    }

    private func openDocument(
        request: DocumentOpenRequest,
        resolveDocument: () -> Document
    ) {
        let document = resolveDocument()

        if let error = validateDocument(document) {
            state = .failed(error)
            presentedOpenError = error
            return
        }

        let componentPolicy = ComponentWindowLayoutPolicy.documentDirected(
            resolveEditorPolicy(document)
        )
        let route = EditorRoute(
            source: request.source,
            windowLayoutPolicy: componentPolicy
        )

        present(
            .editor(
                ResolvedEditorDestination(route: route, document: document)
            )
        )
    }

    /// Policy is applied before the destination is published, so a component
    /// never appears under the previous component's orientation contract.
    private func present(_ destination: ResolvedAppDestination) {
        applyWindowPolicy(destination.route.windowLayoutPolicy)
        state = .ready(destination)
    }
}
