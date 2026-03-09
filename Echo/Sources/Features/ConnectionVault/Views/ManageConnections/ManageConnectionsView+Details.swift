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
            VStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("No Results")
                    .font(TypographyTokens.displayLarge.weight(.semibold))
                Text("No connections or identities match your search.")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.secondary)
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

    @ViewBuilder
    func emptyState(for section: ManageSection) -> some View {
        VStack(spacing: 14) {
            Image(systemName: section == .connections ? "externaldrive.badge.plus" : "person.crop.circle.badge.plus")
                .font(.system(size: 40, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(appearanceStore.accentColor)

            Text(section.emptyTitle)
                .font(TypographyTokens.displayLarge.weight(.semibold))

            Text(section.emptyMessage)
                .font(TypographyTokens.standard)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button {
                handlePrimaryAdd(for: section)
            } label: {
                Label(section.emptyActionTitle, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func identityDecoration(for connection: SavedConnection) -> (name: String, icon: String)? {
        guard let identityID = connection.identityID,
              let identity = identityLookup[identityID] else {
            return nil
        }
        return (identity.name, "person.crop.circle")
    }
}
