import SwiftUI

struct ConnectionDashboardView: View {
    @ObservedObject var session: ConnectionSession
    let onNewQuery: () -> Void
    let onOpenJobQueue: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.lg) {
                ConnectionDashboardHeader(session: session)
                ConnectionDashboardQuickActions(
                    session: session,
                    onNewQuery: onNewQuery,
                    onOpenJobQueue: onOpenJobQueue
                )
                ConnectionDashboardDetails(session: session)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, SpacingTokens.xl)
            .padding(.vertical, SpacingTokens.xl2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Header

struct ConnectionDashboardHeader: View {
    @ObservedObject var session: ConnectionSession

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            connectionIcon
            VStack(spacing: SpacingTokens.xxs) {
                Text(session.connection.connectionName)
                    .font(TypographyTokens.displayLarge.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)

                Text(serverSubtitle)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, SpacingTokens.xs)
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
            Image(session.connection.databaseType.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundStyle(session.connection.color)
        }
    }
}
