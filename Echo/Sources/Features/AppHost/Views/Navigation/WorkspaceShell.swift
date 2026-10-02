import SwiftUI

/// The canvas-and-cards window (Design/02-layout.md): the server rail, the Explorer tree and the
/// tabs with their cards, side by side on the window canvas and separated by the gutter setting.
/// Echo draws this itself instead of using the system sidebar or inspector: the inspector is a
/// column of cards on the trailing side, mirroring the tree (plan I1).
///
/// Hiding the tree (⌃⌘S) leaves the rail where it is: the tree slides behind it while the cards
/// grow into its space. While it is hidden, a server click opens it again, scrolled to that server
/// (round 40, RC1; the peek on glass is gone).
struct WorkspaceShell: View {
    @Environment(AppState.self) var appState
    @Environment(EnvironmentState.self) var environmentState
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.echoMotion) var motion
    @Environment(TabStore.self) var tabStore

    @AppStorage("workspace.treeWidth") private var treeWidth = Double(LayoutTokens.Workspace.treeIdealWidth)
    @State private var railBridge = ServerRailBridge()
    @State var departureTask: Task<Void, Never>?

    var body: some View {
        let gutter = projectStore.globalSettings.workspaceGutter.points
        // While the welcome's pills leave, and for a moment after the rail shows the server, the
        // tree waits (round 48, LV2 and CO1).
        let isTreeVisible = appState.isWorkspaceTreeVisible
            && WorkspaceTreeAvailability.hasContent(environmentState: environmentState, navigationStore: navigationStore)
            && appState.welcomeDeparture == .idle
        // The tab strip keeps a little room above its plate. The rail and tree start that much
        // lower, so the rail, the tree and the plate all sit one gutter below the toolbar.
        let stripInset = (WorkspaceChromeMetrics.tabStripTotalHeight - WorkspaceChromeMetrics.chromeBackgroundHeight) / 2

        HStack(spacing: SpacingTokens.none) {
            WorkspaceRailColumn(bridge: railBridge)
                .padding(.leading, gutter)
                .padding(.top, stripInset)
                // Above the tree, so the tree slides away under the rail's glass.
                .zIndex(2)

            HStack(spacing: SpacingTokens.none) {
                treeArea(gutter: gutter, isVisible: isTreeVisible)
                    .padding(.top, stripInset)

                WorkspaceMainContent()
                .accessibilityIdentifier("workspace-content")
                .frame(minWidth: SpacingTokens.none, maxWidth: .infinity, minHeight: SpacingTokens.none, maxHeight: .infinity)
                .padding(.leading, isTreeVisible ? SpacingTokens.none : gutter)
                .padding(.trailing, appState.isInspectorColumnVisible ? SpacingTokens.none : gutter)

                // The inspector mirrors the tree on the trailing side (plan I1).
                WorkspaceInspectorColumn(gutter: gutter)
                    .padding(.top, stripInset)
            }
        }
        .padding(.top, max(gutter - stripInset, SpacingTokens.none))
        .padding(.bottom, gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas.ignoresSafeArea())
        .environment(\.workspaceCardCornerRadius, projectStore.globalSettings.workspaceCornerRadius.points)
        // Showing the tree keeps the house bounce. Hiding it settles without overshoot, so the
        // cards growing toward the rail stop exactly at their place instead of bouncing into it.
        .animation(isTreeVisible ? motion.standard : motion.settle, value: isTreeVisible)
        // The inspector moves as the tree does: the house spring out, settling back without overshoot.
        .animation(appState.isInspectorColumnVisible ? motion.standard : motion.settle, value: appState.isInspectorColumnVisible)
        .onChange(of: isTreeVisible) { _, _ in
            WindowDragPause.pauseWorkspace(for: motion.settleDuration + 0.15)
        }
        .onChange(of: hasConnectionActivity) { _, isActive in
            updateWelcomeDeparture(isActive: isActive)
        }
        // The columns sliding would otherwise recompute the window's drag regions every frame.
        .onChange(of: appState.isInspectorColumnVisible) { _, _ in
            WindowDragPause.pauseWorkspace(for: motion.settleDuration + 0.15)
        }
        // The Save card (round IC, H1), for ⌘S on a tab without a home, Save As…, Save to
        // Bookmarks…, Save to File… and Add to Bookmarks.
        .sheet(item: Binding(get: { appState.saveCardRequest }, set: { appState.saveCardRequest = $0 })) { request in
            SaveQueryCard(request: request)
        }
    }

    private var clampedTreeWidth: CGFloat {
        min(max(CGFloat(treeWidth), LayoutTokens.Workspace.treeMinWidth), LayoutTokens.Workspace.treeMaxWidth)
    }

    /// The tree with the gutter on each side; the trailing gutter is the resize handle.
    ///
    /// Hidden, the tree slides left behind the rail as it fades (Design/04-motion.md) and its space
    /// collapses so the cards grow. It stays alive while hidden, so the table keeps its rows,
    /// scroll position and expansion, and still answers reveal requests. Reduce Motion fades only.
    private func treeArea(gutter: CGFloat, isVisible: Bool) -> some View {
        let width = clampedTreeWidth
        let isShown = isVisible

        return HStack(spacing: SpacingTokens.none) {
            SidebarColumn(railBridge: railBridge)
                .accessibilityIdentifier("workspace-sidebar")
                .frame(width: width)
                .padding(.leading, gutter)

            WorkspaceColumnResizeHandle(
                width: $treeWidth,
                gutter: gutter,
                range: Double(LayoutTokens.Workspace.treeMinWidth)...Double(LayoutTokens.Workspace.treeMaxWidth),
                defaultWidth: Double(LayoutTokens.Workspace.treeIdealWidth),
                edge: .trailing,
                accessibilityLabel: "Sidebar width"
            )
                .allowsHitTesting(isVisible)
        }
        // Hidden, the tree slides left under the rail's glass and fades. Reduce Motion fades only.
        .offset(x: isShown || motion.reduceMotion ? 0 : -(width + gutter))
        .opacity(isShown ? 1 : 0)
        .frame(width: isVisible ? width + gutter * 2 : 0, alignment: .leading)
        .allowsHitTesting(isShown)
        .accessibilityHidden(!isShown)
        .zIndex(1)
    }
}

/// Whether the tree has anything to show (Design/02-layout.md › Tree): a server in the rail,
/// connected or connecting, or a tool page. With neither it stays hidden and can't be opened;
/// the first server to connect, or picking a tool, brings it out.
enum WorkspaceTreeAvailability {
    @MainActor
    static func hasContent(environmentState: EnvironmentState, navigationStore: NavigationStore) -> Bool {
        !environmentState.sessionGroup.sessions.isEmpty
            || !environmentState.pendingConnections.isEmpty
            || navigationStore.sidebarSection == .connections
    }
}

/// Shows and hides the tree (⌃⌘S), at the leading end of the toolbar.
struct SidebarToggleToolbarButton: View {
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(NavigationStore.self) private var navigationStore

    var body: some View {
        let hasContent = WorkspaceTreeAvailability.hasContent(
            environmentState: environmentState,
            navigationStore: navigationStore
        )
        let isShown = appState.isWorkspaceTreeVisible && hasContent

        Button {
            appState.isWorkspaceTreeVisible = !isShown
        } label: {
            Label(isShown ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left")
        }
        .labelStyle(.iconOnly)
        .disabled(!hasContent)
        .help(hasContent ? (isShown ? "Hide Sidebar (⌃⌘S)" : "Show Sidebar (⌃⌘S)") : "Connect to a server to show the sidebar")
    }
}
