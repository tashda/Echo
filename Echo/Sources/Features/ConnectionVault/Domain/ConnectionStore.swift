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
        
        // Default selections if none exist
        if selectedFolderID == nil {
            selectedFolderID = folders.first(where: { $0.kind == .connections })?.id
        }
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
    
    func updateExpandedConnectionFolders(_ ids: Set<UUID>) {
        self.expandedConnectionFolderIDs = ids
    }
    
    // MARK: - CRUD
    
    func addConnection(_ connection: SavedConnection) async throws {
        connections.append(connection)
        try await saveConnections()
    }
    
    func updateConnection(_ connection: SavedConnection) async throws {
        guard let index = connections.firstIndex(where: { $0.id == connection.id }) else { return }
        connections[index] = connection
        try await saveConnections()
    }
    
    func deleteConnection(_ connection: SavedConnection) async throws {
        connections.removeAll { $0.id == connection.id }
        try await saveConnections()
    }
    
    func deleteFolder(_ folder: SavedFolder) async throws {
        folders.removeAll { $0.id == folder.id }
        try await saveFolders()
    }
    
    func updateFolder(_ folder: SavedFolder) async throws {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
        } else {
            folders.append(folder)
        }
        try await saveFolders()
    }
    
    func updateIdentity(_ identity: SavedIdentity) async throws {
        if let index = identities.firstIndex(where: { $0.id == identity.id }) {
            identities[index] = identity
        } else {
            identities.append(identity)
        }
        try await saveIdentities()
    }
    
    func deleteIdentity(_ identity: SavedIdentity) async throws {
        identities.removeAll { $0.id == identity.id }
        try await saveIdentities()
    }
}
