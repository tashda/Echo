import SwiftUI

/// Loading a folder's items: one entry point per source, so the tree never needs to know which
/// loader belongs to which folder.
extension ObjectBrowserSidebarView {
    /// Loads a folder's source unless it has already loaded or is loading.
    func loadIfNeeded(_ folder: ExplorerFolder) {
        guard let key = folder.sourceKey, viewModel.sourceState(key).needsLoad else { return }
        load(key, session: folder.session)
    }

    /// Loads (or reloads) a source.
    func load(_ key: ExplorerSourceKey, session: ConnectionSession) {
        switch key.source {
        case .serverSecurity:
            loadServerSecurity(session: session)
        case .databaseSnapshots:
            loadDatabaseSnapshots(session: session)
        case .agentJobs:
            loadAgentJobs(session: session)
        case .integrationServices:
            Task { await loadSSISFoldersAsync(session: session) }
        case .linkedServers:
            loadLinkedServers(session: session)
        case .serverTriggers:
            loadServerTriggers(session: session)
        case .databaseSecurity, .databaseTriggers, .serviceBroker, .externalResources:
            guard let database = session.databaseStructure?.databases.first(where: { $0.name == key.databaseName }) else { return }
            switch key.source {
            case .databaseSecurity: loadDatabaseSecurity(database: database, session: session)
            case .databaseTriggers: loadDatabaseDDLTriggers(database: database, session: session)
            case .serviceBroker: loadServiceBrokerData(database: database, session: session)
            default: loadExternalResources(database: database, session: session)
            }
        }
    }

    /// Loads the sources of folders that are already open, such as folders restored as open
    /// after a relaunch.
    func loadSourcesOfOpenFolders(in nodes: [ObjectBrowserNode]) {
        for node in nodes where viewModel.isExpanded(node.id) {
            switch node.row {
            case .section(let folder), .folder(let folder):
                loadIfNeeded(folder)
            default:
                break
            }
            loadSourcesOfOpenFolders(in: node.children)
        }
    }
}
