import Foundation
import Observation

/// A modular store that manages connections, folders, and identities.
/// Refactored from `EnvironmentState` to adhere to modular MVVM and under-500-line limits.
@Observable @MainActor
final class ConnectionStore {
    // MARK: - State
    var connections: [SavedConnection] = []
    var folders: [SavedFolder] = []
    var identities: [SavedIdentity] = []
    
    var selectedConnectionID: UUID?
    var selectedFolderID: UUID?
    var selectedIdentityID: UUID?
    var expandedConnectionFolderIDs: Set<UUID> = []
    
    // MARK: - Dependencies
    private let repository: any ConnectionRepositoryProtocol

    /// Called after any data change to notify the sync engine.
    /// Parameters: (objectID, collection, projectID, isDelete)
    @ObservationIgnored var onDataChanged: ((_ id: UUID, _ collection: SyncCollection, _ projectID: UUID, _ isDelete: Bool) -> Void)? {
        didSet { flushPendingSyncChanges() }
    }

    /// Changes made before sync was attached (the folder retirement on launch), sent once it is.
    @ObservationIgnored private var pendingSyncChanges: [(id: UUID, collection: SyncCollection, projectID: UUID, isDelete: Bool)] = []
    
    // MARK: - Initialization
    init(repository: any ConnectionRepositoryProtocol = ConnectionRepository()) {
        self.repository = repository
    }
    
    // MARK: - Public API
    
    var selectedConnection: SavedConnection? {
        guard let id = selectedConnectionID else { return nil }
        return connections.first { $0.id == id }
    }
    
    func load() async throws {
        self.connections = try await repository.loadConnections()
        self.folders = try await repository.loadFolders()
        self.identities = try await repository.loadIdentities()

        // Round MC: connection folders retire. Older data is turned into identities once.
        try await retireFolders()
        selectedFolderID = nil

        if selectedIdentityID == nil {
            selectedIdentityID = identities.first?.id
        }
    }
    
    func saveConnections() async throws {
        try await repository.saveConnections(connections)
    }
    
    func saveFolders() async throws {
        try await repository.saveFolders(folders)
    }
    
    func saveIdentities() async throws {
        try await repository.saveIdentities(identities)
    }
    
    /// Round MC, MC-0: moves inherited sign-ins to identities and removes connection folders
    /// (`FolderRetirement`). Runs after loading, after a sync pull and after importing from another
    /// project, so folders arriving from an older Echo are retired too. Does nothing on data
    /// without folders or inherited sign-ins.
    func retireFolders() async throws {
        let outcome = FolderRetirement.run(connections: connections, folders: folders, identities: identities)
        guard outcome.didChange else { return }

        connections = outcome.connections
        identities = outcome.identities
        folders = outcome.folders
        if let selected = selectedFolderID, !folders.contains(where: { $0.id == selected }) {
            selectedFolderID = nil
        }
        expandedConnectionFolderIDs = []

        try await saveIdentities()
        try await saveConnections()
        try await saveFolders()

        for identity in identities where outcome.changedIdentityIDs.contains(identity.id) {
            if let projectID = identity.projectID { notifySync(identity.id, .identities, projectID, isDelete: false) }
        }
        for connection in connections where outcome.changedConnectionIDs.contains(connection.id) {
            if let projectID = connection.projectID { notifySync(connection.id, .connections, projectID, isDelete: false) }
        }
        for folder in outcome.removedFolders {
            if let projectID = folder.projectID { notifySync(folder.id, .folders, projectID, isDelete: true) }
        }
    }

    private func notifySync(_ id: UUID, _ collection: SyncCollection, _ projectID: UUID, isDelete: Bool) {
        if let onDataChanged {
            onDataChanged(id, collection, projectID, isDelete)
        } else {
            pendingSyncChanges.append((id, collection, projectID, isDelete))
        }
    }

    private func flushPendingSyncChanges() {
        guard let onDataChanged, !pendingSyncChanges.isEmpty else { return }
        let pending = pendingSyncChanges
        pendingSyncChanges = []
        for change in pending {
            onDataChanged(change.id, change.collection, change.projectID, change.isDelete)
        }
    }

    func updateExpandedConnectionFolders(_ ids: Set<UUID>) {
        self.expandedConnectionFolderIDs = ids
    }
    
    // MARK: - CRUD
    
    func addConnection(_ connection: SavedConnection) async throws {
        connections.append(connection)
        try await saveConnections()
        if let projectID = connection.projectID {
            onDataChanged?(connection.id, .connections, projectID, false)
        }
    }

    func updateConnection(_ connection: SavedConnection) async throws {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        try await saveConnections()
        if let projectID = connection.projectID {
            onDataChanged?(connection.id, .connections, projectID, false)
        }
    }

    func deleteConnection(_ connection: SavedConnection) async throws {
        let projectID = connection.projectID
        connections.removeAll { $0.id == connection.id }
        try await saveConnections()
        if let projectID {
            onDataChanged?(connection.id, .connections, projectID, true)
        }
    }

    func deleteFolder(_ folder: SavedFolder) async throws {
        let projectID = folder.projectID
        folders.removeAll { $0.id == folder.id }
        try await saveFolders()
        if let projectID {
            onDataChanged?(folder.id, .folders, projectID, true)
        }
    }

    func updateFolder(_ folder: SavedFolder) async throws {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
        } else {
            folders.append(folder)
        }
        try await saveFolders()
        if let projectID = folder.projectID {
            onDataChanged?(folder.id, .folders, projectID, false)
        }
    }

    func updateIdentity(_ identity: SavedIdentity) async throws {
        if let index = identities.firstIndex(where: { $0.id == identity.id }) {
            identities[index] = identity
        } else {
            identities.append(identity)
        }
        try await saveIdentities()
        if let projectID = identity.projectID {
            onDataChanged?(identity.id, .identities, projectID, false)
        }
    }

    func deleteIdentity(_ identity: SavedIdentity) async throws {
        let projectID = identity.projectID
        identities.removeAll { $0.id == identity.id }
        try await saveIdentities()
        if let projectID {
            onDataChanged?(identity.id, .identities, projectID, true)
        }
    }
}
