import SwiftUI

extension ServerRail {
    // MARK: - Groups

    /// The rail's groups for the entries on screen (round 55): open servers, minimized servers
    /// under the hairline, and the recents from the project's saved connections.
    func layout(for entries: [ServerRailEntry]) -> ServerRailLayout {
        let settings = projectStore.globalSettings
        var sessionIDs: [UUID] = []
        var pendingIDs: [UUID] = []
        var connectingIDs: Set<UUID> = []
        for entry in entries {
            switch entry {
            case .session:
                sessionIDs.append(entry.connectionID)
            case .pending:
                pendingIDs.append(entry.connectionID)
                if entry.status == .connecting { connectingIDs.insert(entry.connectionID) }
            }
        }

        let projectID = projectStore.selectedProject?.id
        let savedIDs = Set(connectionStore.connections.filter { $0.projectID == projectID }.map(\.id))
        return ServerRailLayout(
            sessionIDs: sessionIDs,
            pendingIDs: pendingIDs,
            minimizedIDs: bridge.minimizedConnectionIDs,
            recentCandidates: environmentState.recentConnections.map(\.id).filter { savedIDs.contains($0) },
            connectingFromRecents: connectingRecentIDs.intersection(connectingIDs),
            showsRecents: settings.showsRecentServers && appState.welcomeDeparture != .leaving,
            recentLimit: settings.recentServerCount.rawValue
        )
    }

    /// The entries in the order the connected pill draws them. A connection that is staying in
    /// the recents while it connects is not among them.
    func orderedEntries(_ entries: [ServerRailEntry], in layout: ServerRailLayout) -> [ServerRailEntry] {
        let byID = Dictionary(entries.map { ($0.connectionID, $0) }, uniquingKeysWith: { first, _ in first })
        return layout.connectedIDs.compactMap { byID[$0] }
    }

    /// Forgets recents that are no longer connecting: they connected, failed or were cancelled.
    func pruneConnectingRecents(in entries: [ServerRailEntry]) {
        let stillConnecting = Set(entries.filter { entry in
            if case .pending = entry { return entry.status == .connecting }
            return false
        }.map(\.connectionID))
        let pruned = connectingRecentIDs.intersection(stillConnecting)
        // A click is in the set before its pending connection exists; leave those alone.
        let justClicked = connectingRecentIDs.filter { id in !entries.contains { $0.connectionID == id } }
        let next = pruned.union(justClicked)
        if next != connectingRecentIDs { connectingRecentIDs = next }
    }
}
