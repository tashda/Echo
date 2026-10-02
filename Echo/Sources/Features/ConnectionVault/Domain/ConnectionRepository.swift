import Foundation

/// Implementation of the `ConnectionRepositoryProtocol` using disk-based storage.
final class ConnectionRepository: ConnectionRepositoryProtocol {
    private let connectionStore: ConnectionDiskStore
    private let identityStore: IdentityDiskStore
    
    init(
        connectionStore: ConnectionDiskStore = ConnectionDiskStore(),
        identityStore: IdentityDiskStore = IdentityDiskStore()
    ) {
        self.connectionStore = connectionStore
        self.identityStore = identityStore
    }
    
    func loadConnections() async throws -> [SavedConnection] {
        try await connectionStore.load()
    }
    
    func saveConnections(_ connections: [SavedConnection]) async throws {
        try await connectionStore.save(connections)
    }
    
    func loadIdentities() async throws -> [SavedIdentity] {
        try await identityStore.load()
    }
    
    func saveIdentities(_ identities: [SavedIdentity]) async throws {
        try await identityStore.save(identities)
    }
}
