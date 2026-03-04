import SwiftUI

extension ManageConnectionsView {
    @ViewBuilder
    var detailBody: some View {
        switch activeSection {
        case .connections:
            connectionsDetail
        case .identities:
            identitiesDetail
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
                createFolderAndMoveConnection: createFolderAndMoveConnection
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
                createFolderAndMoveIdentity: createFolderAndMoveIdentity
            )
        }
    }

    @ViewBuilder
    func emptyState(for section: ManageSection) -> some View {
        VStack(spacing: 14) {
            Image(systemName: section == .connections ? "externaldrive.badge.plus" : "person.crop.circle.badge.plus")
                .font(.system(size: 40, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.accentColor)

            Text(section.emptyTitle)
                .font(.system(size: 18, weight: .semibold))

            Text(section.emptyMessage)
                .font(.system(size: 13))
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
        .background(themeManager.surfaceBackgroundColor)
    }

    func identityDecoration(for connection: SavedConnection) -> (name: String, icon: String)? {
        guard let identityID = connection.identityID,
              let identity = identityLookup[identityID] else {
            return nil
        }
        return (identity.name, "person.crop.circle")
    }
}
