import SwiftUI

struct MailboxSidebarView: View {
    let repository: LocalMailboxRepository
    let selectedEnvelopeID: UUID?
    let onOutput: (MailboxSidebarOutputIntent) -> Void

    @State private var selectedLocation: MailboxLocation = .draft
    @State private var envelopesByLocation: [MailboxLocation: [LetterEnvelope]] = [:]
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            locationList
            Divider()
            envelopeList
        }
        .background(Color(.secondarySystemGroupedBackground))
        .onAppear(perform: reload)
    }

    private var header: some View {
        HStack {
            Text("Mailbox")
                .font(.headline)
            Spacer()
            Button {
                onOutput(.closeSidebar)
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .frame(width: 44, height: 44)
            .buttonStyle(.plain)
            .accessibilityLabel("Close Mailbox")
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    private var locationList: some View {
        VStack(spacing: 2) {
            ForEach(MailboxLocation.allCases, id: \.self) { location in
                Button {
                    selectedLocation = location
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: location.systemImageName)
                            .frame(width: 20)
                        Text(location.displayName)
                        Spacer()
                        Text("\(envelopesByLocation[location, default: []].count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .contentShape(Rectangle())
                    .background(
                        selectedLocation == location
                            ? Color.accentColor.opacity(0.14)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(location.displayName)
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private var envelopeList: some View {
        if loadFailed {
            ContentUnavailableView(
                "Mailbox Unavailable",
                systemImage: "exclamationmark.triangle"
            )
        } else {
            let envelopes = envelopesByLocation[selectedLocation, default: []]
            if envelopes.isEmpty {
                ContentUnavailableView(
                    "No Letters",
                    systemImage: selectedLocation.systemImageName
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(envelopes, id: \.id) { envelope in
                            Button {
                                onOutput(.selectEnvelope(id: envelope.id))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(envelope.title.isEmpty ? "Untitled" : envelope.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    Text(envelope.updatedAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    selectedEnvelopeID == envelope.id
                                        ? Color.accentColor.opacity(0.14)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func reload() {
        do {
            envelopesByLocation = try Dictionary(
                uniqueKeysWithValues: MailboxLocation.allCases.map { location in
                    (location, try repository.envelopes(in: location))
                }
            )
            loadFailed = false
        } catch {
            envelopesByLocation = [:]
            loadFailed = true
        }
    }
}

private extension MailboxLocation {
    var displayName: String {
        switch self {
        case .inbox: "Inbox"
        case .draft: "Drafts"
        case .outbox: "Outbox"
        case .sent: "Sent"
        }
    }

    var systemImageName: String {
        switch self {
        case .inbox: "tray"
        case .draft: "doc"
        case .outbox: "paperplane"
        case .sent: "checkmark.circle"
        }
    }
}
