import SwiftUI

extension SidebarMenu {
    @ViewBuilder
    func contentView(for section: NavSection) -> some View {
        switch section {
        case .folder:
            // Rendered separately by `SidebarMenu` so it stays alive while other tools show.
            EmptyView()
        case .bookmark, .clipboard, .snippets, .history:
            EmptyView() // Removed rail destinations; library lives in the inspector (round 39).
        case .connections:
            ConnectionsSidebarView(
                selectedConnectionID: $selectedConnectionID,
                selectedIdentityID: $selectedIdentityID,
                onCreateConnection: { folder in
                    connectionStore.selectedFolderID = folder?.id
                    selectedConnectionID = nil
                    onAddConnection()
                },
                onEditConnection: { connection in
                    connectionStore.selectedFolderID = connection.folderID
                    selectedConnectionID = connection.id
                    onAddConnection()
                },
                onConnect: { connection in
                    connectAndNavigate(to: connection)
                },
                onMoveConnection: { connectionID, folderID in
                    Task { @MainActor in
                        if var connection = connectionStore.connections.first(where: { $0.id == connectionID }) {
                            connection.folderID = folderID
                            try? await connectionStore.updateConnection(connection)
                        }
                    }
                },
                onMoveFolder: { folderID, parentID in
                    Task { @MainActor in
                        if var folder = connectionStore.folders.first(where: { $0.id == folderID }) {
                            folder.parentFolderID = parentID
                            try? await connectionStore.saveFolders()
                        }
                    }
                },
                onDuplicateConnection: { connection in
                    pendingDuplicateConnection = connection
                }
            )
        }
    }
}
