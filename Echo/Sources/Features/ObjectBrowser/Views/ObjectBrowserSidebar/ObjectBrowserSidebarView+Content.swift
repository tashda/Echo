import SwiftUI

extension ObjectBrowserSidebarView {
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No Database Connected")
                .font(TypographyTokens.displayLarge.weight(.semibold))
            Text("Connect to a server to explore its schemas, tables, and functions.")
                .font(TypographyTokens.standard)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .padding(.vertical, SpacingTokens.xxl)
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
