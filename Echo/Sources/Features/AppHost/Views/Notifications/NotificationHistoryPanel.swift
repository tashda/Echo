import SwiftUI

/// The inspector's Notifications page (round IC on round 17): every event, by day, on the shared
/// list in grouped boxes. Each row is two lines: the headline (bold while new) and its clock time,
/// then the server's dot, its name and the start of the message. A click opens the row in place
/// with the rest of the message (selectable) and small buttons: its action, Open Tab or Show
/// Server, Copy. Filters and Clear All share one ⋯ menu. The unread count is on the toolbar bell
/// only.
struct NotificationHistoryPanel: View {
    let history: NotificationHistory

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(\.echoMotion) private var motion

    @State private var filter: NotificationHistoryFilter = .all
    @State private var openRecordID: UUID?

    var body: some View {
        let groups = history.groupedByDay(filter)
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            InspectorPageHeader(summary: summary) { menu }
            if groups.isEmpty {
                InspectorEmptyState(systemImage: "bell",
                                    title: filter == .all ? "No Notifications" : "No \(filter.rawValue) Notifications",
                                    message: "What Echo tells you shows here, by day.") {
                    if filter != .all {
                        Button("Show All") { filter = .all }
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                        ForEach(groups, id: \.title) { group in
                            Section {
                                InspectorGroupBox {
                                    ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                                        row(record, showsSeparator: index > 0)
                                    }
                                }
                            } header: {
                                InspectorGroupHeading(title: group.title, count: group.records.count)
                                    .background(ColorTokens.Workspace.card)
                            }
                        }
                    }
                    .padding(.bottom, SpacingTokens.xs)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
        .animation(motion.standard, value: openRecordID)
        .animation(motion.standard, value: filter)
    }

    private var summary: String {
        let total = history.records.count
        guard total > 0 else { return "No notifications" }
        let new = history.newRecordIDs.count
        return new > 0 ? "\(new) new · \(total) in all" : "All read · \(total)"
    }

    private var menu: some View {
        Menu {
            Picker("Show", selection: $filter) {
                ForEach(NotificationHistoryFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Clear All", role: .destructive) { history.clear() }
                .disabled(history.records.isEmpty)
        } label: {
            Label("Filter and Clear", systemImage: "ellipsis.circle")
        }
        .help("Filter and Clear")
    }

    private func row(_ record: NotificationRecord, showsSeparator: Bool) -> some View {
        let isOpen = openRecordID == record.id
        let isNew = history.newRecordIDs.contains(record.id)
        let connection = record.context?.connectionID.flatMap { id in connectionStore.connections.first { $0.id == id } }
        let isConnected = record.context?.connectionID.map { id in
            environmentState.sessionGroup.activeSessions.contains { $0.connection.id == id }
        } ?? true
        let server = record.context?.serverName ?? connection.map { $0.connectionName.isEmpty ? $0.host : $0.connectionName }
        return InspectorListRow(isSelected: isOpen, showsSeparator: showsSeparator) {
            Image(systemName: record.category.defaultIcon)
                .foregroundStyle(record.severity.color)
        } title: {
            Text(record.headline)
                .font(TypographyTokens.standard.weight(isNew ? .semibold : .regular))
                .foregroundStyle(ColorTokens.Text.primary)
        } trailing: {
            Text(InspectorListFormat.time(record.date))
        } detail: {
            let line = [server, isOpen ? nil : record.detail].compactMap { $0 }.joined(separator: " · ")
            if !line.isEmpty {
                InspectorRowDetail(serverColor: connection?.color ?? ColorTokens.Text.tertiary,
                                   isConnected: isConnected, text: Text(line))
            }
        } opened: {
            opened(record)
        }
        .onTapGesture { openRecordID = isOpen ? nil : record.id }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { copyToGeneralPasteboard(record.message) }
        }
    }

    @ViewBuilder
    private func opened(_ record: NotificationRecord) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            if let detail = record.detail {
                Text(detail)
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            InspectorRowActions {
                if let action = record.context?.action, environmentState.canPerform(action, context: record.context) {
                    Button(action.title) { environmentState.perform(action, context: record.context) }
                        .buttonStyle(.borderedProminent)
                }
                if environmentState.canReveal(record.context) {
                    Button(record.context?.tabID != nil ? "Open Tab" : "Show Server") {
                        environmentState.reveal(record.context)
                    }
                }
                Button("Copy") { copyToGeneralPasteboard(record.message) }
            }
        }
    }
}

extension NotificationRecord.Severity {
    var color: Color {
        switch self {
        case .success: ColorTokens.Status.success
        case .info: ColorTokens.Text.secondary
        case .warning: ColorTokens.Status.warning
        case .error: ColorTokens.Status.error
        }
    }
}
