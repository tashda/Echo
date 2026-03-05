import SwiftUI

extension TabOverviewView {
    func serverGroupView(_ group: ServerGroup) -> some View {
        let serverID = group.connection.id
        let isExpanded = !collapsedServers.contains(serverID)
        let isActiveServer = group.connection.id == activeConnectionID

        return VStack(alignment: .leading, spacing: 18) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    toggleServerExpansion(serverID: serverID)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(TypographyTokens.caption2.weight(.bold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 16)

                    Label {
                        Text(group.connection.connectionName)
                            .font(TypographyTokens.displayLarge.weight(.bold))
                    } icon: {
                        Image(systemName: group.connection.databaseType.iconName)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isActiveServer ? Color.accentColor : Color.secondary)
                    }

                    Text("\(group.totalTabCount) tab\(group.totalTabCount == 1 ? "" : "s")")
                        .font(TypographyTokens.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxxs)
                        .background(Color.primary.opacity(0.06), in: Capsule())

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 24) {
                    let sortedDatabases = group.databaseGroups.values.sorted { $0.databaseName.localizedCaseInsensitiveCompare($1.databaseName) == .orderedAscending }
                    ForEach(sortedDatabases) { databaseGroup in
                        databaseGroupView(databaseGroup, serverID: serverID)
                    }
                }
                .padding(.leading, 28)
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
