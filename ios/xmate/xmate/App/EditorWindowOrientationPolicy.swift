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

final class EditorWindowOrientationPolicyStore {
    static let shared = EditorWindowOrientationPolicyStore()

    private init() {}

    private(set) var supportedInterfaceOrientations: UIInterfaceOrientationMask = [
        .portrait,
        .portraitUpsideDown,
    ]

    func apply(_ policy: EditorWindowOrientationPolicy) {
        supportedInterfaceOrientations = policy.preferredInterfaceOrientations
    }
}

struct WindowOrientationPolicyBridge: UIViewRepresentable {
    let policy: EditorWindowOrientationPolicy

    func makeUIView(context: Context) -> OrientationPolicyView {
        OrientationPolicyView()
    }

    func updateUIView(_ uiView: OrientationPolicyView, context: Context) {
        uiView.apply(policy)
    }

    final class OrientationPolicyView: UIView {
        private var policy: EditorWindowOrientationPolicy?
        private var lastRequestedMask: UIInterfaceOrientationMask?

        func apply(_ policy: EditorWindowOrientationPolicy) {
            self.policy = policy
            requestIfPossible()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            requestIfPossible()
        }

        private func requestIfPossible() {
            guard let policy,
                  lastRequestedMask != policy.preferredInterfaceOrientations,
                  let windowScene = window?.windowScene else {
                return
            }

            lastRequestedMask = policy.preferredInterfaceOrientations
            EditorWindowOrientationPolicyStore.shared.apply(policy)
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(
                .iOS(interfaceOrientations: policy.preferredInterfaceOrientations)
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
