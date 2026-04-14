import SwiftUI

struct ConnectionDashboardDetails: View {
    @Bindable var session: ConnectionSession
    @Environment(ConnectionStore.self) private var connectionStore

    private var connection: SavedConnection { session.connection }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            DashboardSectionLabel(title: "Connection")

            VStack(spacing: 0) {
                detailRow("Server", value: connection.host)
                detailDivider
                detailRow("Port", value: "\(connection.port)")
                detailDivider
                detailRow("User", value: resolvedUsername)
                if !connection.database.isEmpty {
                    detailDivider
                    detailRow("Database", value: connection.database)
                }
                if let version = serverVersion, !version.isEmpty {
                    detailDivider
                    detailRow("Version", value: version)
                }
                detailDivider
                detailRow("Encryption", value: connection.databaseType == .postgresql
                    ? connection.tlsMode.rawValue
                    : (connection.useTLS ? "TLS" : "None"))
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ColorTokens.Surface.rest)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private var detailDivider: some View {
        Divider()
            .padding(.leading, SpacingTokens.sm)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
            Text(value)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs2)
    }
}
