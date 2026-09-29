import SwiftUI

/// The notification history (plan N3): a floating card under the bell, grouped by server, with
/// filters. A row whose tab or server is still around links to it.
struct NotificationHistoryCard: View {
    let history: NotificationHistory
    let onClose: () -> Void

    @Environment(EnvironmentState.self) private var environmentState
    @State private var filter: NotificationHistoryFilter = .all

    var body: some View {
        FloatingCard(size: .large) {
            header
            Picker("Show", selection: $filter) {
                ForEach(NotificationHistoryFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            list
        }
    }

    private var header: some View {
        HStack {
            Text("Notifications")
                .font(TypographyTokens.headline)
            Spacer()
            Button("Clear") { history.clear() }
                .buttonStyle(.link)
                .disabled(history.records.isEmpty)
        }
    }

    @ViewBuilder
    private var list: some View {
        let groups = history.groupedByServer(filter)
        if groups.isEmpty {
            Text(filter == .all ? "No notifications" : "No \(filter.rawValue.lowercased()) notifications")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(maxWidth: .infinity, minHeight: LayoutTokens.FloatingSurface.rowHeight * 2)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    ForEach(groups, id: \.server) { group in
                        Text(group.server)
                            .font(TypographyTokens.detail.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.top, SpacingTokens.xxs)
                        ForEach(group.records) { record in
                            NotificationHistoryRow(record: record, canReveal: environmentState.canReveal(record.context)) {
                                environmentState.reveal(record.context)
                                onClose()
                            }
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: LayoutTokens.CommandPalette.listMaxHeight)
        }
    }
}

/// One event: its icon in the severity colour, the message, and when it happened.
private struct NotificationHistoryRow: View {
    let record: NotificationRecord
    let canReveal: Bool
    let onReveal: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onReveal) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: record.category.defaultIcon)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(record.severity.color)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(record.message)
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(record.date, format: .relative(presentation: .named))
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(SpacingTokens.xs)
            .background(
                isHovering && canReveal ? ColorTokens.Sidebar.hoverFill : .clear,
                in: RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canReveal)
        .onHover { isHovering = $0 }
        .help(canReveal ? (record.context?.tabID != nil ? "Open Tab" : "Show Server") : "")
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
