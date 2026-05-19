// Root view (3a).
//
// On appear, loads (or on first launch creates) the default Document
// via C-001 NoteStore and hosts U-023 Canvas via C-002 PencilKitBridge
// bound to that document's only page. Will be replaced by
// U-002 NoteListScreen when F-011's CRUD UI lands.

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
