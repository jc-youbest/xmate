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
    case mailboxEnvelope(id: UUID, location: MailboxLocation)
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

enum EditorWorkspaceAccessory: Equatable {
    case mailboxSidebar
}

enum MailboxEnvelopeSelectionRejection: Equatable {
    case requiresEditorDestination
    case requiresMailboxSidebar
    case envelopeNotFound(id: UUID)
    case repositoryFailure(id: UUID)
    case cacheUnavailable(MailboxDocumentCacheResolution)
    case cachedDocumentChanged(documentID: UUID)
    case invalidDocument(DocumentOpenError)
}

enum MailboxEnvelopeSelectionOutcome: Equatable {
    case applied
    case rejected(MailboxEnvelopeSelectionRejection)
}

@MainActor
final class AppFlowCoordinator: ObservableObject {
    typealias DocumentValidator = (Document) -> DocumentOpenError?
    typealias EditorPolicyResolver = (Document) -> EditorWindowOrientationPolicy
    typealias WindowPolicyApplier = (ComponentWindowLayoutPolicy) -> Void

    @Published private(set) var state: AppFlowState = .resolving
    @Published private(set) var presentedOpenError: DocumentOpenError?
    @Published private(set) var editorWorkspaceAccessory: EditorWorkspaceAccessory?

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
        case .showMailbox:
            guard case .ready(.editor) = state else { return }
            editorWorkspaceAccessory = .mailboxSidebar

        case .showSocial:
            guard case .ready(.editor(let editorDestination)) = state,
                  editorWorkspaceAccessory == nil else {
                return
            }

            editorReturnDestination = editorDestination
            present(.social(SocialRoute()))
        }
    }

    @discardableResult
    func handleMailboxSidebarOutput(
        _ intent: MailboxSidebarOutputIntent,
        resolveEnvelope: (UUID) throws -> MailboxEnvelopeDocumentResolution? = { _ in nil },
        resolveCachedDocument: (UUID) throws -> Document? = { _ in nil }
    ) -> MailboxEnvelopeSelectionOutcome? {
        switch intent {
        case .closeSidebar:
            guard editorWorkspaceAccessory == .mailboxSidebar,
                  case .ready(.editor(let destination)) = state else {
                return nil
            }

            let committedPolicy = ComponentWindowLayoutPolicy.documentDirected(
                resolveEditorPolicy(destination.document)
            )
            let committedDestination = ResolvedEditorDestination(
                route: EditorRoute(
                    source: destination.route.source,
                    windowLayoutPolicy: committedPolicy
                ),
                document: destination.document
            )
            present(.editor(committedDestination))
            editorWorkspaceAccessory = nil
            return nil

        case .selectEnvelope(let id):
            return selectMailboxEnvelope(
                id: id,
                resolveEnvelope: resolveEnvelope,
                resolveCachedDocument: resolveCachedDocument
            )
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

    /// Replaces the Editor's Document from an envelope selected inside the
    /// Editor Workspace. The caller must complete the Editor drawing handoff
    /// before invoking this method. Failures preserve the current destination.
    /// A successful selection also preserves the workspace window policy;
    /// dismissing the sidebar will commit the selected Document's policy in a
    /// later workspace-presentation increment.
    @discardableResult
    func selectMailboxEnvelope(
        id: UUID,
        resolveEnvelope: (UUID) throws -> MailboxEnvelopeDocumentResolution?,
        resolveCachedDocument: (UUID) throws -> Document?
    ) -> MailboxEnvelopeSelectionOutcome {
        guard case .ready(.editor(let currentDestination)) = state else {
            return .rejected(.requiresEditorDestination)
        }
        guard editorWorkspaceAccessory == .mailboxSidebar else {
            return .rejected(.requiresMailboxSidebar)
        }

        let resolvedEnvelope: MailboxEnvelopeDocumentResolution
        do {
            guard let resolution = try resolveEnvelope(id) else {
                return .rejected(.envelopeNotFound(id: id))
            }
            resolvedEnvelope = resolution
        } catch {
            return .rejected(.repositoryFailure(id: id))
        }

        guard case .hit(let descriptor) = resolvedEnvelope.documentCache else {
            return .rejected(
                .cacheUnavailable(resolvedEnvelope.documentCache)
            )
        }

        let document: Document
        do {
            guard let cachedDocument = try resolveCachedDocument(
                descriptor.documentID
            ),
                  cachedDocument.id == descriptor.documentID,
                  cachedDocument.contentRevision == descriptor.revision.rawValue
            else {
                return .rejected(.cachedDocumentChanged(
                    documentID: descriptor.documentID
                ))
            }
            document = cachedDocument
        } catch {
            return .rejected(.repositoryFailure(id: id))
        }

        if let error = validateDocument(document) {
            return .rejected(.invalidDocument(error))
        }

        let route = EditorRoute(
            source: .mailboxEnvelope(
                id: resolvedEnvelope.envelope.id,
                location: resolvedEnvelope.envelope.mailboxLocation
            ),
            windowLayoutPolicy: currentDestination.route.windowLayoutPolicy
        )
        state = .ready(.editor(ResolvedEditorDestination(
            route: route,
            document: document
        )))
        editorReturnDestination = nil
        return .applied
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
