import SwiftUI
import SQLServerKit

struct AGReplicaSection: View {
    let replicas: [SQLServerAGReplica]
    let detailState: AvailabilityGroupsViewModel.LoadingState

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            SidebarSectionHeader(title: "Replicas (\(replicas.count))")

            if detailState == .loading && replicas.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(SpacingTokens.md)
            } else if case .error(let msg) = detailState, replicas.isEmpty {
                Text(msg)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
                    .padding(SpacingTokens.md)
            } else if replicas.isEmpty {
                Text("No replicas found.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(SpacingTokens.md)
            } else {
                replicaTable
            }
        }
    }

    private var replicaTable: some View {
        VStack(spacing: 0) {
            replicaHeader
            Divider()
            ForEach(replicas) { replica in
                replicaRow(replica)
                Divider()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ColorTokens.Background.secondary)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var replicaHeader: some View {
        HStack(spacing: 0) {
            headerCell("Server", width: 180)
            headerCell("Role", width: 90)
            headerCell("Availability", width: 120)
            headerCell("Failover", width: 100)
            headerCell("State", width: 100)
            headerCell("Health", width: 100)
            headerCell("Connection", width: 110)
        }
        .padding(.vertical, SpacingTokens.xs)
        .padding(.horizontal, SpacingTokens.sm)
        .background(ColorTokens.Background.tertiary)
    }

    private func replicaRow(_ replica: SQLServerAGReplica) -> some View {
        HStack(spacing: 0) {
            cellText(replica.replicaServerName, width: 180, bold: true)
            roleCell(replica.role, width: 90)
            cellText(replica.availabilityMode, width: 120)
            cellText(replica.failoverMode, width: 100)
            cellText(replica.operationalState, width: 100)
            healthCell(replica.synchronizationHealth, width: 100)
            cellText(replica.connectionState, width: 110)
        }
        .padding(.vertical, SpacingTokens.xs)
        .padding(.horizontal, SpacingTokens.sm)
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

    private func roleCell(_ role: String, width: CGFloat) -> some View {
        let isPrimary = role.uppercased() == "PRIMARY"
        return HStack(spacing: SpacingTokens.xxs) {
            Circle()
                .fill(isPrimary ? ColorTokens.Status.info : ColorTokens.Text.tertiary)
                .frame(width: 6, height: 6)
            Text(role)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(isPrimary ? ColorTokens.Status.info : ColorTokens.Text.primary)
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

    private func healthColor(_ health: String) -> Color {
        switch health.uppercased() {
        case "HEALTHY": return ColorTokens.Status.success
        case "PARTIALLY_HEALTHY": return ColorTokens.Status.warning
        case "NOT_HEALTHY": return ColorTokens.Status.error
        default: return ColorTokens.Text.tertiary
        }
    }
}
