import SwiftUI

/// The server page, shown on the canvas while a server is active and no tab is open
/// (Design/05-components.md › Server page, S1a). Light, like the welcome: the server's name large,
/// its version as one quiet line, its tools on Liquid Glass buttons, then the databases on one
/// small card with a filter. The top lines up with the top of the rail.
///
/// The page builds up when it appears (round 48, AR2): the name, the version, the tools and the
/// databases each rise a few points and fade in, 0.06 s apart.
struct ConnectionDashboardView: View {
    @Bindable var session: ConnectionSession

    @Environment(\.echoMotion) private var motion
    @State private var revealed = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                ConnectionDashboardHeader(session: session, revealed: revealed)
                ConnectionDashboardTools(session: session)
                    .modifier(DashboardPiece(index: 2, revealed: revealed))
                ConnectionDashboardDatabases(session: session)
                    .modifier(DashboardPiece(index: 3, revealed: revealed))
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
        .task(name: "server-page-build-up") { await buildUp() }
    }

    private func buildUp() async {
        guard !motion.reduceMotion else {
            revealed = WelcomeMarkMotion.pieceCount
            return
        }
        let scale = motion.durationScale
        try? await Task.sleep(for: .seconds(WelcomeMarkMotion.pageStartDelay * scale))
        for piece in 1...WelcomeMarkMotion.pieceCount {
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: WelcomeMarkMotion.pieceDuration * scale)) { revealed = piece }
            try? await Task.sleep(for: .seconds(WelcomeMarkMotion.pieceGap * scale))
        }
    }
}

/// One piece of the server page rising into place once `revealed` has passed its index.
struct DashboardPiece: ViewModifier {
    let index: Int
    let revealed: Int

    func body(content: Content) -> some View {
        content
            .opacity(revealed > index ? 1 : 0)
            .offset(y: revealed > index ? 0 : WelcomeMarkMotion.pieceDistance)
    }
}

// MARK: - Header

struct ConnectionDashboardHeader: View {
    @Bindable var session: ConnectionSession
    var revealed = WelcomeMarkMotion.pieceCount

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
            .modifier(DashboardPiece(index: 0, revealed: revealed))

            if let version = session.databaseStructure?.serverVersion ?? session.connection.serverVersion {
                Text(version)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .modifier(DashboardPiece(index: 1, revealed: revealed))
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
