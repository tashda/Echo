import SwiftUI
import EchoSense

/// The connections menu: open sessions, saved connections by folder, Manage Connections and
/// Quick Connect. The menu bar's File › Connect To shows it; the rail's + opens the searchable
/// trail instead (round 52).
struct ConnectionsMenuContent: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        Section("Connections") {
            let activeSessions = environmentState.sessionGroup.activeSessions
            let connectedIDs = Set(activeSessions.map { $0.connection.id })

            // Active Sessions
            if !activeSessions.isEmpty {
                ForEach(activeSessions) { session in
                    sessionButton(session)
                }
                Divider()
            }

            // Saved connections (round MC: no folders)
            let projectID = projectStore.selectedProject?.id
            let rootConnections = connectionStore.connections
                .filter { $0.projectID == projectID && !connectedIDs.contains($0.id) }
                .sorted { $0.connectionName.localizedCaseInsensitiveCompare($1.connectionName) == .orderedAscending }

            ForEach(rootConnections) { connection in
                connectionButton(connection)
            }
        }

        Divider()

        Button {
            ManageConnectionsWindowController.shared.present()
        } label: {
            Label("Manage Connections", systemImage: "gearshape")
        }

        Button {
            AppDirector.shared.appState.showSheet(.quickConnect)
        } label: {
            Label("Quick Connect", systemImage: "bolt.fill")
        }
    }

    // MARK: - Menu Helpers

    @ViewBuilder
    private func connectionButton(_ connection: SavedConnection) -> some View {
        Button {
            environmentState.connectToNewSession(to: connection)
        } label: {
            Label {
                Text(connection.connectionName.isEmpty ? connection.host : connection.connectionName)
            } icon: {
                DatabaseTypeIcon(databaseType: connection.databaseType, presentation: .menu)
            }
        }
    }

    @ViewBuilder
    private func sessionButton(_ session: ConnectionSession) -> some View {
        let conn = session.connection
        let isActive = conn.id == connectionStore.selectedConnectionID

        Button {
            connectionStore.selectedConnectionID = conn.id
            environmentState.sessionGroup.setActiveSession(session.id)
        } label: {
            HStack {
                DatabaseTypeIcon(databaseType: conn.databaseType, presentation: .menu)
                Text(session.displayName)
                if isActive {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
