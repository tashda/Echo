import SwiftUI

extension TabOverviewView {
    func serverGroupView(_ group: ServerGroup) -> some View {
        let serverID = group.connection.id
        let isExpanded = !collapsedServers.contains(serverID)
        let isActiveServer = group.connection.id == activeConnectionID

        return VStack(alignment: .leading, spacing: SpacingTokens.md2) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    toggleServerExpansion(serverID: serverID)
                }
            } label: {
                HStack(spacing: SpacingTokens.sm) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(TypographyTokens.caption2.weight(.bold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: SpacingTokens.md)

                    Label {
                        Text(group.connection.connectionName)
                            .font(TypographyTokens.displayLarge.weight(.bold))
                    } icon: {
                        DatabaseTypeIcon(
                            databaseType: group.connection.databaseType,
                            tint: isActiveServer ? ColorTokens.accent : ColorTokens.Text.secondary
                        )
                        .frame(width: SpacingTokens.md, height: SpacingTokens.md)
                    }

                    if group.connection.databaseType.isBeta {
                        FeatureBadge.beta
                    }

                    Text("\(group.totalTabCount) tab\(group.totalTabCount == 1 ? "" : "s")")
                        .font(TypographyTokens.caption2.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxxs)
                        .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    let sortedDatabases = group.databaseGroups.values.sorted { $0.databaseName.localizedCaseInsensitiveCompare($1.databaseName) == .orderedAscending }
                    ForEach(sortedDatabases) { databaseGroup in
                        databaseGroupView(databaseGroup, serverID: serverID)
                    }
                }
                .padding(.leading, SpacingTokens.lg2)
            }
        }
    }

    private func toggleServerExpansion(serverID: UUID) {
        if collapsedServers.contains(serverID) {
            collapsedServers.remove(serverID)
        } else {
            collapsedServers.insert(serverID)
        }
    }
}
