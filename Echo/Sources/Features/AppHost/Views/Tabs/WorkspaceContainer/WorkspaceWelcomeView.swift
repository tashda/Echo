import AppKit
import SwiftUI

/// A recently used connection on the welcome screen.
struct RecentConnectionItem: Identifiable {
    let id: String
    let record: RecentConnectionRecord
    let name: String
    let server: String
    let lastConnectedAt: Date
    /// The connection's own colour, as the rail shows it.
    let color: Color
}

/// What the canvas shows while no tab is open and no server is active (Design/05-components.md ›
/// Welcome, W1b). There is no card around it: cards exist only for content. Echo's icon and
/// name, the connect actions on glass buttons, and the latest connections on one small opaque
/// card, each with the same monogram and colour it will have in the rail.
struct WorkspaceWelcomeView: View {
    /// The welcome lists only the latest few; the rest are in the toolbar's Recent menu.
    static let maximumRecentCount = 5

    let recents: [RecentConnectionItem]
    let onSelectRecent: (RecentConnectionItem) -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            VStack(spacing: SpacingTokens.sm) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: LayoutTokens.Welcome.iconSize, height: LayoutTokens.Welcome.iconSize)
                    .accessibilityHidden(true)

                Text("Echo")
                    .font(.system(size: LayoutTokens.Welcome.titleSize, weight: .bold))
                    .foregroundStyle(ColorTokens.Text.primary)
            }

            actions

            if !recents.isEmpty {
                recentList
            }
        }
        .frame(maxWidth: LayoutTokens.Welcome.width)
        .padding(SpacingTokens.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actions: some View {
        HStack(spacing: SpacingTokens.xs) {
            Menu {
                ConnectionsMenuContent()
            } label: {
                Label("Connect…", systemImage: "plus")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.glassProminent)
            .fixedSize()

            Button {
                appState.showSheet(.quickConnect)
            } label: {
                Label("Quick Connect", systemImage: "bolt")
            }
            .buttonStyle(.glass)

            Button {
                ManageConnectionsWindowController.shared.present()
            } label: {
                Label("Manage", systemImage: "gearshape")
            }
            .buttonStyle(.glass)
        }
        .controlSize(.large)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Recent")
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.leading, LayoutTokens.FloatingSurface.padding)

            VStack(spacing: SpacingTokens.none) {
                ForEach(recents) { item in
                    WelcomeRecentRow(item: item) { onSelectRecent(item) }
                }
            }
            .padding(LayoutTokens.Welcome.listPadding)
            .workspaceCard()
        }
    }
}

/// One recent connection: monogram in the server's colour, name, host and when it was last used.
private struct WelcomeRecentRow: View {
    let item: RecentConnectionItem
    let action: () -> Void

    @Environment(\.echoMotion) private var motion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs) {
                Text(ServerRailMonogram.make(from: item.name))
                    .font(.system(size: LayoutTokens.Welcome.monogramSize, weight: .bold, design: .rounded))
                    .foregroundStyle(item.color)
                    .frame(width: LayoutTokens.Welcome.monogramWidth)

                Text(item.name)
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Text(item.server)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: SpacingTokens.xs)

                Text(item.lastConnectedAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                    .font(TypographyTokens.detail)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LayoutTokens.FloatingSurface.rowHeight)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
                    .fill(isHovering ? ColorTokens.Sidebar.hoverFill : .clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(motion.hover, value: isHovering)
        .help("Connect to \(item.name)")
        .accessibilityLabel("Connect to \(item.name)")
        .accessibilityValue(item.server)
    }
}
