import SwiftUI

/// The server page, shown on the canvas while a server is active and no tab is open
/// (Design/05-components.md › Server page, S1a). Light, like the welcome: the server's name large,
/// its version as one quiet line, its tools on Liquid Glass buttons, then the databases on one
/// small card with a filter. The top lines up with the top of the rail.
struct ConnectionDashboardView: View {
    @Bindable var session: ConnectionSession

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                ConnectionDashboardHeader(session: session)
                ConnectionDashboardTools(session: session)
                ConnectionDashboardDatabases(session: session)
            }
            .frame(maxWidth: LayoutTokens.ServerPage.width, alignment: .leading)
            .padding(.horizontal, SpacingTokens.xl)
            // The rail and tree start this much below the content's top (the tab strip's inset).
            .padding(.top, (WorkspaceChromeMetrics.tabStripTotalHeight - WorkspaceChromeMetrics.chromeBackgroundHeight) / 2)
            .padding(.bottom, SpacingTokens.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Header

struct ConnectionDashboardHeader: View {
    @Bindable var session: ConnectionSession

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack(spacing: SpacingTokens.xs) {
                Text(session.connection.connectionName)
                    .font(.system(size: LayoutTokens.ServerPage.nameSize, weight: .bold))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)

                if session.connection.databaseType.isBeta {
                    FeatureBadge.beta
                }
            }

            if let version = session.databaseStructure?.serverVersion ?? session.connection.serverVersion {
                Text(version)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
        }
        .help(session.connection.host)
    }
}

// MARK: - Cards

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
