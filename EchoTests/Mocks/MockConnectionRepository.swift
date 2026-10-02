import Foundation
@testable import Echo

final class MockConnectionRepository: ConnectionRepositoryProtocol, @unchecked Sendable {
    // MARK: - In-Memory Storage

    var connections: [SavedConnection] = []
    var identities: [SavedIdentity] = []

    // MARK: - Call Tracking

    var loadConnectionsCallCount = 0
    var saveConnectionsCallCount = 0
    var loadIdentitiesCallCount = 0
    var saveIdentitiesCallCount = 0

    // MARK: - Error Injection

    var loadConnectionsError: Error?
    var saveConnectionsError: Error?
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
