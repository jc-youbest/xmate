// Root view (v0).
//
// Hosts U-023 Canvas via C-002 PencilKitBridge at full screen.
// This view is a temporary v0 host; once F-011 Note CRUD is added,
// it will be replaced by U-002 NoteListScreen as the app's root.

import SwiftUI

struct ContentView: View {
    var body: some View {
        PencilKitBridge()
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
