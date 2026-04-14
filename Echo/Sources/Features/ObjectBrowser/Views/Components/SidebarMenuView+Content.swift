import SwiftUI

extension SidebarMenu {
    @ViewBuilder
    var contentView: some View {
        switch selectedNavSection {
        case .folder:
            ExperimentalObjectBrowserSidebarView(selectedConnectionID: $selectedConnectionID)
        case .experimentalFolder:
            ObjectBrowserSidebarView(selectedConnectionID: $selectedConnectionID)
        case .bookmark:
            BookmarksSidebarView()
        case .search:
            SearchSidebarView()
        case .clipboard:
            ClipboardHistoryView()
        case .snippets:
            SnippetsSidebarView()
        case .history:
            HistorySidebarView(
                icon: "clock.fill",
                title: "History",
                description: "Recent database operations and query history"
            )
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
