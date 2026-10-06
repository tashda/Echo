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
/// Welcome, W1b). There is no card around it: cards exist only for content. Echo's mark alone
/// (the three pills, no tile and no name; they echo in as on echodb.dev, round 48), the connect
/// actions on glass buttons, and the latest connections on one small opaque card, each with the
/// same monogram and colour it will have in the rail.
struct WorkspaceWelcomeView: View {
    /// The welcome lists only the latest few; the rest are in the toolbar's Recent menu.
    static let maximumRecentCount = 5

    let recents: [RecentConnectionItem]
    let onSelectRecent: (RecentConnectionItem) -> Void

    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.echoMotion) private var motion

    @State private var markPhase: WelcomeMarkPhase = .hidden
    @State private var actionsShown = false
    @State private var recentsShown = false
    @State private var isGone = false

    /// A server is connecting: the welcome leaves, and comes back if the connection fails.
    private var isDeparting: Bool {
        appState.welcomeDeparture != .idle || !environmentState.pendingConnections.isEmpty
    }

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            WelcomeMark(phase: markPhase)

            actions
                .modifier(WelcomeRise(isShown: actionsShown))

            if !recents.isEmpty {
                recentList
                    .modifier(WelcomeRise(isShown: recentsShown))
            }
        }
        .frame(maxWidth: LayoutTokens.Welcome.width)
        .padding(SpacingTokens.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isGone ? 0 : 1)
        .task(id: isDeparting, name: "welcome-motion") {
            if isDeparting { await depart() } else { await arrive() }
        }
    }

    /// The mark echoes in, then the buttons and the recents rise under it (round 48, WM2 and WR1),
    /// every time the welcome appears.
    private func arrive() async {
        isGone = false
        guard !motion.reduceMotion else {
            markPhase = .resting
            actionsShown = true
            recentsShown = true
            return
        }
        let scale = motion.durationScale
        markPhase = .hidden
        actionsShown = false
        recentsShown = false
        try? await Task.sleep(for: .seconds(WelcomeMarkMotion.startDelay * scale))
        guard !Task.isCancelled else { return }
        markPhase = .playing(Date())
        try? await Task.sleep(for: .seconds(WelcomeMarkMotion.restDelay * scale))
        guard !Task.isCancelled else { return }
        withAnimation(.smooth(duration: WelcomeMarkMotion.riseDuration * scale)) { actionsShown = true }
        try? await Task.sleep(for: .seconds(WelcomeMarkMotion.restGap * scale))
        guard !Task.isCancelled else { return }
        withAnimation(.smooth(duration: WelcomeMarkMotion.riseDuration * scale)) { recentsShown = true }
        // The mark has settled: from here it is drawn once, with no clock (a clock that never stops redraws the window every frame).
        let remaining = WelcomeMarkMotion.length(of: .playing(Date()), scale: scale).map { $0 - (WelcomeMarkMotion.restDelay + WelcomeMarkMotion.restGap) * scale } ?? 0
        try? await Task.sleep(for: .seconds(max(remaining, 0)))
        guard !Task.isCancelled else { return }
        markPhase = .resting
    }

    /// The pills echo out to the left, last first, and the rest fades (round 48, LV2); the rail
    /// and the tree wait for this (WorkspaceShell+WelcomeDeparture).
    private func depart() async {
        guard !motion.reduceMotion else {
            withAnimation(motion.standard) { isGone = true }
            return
        }
        let scale = motion.durationScale
        markPhase = .leaving(Date())
        try? await Task.sleep(for: .seconds(0.1 * scale))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2 * scale)) {
            actionsShown = false
            recentsShown = false
        }
        try? await Task.sleep(for: .seconds((WelcomeMarkMotion.leaveTotal - 0.1) * scale))
        guard !Task.isCancelled else { return }
        isGone = true
        markPhase = .hidden
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

/// Fades a part of the welcome in and lifts it into place.
private struct WelcomeRise: ViewModifier {
    let isShown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : WelcomeMarkMotion.riseDistance)
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
