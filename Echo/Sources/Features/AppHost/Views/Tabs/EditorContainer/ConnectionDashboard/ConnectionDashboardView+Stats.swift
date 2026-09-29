import SwiftUI

struct ConnectionDashboardDetails: View {
    @Bindable var session: ConnectionSession
    @Environment(ConnectionStore.self) private var connectionStore

    private var connection: SavedConnection { session.connection }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            DashboardSectionLabel(title: "Connection")

            DashboardCard {
                detailRow("Server", value: connection.host)
                detailRow("Port", value: "\(connection.port)")
                detailRow("User", value: resolvedUsername)
                if !connection.database.isEmpty {
                    detailRow("Database", value: connection.database)
                }
                if let version = serverVersion, !version.isEmpty {
                    detailRow("Version", value: version)
                }
                detailRow("Encryption", value: connection.databaseType == .postgresql
                    ? connection.tlsMode.rawValue
                    : (connection.useTLS ? "TLS" : "None"))
            }
        }
    }

    private var resolvedUsername: String {
        // Direct username on the connection
        if !connection.username.isEmpty {
            return connection.username
        }
        // Resolve from identity if the connection uses one
        if connection.usesIdentity,
           let identityID = connection.identityID,
           let identity = connectionStore.identities.first(where: { $0.id == identityID }) {
            return identity.username
        }
        return "–"
    }

    private var serverVersion: String? {
        session.databaseStructure?.serverVersion ?? connection.serverVersion
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(label)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer(minLength: SpacingTokens.xs)
            Text(value)
                .font(TypographyTokens.standard)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(minHeight: LayoutTokens.FloatingSurface.rowHeight)
    }
}
