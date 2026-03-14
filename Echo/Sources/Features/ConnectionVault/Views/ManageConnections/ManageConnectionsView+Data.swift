import SwiftUI

extension ManageConnectionsView {
    var selectedProjectID: UUID? {
        projectStore.selectedProject?.id
    }

    var projectConnections: [SavedConnection] {
        connectionStore.connections.filter { $0.projectID == selectedProjectID }
    }

    var projectIdentities: [SavedIdentity] {
        connectionStore.identities.filter { $0.projectID == selectedProjectID }
    }

    var connectionFolders: [SavedFolder] {
        connectionStore.folders.filter { $0.kind == .connections && $0.projectID == selectedProjectID }
    }

    var identityFolders: [SavedFolder] {
        connectionStore.folders.filter { $0.kind == .identities && $0.projectID == selectedProjectID }
    }

    var connectionFolderNodes: [FolderNode] {
        buildFolderNodes(
            from: connectionFolders.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            itemMap: Dictionary(grouping: projectConnections, by: { $0.folderID })
        )
    }

    var identityFolderNodes: [FolderNode] {
        buildFolderNodes(
            from: identityFolders.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending },
            itemMap: Dictionary(grouping: projectIdentities, by: { $0.folderID })
        )
    }

    var identityLookup: [UUID: SavedIdentity] {
        Dictionary(uniqueKeysWithValues: projectIdentities.map { ($0.id, $0) })
    }

    var normalizedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    var filteredConnectionsForTable: [SavedConnection] {
        var items = projectConnections

        if let folderID = activeFolderID(for: .connections) {
            let scope = folderScope(for: folderID, in: .connections)
            items = items.filter { connection in
                guard let id = connection.folderID else { return false }
                return scope.contains(id)
            }
        }

        if let query = normalizedQuery {
            items = items.filter { connectionMatches($0, query: query) }
        }

        return items.sorted(using: connectionSortOrder)
    }

    var filteredIdentitiesForTable: [SavedIdentity] {
        var items = projectIdentities

        if let folderID = activeFolderID(for: .identities) {
            let scope = folderScope(for: folderID, in: .identities)
            items = items.filter { identity in
                guard let id = identity.folderID else { return false }
                return scope.contains(id)
            }
        }

        if let query = normalizedQuery {
            items = items.filter { identityMatches($0, query: query) }
        }

        return items.sorted(using: identitySortOrder)
    }

    var searchFilteredConnections: [SavedConnection] {
        guard let query = normalizedQuery else { return [] }
        return projectConnections
            .filter { connectionMatches($0, query: query) }
            .sorted(using: connectionSortOrder)
    }

    var searchFilteredIdentities: [SavedIdentity] {
        guard let query = normalizedQuery else { return [] }
        return projectIdentities
            .filter { identityMatches($0, query: query) }
            .sorted(using: identitySortOrder)
    }

    func connectionMatches(_ connection: SavedConnection, query: String) -> Bool {
        if connection.connectionName.lowercased().contains(query) { return true }
        if connection.host.lowercased().contains(query) { return true }
        if connection.database.lowercased().contains(query) { return true }
        if connection.username.lowercased().contains(query) { return true }
        if let identityID = connection.identityID,
           let identity = identityLookup[identityID],
           identity.name.lowercased().contains(query) {
            return true
        }
        return false
    }

    func identityMatches(_ identity: SavedIdentity, query: String) -> Bool {
        if identity.name.lowercased().contains(query) { return true }
        if identity.username.lowercased().contains(query) { return true }
        return false
    }

    func folderLookup(for section: ManageSection) -> [UUID: SavedFolder] {
        let folders: [SavedFolder]
        switch section {
        case .connections: folders = connectionFolders
        case .identities: folders = identityFolders
        case .projects: folders = []
        }
        return Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
    }

    func buildFolderNodes<Item: Hashable>(
        from folders: [SavedFolder],
        itemMap: [UUID?: [Item]]
    ) -> [FolderNode] {
        let grouped = Dictionary(grouping: folders, by: { $0.parentFolderID })

        func makeNodes(parent: UUID?) -> [FolderNode] {
            guard let folderList = grouped[parent] else { return [] }

            return folderList.map { folder in
                let children = makeNodes(parent: folder.id)
                return FolderNode(
                    folder: folder,
                    childNodes: children.isEmpty ? nil : children,
                    items: itemMap[folder.id] ?? []
                )
            }
        }

        return makeNodes(parent: nil)
    }

    func activeFolderID(for section: ManageSection) -> UUID? {
        guard let selection = sidebarSelection else { return nil }
        switch selection {
        case .section:
            return nil
        case .folder(let folderID, let targetSection):
            return targetSection == section ? folderID : nil
        case .project:
            return nil
        }
    }

    func folderScope(for folderID: UUID, in section: ManageSection) -> Set<UUID> {
        var scope: Set<UUID> = [folderID]
        let folders: [SavedFolder]
        switch section {
        case .connections: folders = connectionFolders
        case .identities: folders = identityFolders
        case .projects: folders = []
        }
        var stack: [UUID] = [folderID]

        while let current = stack.popLast() {
            let children = folders.filter { $0.parentFolderID == current }
            for child in children {
                if scope.insert(child.id).inserted {
                    stack.append(child.id)
                }
            }
        }

        return scope
    }

    func folder(withID id: UUID) -> SavedFolder? {
        connectionStore.folders.first(where: { $0.id == id })
    }
}
