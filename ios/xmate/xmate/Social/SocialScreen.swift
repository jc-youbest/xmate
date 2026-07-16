// SocialScreen
//
// F-055 structural shell. Concrete inbox, feed, and pen-pal content lands in
// v3+. This component owns only its adaptive UI and emits typed output intents;
// App owns routing and the active window-layout policy.

import SwiftUI

enum SocialScreenOutputIntent: Equatable {
    case returnToEditor
}

struct SocialScreen: View {
    let onOutput: (SocialScreenOutputIntent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Social")
                    .font(.headline)

                HStack {
                    Button {
                        onOutput(.returnToEditor)
                    } label: {
                        Label("Back to Editor", systemImage: "chevron.backward")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .background(.bar)

            ContentUnavailableView(
                "Social",
                systemImage: "person.2",
                description: Text("Inbox, feed, and pen pals will appear here in a later stage.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    SocialScreen(onOutput: { _ in })
}
