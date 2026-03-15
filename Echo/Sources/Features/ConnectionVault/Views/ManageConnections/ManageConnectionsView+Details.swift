import SwiftUI

extension ManageConnectionsView {
    @ViewBuilder
    var detailBody: some View {
        if isSearching {
            searchResultsDetail
        } else {
            switch activeSection {
            case .connections:
                connectionsDetail
            case .identities:
                identitiesDetail
            case .projects:
                projectsDetail
            }
        }
    }

    private var isSearching: Bool {
        normalizedQuery != nil
    }

    @ViewBuilder
    private var searchResultsDetail: some View {
        let connections = searchFilteredConnections
        let identities = searchFilteredIdentities

        if connections.isEmpty && identities.isEmpty {
            VStack(spacing: SpacingTokens.sm2) {
                Image(systemName: "magnifyingglass")
                    .font(TypographyTokens.hero.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Text("No Results")
                    .font(TypographyTokens.displayLarge.weight(.semibold))
                Text("No connections or identities match your search.")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if !connections.isEmpty {
                    ConnectionsTableView(
                        connections: connections,
                        selection: $connectionSelection,
                        sortOrder: $connectionSortOrder,
                        folderLookup: folderLookup(for: .connections),
                        onConnect: connectToConnection,
                        onEdit: editConnection,
                        onDuplicate: duplicateConnection,
                        onDelete: { handleDeletion(.connection($0)) },
                        identityDecorationProvider: identityDecoration(for:),
                        onDoubleClick: connectToConnection,
                        moveConnectionToFolder: moveConnectionToFolder,
                        createFolderAndMoveConnection: createFolderAndMoveConnection,
                        onNewConnection: createNewConnection,
                        onNewFolder: { presentCreateFolder(for: .connections) }
                    )
                }
                if !identities.isEmpty {
                    if !connections.isEmpty {
                        Divider()
                    }
                    IdentitiesTableView(
                        identities: identities,
                        selection: $identitySelection,
                        sortOrder: $identitySortOrder,
                        folderLookup: folderLookup(for: .identities),
                        onEdit: editIdentity,
                        onDelete: { handleDeletion(.identity($0)) },
                        moveIdentityToFolder: moveIdentityToFolder,
                        createFolderAndMoveIdentity: createFolderAndMoveIdentity,
                        onNewIdentity: createNewIdentity,
                        onNewFolder: { presentCreateFolder(for: .identities) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    var connectionsDetail: some View {
        if filteredConnectionsForTable.isEmpty {
            emptyState(for: .connections)
        } else {
            ConnectionsTableView(
                connections: filteredConnectionsForTable,
                selection: $connectionSelection,
                sortOrder: $connectionSortOrder,
                folderLookup: folderLookup(for: ManageSection.connections),
                onConnect: connectToConnection,
                onEdit: editConnection,
                onDuplicate: duplicateConnection,
                onDelete: { handleDeletion(.connection($0)) },
                identityDecorationProvider: identityDecoration(for:),
                onDoubleClick: connectToConnection,
                moveConnectionToFolder: moveConnectionToFolder,
                createFolderAndMoveConnection: createFolderAndMoveConnection,
                onNewConnection: createNewConnection,
                onNewFolder: { presentCreateFolder(for: .connections) }
            )
        }
    }

    @ViewBuilder
    var identitiesDetail: some View {
        if filteredIdentitiesForTable.isEmpty {
            emptyState(for: .identities)
        } else {
            IdentitiesTableView(
                identities: filteredIdentitiesForTable,
                selection: $identitySelection,
                sortOrder: $identitySortOrder,
                folderLookup: folderLookup(for: ManageSection.identities),
                onEdit: editIdentity,
                onDelete: { handleDeletion(.identity($0)) },
                moveIdentityToFolder: moveIdentityToFolder,
                createFolderAndMoveIdentity: createFolderAndMoveIdentity,
                onNewIdentity: createNewIdentity,
                onNewFolder: { presentCreateFolder(for: .identities) }
            )
        }
    }

    func identityDecoration(for connection: SavedConnection) -> (name: String, icon: String)? {
        guard let identityID = connection.identityID,
              let identity = identityLookup[identityID] else {
            return nil
        }
        return (identity.name, "person.crop.circle")
    }
}
