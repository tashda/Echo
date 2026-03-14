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

    @ViewBuilder
    func emptyState(for section: ManageSection) -> some View {
        let isInFolder = activeFolderID(for: section) != nil

        if isInFolder {
            folderEmptyState(for: section)
        } else {
            globalEmptyState(for: section)
        }
    }

    /// Empty state for a folder — offers to move unassigned items into it,
    /// or create a new one if none are unassigned.
    @ViewBuilder
    private func folderEmptyState(for section: ManageSection) -> some View {
        ContentUnavailableView {
            Label(
                section == .connections ? "No Connections" : "No Identities",
                systemImage: section == .connections ? "externaldrive" : "person.crop.circle"
            )
        } description: {
            Text("This folder is empty.")
        } actions: {
            emptyFolderActionMenu(for: section)
        }
    }

    /// Empty state when the project has no items at all for this section.
    @ViewBuilder
    private func globalEmptyState(for section: ManageSection) -> some View {
        ContentUnavailableView {
            Label(section.emptyTitle, systemImage: section == .connections
                  ? "externaldrive"
                  : "person.crop.circle")
        } description: {
            Text(section.emptyMessage)
        } actions: {
            Button {
                handlePrimaryAdd(for: section)
            } label: {
                Text(section.emptyActionTitle)
            }
        }
    }

    /// Menu button for empty folders: lists unassigned items that can be moved
    /// into this folder, with a "New..." option at the bottom. If no unassigned
    /// items exist, tapping creates a new item directly.
    @ViewBuilder
    private func emptyFolderActionMenu(for section: ManageSection) -> some View {
        let folderID = activeFolderID(for: section)

        switch section {
        case .connections:
            let unassigned = projectConnections.filter { $0.folderID == nil }

            if unassigned.isEmpty {
                Button {
                    createNewConnection()
                } label: {
                    Text("New Connection")
                }
            } else {
                Menu("Add to Folder") {
                    ForEach(unassigned) { connection in
                        Button {
                            if let folderID, let folder = folder(withID: folderID) {
                                moveConnectionToFolder(connection, folder)
                            }
                        } label: {
                            Text(connection.connectionName)
                        }
                    }
                    Divider()
                    Button {
                        createNewConnection()
                    } label: {
                        Label("New Connection", systemImage: "plus")
                    }
                }
            }

        case .identities:
            let unassigned = projectIdentities.filter { $0.folderID == nil }

            if unassigned.isEmpty {
                Button {
                    createNewIdentity()
                } label: {
                    Text("New Identity")
                }
            } else {
                Menu("Add to Folder") {
                    ForEach(unassigned) { identity in
                        Button {
                            if let folderID, let folder = folder(withID: folderID) {
                                moveIdentityToFolder(identity, folder)
                            }
                        } label: {
                            Text(identity.name)
                        }
                    }
                    Divider()
                    Button {
                        createNewIdentity()
                    } label: {
                        Label("New Identity", systemImage: "plus")
                    }
                }
            }
        case .projects:
            Button {
                isPresentingNewProjectSheet = true
            } label: {
                Text("New Project")
            }
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
