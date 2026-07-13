// Application entry — hosts AppRoot (RootView).
//
// Wires the app-wide stores into the environment and delegates
// everything else (including document selection) to RootView.

import SwiftUI
import UIKit

final class XmateAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        EditorWindowOrientationPolicyStore.shared.supportedInterfaceOrientations
    }
}

@main
struct xmateApp: App {
    @UIApplicationDelegateAdaptor(XmateAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(NoteStore.shared)
                .environmentObject(SettingsStore.shared)
        }
    }
}
