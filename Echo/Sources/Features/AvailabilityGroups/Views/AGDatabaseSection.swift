import SwiftUI
import SQLServerKit

struct AGDatabaseSection: View {
    let databases: [SQLServerAGDatabase]
    let detailState: AvailabilityGroupsViewModel.LoadingState
    var groupName: String?
    var onRemoveDatabase: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            SidebarSectionHeader(title: "Databases (\(databases.count))")

            if detailState == .loading && databases.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(SpacingTokens.md)
            } else if case .error(let msg) = detailState, databases.isEmpty {
                Text(msg)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
                    .padding(SpacingTokens.md)
            } else if databases.isEmpty {
                Text("No databases in this availability group.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(SpacingTokens.md)
            } else {
                databaseTable
            }
        }
    }

    private var databaseTable: some View {
        VStack(spacing: 0) {
            databaseHeader
            Divider()
            ForEach(databases) { db in
                databaseRow(db)
                Divider()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ColorTokens.Background.secondary)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var databaseHeader: some View {
        HStack(spacing: 0) {
            headerCell("Database", width: 180)
            headerCell("Sync State", width: 130)
            headerCell("Health", width: 100)
            headerCell("DB State", width: 100)
            headerCell("Suspended", width: 80)
            headerCell("Log Queue (KB)", width: 110)
            headerCell("Redo Queue (KB)", width: 110)
        }
        .padding(.vertical, SpacingTokens.xs)
        .padding(.horizontal, SpacingTokens.sm)
        .background(ColorTokens.Background.tertiary)
    }

    private func databaseRow(_ db: SQLServerAGDatabase) -> some View {
        HStack(spacing: 0) {
            cellText(db.databaseName, width: 180, bold: true)
            syncStateCell(db.synchronizationState, width: 130)
            healthCell(db.synchronizationHealth, width: 100)
            cellText(db.databaseState, width: 100)
            suspendedCell(db.isSuspended, reason: db.suspendReason, width: 80)
            queueCell(db.logSendQueueSize, width: 110)
            queueCell(db.redoQueueSize, width: 110)
        }
        .padding(.vertical, SpacingTokens.xs)
        .padding(.horizontal, SpacingTokens.sm)
        .contextMenu {
            if let onRemove = onRemoveDatabase, groupName != nil {
                Button(role: .destructive) {
                    onRemove(db.databaseName)
                } label: {
                    Label("Remove from Group", systemImage: "minus.circle")
                }
            }
        }
    }

    private func headerCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(TypographyTokens.detail.weight(.semibold))
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(width: width, alignment: .leading)
    }

    private func cellText(_ text: String, width: CGFloat, bold: Bool = false) -> some View {
        Text(text)
            .font(bold ? TypographyTokens.detail.weight(.semibold) : TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.primary)
            .frame(width: width, alignment: .leading)
            .lineLimit(1)
    }

    private func syncStateCell(_ state: String, width: CGFloat) -> some View {
        let color = syncColor(state)
        return HStack(spacing: SpacingTokens.xxs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(state)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(width: width, alignment: .leading)
    }

    private func healthCell(_ health: String, width: CGFloat) -> some View {
        let color = healthColor(health)
        return HStack(spacing: SpacingTokens.xxs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(health)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(width: width, alignment: .leading)
    }

    private func suspendedCell(_ isSuspended: Bool, reason: String?, width: CGFloat) -> some View {
        Group {
            if isSuspended {
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: "pause.circle.fill")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.warning)
                    Text(reason ?? "Yes")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.warning)
                }
            } else {
                Text("No")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private func queueCell(_ size: Int64, width: CGFloat) -> some View {
        let displayValue = size > 0 ? formatQueueSize(size) : "0"
        let color: Color = size > 10_000 ? ColorTokens.Status.warning : ColorTokens.Text.primary
        return Text(displayValue)
            .font(TypographyTokens.detail.monospacedDigit())
            .foregroundStyle(color)
            .frame(width: width, alignment: .trailing)
    }

    private func formatQueueSize(_ kb: Int64) -> String {
        if kb >= 1_048_576 {
            return String(format: "%.1f GB", Double(kb) / 1_048_576.0)
        } else if kb >= 1024 {
            return String(format: "%.1f MB", Double(kb) / 1024.0)
        }
        return "\(kb)"
    }

    private func syncColor(_ state: String) -> Color {
        switch state.uppercased() {
        case "SYNCHRONIZED": return ColorTokens.Status.success
        case "SYNCHRONIZING": return ColorTokens.Status.info
        case "NOT SYNCHRONIZING", "NOT_SYNCHRONIZING": return ColorTokens.Status.warning
        default: return ColorTokens.Text.tertiary
        }
    }

    private func healthColor(_ health: String) -> Color {
        switch health.uppercased() {
        case "HEALTHY": return ColorTokens.Status.success
        case "PARTIALLY_HEALTHY": return ColorTokens.Status.warning
        case "NOT_HEALTHY": return ColorTokens.Status.error
        default: return ColorTokens.Text.tertiary
        }
    }
}
