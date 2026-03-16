import SwiftUI
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - Connections Selection Menu

    @ViewBuilder
    internal var connectionsSelectionMenu: some View {
        Menu {
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

                // Hierarchical Saved Connections
                let projectID = projectStore.selectedProject?.id
                let projectConnections = connectionStore.connections.filter { $0.projectID == projectID && !connectedIDs.contains($0.id) }
                let projectFolders = connectionStore.folders.filter { $0.projectID == projectID && $0.kind == .connections }
                
                let rootFolders = projectFolders.filter { $0.parentFolderID == nil }
                    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                
                ForEach(rootFolders) { folder in
                    ToolbarFolderMenu(
                        folder: folder,
                        allFolders: projectFolders,
                        allConnections: projectConnections,
                        onConnect: { conn in
                            Task { await environmentState.connectToNewSession(to: conn) }
                        }
                    )
                }
                
                let rootConnections = projectConnections.filter { $0.folderID == nil }
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
        } label: {
            Label("Connections", systemImage: "server.rack")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .help("Connections")
    }

    // MARK: - Menu Helpers

    @ViewBuilder
    private func connectionButton(_ connection: SavedConnection) -> some View {
        Button {
            Task { await environmentState.connectToNewSession(to: connection) }
        } label: {
            HStack {
                if let image = NSImage(named: connection.databaseType.iconName) {
                    Image(nsImage: image)
                } else {
                    Image(systemName: "server.rack")
                }
                Text(connection.connectionName.isEmpty ? connection.host : connection.connectionName)
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
                if let image = NSImage(named: conn.databaseType.iconName) {
                    Image(nsImage: image)
                } else {
                    Image(systemName: "server.rack")
                }
                Text(session.displayName)
                if isActive {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

// MARK: - Supporting Views

@MainActor
struct ToolbarFolderMenu: View {
    let folder: SavedFolder
    let allFolders: [SavedFolder]
    let allConnections: [SavedConnection]
    let onConnect: (SavedConnection) -> Void

    var body: some View {
        Menu {
            // Child Folders
            let childFolders = allFolders.filter { $0.parentFolderID == folder.id }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            
            ForEach(childFolders) { child in
                ToolbarFolderMenu(
                    folder: child,
                    allFolders: allFolders,
                    allConnections: allConnections,
                    onConnect: onConnect
                )
            }
            
            if !childFolders.isEmpty {
                Divider()
            }
            
            // Connections in this folder
            let folderConnections = allConnections.filter { $0.folderID == folder.id }
                .sorted { $0.connectionName.localizedCaseInsensitiveCompare($1.connectionName) == .orderedAscending }
            
            if folderConnections.isEmpty && childFolders.isEmpty {
                Text("Empty Folder").foregroundStyle(.secondary)
            } else {
                ForEach(folderConnections) { connection in
                    Button {
                        onConnect(connection)
                    } label: {
                        HStack {
                            if let image = NSImage(named: connection.databaseType.iconName) {
                                Image(nsImage: image)
                            } else {
                                Image(systemName: "server.rack")
                            }
                            Text(connection.connectionName.isEmpty ? connection.host : connection.connectionName)
                        }
                    }
                }
            }
        } label: {
            Label(folder.displayName, systemImage: folder.icon)
        }
    }
}
