import SwiftUI

struct ConnectionDashboardDetails: View {
    @ObservedObject var session: ConnectionSession

    private var connection: SavedConnection { session.connection }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Connection")
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.tertiary)
                .textCase(.uppercase)
                .padding(.leading, SpacingTokens.xxs)

            VStack(spacing: 0) {
                detailRow("Server", value: connection.host)
                detailDivider
                detailRow("Port", value: "\(connection.port)")
                if !connection.database.isEmpty {
                    detailDivider
                    detailRow("Database", value: connection.database)
                }
                if let version = serverVersion, !version.isEmpty {
                    detailDivider
                    detailRow("Version", value: version)
                }
                detailDivider
                detailRow("Type", value: connection.databaseType.displayName)
                detailDivider
                detailRow("Encryption", value: connection.databaseType == .postgresql
                    ? connection.tlsMode.rawValue
                    : (connection.useTLS ? "TLS" : "None"))
                if !connection.username.isEmpty {
                    detailDivider
                    detailRow("User", value: connection.username)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ColorTokens.Text.primary.opacity(0.02))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
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
