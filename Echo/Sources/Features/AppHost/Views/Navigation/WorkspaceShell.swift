import SwiftUI

/// The canvas-and-cards window (Design/02-layout.md): the server rail, the Explorer tree and the
/// tabs with their cards, side by side on the window canvas and separated by the gutter setting.
/// Echo draws this itself instead of using the system sidebar; the inspector stays a system column.
///
/// Hiding the tree (⌃⌘S) leaves the rail where it is: the tree shrinks into it while the cards
/// grow into its space.
struct WorkspaceShell: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.echoMotion) private var motion

    @AppStorage("workspace.treeWidth") private var treeWidth = Double(LayoutTokens.Workspace.treeIdealWidth)
    @State private var railBridge = ServerRailBridge()

    var body: some View {
        let gutter = projectStore.globalSettings.workspaceGutter.points
        let isTreeVisible = appState.isWorkspaceTreeVisible

        HStack(spacing: SpacingTokens.none) {
            WorkspaceRailColumn(bridge: railBridge)
                .padding(.leading, gutter)

            treeArea(gutter: gutter, isVisible: isTreeVisible)

            WorkspaceMainContent()
                .accessibilityIdentifier("workspace-content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, isTreeVisible ? SpacingTokens.none : gutter)
        }
        .overlay(alignment: .topLeading) {
            // Open Queries floats beside the rail until the old rail placement goes (plan S7).
            QueryGlanceOverlay()
                .padding(.leading, gutter + LayoutTokens.ServerRail.width + LayoutTokens.QueryGlance.railGap)
                .padding(.top, SpacingTokens.xxs)
        }
        .padding(.top, appState.workspaceTabBarStyle.chromeTopPadding)
        .padding([.trailing, .bottom], gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas.ignoresSafeArea())
        .animation(motion.standard, value: isTreeVisible)
    }

    private var clampedTreeWidth: CGFloat {
        min(max(CGFloat(treeWidth), LayoutTokens.Workspace.treeMinWidth), LayoutTokens.Workspace.treeMaxWidth)
    }

    /// The tree with the gutter on each side; the trailing gutter is the resize handle.
    ///
    /// Hidden, the tree shrinks into the rail as it fades (Design/04-motion.md) and its space
    /// collapses so the cards grow. It stays alive while hidden, so the table keeps its rows,
    /// scroll position and expansion, and still answers reveal requests. Reduce Motion fades only.
    private func treeArea(gutter: CGFloat, isVisible: Bool) -> some View {
        let width = clampedTreeWidth
        return HStack(spacing: SpacingTokens.none) {
            SidebarColumn(railBridge: railBridge)
                .accessibilityIdentifier("workspace-sidebar")
                .frame(width: width)
                .padding(.leading, gutter)

            WorkspaceTreeResizeHandle(width: $treeWidth, gutter: gutter)
        }
        .scaleEffect(isVisible || motion.reduceMotion ? 1 : 0.55, anchor: .leading)
        .opacity(isVisible ? 1 : 0)
        .frame(width: isVisible ? width + gutter * 2 : 0, alignment: .leading)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .zIndex(1)
    }
}

/// The server rail at the window's leading edge. It stays in place whether or not the tree shows.
struct WorkspaceRailColumn: View {
    let bridge: ServerRailBridge

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(AppState.self) private var appState

    var body: some View {
        ServerRail(
            style: .embedded,
            selectedSection: Bindable(navigationStore).sidebarSection,
            isGlanceOpen: Bindable(navigationStore).isQueryGlanceOpen,
            bridge: bridge,
            onSelectSession: { session in
                showTree()
                environmentState.sessionGroup.setActiveSession(session.id)
                navigationStore.revealExplorerConnection(session.connection.id)
            },
            onRetryPending: { pending in
                environmentState.retryPendingConnection(for: pending.connection.id)
            },
            onConnect: { connection in
                connectionStore.selectedConnectionID = connection.id
                navigationStore.sidebarSection = .folder
                showTree()
                environmentState.connect(to: connection)
            },
            onToolSelected: showTree
        )
        .frame(maxHeight: .infinity)
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
