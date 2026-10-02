import Foundation
import Observation

/// A modular store that manages connections and identities (round MC: no folders).
/// Refactored from `EnvironmentState` to adhere to modular MVVM and under-500-line limits.
@Observable @MainActor
final class ConnectionStore {
    // MARK: - State
    var connections: [SavedConnection] = []
    var identities: [SavedIdentity] = []
    
    var selectedConnectionID: UUID?
    var selectedIdentityID: UUID?
    
    // MARK: - Dependencies
    private let repository: any ConnectionRepositoryProtocol

    /// Called after any data change to notify the sync engine.
    /// Parameters: (objectID, collection, projectID, isDelete)
    var onDataChanged: ((_ id: UUID, _ collection: SyncCollection, _ projectID: UUID, _ isDelete: Bool) -> Void)?
    
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
        self.identities = try await repository.loadIdentities()

        if selectedIdentityID == nil {
            selectedIdentityID = identities.first?.id
        }
    }
    
    func saveConnections() async throws {
        try await repository.saveConnections(connections)
    }
    
    func saveIdentities() async throws {
        try await repository.saveIdentities(identities)
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
