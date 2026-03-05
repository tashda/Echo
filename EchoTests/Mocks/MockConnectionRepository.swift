import Foundation
@testable import Echo

final class MockConnectionRepository: ConnectionRepositoryProtocol, @unchecked Sendable {
    // MARK: - In-Memory Storage

    var connections: [SavedConnection] = []
    var folders: [SavedFolder] = []
    var identities: [SavedIdentity] = []

    // MARK: - Call Tracking

    var loadConnectionsCallCount = 0
    var saveConnectionsCallCount = 0
    var loadFoldersCallCount = 0
    var saveFoldersCallCount = 0
    var loadIdentitiesCallCount = 0
    var saveIdentitiesCallCount = 0

    // MARK: - Error Injection

    var loadConnectionsError: Error?
    var saveConnectionsError: Error?
    var loadFoldersError: Error?
    var saveFoldersError: Error?
    var loadIdentitiesError: Error?
    var saveIdentitiesError: Error?

    // MARK: - ConnectionRepositoryProtocol

    func loadConnections() async throws -> [SavedConnection] {
        loadConnectionsCallCount += 1
        if let error = loadConnectionsError { throw error }
        return connections
    }

    func saveConnections(_ connections: [SavedConnection]) async throws {
        saveConnectionsCallCount += 1
        if let error = saveConnectionsError { throw error }
        self.connections = connections
    }

    func loadFolders() async throws -> [SavedFolder] {
        loadFoldersCallCount += 1
        if let error = loadFoldersError { throw error }
        return folders
    }

    func saveFolders(_ folders: [SavedFolder]) async throws {
        saveFoldersCallCount += 1
        if let error = saveFoldersError { throw error }
        self.folders = folders
    }

    func loadIdentities() async throws -> [SavedIdentity] {
        loadIdentitiesCallCount += 1
        if let error = loadIdentitiesError { throw error }
        return identities
    }

    func saveIdentities(_ identities: [SavedIdentity]) async throws {
        saveIdentitiesCallCount += 1
        if let error = saveIdentitiesError { throw error }
        self.identities = identities
    }
}
