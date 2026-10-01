import SwiftUI

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
            onSelectSession: selectSession,
            onRetryPending: { pending in
                environmentState.retryPendingConnection(for: pending.connection.id)
            }
        )
    }

    /// A click selects the server and the tree glides to its card. With the tree hidden, the
    /// click opens it too, and it slides in while it scrolls to the server (round 40, RC1 and
    /// OM0); the rail shows which server it is (SM1).
    private func selectSession(_ session: ConnectionSession) {
        let connectionID = session.connection.id

        if !appState.isWorkspaceTreeVisible {
            appState.isWorkspaceTreeVisible = true
        }

        if navigationStore.sidebarSection != .folder {
            navigationStore.sidebarSection = .folder
        }
        environmentState.sessionGroup.setActiveSession(session.id)
        navigationStore.revealExplorerConnection(connectionID)
    }


}
