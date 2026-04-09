import SwiftUI

struct ConnectionDashboardView: View {
    @Bindable var session: ConnectionSession
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: SpacingTokens.xl) {
                ConnectionDashboardHeader(session: session)
                ConnectionDashboardTools(session: session)
                ConnectionDashboardDatabases(session: session)
                ConnectionDashboardRecentQueries(session: session)
                ConnectionDashboardDetails(session: session)
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, SpacingTokens.xl)
            .padding(.vertical, SpacingTokens.xl2)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Header

struct ConnectionDashboardHeader: View {
    @Bindable var session: ConnectionSession

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            connectionIcon
            VStack(spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.xs) {
                    Text(session.connection.connectionName)
                        .font(TypographyTokens.displayLarge.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.primary)

                    if session.connection.databaseType.isBeta {
                        FeatureBadge.beta
                    }
                }

                Text(serverSubtitle)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var serverSubtitle: String {
        var parts: [String] = []
        parts.append(session.connection.host)
        if let version = session.databaseStructure?.serverVersion
            ?? session.connection.serverVersion {
            parts.append(version)
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var connectionIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(session.connection.color.opacity(0.1))
                .frame(width: 48, height: 48)
            DatabaseTypeIcon(
                databaseType: session.connection.databaseType,
                tint: session.connection.color
            )
                .frame(width: 24, height: 24)
        }
    }
}

// MARK: - Section Header

struct DashboardSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(TypographyTokens.detail.weight(.medium))
            .foregroundStyle(ColorTokens.Text.tertiary)
            .textCase(.uppercase)
    }
}
