// EditorWindowOrientationPolicy
//
// App-layer bridge from document page orientation to the iPad window
// orientation preference. PageSpec remains document semantics; this policy is
// only a request to the current UIWindowScene, and the editor still adapts to
// whatever viewport iPadOS actually provides.

import SwiftUI
import UIKit

struct EditorWindowOrientationPolicy: Equatable {
    let preferredInterfaceOrientations: UIInterfaceOrientationMask
    let debugName: String

    static func preferred(for document: Document) -> EditorWindowOrientationPolicy {
        if let preset = PagePresetCatalog.preset(forID: document.pagePresetID) {
            return preferred(for: preset.spec.size.orientation)
        }

        // The document-open validator should reject invalid presets before the
        // editor loads. Keep a neutral fallback here so this bridge is defensive
        // without becoming a second validation path.
        return EditorWindowOrientationPolicy(
            preferredInterfaceOrientations: .all,
            debugName: "all"
        )
    }

    private static func preferred(
        for orientation: PageOrientation
    ) -> EditorWindowOrientationPolicy {
        switch orientation {
        case .portrait:
            return EditorWindowOrientationPolicy(
                preferredInterfaceOrientations: [.portrait, .portraitUpsideDown],
                debugName: "portrait"
            )
        case .landscape:
            return EditorWindowOrientationPolicy(
                preferredInterfaceOrientations: [.landscapeLeft, .landscapeRight],
                debugName: "landscape"
            )
        case .square:
            return EditorWindowOrientationPolicy(
                preferredInterfaceOrientations: .all,
                debugName: "all"
            )
        }
    }
}

/// Window-orientation behavior declared by the active App component. Ordinary
/// components accept the iPadOS arrangement; Editor carries a validated
/// document-derived orientation policy. Components never apply this directly.
enum ComponentWindowLayoutPolicy: Equatable {
    case systemResponsive
    case documentDirected(EditorWindowOrientationPolicy)

    var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch self {
        case .systemResponsive:
            .all
        case .documentDirected(let editorPolicy):
            editorPolicy.preferredInterfaceOrientations
        }
    }

    var debugName: String {
        switch self {
        case .systemResponsive:
            "system-responsive"
        case .documentDirected(let editorPolicy):
            "document-\(editorPolicy.debugName)"
        }
    }
}

/// The single App/window owner for the active component policy.
final class AppWindowLayoutPolicyStore {
    static let shared = AppWindowLayoutPolicyStore()

    private init() {}

    private(set) var supportedInterfaceOrientations: UIInterfaceOrientationMask =
        ComponentWindowLayoutPolicy.systemResponsive.supportedInterfaceOrientations

    func apply(_ policy: ComponentWindowLayoutPolicy) {
        supportedInterfaceOrientations = policy.supportedInterfaceOrientations
    }
}

struct WindowOrientationPolicyBridge: UIViewRepresentable {
    let policy: ComponentWindowLayoutPolicy

    func makeUIView(context: Context) -> OrientationPolicyView {
        OrientationPolicyView()
    }

    func updateUIView(_ uiView: OrientationPolicyView, context: Context) {
        uiView.apply(policy)
    }

    final class OrientationPolicyView: UIView {
        private var policy: ComponentWindowLayoutPolicy?
        private var lastRequestedMask: UIInterfaceOrientationMask?

        func apply(_ policy: ComponentWindowLayoutPolicy) {
            self.policy = policy
            requestIfPossible()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            requestIfPossible()
        }

        private func requestIfPossible() {
            guard let policy,
                  lastRequestedMask != policy.supportedInterfaceOrientations,
                  let windowScene = window?.windowScene else {
                return
            }

            lastRequestedMask = policy.supportedInterfaceOrientations
            AppWindowLayoutPolicyStore.shared.apply(policy)
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(
                .iOS(interfaceOrientations: policy.supportedInterfaceOrientations)
            ) { error in
                #if DEBUG
                print("[WINDOW-ORIENTATION] request=\(policy.debugName) failed=\(error.localizedDescription)")
                #endif
            }

            #if DEBUG
            print("[WINDOW-ORIENTATION] request=\(policy.debugName)")
            #endif
        }
    }
}
