// Root view — roadmap stage v0.
//
// On appear, loads (or on first launch creates) the default Document
// via C-001 NoteStore and hosts U-023 Canvas via C-002 PencilKitBridge
// bound to that document's only page. This is the v0 stand-in for
// U-101 WritingScreen, which arrives with the v1 writing mode.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @State private var page: Page?

    var body: some View {
        Group {
            if let page = page {
                PencilKitBridge(page: page, store: store)
                    .ignoresSafeArea()
            } else {
                Color.white
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            guard page == nil else { return }
            let document = store.loadOrCreateDefaultDocument()
            page = store.currentPage(of: document)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore.shared)
}
