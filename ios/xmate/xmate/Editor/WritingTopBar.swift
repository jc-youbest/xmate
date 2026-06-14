// WritingTopBar
//
// Thin top bar for writing mode (F-051 / F-053 / F-056). Contains:
//   PageIndicator       — current position, e.g. "1 / 3"
//   ZoomResetButton     — live zoom percentage while zoomed; tap → 100%
//   AddPageButton       — appends a new blank page
//   WritingOverflowMenu — modal: pagination style, delete page, delete document
//     └ PaginationStylePicker — Picker toggling Single Page ↔ Continuous (F-056)
//
// Layout: indicator on the left, buttons on the right.
// Background: .bar material so it reads clearly against any page background.

import SwiftUI

struct WritingTopBar: View {
    /// 0-based index of the currently displayed page.
    let currentIndex: Int
    let pageCount: Int

    /// Global pagination style — reflected and updated by PaginationStylePicker.
    @Binding var paginationStyle: PaginationStyle

    /// Current zoom percentage while zoomed (e.g. 153), nil at fit (F-053).
    /// Non-nil shows ZoomResetButton.
    let zoomPercent: Int?
    /// Tap on ZoomResetButton — restores 100% (fit).
    let onResetZoom: () -> Void

    let onAddPage: () -> Void
    let onDeletePage: () -> Void
    let onDeleteDocument: () -> Void

    var body: some View {
        HStack(spacing: 0) {

            // PageIndicator
            Text("\(currentIndex + 1) / \(pageCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.leading, 16)

            Spacer()

            // ZoomResetButton — visible only while zoomed (F-053).
            // Shows the live percentage; tapping restores 100% (fit).
            if let zoomPercent {
                Button(action: onResetZoom) {
                    Text("\(zoomPercent)%")
                        .font(.subheadline)
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .padding(.trailing, 8)
            }

            // AddPageButton
            Button(action: onAddPage) {
                Image(systemName: "plus")
                    .imageScale(.large)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            // WritingOverflowMenu
            Menu {

                // PaginationStylePicker — toggle between Single Page and Continuous.
                // A SwiftUI Picker inside a Menu renders as an inline radio group.
                Picker("Pagination", selection: $paginationStyle) {
                    Label("Single Page", systemImage: "doc")
                        .tag(PaginationStyle.singlePage)
                    Label("Continuous", systemImage: "scroll")
                        .tag(PaginationStyle.continuous)
                }

                Divider()

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
            paginationStyle: .constant(.singlePage),
            zoomPercent: 153,
            onResetZoom: {},
            onAddPage: {},
            onDeletePage: {},
            onDeleteDocument: {}
        )
        Spacer()
    }
}
