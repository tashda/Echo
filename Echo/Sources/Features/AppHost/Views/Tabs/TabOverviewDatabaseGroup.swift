import SwiftUI

extension TabOverviewView {
    func databaseGroupView(_ group: DatabaseGroup, serverID: UUID) -> some View {
        let identifier = databaseIdentifier(for: group.databaseName, serverID: serverID)
        let isExpanded = !collapsedDatabases.contains(identifier)
        let isActiveDatabase = group.databaseName == activeDatabaseName && serverID == activeConnectionID

        return VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    toggleDatabaseExpansion(identifier: identifier)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 12)

                    Label(group.databaseName, systemImage: "database.outlined")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isActiveDatabase ? Color.accentColor : Color.primary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(databaseBackground(isActive: isActiveDatabase), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(isActiveDatabase ? 0.15 : 0.06), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(group.sections) { section in
                        sectionView(section, serverID: serverID, databaseIdentifier: identifier)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    private func sectionView(_ section: SectionGroup, serverID: UUID, databaseIdentifier: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: section.kind.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(section.kind.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                
                Text("\(section.tabs.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .foregroundStyle(.secondary)
            .padding(.leading, 4)

            LazyVGrid(columns: gridConfiguration.columns, spacing: gridConfiguration.spacing) {
                ForEach(section.tabs) { tab in
                    tabCard(for: tab, serverID: serverID, databaseIdentifier: databaseIdentifier)
                        .id(tab.id)
                }
            }
        }
    }

    private func toggleDatabaseExpansion(identifier: String) {
        if collapsedDatabases.contains(identifier) {
            collapsedDatabases.remove(identifier)
        } else {
            collapsedDatabases.insert(identifier)
        }
    }

    internal func databaseIdentifier(for databaseName: String, serverID: UUID) -> String {
        "\(serverID.uuidString)|\(databaseName)"
    }
}
