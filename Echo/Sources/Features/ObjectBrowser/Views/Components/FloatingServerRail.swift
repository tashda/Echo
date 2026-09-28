import SwiftUI

/// The server rail shown over the editor while the sidebar is hidden. Picking a server or a
/// tool brings the sidebar back at that place.
struct FloatingServerRail: View {
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(AppState.self) private var appState
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        ServerRail(
            style: .floating,
            sessions: environmentState.sessionGroup.sessions,
            pendingConnections: environmentState.pendingConnections,
            savedConnections: connectionStore.connections,
            selectedConnectionID: connectionStore.selectedConnectionID,
            runningQueryCounts: tabStore.runningQueryCountsByConnection,
            selectedSection: Bindable(navigationStore).sidebarSection,
            isGlanceOpen: Bindable(navigationStore).isQueryGlanceOpen,
            onSelectSession: { session in
                showSidebar()
                environmentState.connect(to: session.connection)
            },
            onRetryPending: { pending in
                environmentState.retryPendingConnection(for: pending.connection.id)
            },
            onConnect: { connection in
                environmentState.connect(to: connection)
            },
            onToolSelected: showSidebar
        )
        .overlay(alignment: .topLeading) {
            QueryGlancePanel(
                sessions: environmentState.sessionGroup.sessions,
                isOpen: navigationStore.isQueryGlanceOpen,
                onClose: { navigationStore.isQueryGlanceOpen = false }
            )
            .frame(width: LayoutTokens.QueryGlance.width)
            .offset(
                x: LayoutTokens.ServerRail.itemSize
                    + LayoutTokens.ServerRail.floatingPadding * 2
                    + SpacingTokens.xs
            )
        }
    }

    private func showSidebar() {
        withAnimation(.smooth(duration: 0.3)) {
            appState.workspaceSidebarVisibility = .all
        }
    }
}
