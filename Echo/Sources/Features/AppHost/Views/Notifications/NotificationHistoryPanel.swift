import SwiftUI

/// The notification history in the inspector's column (plan N3, round 15 option B): one card with
/// a server's events in a grouped box each. A row opens in place to the whole message, selectable,
/// with Copy and a link back to its tab or server. Nothing is greyed out.
struct NotificationHistoryPanel: View {
    let history: NotificationHistory

    @State private var filter: NotificationHistoryFilter = .all
    @State private var openRecordID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            header
                .padding([.horizontal, .top], LayoutTokens.Inspector.cardPadding)
            ScrollView {
                list
                    .padding([.horizontal, .bottom], LayoutTokens.Inspector.cardPadding)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    /// The title, a filter menu and Clear. The filter names itself when it isn't All.
    private var header: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(filter == .all ? "Notifications" : "\(filter.rawValue) Notifications")
                .font(TypographyTokens.headline)
            Spacer(minLength: SpacingTokens.none)
            Menu {
                Picker("Show", selection: $filter) {
                    ForEach(NotificationHistoryFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .labelStyle(.iconOnly)
            .fixedSize()
            .help("Filter")
            Button("Clear") { history.clear() }
                .buttonStyle(.borderless)
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
                .padding(.top, SpacingTokens.xs)
        } else {
            LazyVStack(alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(groups, id: \.server) { group in
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text(group.server)
                            .font(TypographyTokens.detail.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.horizontal, SpacingTokens.xxs)
                        VStack(alignment: .leading, spacing: SpacingTokens.none) {
                            ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                                NotificationHistoryRow(
                                    record: record,
                                    isOpen: openRecordID == record.id,
                                    isLast: index == group.records.count - 1
                                ) {
                                    openRecordID = openRecordID == record.id ? nil : record.id
                                }
                            }
                        }
                        .padding(.horizontal, LayoutTokens.Inspector.cardPadding)
                        .background(
                            ColorTokens.Background.secondary,
                            in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
                        )
                    }
                }
            }
        }
    }
}

/// One event: icon, message and time; open, the whole message and its actions.
private struct NotificationHistoryRow: View {
    let record: NotificationRecord
    let isOpen: Bool
    let isLast: Bool
    let onToggle: () -> Void

    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: record.category.defaultIcon)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(record.severity.color)
                Text(record.message)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(isOpen ? nil : 2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: isOpen)
                Spacer(minLength: SpacingTokens.xs)
                Text(record.date, format: .relative(presentation: .named))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            if isOpen { actions }
        }
        .padding(.vertical, SpacingTokens.xs)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .overlay(alignment: .bottom) {
            if !isLast { Divider() }
        }
    }

    private var actions: some View {
        HStack(spacing: SpacingTokens.sm) {
            if environmentState.canReveal(record.context) {
                Button(record.context?.tabID != nil ? "Open Tab" : "Show Server") {
                    environmentState.reveal(record.context)
                }
            }
            Button("Copy") { copyToGeneralPasteboard(record.message) }
        }
        .buttonStyle(.plain)
        .font(TypographyTokens.detail.weight(.medium))
        .foregroundStyle(ColorTokens.accent)
        .padding(.leading, SpacingTokens.lg)
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
