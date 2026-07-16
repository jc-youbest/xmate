// AppFlowCoordinator
//
// App-owned component routing and document-open coordination. The current
// increment intentionally has one route (Editor) and one source (the named
// development document); future Library/Social sources enter through the same
// resolve -> validate -> window policy -> present pipeline.

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

enum AppRoute: Equatable {
    case editor(EditorRoute)

    var windowLayoutPolicy: ComponentWindowLayoutPolicy {
        switch self {
        case .editor(let route):
            route.windowLayoutPolicy
        }
    }
}

struct ResolvedAppDestination {
    let route: AppRoute
    let document: Document
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
        let route = AppRoute.editor(
            EditorRoute(
                source: request.source,
                windowLayoutPolicy: componentPolicy
            )
        )

        applyWindowPolicy(componentPolicy)
        state = .ready(
            ResolvedAppDestination(route: route, document: document)
        )
    }
}
