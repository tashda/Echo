import Foundation

/// Protocol defining the contract for managing connection, folder, and identity data.
protocol ConnectionRepositoryProtocol: Sendable {
    func loadConnections() async throws -> [SavedConnection]
    func saveConnections(_ connections: [SavedConnection]) async throws
    
    func loadFolders() async throws -> [SavedFolder]
    func saveFolders(_ folders: [SavedFolder]) async throws
    
    func loadIdentities() async throws -> [SavedIdentity]
    func saveIdentities(_ identities: [SavedIdentity]) async throws
}
