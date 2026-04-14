import SwiftUI

extension TabOverviewView {
    func databaseGroupView(_ group: DatabaseGroup, serverID: UUID) -> some View {
        let identifier = databaseIdentifier(for: group.databaseName, serverID: serverID)
        let isExpanded = !collapsedDatabases.contains(identifier)
        let isActiveDatabase = group.databaseName == activeDatabaseName && serverID == activeConnectionID

        return VStack(alignment: .leading, spacing: SpacingTokens.sm2) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    toggleDatabaseExpansion(identifier: identifier)
                }
            } label: {
                HStack(spacing: SpacingTokens.xs2) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(TypographyTokens.label.weight(.bold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 12)

                    Label(group.databaseName, systemImage: "cylinder")
                        .font(TypographyTokens.prominent.weight(.semibold))
                        .foregroundStyle(isActiveDatabase ? ColorTokens.accent : ColorTokens.Text.primary)

                    Spacer()
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
                .background(databaseBackground(isActive: isActiveDatabase), in: RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous)
                        .stroke(ColorTokens.Text.primary.opacity(isActiveDatabase ? 0.15 : 0.06), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(group.sections) { section in
                        sectionView(section, serverID: serverID, databaseIdentifier: identifier)
                    }
                }
                .padding(.leading, SpacingTokens.sm)
            }
        }
    }

    private func sectionView(_ section: SectionGroup, serverID: UUID, databaseIdentifier: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: section.kind.icon)
                    .font(TypographyTokens.detail.weight(.semibold))
                Text(section.kind.displayName.uppercased())
                    .font(TypographyTokens.detail.weight(.bold))

                Text("\(section.tabs.count)")
                    .font(TypographyTokens.label.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.horizontal, SpacingTokens.xxs2)
                    .padding(.vertical, 1)
                    .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
            }
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.leading, SpacingTokens.xxs)

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
