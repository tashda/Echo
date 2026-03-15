import SwiftUI

extension ObjectBrowserSidebarView {
    var emptyStateView: some View {
        VStack(spacing: SpacingTokens.xs) {
            Image(systemName: "server.rack")
                .font(TypographyTokens.hero.weight(.medium))
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No Connection")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.vertical, SpacingTokens.xl2)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func selectedDatabase(in structure: DatabaseStructure, for session: ConnectionSession) -> DatabaseInfo? {
        if let selectedName = session.selectedDatabaseName,
           let match = structure.databases.first(where: { $0.name == selectedName }) {
            return match
        }

        if !session.connection.database.isEmpty,
           let match = structure.databases.first(where: { $0.name == session.connection.database }) {
            return match
        }
        return nil
    }
}
