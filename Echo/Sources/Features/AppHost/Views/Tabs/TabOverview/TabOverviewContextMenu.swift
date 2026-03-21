import SwiftUI

extension TabOverviewView {
    @ViewBuilder
    func tabContextMenu(for tab: WorkspaceTab, serverID: UUID, databaseIdentifier: String) -> some View {
        Button {
            onSelectTab(tab.id)
        } label: {
            Label("Select Tab", systemImage: "hand.tap")
        }

        Divider()

        Button {
            duplicateTab(tab)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }

        if !tab.isPinned {
            Button {
                pinTab(tab)
            } label: {
                Label("Pin Tab", systemImage: "pin")
            }
        } else {
            Button {
                unpinTab(tab)
            } label: {
                Label("Unpin Tab", systemImage: "pin.slash")
            }
        }

        Divider()

        Menu("Move to", systemImage: "arrow.right") {
            moveTabMenuContent(for: tab, currentServerID: serverID, currentDatabaseIdentifier: databaseIdentifier)
        }

        Divider()

        Button(role: .destructive) {
            onCloseTab(tab.id)
        } label: {
            Label("Close Tab", systemImage: "xmark")
        }
    }

    @ViewBuilder
    private func moveTabMenuContent(for tab: WorkspaceTab, currentServerID: UUID, currentDatabaseIdentifier: String) -> some View {
        let servers = groupedTabs
        ForEach(servers) { server in
            Menu(server.connection.connectionName) {
                let databases = server.databaseGroups.values.sorted { $0.databaseName.localizedCaseInsensitiveCompare($1.databaseName) == .orderedAscending }
                ForEach(databases) { db in
                    let dbIdentifier = databaseIdentifier(for: db.databaseName, serverID: server.connection.id)
                    let isCurrentDb = dbIdentifier == currentDatabaseIdentifier
                    
                    Button {
                        moveTab(tab, toServer: server.connection.id, database: db.databaseName)
                    } label: {
                        HStack {
                            Text(db.databaseName)
                            if isCurrentDb {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isCurrentDb)
                }
            }
        }
    }

    private func duplicateTab(_ tab: WorkspaceTab) {
        environmentState.duplicateTab(tab)
    }

    private func pinTab(_ tab: WorkspaceTab) {
        tabStore.togglePin(for: tab.id)
    }

    private func unpinTab(_ tab: WorkspaceTab) {
        tabStore.togglePin(for: tab.id)
    }

    private func moveTab(_ tab: WorkspaceTab, toServer serverID: UUID, database: String) {
        // Implementation for moving tab between server/database groups
        // This might require more complex logic in TabStore
    }
}
