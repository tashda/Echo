import SwiftUI

/// The server page, shown on the canvas while a server is active and no tab is open
/// (Design/05-components.md › Server page). Same shape as the welcome: no big card, the server's
/// icon and name, its tools on Liquid Glass buttons, then small opaque cards for the databases,
/// recent queries and connection details.
struct ConnectionDashboardView: View {
    @Bindable var session: ConnectionSession

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: SpacingTokens.lg) {
                ConnectionDashboardHeader(session: session)
                ConnectionDashboardTools(session: session)

                // Two columns when there is room, one otherwise.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: SpacingTokens.sm) {
                        ConnectionDashboardDatabases(session: session)
                            .frame(minWidth: LayoutTokens.ServerPage.columnMinWidth)
                        VStack(spacing: SpacingTokens.lg) {
                            ConnectionDashboardRecentQueries(session: session)
                            ConnectionDashboardDetails(session: session)
                        }
                        .frame(minWidth: LayoutTokens.ServerPage.columnMinWidth)
                    }
                    VStack(spacing: SpacingTokens.lg) {
                        ConnectionDashboardDatabases(session: session)
                        ConnectionDashboardRecentQueries(session: session)
                        ConnectionDashboardDetails(session: session)
                    }
                }
            }
            .frame(maxWidth: LayoutTokens.ServerPage.width)
            .padding(SpacingTokens.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
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
                    .multilineTextAlignment(.center)
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

/// The label above one of the page's small cards, set like the welcome's "Recent".
struct DashboardSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(TypographyTokens.detail.weight(.medium))
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.leading, LayoutTokens.FloatingSurface.padding)
    }
}

/// One of the page's small opaque cards: the welcome's recents card.
struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            content()
        }
        .padding(LayoutTokens.Welcome.listPadding)
        .frame(maxWidth: .infinity)
        .workspaceCard()
    }
}

/// A 28pt row on a dashboard card, with the tree's hover fill.
struct DashboardCardRow<Content: View>: View {
    var isSelected = false
    @ViewBuilder let content: () -> Content

    @Environment(\.echoMotion) private var motion
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            content()
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(minHeight: LayoutTokens.FloatingSurface.rowHeight)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
                .fill(isSelected ? ColorTokens.Sidebar.selectedFill : isHovering ? ColorTokens.Sidebar.hoverFill : .clear)
        }
        .onHover { isHovering = $0 }
        .animation(motion.hover, value: isHovering)
    }
}
