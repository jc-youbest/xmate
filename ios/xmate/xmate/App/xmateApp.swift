// Application entry — hosts U-001 AppRoot (RootView).
//
// Wires the app-wide stores into the environment and delegates
// everything else (including document selection) to RootView.

import SwiftUI

@main
struct xmateApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(NoteStore.shared)
                .environmentObject(SettingsStore.shared)
        }
    }
}
