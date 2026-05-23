// Entry point view — delegates to U-101 WritingScreen (roadmap stage v1).
//
// ContentView exists solely because xmateApp references it by name. All
// writing-mode logic lives in WritingScreen.swift.

import SwiftUI

struct ContentView: View {
    var body: some View {
        WritingScreen()
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore.shared)
}
