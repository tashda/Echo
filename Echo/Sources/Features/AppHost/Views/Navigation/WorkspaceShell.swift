import SwiftUI

/// The canvas-and-cards window (Design/02-layout.md): the server rail, the Explorer tree and the
/// tabs with their cards, side by side on the window canvas and separated by the gutter setting.
/// Echo draws this itself instead of using the system sidebar; the inspector stays a system column.
///
/// Hiding the tree (⌃⌘S) leaves the rail where it is: the tree slides behind it while the cards
/// grow into its space. While it is hidden, a server click can peek: the tree slides back out on
/// glass over the cards, without moving them, until a click outside or Esc.
struct WorkspaceShell: View {
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(ProjectStore.self) private var projectStore
    @Environment(TabStore.self) private var tabStore
    @Environment(\.echoMotion) private var motion

    @AppStorage("workspace.treeWidth") private var treeWidth = Double(LayoutTokens.Workspace.treeIdealWidth)
    @State private var railBridge = ServerRailBridge()

    var body: some View {
        let gutter = projectStore.globalSettings.workspaceGutter.points
        let isTreeVisible = appState.isWorkspaceTreeVisible
            && WorkspaceTreeAvailability.hasContent(environmentState: environmentState, navigationStore: navigationStore)
        let isPeeking = !isTreeVisible && appState.peekedServerID != nil
        // The tab strip keeps a little room above its plate. The rail and tree start that much
        // lower, so the rail, the tree and the plate all sit one gutter below the toolbar.
        let stripInset = (WorkspaceChromeMetrics.tabStripTotalHeight - WorkspaceChromeMetrics.chromeBackgroundHeight) / 2

        HStack(spacing: SpacingTokens.none) {
            WorkspaceRailColumn(bridge: railBridge)
                .padding(.leading, gutter)
                .padding(.top, stripInset)

            // Everything right of the rail. The house spring keeps its bounce, but this area is
            // masked at the rail's edge, so a card overshooting to the left, or the tree sliding
            // away, disappears behind the rail instead of crossing it. The mask reaches past the
            // other edges, so card shadows there are untouched.
            HStack(spacing: SpacingTokens.none) {
                treeArea(gutter: gutter, isVisible: isTreeVisible, isPeeking: isPeeking)
                    .padding(.top, stripInset)

                WorkspaceMainContent()
                .accessibilityIdentifier("workspace-content")
                .frame(minWidth: SpacingTokens.none, maxWidth: .infinity, minHeight: SpacingTokens.none, maxHeight: .infinity)
                .padding(.leading, isTreeVisible ? SpacingTokens.none : gutter)
                .overlay {
                    if isPeeking {
                        // A click anywhere on the cards closes the peek.
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { closePeek() }
                            .accessibilityHidden(true)
                    }
                }
            }
            .mask {
                Rectangle()
                    .padding([.top, .bottom, .trailing], -ObjectBrowserCardLayerView.shadowOutset)
            }
        }
        .padding(.top, max(gutter - stripInset, SpacingTokens.none))
        .padding([.trailing, .bottom], gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas.ignoresSafeArea())
        .background {
            if isPeeking {
                Button("Close Peek", action: closePeek)
                    .keyboardShortcut(.cancelAction)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .environment(\.workspaceCardCornerRadius, projectStore.globalSettings.workspaceCornerRadius.points)
        .animation(motion.standard, value: isTreeVisible)
        .animation(motion.standard, value: isPeeking)
        .onChange(of: isTreeVisible) { _, isVisible in
            if isVisible { appState.peekedServerID = nil }
        }
        .onChange(of: tabStore.activeTabId) { _, _ in
            // Opening something from the peek puts it away.
            closePeek()
        }
    }

    private var clampedTreeWidth: CGFloat {
        min(max(CGFloat(treeWidth), LayoutTokens.Workspace.treeMinWidth), LayoutTokens.Workspace.treeMaxWidth)
    }

    private func closePeek() {
        if appState.peekedServerID != nil {
            appState.peekedServerID = nil
        }
    }

    /// The tree with the gutter on each side; the trailing gutter is the resize handle.
    ///
    /// Hidden, the tree slides left behind the rail as it fades (Design/04-motion.md) and its space
    /// collapses so the cards grow. It stays alive while hidden, so the table keeps its rows,
    /// scroll position and expansion, and still answers reveal requests. Reduce Motion fades only.
    ///
    /// Peeking shows the same tree again at full size on a glass card, while its space stays
    /// collapsed, so it lies over the cards instead of pushing them aside.
    private func treeArea(gutter: CGFloat, isVisible: Bool, isPeeking: Bool) -> some View {
        let width = clampedTreeWidth
        let isShown = isVisible || isPeeking
        let peekShape = RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius, style: .continuous)

        return HStack(spacing: SpacingTokens.none) {
            SidebarColumn(railBridge: railBridge)
                .accessibilityIdentifier("workspace-sidebar")
                .frame(width: width)
                .background {
                    if isPeeking {
                        Color.clear
                            .glassEffect(.regular, in: peekShape)
                            .transition(.opacity)
                    }
                }
                .padding(.leading, gutter)

            WorkspaceTreeResizeHandle(width: $treeWidth, gutter: gutter)
                .allowsHitTesting(isVisible)
        }
        // Hidden, the tree slides left behind the rail (the mask above cuts it off there) and
        // fades. Reduce Motion fades only.
        .offset(x: isShown || motion.reduceMotion ? 0 : -(width + gutter))
        .opacity(isShown ? 1 : 0)
        .frame(width: isVisible ? width + gutter * 2 : 0, alignment: .leading)
        .allowsHitTesting(isShown)
        .accessibilityHidden(!isShown)
        .zIndex(1)
    }
}

/// The server rail at the window's leading edge. It stays in place whether or not the tree shows.
struct WorkspaceRailColumn: View {
    let bridge: ServerRailBridge

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(ProjectStore.self) private var projectStore
    @Environment(AppState.self) private var appState
    @Environment(\.echoMotion) private var motion

    var body: some View {
        ServerRail(
            bridge: bridge,
            itemSize: projectStore.globalSettings.railItemSize.points,
            selectedTool: selectedTool,
            onSelectSession: selectSession,
            onRetryPending: { pending in
                environmentState.retryPendingConnection(for: pending.connection.id)
            },
            onSelectTool: selectTool
        )
    }

    /// With the tree showing, a click selects the server and the tree glides to it. With the
    /// tree hidden, the `collapsedServerClick` setting decides between peeking and showing the
    /// tree (Design/05-components.md › Server rail). A plain click on the server that is
    /// peeking puts the peek away.
    private func selectSession(_ session: ConnectionSession, click: ServerRailClick) {
        let connectionID = session.connection.id

        if !appState.isWorkspaceTreeVisible {
            let showsTree: Bool
            switch projectStore.globalSettings.collapsedServerClick {
            case .peekCommandReopens: showsTree = click != .plain
            case .alwaysPeek: showsTree = false
            case .alwaysReopen: showsTree = true
            }

            if showsTree {
                appState.peekedServerID = nil
                appState.isWorkspaceTreeVisible = true
            } else if click == .plain && appState.peekedServerID == connectionID {
                appState.peekedServerID = nil
                return
            } else {
                appState.peekedServerID = connectionID
            }
        }

        if navigationStore.sidebarSection != .folder {
            navigationStore.sidebarSection = .folder
        }
        environmentState.sessionGroup.setActiveSession(session.id)
        navigationStore.revealExplorerConnection(connectionID)
    }

    /// The tool page showing in the tree's place, while the tree shows.
    private var selectedTool: SidebarMenu.NavSection? {
        guard appState.isWorkspaceTreeVisible else { return nil }
        let section = navigationStore.sidebarSection
        return SidebarMenu.NavSection.railTools.contains(section) ? section : nil
    }

    /// Picking the tool that is showing goes back to the tree; any other tool shows its page.
    private func selectTool(_ section: SidebarMenu.NavSection) {
        let next: SidebarMenu.NavSection = selectedTool == section ? .folder : section
        withAnimation(motion.standard) {
            navigationStore.sidebarSection = next
        }
        showTree()
    }

    private func showTree() {
        if !appState.isWorkspaceTreeVisible {
            appState.isWorkspaceTreeVisible = true
        }
    }
}

/// The gap between the tree and the cards, which resizes the tree when dragged. Double-click
/// returns it to its default width.
struct WorkspaceTreeResizeHandle: View {
    @Binding var width: Double
    let gutter: CGFloat

    @State private var widthAtDragStart: Double?

    var body: some View {
        Color.clear
            .frame(width: gutter)
            .frame(maxHeight: .infinity)
            .overlay {
                // Wider than the gutter so it is easy to grab.
                Color.clear
                    .frame(width: max(gutter, LayoutTokens.Workspace.treeResizeHandleWidth))
                    .contentShape(Rectangle())
                    .pointerStyle(.columnResize)
                    .gesture(drag)
                    .onTapGesture(count: 2) {
                        width = Double(LayoutTokens.Workspace.treeIdealWidth)
                    }
            }
            .accessibilityElement()
            .accessibilityLabel("Sidebar width")
            .accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction { direction in
                let step = Double(SpacingTokens.md)
                switch direction {
                case .increment: width = clamp(width + step)
                case .decrement: width = clamp(width - step)
                @unknown default: break
                }
            }
    }

    private var drag: some Gesture {
        // Global coordinates, because the handle itself moves as the tree resizes.
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let start = widthAtDragStart ?? width
                if widthAtDragStart == nil { widthAtDragStart = start }
                width = clamp(start + Double(value.translation.width))
            }
            .onEnded { _ in
                widthAtDragStart = nil
            }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, Double(LayoutTokens.Workspace.treeMinWidth)), Double(LayoutTokens.Workspace.treeMaxWidth))
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
            || navigationStore.sidebarSection != .folder
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
