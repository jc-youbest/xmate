// U-102 WritingTopBar
//
// Thin top bar for writing mode (F-051). Contains:
//   U-093 PageIndicator  — current position, e.g. "1 / 3"
//   U-095 AddPageButton  — appends a new blank page
//   U-103 WritingOverflowMenu — modal: delete page, delete document
//
// Layout: indicator on the left, buttons on the right.
// Background: .bar material so it reads clearly against any page background.

import SwiftUI

struct WritingTopBar: View {
    /// 0-based index of the currently displayed page.
    let currentIndex: Int
    let pageCount: Int

    let onAddPage: () -> Void
    let onDeletePage: () -> Void
    let onDeleteDocument: () -> Void

    var body: some View {
        HStack(spacing: 0) {

            // U-093 PageIndicator
            Text("\(currentIndex + 1) / \(pageCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.leading, 16)

            Spacer()

            // U-095 AddPageButton
            Button(action: onAddPage) {
                Image(systemName: "plus")
                    .imageScale(.large)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            // U-103 WritingOverflowMenu
            Menu {
                // "Delete Page" is disabled when there is only one page.
                Button(role: .destructive, action: onDeletePage) {
                    Label("Delete Page", systemImage: "trash")
                }
                .disabled(pageCount <= 1)

                Button(role: .destructive, action: onDeleteDocument) {
                    Label("Delete Document", systemImage: "trash.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(.trailing, 8)
        }
        .frame(height: 44)
        .background(.bar)
    }
}

#Preview {
    VStack(spacing: 0) {
        WritingTopBar(
            currentIndex: 1,
            pageCount: 5,
            onAddPage: {},
            onDeletePage: {},
            onDeleteDocument: {}
        )
        Spacer()
    }
}
