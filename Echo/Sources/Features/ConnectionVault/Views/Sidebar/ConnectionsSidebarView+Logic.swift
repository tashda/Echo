import SwiftUI

extension ConnectionsSidebarView {
    
    func connections(in folderID: UUID?) -> [SavedConnection] {
        guard let projectID = currentProjectID else { return [] }
        return connectionStore.connections
            .filter { $0.folderID == folderID && $0.projectID == projectID }
            .sorted { $0.connectionName.localizedCaseInsensitiveCompare($1.connectionName) == .orderedAscending }
    }

    func buildGroups(parentID: UUID?, depth: Int) -> [ConnectionFolderGroup] {
        guard let projectID = currentProjectID else { return [] }
        let folders = connectionStore.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID && $0.projectID == projectID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return folders.map { folder in
            ConnectionFolderGroup(
                folder: folder,
                depth: depth,
                connections: connections(in: folder.id),
                children: buildGroups(parentID: folder.id, depth: depth + 1)
            )
        }
    }

    func filterGroups(_ groups: [ConnectionFolderGroup]) -> [ConnectionFolderGroup] {
        guard isSearching else { return groups }
        return groups.compactMap { filterGroup($0) }
    }

    func filterGroup(_ group: ConnectionFolderGroup) -> ConnectionFolderGroup? {
        let folderMatches = matchesSearch(in: group.folder.name)
        let filteredConnections = folderMatches ? group.connections : filterConnections(group.connections)
        let filteredChildren = folderMatches ? group.children : filterGroups(group.children)

        if folderMatches || !filteredConnections.isEmpty || !filteredChildren.isEmpty {
            return ConnectionFolderGroup(
                folder: group.folder,
                depth: group.depth,
                connections: filteredConnections,
                children: filteredChildren
            )
        }
        return nil
    }

    func filterConnections(_ connections: [SavedConnection]) -> [SavedConnection] {
        guard isSearching else { return connections }
        return connections.filter { matchesSearch(for: $0) }
    }

    func matchesSearch(for connection: SavedConnection) -> Bool {
        guard !trimmedSearch.isEmpty else { return true }
        return connection.connectionName.localizedCaseInsensitiveContains(trimmedSearch) ||
            connection.host.localizedCaseInsensitiveContains(trimmedSearch)
    }

    func matchesSearch(in text: String) -> Bool {
        guard !trimmedSearch.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(trimmedSearch)
    }
}

struct ConnectionFolderGroup: Identifiable {
    let folder: SavedFolder
    let depth: Int
    var connections: [SavedConnection]
    var children: [ConnectionFolderGroup]

    var id: UUID { folder.id }
    var totalConnectionCount: Int {
        connections.count + children.reduce(0) { $0 + $1.totalConnectionCount }
    }
}
