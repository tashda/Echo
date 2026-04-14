import Foundation

extension ExperimentalObjectBrowserSidebarViewModel {
    private static let sidebarStateDefaultsKey = "experimentalObjectBrowser.sidebarStateByProject"

    struct PersistedSidebarState: Codable {
        let expandedNodeIDs: [String]
        let initializedConnectionIDs: [UUID]
    }

    func restoreExpansionState(projectID: UUID?, sessions: [ConnectionSession]) {
        let payloads = loadPersistedStatePayloads()
        let storageKey = persistenceStorageKey(for: projectID)
        guard let payload = payloads[storageKey] else {
            initializedConnectionIDs = []
            expandedNodeIDs = []
            return
        }

        let sessionIDs = Set(sessions.map(\.connection.id))
        let restoredInitialized = Set(payload.initializedConnectionIDs).intersection(sessionIDs)
        initializedConnectionIDs = restoredInitialized

        let validPrefixes = restoredInitialized.map { $0.uuidString }
        expandedNodeIDs = Set(
            payload.expandedNodeIDs.filter { nodeID in
                validPrefixes.contains(where: { nodeID.hasPrefix($0) })
            }
        )
    }

    func persistExpansionState(projectID: UUID?) {
        var payloads = loadPersistedStatePayloads()
        let storageKey = persistenceStorageKey(for: projectID)

        payloads[storageKey] = PersistedSidebarState(
            expandedNodeIDs: Array(expandedNodeIDs).sorted(),
            initializedConnectionIDs: Array(initializedConnectionIDs).sorted { $0.uuidString < $1.uuidString }
        )

        guard let encoded = try? JSONEncoder().encode(payloads) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.sidebarStateDefaultsKey)
    }

    private func persistenceStorageKey(for projectID: UUID?) -> String {
        projectID?.uuidString ?? "global"
    }

    private func loadPersistedStatePayloads() -> [String: PersistedSidebarState] {
        guard let data = UserDefaults.standard.data(forKey: Self.sidebarStateDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: PersistedSidebarState].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
